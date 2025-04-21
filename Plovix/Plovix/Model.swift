import Foundation
import SwiftData

@Model
final class MailingList {
    var name: String
    var desc: String
    @Relationship(deleteRule: .cascade) var messages: [Message]
    
    init(name: String, desc: String) {
        self.name = name
        self.desc = desc
        self.messages = []
    }
}

@Model
final class Message {
    var id: String
    var subject: String
    var author: String
    var date: Date
    var content: String
    var url: String
    var parent: Message?
    @Relationship(deleteRule: .cascade) var replies: [Message]
    
    init(subject: String, author: String, date: Date, content: String, url: String) {
        self.id = url
        self.subject = subject
        self.author = author
        self.date = date
        self.content = content
        self.url = url
        self.replies = []
    }
} 