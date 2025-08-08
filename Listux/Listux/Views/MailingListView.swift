import SwiftData
import SwiftUI

struct MailingListView: View {
  let mailingLists: [MailingList]
  let isLoading: Bool
  let onAppear: () -> Void
  @State private var selectedList: MailingList? = nil
  @State private var showMessages: Bool = false
  @State private var searchText: String = ""
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      try? modelContext.save()
      return new
    }
  }

  private var filteredLists: [MailingList] {
    if searchText.isEmpty {
      return mailingLists
    }
    return mailingLists.filter { list in
      list.name.localizedCaseInsensitiveContains(searchText)
        || list.desc.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var sortedLists: [MailingList] {
    let pinned = filteredLists.filter { $0.isPinned }.sorted { $0.name < $1.name }
    let unpinned = filteredLists.filter { !$0.isPinned }.sorted { $0.name < $1.name }
    return pinned + unpinned
  }

  var body: some View {
    VStack(spacing: 0) {
      // Search bar
      HStack {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
        TextField("Search mailing lists", text: $searchText)
          .textFieldStyle(.plain)
          .font(.system(size: 16))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 10)
          #if os(iOS)
            .fill(Color(.systemGray6))
          #else
            .fill(Color(.windowBackgroundColor))
          #endif
      )
      .padding(.horizontal, 16)
      .padding(.vertical, 8)

      // Mailing lists
      List(sortedLists, id: \.id) { list in
        HStack {
          NavigationLink(destination: MailingListMessageView(mailingList: list)) {
            VStack(alignment: .leading) {
              HStack {
                if list.isPinned {
                  Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                }
                Text(list.name)
                  .font(.headline)
              }
              Text(list.desc)
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }

          Spacer()

          Button(action: {
            withAnimation(AnimationConstants.springQuick) {
              preference.togglePinned(list)
            }
          }) {
            Image(systemName: list.isPinned ? "pin.fill" : "pin")
              .font(.caption)
              .foregroundColor(list.isPinned ? .orange : .secondary)
          }
          .buttonStyle(.plain)
        }
      }
      .listStyle(PlainListStyle())
    }
    .navigationTitle("Mailing Lists")
    .onAppear(perform: onAppear)
    .overlay(
      Group {
        if isLoading {
          ProgressView("Loading...")
        }
      }
    )
  }
}

struct MailingListMessageView: View {
  let mailingList: MailingList
  @State private var isLoading: Bool = false
  @State private var isLoadingMore: Bool = false
  @State private var messages: [Message] = []
  @State private var nextURL: String?
  @State private var hasReachedEnd: Bool = false
  @State private var selectedMessage: Message? = nil
  @State private var uiUpdateTrigger: Bool = false
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      return new
    }
  }

  var body: some View {
    NavigationStack {
      MessageListView(
        messages: messages,
        title: mailingList.name,
        isLoading: isLoading,
        onLoadMore: {
          await loadMoreMessages()
        },
        hasReachedEnd: hasReachedEnd,
        selectedMessage: $selectedMessage
      )
      .id(uiUpdateTrigger)  // Force view refresh when trigger changes
      .onAppear {
        if messages.isEmpty {
          loadMessages()
        }
      }
    }
    .sheet(item: $selectedMessage) { message in
      NavigationStack {
        MessageDetailView(selectedMessage: message)
          .navigationTitle("Message Detail")
          #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                  selectedMessage = nil
                }
              }
            }
          #endif
      }
    }
  }

  private func loadMessages() {
    guard !isLoading else { return }

    isLoading = true
    print("MailingListMessageView: Loading initial messages for \(mailingList.name)")

    Task {
      do {
        let html = try await NetworkService.shared.fetchListPage(mailingList.name)
        let result = Parser.parseMsgsFromListPage(
          from: html, mailingList: mailingList, startingSeqId: 0)
        await MainActor.run {
          messages = result.messages
          nextURL = result.nextURL
          hasReachedEnd = result.nextURL == nil
          isLoading = false
          print(
            "MailingListMessageView: Loaded \(result.messages.count) initial messages, hasReachedEnd: \(hasReachedEnd), nextURL: \(result.nextURL ?? "nil")"
          )
        }
      } catch {
        await MainActor.run {
          isLoading = false
          print("MailingListMessageView: Failed to load initial messages: \(error)")
        }
      }
    }
  }

  private func loadMoreMessages() async {
    print("MailingListMessageView: loadMoreMessages called")
    guard let nextURL = nextURL, !hasReachedEnd, !isLoadingMore else {
      print(
        "MailingListMessageView: Skipping loadMoreMessages - nextURL: \(nextURL != nil), hasReachedEnd: \(hasReachedEnd), isLoadingMore: \(isLoadingMore)"
      )
      return
    }

    isLoadingMore = true
    print("MailingListMessageView: Loading more messages from \(nextURL)")

    do {
      // Construct full URL from relative URL
      let fullURL: String
      if nextURL.hasPrefix("http") {
        fullURL = nextURL
      } else if nextURL.hasPrefix("/") {
        // Absolute path from root
        fullURL = "\(LORE_LINUX_BASE_URL.value)\(nextURL)"
      } else {
        // Relative path, append to current list URL
        fullURL = "\(LORE_LINUX_BASE_URL.value)/\(mailingList.name)/\(nextURL)"
      }

      print("MailingListMessageView: Fetching from full URL: \(fullURL)")
      let html = try await NetworkService.shared.fetchURL(fullURL)

      // Calculate starting seqId based on existing messages
      let startingSeqId = messages.isEmpty ? 0 : (messages.map { $0.seqId }.max() ?? -1) + 1
      let result = Parser.parseMsgsFromListPage(
        from: html, mailingList: mailingList, startingSeqId: startingSeqId)

      await MainActor.run {
        let _oldCount = messages.count
        let existingIds = Set(messages.map { $0.messageId })
        var messagesToAdd: [Message] = []

        for message in result.messages {
          if !existingIds.contains(message.messageId) {
            messagesToAdd.append(message)
            print(
              "  [\(messagesToAdd.count-1)] SeqID: \(message.seqId), Subject: \(message.subject)")
          } else {
            print("  Skipping duplicate message: \(message.messageId)")
          }
        }

        messages.append(contentsOf: messagesToAdd)
        self.nextURL = result.nextURL
        hasReachedEnd = result.nextURL == nil
        isLoadingMore = false

        // Force UI update
        mailingList.objectWillChange.send()

        // Trigger UI update
        uiUpdateTrigger.toggle()

        print(
          "MailingListMessageView: Loaded \(messagesToAdd.count) more messages (total: \(messages.count)), hasReachedEnd: \(hasReachedEnd), nextURL: \(result.nextURL ?? "nil")"
        )
      }
    } catch {
      await MainActor.run {
        isLoadingMore = false
        print("MailingListMessageView: Failed to load more messages: \(error)")
      }
    }
  }
}

struct MailingListItemView: View {
  let list: MailingList
  let isSelected: Bool
  let isPinned: Bool
  let onSelect: () -> Void
  let onPinToggle: () -> Void
  @State private var isHovered: Bool = false

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        // Pin indicator
        if isPinned {
          Image(systemName: "pin.fill")
            .font(.system(size: 10))
            .foregroundColor(.orange)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(list.name)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(1)
          Text(list.desc)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }

        Spacer()

        // Pin toggle button
        Button(action: onPinToggle) {
          Image(systemName: isPinned ? "pin.fill" : "pin")
            .font(.system(size: 11))
            .foregroundColor(isPinned ? .orange : .secondary)
            .scaleEffect(isPinned ? AnimationConstants.favoriteScale : 1.0)
        }
        .buttonStyle(.plain)
        .animation(AnimationConstants.springQuick, value: isPinned)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(
            isSelected
              ? Color.accentColor.opacity(0.15)
              : (isHovered ? Color.primary.opacity(0.08) : Color.clear)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
          )
      )
    }
    .buttonStyle(.plain)
    .onHover { hovering in
      isHovered = hovering
    }
    .animation(Animation.userPreferenceQuick, value: isSelected)
    .animation(Animation.userPreferenceQuick, value: isHovered)
  }
}
