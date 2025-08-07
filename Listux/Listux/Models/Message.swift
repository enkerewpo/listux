import Foundation

// Non-persistent Message model - only stored in memory
final class Message: Identifiable, Hashable, ObservableObject {

  var id: UUID
  var subject: String
  var content: String
  var timestamp: Date
  var parent: Message?
  var replies: [Message] = []
  var mailingList: MailingList?
  var isExpanded: Bool = false
  var seqId: Int = 0
  var messageId: String = ""

  // Properties for detailed message parsing
  var author: String = ""
  var recipients: [String] = []
  var ccRecipients: [String] = []
  var rawHtml: String = ""
  var permalink: String = ""
  var rawUrl: String = ""

  // Favorite and tag properties (synced with persistent storage)
  @Published var isFavorite: Bool = false
  @Published var tags: [String] = []

  init(
    subject: String, content: String, timestamp: Date, parent: Message? = nil,
    seqId: Int = 0, messageId: String = ""
  ) {
    self.id = UUID()
    self.subject = subject
    self.content = content
    self.timestamp = timestamp
    self.parent = parent
    self.replies = []
    self.seqId = seqId
    self.messageId = messageId
  }

  // Hashable conformance
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // Equatable conformance
  static func == (lhs: Message, rhs: Message) -> Bool {
    return lhs.id == rhs.id
  }

  func addChild(message: Message) {
    replies.append(message)
  }

  func removeChild(message: Message) {
    replies.removeAll { $0.id == message.id }
  }

  func removeAllChildren() {
    replies.removeAll()
  }

  func addParent(message: Message) {
    parent = message
  }

  func removeParent() {
    parent = nil
  }

  // Methods for syncing with persistent storage
  @MainActor
  func syncWithPersistentStorage(_ favoriteMessage: FavoriteMessage?) {
    if let favoriteMessage = favoriteMessage {
      self.isFavorite = true
      self.tags = favoriteMessage.tags
    } else {
      self.isFavorite = false
      self.tags = []
    }
  }

  func toFavoriteMessage() -> FavoriteMessage? {
    guard !messageId.isEmpty && !subject.isEmpty else {
      print(
        "Message.toFavoriteMessage: messageId or subject is empty - messageId: '\(messageId)', subject: '\(subject)'"
      )
      return nil
    }

    print("Message.toFavoriteMessage: Creating favorite message for messageId: \(messageId)")

    let favoriteMessage = FavoriteMessage()
    favoriteMessage.messageId = messageId
    favoriteMessage.subject = subject
    favoriteMessage.author = author
    favoriteMessage.timestamp = timestamp
    favoriteMessage.permalink = permalink
    favoriteMessage.rawUrl = rawUrl
    favoriteMessage.tags = tags
    favoriteMessage.mailingListName = mailingList?.name ?? ""
    favoriteMessage.seqId = seqId

    print("Message.toFavoriteMessage: Created favorite message successfully")
    return favoriteMessage
  }
}

extension Message: CustomStringConvertible {
  var description: String {
    return
      "Message(subject: \(subject), content: \(content), timestamp: \(timestamp), parent: \(String(describing: parent?.messageId)), replies: \(replies.count), mailingList: \(String(describing: mailingList)), isExpanded: \(isExpanded), seqId: \(seqId), messageId: \(messageId))"
  }
}
