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
      MailingList.self,
      Message.self,
      Preference.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
