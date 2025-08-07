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

    let availableWidth = windowWidth - minSidebarWidth - minMessageListWidth - minDetailWidth

    if availableWidth >= 0 {
      let extraPerColumn = availableWidth / 3
      let sidebarWidth = minSidebarWidth + extraPerColumn
      let messageListWidth = minMessageListWidth + extraPerColumn
      let detailWidth = minDetailWidth + extraPerColumn

      return (sidebarWidth, messageListWidth, detailWidth)
    } else {
      return (minSidebarWidth, minMessageListWidth, minDetailWidth)
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
