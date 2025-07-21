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
  /// Sequential id for UI rendering order, assigned during parsing
  var seqId: Int = 0
  /// Whether the message is marked as favorite (local only)
  var isFavorite: Bool = false

  init(
    subject: String, content: String, timestamp: Date = Date(), parent: Message? = nil,
    seqId: Int = 0, isFavorite: Bool = false
  ) {
    self.subject = subject
    self.content = content
    self.timestamp = timestamp
    self.parent = parent
    self.replies = []
    self.seqId = seqId
    self.isFavorite = isFavorite
  }
}
