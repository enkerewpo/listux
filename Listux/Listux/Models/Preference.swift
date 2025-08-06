import Foundation
import SwiftData
import SwiftUI

@Model
final class Preference {

  var favoriteLists: [String] = []  // Store list names instead of objects
  var pinnedLists: [String] = []    // Store list names instead of objects
  var favoriteMessageIds: [String] = []  // Store message IDs as strings for persistence
  var messageTags: [String: [String]] = [:]  // messageId -> [tag1, tag2, ...]
  var lastViewedList: String?       // Store list name instead of object

  init() {}

  func toggleFavorite(_ list: MailingList) {
    if favoriteLists.contains(list.name) {
      favoriteLists.removeAll { $0 == list.name }
    } else {
      favoriteLists.append(list.name)
    }
  }

  func isFavorite(_ list: MailingList) -> Bool {
    favoriteLists.contains(list.name)
  }

  func togglePinned(_ list: MailingList) {
    if pinnedLists.contains(list.name) {
      pinnedLists.removeAll { $0 == list.name }
      list.isPinned = false
    } else {
      pinnedLists.append(list.name)
      list.isPinned = true
    }
  }

  func isPinned(_ list: MailingList) -> Bool {
    pinnedLists.contains(list.name)
  }

  func toggleFavoriteMessage(_ messageId: String) {
    if favoriteMessageIds.contains(messageId) {
      favoriteMessageIds.removeAll { $0 == messageId }
      // Remove all tags for this message when unfavoriting
      messageTags.removeValue(forKey: messageId)
    } else {
      favoriteMessageIds.append(messageId)
    }
  }

  func isFavoriteMessage(_ messageId: String) -> Bool {
    favoriteMessageIds.contains(messageId)
  }

  // Tag management
  func addTag(_ tag: String, to messageId: String) {
    if !favoriteMessageIds.contains(messageId) {
      return  // Can only tag favorite messages
    }

    if messageTags[messageId] == nil {
      messageTags[messageId] = []
    }

    if !messageTags[messageId]!.contains(tag) {
      messageTags[messageId]!.append(tag)
    }
  }

  func removeTag(_ tag: String, from messageId: String) {
    messageTags[messageId]?.removeAll { $0 == tag }
  }

  func getTags(for messageId: String) -> [String] {
    return messageTags[messageId] ?? []
  }

  func getAllTags() -> [String] {
    let allTags = Set(messageTags.values.flatMap { $0 })
    return Array(allTags).sorted()
  }

  func getMessagesWithTag(_ tag: String) -> [String] {
    return messageTags.compactMap { messageId, tags in
      tags.contains(tag) ? messageId : nil
    }
  }

  func getUntaggedMessages() -> [String] {
    return favoriteMessageIds.filter { messageId in
      messageTags[messageId]?.isEmpty ?? true
    }
  }
}

@Observable
class UserPreferences {
  static let shared = UserPreferences()

  // Base URL settings
  var baseURL: String {
    didSet {
      UserDefaults.standard.set(baseURL, forKey: "baseURL")
    }
  }

  // Animation settings
  var animationsEnabled: Bool {
    didSet {
      UserDefaults.standard.set(animationsEnabled, forKey: "animationsEnabled")
    }
  }

  var animationSpeed: AnimationSpeed {
    didSet {
      UserDefaults.standard.set(animationSpeed.rawValue, forKey: "animationSpeed")
    }
  }

  var autoRefreshEnabled: Bool {
    didSet {
      UserDefaults.standard.set(autoRefreshEnabled, forKey: "autoRefreshEnabled")
    }
  }

  var autoRefreshInterval: Int {
    didSet {
      UserDefaults.standard.set(autoRefreshInterval, forKey: "autoRefreshInterval")
    }
  }

  private init() {
    // Load saved preferences or use defaults
    let savedBaseURL = UserDefaults.standard.string(forKey: "baseURL") ?? "https://lore.kernel.org"
    let savedAnimationsEnabled =
      UserDefaults.standard.object(forKey: "animationsEnabled") as? Bool ?? true
    let savedAnimationSpeed =
      AnimationSpeed(rawValue: UserDefaults.standard.string(forKey: "animationSpeed") ?? "standard")
      ?? .standard
    let savedAutoRefreshEnabled =
      UserDefaults.standard.object(forKey: "autoRefreshEnabled") as? Bool ?? false
    let savedAutoRefreshInterval = UserDefaults.standard.integer(forKey: "autoRefreshInterval")

    // Initialize properties
    self.baseURL = savedBaseURL
    self.animationsEnabled = savedAnimationsEnabled
    self.animationSpeed = savedAnimationSpeed
    self.autoRefreshEnabled = savedAutoRefreshEnabled
    self.autoRefreshInterval = savedAutoRefreshInterval == 0 ? 300 : savedAutoRefreshInterval
  }
}

enum AnimationSpeed: String, CaseIterable {
  case fast = "fast"
  case standard = "standard"
  case slow = "slow"

  var displayName: String {
    switch self {
    case .fast: return "Fast"
    case .standard: return "Standard"
    case .slow: return "Slow"
    }
  }

  var duration: Double {
    switch self {
    case .fast: return 0.15
    case .standard: return 0.3
    case .slow: return 0.5
    }
  }
}

// Extension to provide animation based on user preferences
extension Animation {
  static var userPreference: Animation {
    let prefs = UserPreferences.shared
    if !prefs.animationsEnabled {
      return Animation.linear(duration: 0)
    }
    return .easeInOut(duration: prefs.animationSpeed.duration)
  }

  static var userPreferenceQuick: Animation {
    let prefs = UserPreferences.shared
    if !prefs.animationsEnabled {
      return Animation.linear(duration: 0)
    }
    return .easeInOut(duration: prefs.animationSpeed.duration * 0.6)
  }

  static var userPreferenceSlow: Animation {
    let prefs = UserPreferences.shared
    if !prefs.animationsEnabled {
      return Animation.linear(duration: 0)
    }
    return .easeInOut(duration: prefs.animationSpeed.duration * 1.5)
  }
}
