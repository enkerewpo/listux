import Foundation

struct MessageDiff {
    let filePath: String
    let additions: [DiffLine]
    let deletions: [DiffLine]
    let context: [DiffLine]
    
    init(filePath: String, additions: [DiffLine] = [], deletions: [DiffLine] = [], context: [DiffLine] = []) {
        self.filePath = filePath
        self.additions = additions
        self.deletions = deletions
        self.context = context
    }
}

struct DiffLine {
    let lineNumber: Int?
    let content: String
    let type: DiffLineType
    
    enum DiffLineType {
        case addition
        case deletion
        case context
        case header
    }
}

struct ThreadNavigation {
    let parentMessage: String?
    let childMessages: [String]
    let siblingMessages: [String]
    let threadStart: String?
    let threadEnd: String?
    
    init(parentMessage: String? = nil, childMessages: [String] = [], siblingMessages: [String] = [], threadStart: String? = nil, threadEnd: String? = nil) {
        self.parentMessage = parentMessage
        self.childMessages = childMessages
        self.siblingMessages = siblingMessages
        self.threadStart = threadStart
        self.threadEnd = threadEnd
    }
}

struct MessageMetadata {
    let author: String
    let date: Date
    let recipients: [String]
    let ccRecipients: [String]
    let subject: String
    let messageId: String
    let permalink: String
    let rawUrl: String
    
    init(author: String, date: Date, recipients: [String], ccRecipients: [String], subject: String, messageId: String, permalink: String, rawUrl: String) {
        self.author = author
        self.date = date
        self.recipients = recipients
        self.ccRecipients = ccRecipients
        self.subject = subject
        self.messageId = messageId
        self.permalink = permalink
        self.rawUrl = rawUrl
    }
}

struct ParsedMessageDetail {
    let metadata: MessageMetadata
    let content: String
    let diffContent: [MessageDiff]
    let threadNavigation: ThreadNavigation?
    let rawHtml: String
    
    init(metadata: MessageMetadata, content: String, diffContent: [MessageDiff] = [], threadNavigation: ThreadNavigation? = nil, rawHtml: String = "") {
        self.metadata = metadata
        self.content = content
        self.diffContent = diffContent
        self.threadNavigation = threadNavigation
        self.rawHtml = rawHtml
    }
} 