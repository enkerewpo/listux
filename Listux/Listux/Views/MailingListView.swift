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
    MessageListView(
      messages: messages,
      title: mailingList.name,
      isLoading: isLoading,
      onLoadMore: loadMoreMessages
    )
    .onAppear {
      loadMessages()
    }
  }

  private func loadMessages() {
    isLoading = true
    Task {
      do {
        let html = try await NetworkService.shared.fetchListPage(mailingList.name)
        let result = Parser.parseMsgsFromListPage(from: html, mailingList: mailingList)
        await MainActor.run {
          messages = result.messages
          nextURL = result.nextURL
          isLoading = false
        }
      } catch {
        await MainActor.run {
          isLoading = false
        }
      }
    }
  }
  
  private func loadMoreMessages() async {
    guard let nextURL = nextURL, !hasReachedEnd else {
      return
    }
    
    do {
      let html = try await NetworkService.shared.fetchURL(nextURL)
      let result = Parser.parseMsgsFromListPage(from: html, mailingList: mailingList)
      
      await MainActor.run {
        messages.append(contentsOf: result.messages)
        self.nextURL = result.nextURL
        if result.nextURL == nil {
          hasReachedEnd = true
        }
      }
    } catch {
      print("Failed to load more messages: \(error)")
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
