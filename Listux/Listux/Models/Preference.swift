import Foundation
import SwiftData
import SwiftUI

@Model
final class Preference {

  var favoriteLists: [MailingList] = []
  var lastViewedList: MailingList?

  init() {}

  func toggleFavorite(_ list: MailingList) {
    if favoriteLists.contains(list) {
      favoriteLists.removeAll { $0.id == list.id }
    } else {
      favoriteLists.append(list)
    }
  }

  func isFavorite(_ list: MailingList) -> Bool {
    favoriteLists.contains { $0.id == list.id }
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
