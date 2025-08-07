import SwiftUI

struct FavoritesView: View {
  let preference: Preference
  let allMailingLists: [MailingList]
  @State private var selectedTag: String? = nil
  let favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    List {
      ForEach(favoriteMessageService.getAllTags(), id: \.self) { tag in
        NavigationLink(
          destination: FavoritesMessageView(
            tag: tag, preference: preference, allMailingLists: allMailingLists)
        ) {
          Text(tag)
        }
      }
      if !favoriteMessageService.getUntaggedMessages().isEmpty {
        NavigationLink(
          destination: FavoritesMessageView(
            tag: "Untagged", preference: preference, allMailingLists: allMailingLists)
        ) {
          Text("Untagged")
        }
      }
    }
    .navigationTitle("Tags")
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }
}

struct FavoritesMessageView: View {
  let tag: String
  let preference: Preference
  let allMailingLists: [MailingList]
  @State private var messages: [Message] = []
  let favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    MessageListView(
      messages: messages,
      title: tag,
      isLoading: false
    )
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
      loadMessages()
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
    }
  }

  private func loadMessages() {
    let messageIds: [String]
    if tag == "Untagged" {
      messageIds = favoriteMessageService.getUntaggedMessages()
    } else {
      messageIds = favoriteMessageService.getMessagesWithTag(tag)
    }

    var messageSet = Set<String>()
    var uniqueMessages: [Message] = []

    for list in allMailingLists {
      for message in list.messages {
        if messageIds.contains(message.messageId) && !messageSet.contains(message.messageId) {
          messageSet.insert(message.messageId)
          // Sync the message with persistent storage
          favoriteMessageService.syncMessageWithPersistentStorage(message)
          uniqueMessages.append(message)
        }
      }
    }

    messages = uniqueMessages.sorted { $0.timestamp > $1.timestamp }
  }
}
