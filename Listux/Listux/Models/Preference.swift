import Foundation
import SwiftData
import SwiftUI

@Model
final class Preference {

  var favoriteLists: [String] = []  // Store list names instead of objects
  var pinnedLists: [String] = []    // Store list names instead of objects
  var lastViewedList: String?       // Store list name instead of object
  
  // Window layout preferences
  var sidebarWidth: Double = 320
  var messageListWidth: Double = 500
  var detailViewWidth: Double = 500

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
