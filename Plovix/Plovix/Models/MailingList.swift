import Foundation
import SwiftData

@Model
final class MailingList: Identifiable {
  var id: UUID
  var name: String
  var desc: String
  @Relationship(deleteRule: .cascade) var messages: [Message] = []

  init(name: String, desc: String) {
    self.id = UUID()
    self.name = name
    self.desc = desc
  }
}
