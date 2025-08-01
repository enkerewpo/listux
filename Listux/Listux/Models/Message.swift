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
  var messageId: String = ""

  // New properties for detailed message parsing
  var author: String = ""
  var recipients: [String] = []
  var ccRecipients: [String] = []
  var rawHtml: String = ""
  var permalink: String = ""
  var rawUrl: String = ""

  init(
    subject: String, content: String, timestamp: Date, parent: Message? = nil,
    seqId: Int = 0, messageId: String = ""
  ) {
    self.subject = subject
    self.content = content
    self.timestamp = timestamp
    self.parent = parent
    self.replies = []
    self.seqId = seqId
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
      "Message(subject: \(subject), content: \(content), timestamp: \(timestamp), parent: \(String(describing: parent?.messageId)), replies: \(replies.count), mailingList: \(String(describing: mailingList)), isExpanded: \(isExpanded), seqId: \(seqId), messageId: \(messageId))"
  }
}
