import Foundation
import SwiftData

@Model
final class MailingList: Identifiable {

  var id: UUID
  var name: String
  var desc: String
  var isPinned: Bool = false
  
  @Relationship(deleteRule: .cascade) var messages: [Message] = []
  // Store messages in loaded order for UI display (not persisted)
  var orderedMessages: [Message] = []

  init(name: String, desc: String, isPinned: Bool = false) {
    self.id = UUID()
    self.name = name
    self.desc = desc
    self.isPinned = isPinned
  }
}
