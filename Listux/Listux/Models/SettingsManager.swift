import SwiftData
import SwiftUI

@Observable
class SettingsManager {
  static let shared = SettingsManager()

  var shouldOpenSettings: Bool = false
  var onDataCleared: (() -> Void)?

  private init() {}

  func openSettings() {
    shouldOpenSettings = true
  }

  // Clear all local persistent data (favorites, tags, etc.)
  func clearAllData(modelContext: ModelContext) {
    do {
      // Clear Preference data (favorites, tags, preferences)
      let preferenceDescriptor = FetchDescriptor<Preference>()
      let preferences = try modelContext.fetch(preferenceDescriptor)
      for preference in preferences {
        modelContext.delete(preference)
      }

      // Reset all MailingList pin states
      let mailingListDescriptor = FetchDescriptor<MailingList>()
      let mailingLists = try modelContext.fetch(mailingListDescriptor)
      for list in mailingLists {
        list.isPinned = false
      }

      // Save changes
      try modelContext.save()

      print("All local persistent data has been cleared successfully")

      // Notify that data has been cleared
      DispatchQueue.main.async {
        self.onDataCleared?()
      }
    } catch {
      print("Failed to clear local data: \(error)")
    }
  }
}
