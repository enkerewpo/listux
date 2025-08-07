import Foundation
import SwiftData

@Model
final class FavoriteMessage {
    var id: UUID
    var messageId: String
    var subject: String
    var author: String
    var timestamp: Date
    var permalink: String
    var rawUrl: String
    var tags: [String]
    var mailingListName: String
    var seqId: Int
    var createdAt: Date
    
    init() {
        self.id = UUID()
        self.messageId = ""
        self.subject = ""
        self.author = ""
        self.timestamp = Date()
        self.permalink = ""
        self.rawUrl = ""
        self.tags = []
        self.mailingListName = ""
        self.seqId = 0
        self.createdAt = Date()
    }
    
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
        }
    }
    
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
    
    func hasTag(_ tag: String) -> Bool {
        return tags.contains(tag)
    }
} 