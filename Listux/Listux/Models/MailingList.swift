import Foundation

// Non-persistent MailingList model - only stored in memory
final class MailingList: Identifiable, Equatable, Hashable {

  var id: UUID
  var name: String
  var desc: String
  var isPinned: Bool = false

  // Non-persistent messages array
  var messages: [Message] = []
  // Store ordered message IDs for in-memory ordering
  var orderedMessageIds: [String] = []

  init(name: String, desc: String, isPinned: Bool = false) {
    self.id = UUID()
    self.name = name
    self.desc = desc
    self.isPinned = isPinned
  }

  // Equatable conformance
  static func == (lhs: MailingList, rhs: MailingList) -> Bool {
    return lhs.id == rhs.id
  }

  // Hashable conformance
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // Computed property to get ordered messages
  var orderedMessages: [Message] {
    let messageDict = Dictionary(uniqueKeysWithValues: messages.map { ($0.messageId, $0) })
    
    // Remove duplicates from orderedMessageIds while preserving order
    var seenIds = Set<String>()
    var uniqueOrderedIds: [String] = []
    
    for messageId in orderedMessageIds {
      if !seenIds.contains(messageId) {
        seenIds.insert(messageId)
        uniqueOrderedIds.append(messageId)
      }
    }
    
    let ordered = uniqueOrderedIds.compactMap { messageDict[$0] }
    
    // Debug logging to track order changes
    print("MailingList '\(name)' orderedMessages: \(ordered.count) messages")
    for (index, message) in ordered.enumerated() {
      print("  [\(index)] SeqID: \(message.seqId), Subject: \(message.subject)")
    }
    
    return ordered
  }

  // Method to update ordered messages
  func updateOrderedMessages(_ messages: [Message]) {
    print("Updating ordered messages for '\(name)': \(messages.count) messages")
    
    // Remove duplicates while preserving order
    var seenIds = Set<String>()
    var uniqueMessages: [Message] = []
    
    for message in messages {
      if !seenIds.contains(message.messageId) {
        seenIds.insert(message.messageId)
        uniqueMessages.append(message)
        print("  [\(uniqueMessages.count-1)] SeqID: \(message.seqId), Subject: \(message.subject)")
      } else {
        print("  Skipping duplicate message: \(message.messageId)")
      }
    }
    
    // Update both messages array and ordered IDs
    self.messages = uniqueMessages
    orderedMessageIds = uniqueMessages.map { $0.messageId }
  }
}
