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
      list.name.localizedCaseInsensitiveContains(searchText) ||
      list.desc.localizedCaseInsensitiveContains(searchText)
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
  @State private var messages: [Message] = []
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
    SimpleMessageListView(
      messages: messages,
      title: mailingList.name,
      isLoading: isLoading
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
          isLoading = false
        }
      } catch {
        await MainActor.run {
          isLoading = false
        }
      }
    }
  }
}
