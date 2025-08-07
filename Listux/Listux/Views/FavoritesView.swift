import SwiftUI

struct FavoritesView: View {
  let preference: Preference
  @State private var selectedTag: String? = nil
  @State private var refreshTrigger: Bool = false
  @State private var forceRefresh: Bool = false
  let favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    List {
      ForEach(favoriteMessageService.getAllTags(), id: \.self) { tag in
        NavigationLink(
          destination: FavoritesMessageView(
            tag: tag, preference: preference)
        ) {
          Text(tag)
        }
      }
      if !favoriteMessageService.getUntaggedMessages().isEmpty {
        NavigationLink(
          destination: FavoritesMessageView(
            tag: "Untagged", preference: preference)
        ) {
          Text("Untagged")
        }
      }
    }
    .navigationTitle("Tags")
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
      favoriteMessageService.verifyPersistence()
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
      favoriteMessageService.verifyPersistence()
    }
    .onReceive(NotificationCenter.default.publisher(for: .dataCleared)) { _ in
      refreshTrigger.toggle()
      forceRefresh.toggle()
      favoriteMessageService.setModelContext(modelContext)
      favoriteMessageService.verifyPersistence()
    }
    .id(forceRefresh)  // Force view refresh when data is cleared
  }
}

struct FavoritesMessageView: View {
  let tag: String
  let preference: Preference
  @State private var messages: [Message] = []
  @State private var isLoading: Bool = false
  @State private var refreshTrigger: Bool = false
  @State private var forceRefresh: Bool = false
  let favoriteMessageService = FavoriteMessageService.shared
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    MessageListView(
      messages: messages,
      title: tag,
      isLoading: isLoading,
      onLoadMore: nil
    )
    .onAppear {
      favoriteMessageService.setModelContext(modelContext)
      favoriteMessageService.verifyPersistence()
      loadMessages()
    }
    .task {
      favoriteMessageService.setModelContext(modelContext)
      favoriteMessageService.verifyPersistence()
      loadMessages()
    }
    .onReceive(NotificationCenter.default.publisher(for: .dataCleared)) { _ in
      refreshTrigger.toggle()
      forceRefresh.toggle()
      favoriteMessageService.setModelContext(modelContext)
      favoriteMessageService.verifyPersistence()
      loadMessages()
    }
    .id(forceRefresh)  // Force view refresh when data is cleared
  }

  private func loadMessages() {
    print("FavoritesMessageView: Loading messages for tag '\(tag)'")
    isLoading = true

    // Ensure we have the latest data from persistent storage
    favoriteMessageService.setModelContext(modelContext)

    let messageIds: [String]
    if tag == "Untagged" {
      messageIds = favoriteMessageService.getUntaggedMessages()
    } else {
      messageIds = favoriteMessageService.getMessagesWithTag(tag)
    }

    print("FavoritesMessageView: Found \(messageIds.count) message IDs for tag '\(tag)'")

    // Create messages directly from FavoriteMessage data
    var createdMessages: [Message] = []

    for messageId in messageIds {
      if let favoriteMessage = favoriteMessageService.getFavoriteMessage(messageId: messageId) {
        let message = Message(
          subject: favoriteMessage.subject,
          content: "",  // We don't store content in FavoriteMessage
          timestamp: favoriteMessage.timestamp,
          seqId: favoriteMessage.seqId,
          messageId: favoriteMessage.messageId
        )
        message.author = favoriteMessage.author
        message.permalink = favoriteMessage.permalink
        message.rawUrl = favoriteMessage.rawUrl
        message.isFavorite = true
        message.tags = favoriteMessage.tags

        // Create a dummy mailing list for the message
        let mailingList = MailingList(name: favoriteMessage.mailingListName, desc: "")
        message.mailingList = mailingList

        createdMessages.append(message)
      }
    }

    messages = createdMessages.sorted { $0.timestamp > $1.timestamp }
    isLoading = false

    print("FavoritesMessageView: Loaded \(messages.count) messages for tag '\(tag)'")
  }
}
