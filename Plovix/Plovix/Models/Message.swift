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
    
    init(subject: String, content: String, timestamp: Date = Date()) {
        self.subject = subject
        self.content = content
        self.timestamp = timestamp
        self.replies = []
        self.parent = nil
    }
}
