import SwiftUI

struct FavoritesView: View {
  let preference: Preference
  let allMailingLists: [MailingList]
  @State private var selectedTag: String? = nil

  var body: some View {
    List {
      ForEach(preference.getAllTags(), id: \ .self) { tag in
        NavigationLink(destination: FavoritesMessageListView(tag: tag, preference: preference, allMailingLists: allMailingLists)) {
          Text(tag)
        }
      }
      if !preference.getUntaggedMessages().isEmpty {
        NavigationLink(destination: FavoritesMessageListView(tag: "Untagged", preference: preference, allMailingLists: allMailingLists)) {
          Text("Untagged")
        }
      }
    }
    .navigationTitle("Tags")
  }
}

struct FavoritesMessageListView: View {
  let tag: String
  let preference: Preference
  let allMailingLists: [MailingList]
  @State private var messages: [Message] = []

  var body: some View {
    List(messages, id: \ .messageId) { message in
      NavigationLink(destination: MessageDetailView(selectedMessage: message)) {
        VStack(alignment: .leading) {
          Text(message.subject)
            .font(.headline)
          Text(message.timestamp, style: .date)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .navigationTitle(tag)
    .onAppear {
      loadMessages()
    }
  }

  private func loadMessages() {
    let messageIds: [String]
    if tag == "Untagged" {
      messageIds = preference.getUntaggedMessages()
    } else {
      messageIds = preference.getMessagesWithTag(tag)
    }
    var allMessages: [Message] = []
    for list in allMailingLists {
      allMessages.append(contentsOf: list.messages)
    }
    messages = allMessages.filter { messageIds.contains($0.messageId) }
      .sorted { $0.timestamp > $1.timestamp }
  }
} 