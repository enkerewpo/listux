import Foundation
import SwiftData

@Model
final class MailingList {
  var name: String
  var desc: String
  @Relationship(deleteRule: .cascade) var messages: [Message] = []

  init(name: String, desc: String) {
    self.name = name
    self.desc = desc
  }
}
