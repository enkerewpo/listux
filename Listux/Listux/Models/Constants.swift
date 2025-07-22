import SwiftUI

// MARK: - Animation Constants
struct AnimationConstants {
  // Standard animations
  static let quick = Animation.easeInOut(duration: 0.2)
  static let standard = Animation.easeInOut(duration: 0.3)
  static let slow = Animation.easeInOut(duration: 0.5)

  // Spring animations
  static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.6)
  static let springStandard = Animation.spring(response: 0.4, dampingFraction: 0.7)
  static let springSlow = Animation.spring(response: 0.6, dampingFraction: 0.8)

  // Transitions
  static let fadeInOut = AnyTransition.opacity.combined(with: .scale(scale: 0.9))
  static let slideFromLeading = AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .leading)),
    removal: .opacity.combined(with: .move(edge: .trailing))
  )
  static let slideFromTrailing = AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .trailing)),
    removal: .opacity.combined(with: .move(edge: .leading))
  )
  static let slideFromTop = AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .top)),
    removal: .opacity.combined(with: .move(edge: .bottom))
  )
  static let slideFromBottom = AnyTransition.asymmetric(
    insertion: .opacity.combined(with: .move(edge: .bottom)),
    removal: .opacity.combined(with: .move(edge: .top))
  )

  // Scale effects
  static let hoverScale: CGFloat = 1.05
  static let selectedScale: CGFloat = 1.02
  static let favoriteScale: CGFloat = 1.2
  static let favoriteAnimationScale: CGFloat = 1.3
}

// MARK: - Network Constants
struct LORE_LINUX_BASE_URL {
  static var value: String {
    return UserPreferences.shared.baseURL
  }
}

let GITHUB_HOMEPAGE = "https://github.com/enkerewpo/listux"
