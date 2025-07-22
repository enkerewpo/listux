import Foundation
import SwiftData

@Model
final class Message {

  var subject: String
  var content: String
  var timestamp: Date
  var parent: Message?
  @Relationship(deleteRule: .cascade) var replies: [Message]
  @Relationship(inverse: \MailingList.messages) var mailingList: MailingList?
  var isExpanded: Bool = false
  var seqId: Int = 0
  var isFavorite: Bool = false
  var messageId: String = ""

  init(
    subject: String, content: String, timestamp: Date, parent: Message? = nil,
    seqId: Int = 0, isFavorite: Bool = false, messageId: String = ""
  ) {
    self.subject = subject
    self.content = content
    self.timestamp = timestamp
    self.parent = parent
    self.replies = []
    self.seqId = seqId
    self.isFavorite = isFavorite
    self.messageId = messageId
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
}

extension Message: CustomStringConvertible {
  var description: String {
    return
      "Message(subject: \(subject), content: \(content), timestamp: \(timestamp), parent: \(String(describing: parent)), replies: \(replies.count), mailingList: \(String(describing: mailingList)), isExpanded: \(isExpanded), seqId: \(seqId), isFavorite: \(isFavorite), messageId: \(messageId))"
  }
}
