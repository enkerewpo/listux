import SwiftUI

#if os(macOS)
  import AppKit
#endif

@Observable
class WindowLayoutManager {
  static let shared = WindowLayoutManager()

  private init() {}

  func calculateInitialWindowSize() -> (width: Double, height: Double) {
    #if os(macOS)
      guard let screen = NSScreen.main else {
        return (1200, 800)
      }

      let screenSize = screen.visibleFrame.size
      let targetWidth = screenSize.width * 0.75
      let targetHeight = screenSize.height * 0.75

      return (targetWidth, targetHeight)
    #else
      return (1200, 800)
    #endif
  }

  func calculateOptimalLayout(for windowWidth: Double) -> (
    sidebar: Double, messageList: Double, detail: Double
  ) {
    let minSidebarWidth: Double = 240
    let minMessageListWidth: Double = 300
    let minDetailWidth: Double = 400

    // Calculate available width for messageList and detail (they share the same width)
    let minContentWidth = max(minMessageListWidth, minDetailWidth)  // Use the larger minimum
    let availableWidth = windowWidth - minSidebarWidth - (minContentWidth * 2)

    if availableWidth >= 0 {
      let extraPerColumn = availableWidth / 3
      let sidebarWidth = minSidebarWidth + extraPerColumn
      // messageList and detail share the same width
      let contentWidth = minContentWidth + extraPerColumn
      let messageListWidth = contentWidth
      let detailWidth = contentWidth

      return (sidebarWidth, messageListWidth, detailWidth)
    } else {
      // Fallback: use minimum widths, but make messageList and detail equal
      let contentWidth = minContentWidth
      return (minSidebarWidth, contentWidth, contentWidth)
    }
  }

  func saveLayoutPreferences(sidebarWidth: Double, messageListWidth: Double, detailWidth: Double) {
    UserDefaults.standard.set(sidebarWidth, forKey: "sidebarWidth")
    UserDefaults.standard.set(messageListWidth, forKey: "messageListWidth")
    UserDefaults.standard.set(detailWidth, forKey: "detailWidth")
  }

  func loadLayoutPreferences() -> (sidebar: Double, messageList: Double, detail: Double) {
    let sidebarWidth = UserDefaults.standard.double(forKey: "sidebarWidth")
    let messageListWidth = UserDefaults.standard.double(forKey: "messageListWidth")
    let detailWidth = UserDefaults.standard.double(forKey: "detailWidth")

    if sidebarWidth == 0 {
      return calculateOptimalLayout(for: 1200)
    }

    return (sidebarWidth, messageListWidth, detailWidth)
  }
}
