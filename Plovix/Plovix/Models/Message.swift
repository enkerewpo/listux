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

  init(subject: String, content: String, timestamp: Date = Date(), parent: Message? = nil) {
    self.subject = subject
    self.content = content
    self.timestamp = timestamp
    self.parent = parent
    self.replies = []
  }
}
