import SwiftUI

struct FavoritesView: View {
  let preference: Preference
  let allMailingLists: [MailingList]
  @State private var selectedTag: String? = nil

  var body: some View {
    List {
      ForEach(preference.getAllTags(), id: \.self) { tag in
        NavigationLink(
          destination: FavoritesMessageView(
            tag: tag, preference: preference, allMailingLists: allMailingLists)
        ) {
          Text(tag)
        }
      }
      if !preference.getUntaggedMessages().isEmpty {
        NavigationLink(
          destination: FavoritesMessageView(
            tag: "Untagged", preference: preference, allMailingLists: allMailingLists)
        ) {
          Text("Untagged")
        }
      }
    }
    .navigationTitle("Tags")
  }
}

struct FavoritesMessageView: View {
  let tag: String
  let preference: Preference
  let allMailingLists: [MailingList]
  @State private var messages: [Message] = []

  var body: some View {
    MessageListView(
      messages: messages,
      title: tag,
      isLoading: false
    )
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

    var messageSet = Set<String>()
    var uniqueMessages: [Message] = []

    for list in allMailingLists {
      for message in list.messages {
        if messageIds.contains(message.messageId) && !messageSet.contains(message.messageId) {
          messageSet.insert(message.messageId)
          uniqueMessages.append(message)
        }
      }
    }

    messages = uniqueMessages.sorted { $0.timestamp > $1.timestamp }
  }
}
