import SwiftData
import SwiftUI

extension Notification.Name {
  static let dataCleared = Notification.Name("dataCleared")
}

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
      LogManager.shared.info("SettingsManager: Starting to clear all local data")

      // Clear Preference data (favorites, tags, preferences)
      let preferenceDescriptor = FetchDescriptor<Preference>()
      let preferences = try modelContext.fetch(preferenceDescriptor)
      LogManager.shared.info("SettingsManager: Found \(preferences.count) preferences to delete")
      for preference in preferences {
        modelContext.delete(preference)
      }

      // Clear FavoriteMessage data
      let favoriteMessageDescriptor = FetchDescriptor<FavoriteMessage>()
      let favoriteMessages = try modelContext.fetch(favoriteMessageDescriptor)
      LogManager.shared.info(
        "SettingsManager: Found \(favoriteMessages.count) favorite messages to delete")
      for favoriteMessage in favoriteMessages {
        modelContext.delete(favoriteMessage)
      }

      // Save changes
      try modelContext.save()

      LogManager.shared.info(
        "SettingsManager: All local persistent data has been cleared successfully")

      // Verify that data was actually cleared
      let verifyPreferenceDescriptor = FetchDescriptor<Preference>()
      let verifyFavoriteMessageDescriptor = FetchDescriptor<FavoriteMessage>()

      do {
        let remainingPreferences = try modelContext.fetch(verifyPreferenceDescriptor)
        let remainingFavorites = try modelContext.fetch(verifyFavoriteMessageDescriptor)
        LogManager.shared.info(
          "SettingsManager: Verification - \(remainingPreferences.count) preferences and \(remainingFavorites.count) favorite messages remaining"
        )
      } catch {
        LogManager.shared.error("SettingsManager: Error verifying data clearing: \(error)")
      }

      // Also clear UserDefaults for preferences
      UserDefaults.standard.removeObject(forKey: "baseURL")
      UserDefaults.standard.removeObject(forKey: "animationsEnabled")
      UserDefaults.standard.removeObject(forKey: "animationSpeed")
      UserDefaults.standard.removeObject(forKey: "autoRefreshEnabled")
      UserDefaults.standard.removeObject(forKey: "autoRefreshInterval")
      LogManager.shared.info("SettingsManager: Cleared UserDefaults preferences")

      // Notify that data has been cleared
      DispatchQueue.main.async {
        NotificationCenter.default.post(name: .dataCleared, object: nil)
        self.onDataCleared?()
      }
    } catch {
      LogManager.shared.error("SettingsManager: Failed to clear local data: \(error)")
    }
  }
}
