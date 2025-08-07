import Foundation

// Non-persistent MailingList model - only stored in memory
final class MailingList: Identifiable, Equatable, Hashable, ObservableObject {

  var id: UUID
  var name: String
  var desc: String
  var isPinned: Bool = false

  // Non-persistent messages array
  @Published var messages: [Message] = []
  // Store ordered message IDs for in-memory ordering
  @Published var orderedMessageIds: [String] = []

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

  // Method to append new messages (for pagination)
  func appendOrderedMessages(_ newMessages: [Message]) {
    print("Appending ordered messages for '\(name)': \(newMessages.count) new messages")
    print("Current messages count: \(messages.count)")
    print("Current orderedMessageIds count: \(orderedMessageIds.count)")

    let existingIds = Set(messages.map { $0.messageId })
    print("Existing message IDs: \(existingIds.count)")

    var messagesToAdd: [Message] = []

    for message in newMessages {
      print("Checking message: \(message.messageId) - \(message.subject)")
      if !existingIds.contains(message.messageId) {
        messagesToAdd.append(message)
        print("  [\(messagesToAdd.count-1)] SeqID: \(message.seqId), Subject: \(message.subject)")
      } else {
        print("  Skipping duplicate message: \(message.messageId)")
      }
    }

    if !messagesToAdd.isEmpty {
      // Append new messages to existing ones
      self.messages.append(contentsOf: messagesToAdd)
      self.orderedMessageIds.append(contentsOf: messagesToAdd.map { $0.messageId })
      print("  Total messages after append: \(self.messages.count)")
      print("  Total orderedMessageIds after append: \(self.orderedMessageIds.count)")
      print("  Last few orderedMessageIds: \(self.orderedMessageIds.suffix(5))")
    } else {
      print("  No new messages to add")
    }
  }
}
