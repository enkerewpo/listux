//
//  ListuxApp.swift
//  Listux
//
//  Created by Mr wheatfox on 2025/3/26.
//

import SwiftData
import SwiftUI

@main
struct ListuxApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      Preference.self,
      FavoriteMessage.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
      
      // Debug: Check if FavoriteMessage data persists
      let context = container.mainContext
      let descriptor = FetchDescriptor<FavoriteMessage>()
      do {
        let favorites = try context.fetch(descriptor)
        print("ListuxApp: Found \(favorites.count) favorite messages on app startup")
        for favorite in favorites {
          print("ListuxApp: - \(favorite.messageId): \(favorite.subject) (tags: \(favorite.tags))")
        }
      } catch {
        print("ListuxApp: Error fetching favorites on startup: \(error)")
      }
      
      return container
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
    #if os(macOS)
      .defaultSize(
        width: WindowLayoutManager.shared.calculateInitialWindowSize().width,
        height: WindowLayoutManager.shared.calculateInitialWindowSize().height
      )
      .windowResizability(.contentSize)
      .commands {
        CommandGroup(replacing: .appInfo) {
          Button("About Listux") {
            AboutPanel.show()
          }
          .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandGroup(after: .appInfo) {
          Button("Settings") {
            SettingsManager.shared.openSettings()
          }
          .keyboardShortcut(",", modifiers: [.command])
        }
      }
    #endif
  }
}
