//
//  ListuxApp.swift
//  Listux
//
//  Created by Mr wheatfox on 2025/3/26.
//

import SwiftData
import SwiftUI
import os.log

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
        LogManager.shared.info("Found \(favorites.count) favorite messages on app startup")
        for favorite in favorites {
          LogManager.shared.debug(
            "Favorite message: \(favorite.messageId): \(favorite.subject) (tags: \(favorite.tags))")
        }
      } catch {
        LogManager.shared.error("Error fetching favorites on startup: \(error)")
      }

      return container
    } catch {
      LogManager.shared.fault("Could not create ModelContainer: \(error)")
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          LogManager.shared.info("Listux app started successfully")
        }
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

          Button("Open Log Directory") {
            LogManager.shared.openLogDirectory()
          }
          .keyboardShortcut("l", modifiers: [.command, .option])
        }
      }
    #endif
  }
}
