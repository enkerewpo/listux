//
//  ListuxApp.swift
//  Listux
//
//  Created by Mr wheatfox on 2025/3/26.
//

import SwiftData
import SwiftSoup
import SwiftUI
import os

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @State private var mailingLists: [MailingList] = []
  @State private var selectedSidebarTab: SidebarTab = .lists
  @State private var selectedList: MailingList? = nil
  @State private var selectedTag: String? = nil
  @State private var selectedMessage: Message? = nil
  @State private var isLoadingMessages: Bool = false
  @State private var isLoadingMailingLists: Bool = false
  @State private var mailingListSearchText: String = ""
  @State private var mailingListPageLinks: (next: String?, prev: String?, latest: String?) = (
    nil, nil, nil
  )
  @State private var messagePageLinks: (next: String?, prev: String?, latest: String?) = (
    nil, nil, nil
  )
  @State private var currentPage: Int = 1
  @Query private var preferences: [Preference]

  @State private var settingsManager = SettingsManager.shared
  @State private var favoriteMessageService = FavoriteMessageService.shared
  @State private var windowLayoutManager = WindowLayoutManager.shared

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      // Save the new preference to SwiftData
      try? modelContext.save()
      return new
    }
  }

  private var sortedMailingLists: [MailingList] {
    let pinned = mailingLists.filter { $0.isPinned }.sorted { $0.name < $1.name }
    let unpinned = mailingLists.filter { !$0.isPinned }.sorted { $0.name < $1.name }
    return pinned + unpinned
  }

  private var taggedMessages: [Message] {
    guard let tag = selectedTag else { return [] }

    let messageIds: [String]
    if tag == "Untagged" {
      messageIds = favoriteMessageService.getUntaggedMessages()
    } else {
      messageIds = favoriteMessageService.getMessagesWithTag(tag)
    }

    var allMessages: [Message] = []
    for list in mailingLists {
      allMessages.append(contentsOf: list.messages)
    }

    return allMessages.filter { message in
      messageIds.contains(message.messageId)
    }.sorted { $0.timestamp > $1.timestamp }
  }

  private func onPageLinkTapped(url: String) {
    guard let list = selectedList else { return }
    if let next = messagePageLinks.next, url == next {
      currentPage += 1
    } else if let prev = messagePageLinks.prev, url == prev, currentPage > 1 {
      currentPage -= 1
    } else if let latest = messagePageLinks.latest, url == latest {
      currentPage = 1
    }
    isLoadingMessages = true
    Task {
      do {
        let fullUrl: String
        if url.hasPrefix("http") {
          fullUrl = url
        } else {
          let base = LORE_LINUX_BASE_URL.value + "/"
          fullUrl =
            base + list.name + "/" + url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        let html = try await NetworkService.shared.fetchMessageRaw(url: fullUrl)
        let result = Parser.parseMsgsFromListPage(from: html, mailingList: list)
        await MainActor.run {
          list.updateOrderedMessages(result.messages)
          // Sync messages with persistent storage
          favoriteMessageService.syncMessagesWithPersistentStorage(result.messages)
          messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
          isLoadingMessages = false
        }
      } catch {
        await MainActor.run {
          isLoadingMessages = false
        }
      }
    }
  }

  private func loadMessagesForList(_ list: MailingList) {
    isLoadingMessages = true
    currentPage = 1
    Task {
      do {
        let html = try await NetworkService.shared.fetchListPage(list.name)
        let result = Parser.parseMsgsFromListPage(from: html, mailingList: list)
        await MainActor.run {
          list.updateOrderedMessages(result.messages)
          // Sync messages with persistent storage
          favoriteMessageService.syncMessagesWithPersistentStorage(result.messages)
          messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
          isLoadingMessages = false
        }
      } catch {
        await MainActor.run {
          isLoadingMessages = false
        }
      }
    }
  }

  private func loadMailingLists() {
    if mailingLists.isEmpty {
      isLoadingMailingLists = true
      Task {
        do {
          let html = try await NetworkService.shared.fetchHomePage()
          let lists = Parser.parseListsFromHomePage(from: html)
          await MainActor.run {
            for list in lists {
              let mailingList = MailingList(name: list.name, desc: list.desc)
              // Restore pin state from preferences
              if preference.isPinned(mailingList) {
                mailingList.isPinned = true
              }
              mailingLists.append(mailingList)
            }
            isLoadingMailingLists = false
          }
        } catch {
          await MainActor.run {
            isLoadingMailingLists = false
          }
        }
      }
    }
  }

  #if os(macOS)
    var body: some View {
      NavigationSplitView {
        SidebarView(
          selectedSidebarTab: $selectedSidebarTab,
          selectedList: $selectedList,
          selectedTag: $selectedTag,
          mailingLists: mailingLists,
          isLoading: isLoadingMailingLists,
          searchText: $mailingListSearchText,
          onSelectList: { list in
            loadMessagesForList(list)
          },
          onSelectTag: { tag in
            selectedTag = tag
            selectedMessage = nil
          }
        )
        .frame(
          minWidth: 240,
          idealWidth: WindowLayoutManager.shared.loadLayoutPreferences().sidebar,
          maxWidth: .infinity
        )
      } content: {
        VStack(spacing: 0) {
          if selectedSidebarTab == .favorites {
            if let tag = selectedTag {
              TaggedMessagesView(
                tag: tag,
                messages: taggedMessages,
                selectedMessage: $selectedMessage,
                preference: preference
              )
            } else {
              Text("Select a tag to view messages")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          } else {
            Divider()
            MessageListView(
              messages: selectedList?.orderedMessages ?? [],
              title: selectedList?.name ?? "",
              isLoading: isLoadingMessages,
              onLoadMore: nil
            )
            .frame(
              minWidth: 300,
              idealWidth: WindowLayoutManager.shared.loadLayoutPreferences().messageList,
              maxWidth: .infinity,
              maxHeight: .infinity
            )
          }
        }

      } detail: {
        MessageDetailView(selectedMessage: selectedMessage)
          .frame(
            minWidth: 400,
            idealWidth: WindowLayoutManager.shared.loadLayoutPreferences().detail,
            maxWidth: .infinity
          )
      }
      .onChange(of: selectedList) {
        selectedMessage = nil
        messagePageLinks = (nil, nil, nil)
        currentPage = 1
      }
      .onChange(of: selectedTag) {
        selectedMessage = nil
      }
      .onChange(of: settingsManager.shouldOpenSettings) { _, newValue in
        if newValue {
          withAnimation(Animation.userPreference) {
            selectedSidebarTab = .settings
          }
          settingsManager.shouldOpenSettings = false
        }
      }
      .onAppear {
        favoriteMessageService.setModelContext(modelContext)
        favoriteMessageService.checkDataOnStartup()
        settingsManager.onDataCleared = {
          withAnimation(Animation.userPreference) {
            selectedTag = nil
            selectedMessage = nil
            selectedSidebarTab = .lists
            // Reset mailing lists and reload
            mailingLists.removeAll()
            loadMailingLists()
          }
        }
      }
      .task {
        loadMailingLists()
      }
      #if os(macOS)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResizeNotification)) { _ in
        // 当窗口大小改变时，保存当前的布局偏好
        if let window = NSApplication.shared.windows.first {
          let windowWidth = window.frame.width
          let layout = windowLayoutManager.calculateOptimalLayout(for: windowWidth)
          windowLayoutManager.saveLayoutPreferences(
            sidebarWidth: layout.sidebar,
            messageListWidth: layout.messageList,
            detailWidth: layout.detail
          )
        }
      }
      #endif
    }
  #endif

  #if os(iOS)
    var body: some View {
      TabView(selection: $selectedSidebarTab) {
        NavigationStack {
          MailingListView(
            mailingLists: sortedMailingLists,
            isLoading: isLoadingMailingLists,
            onAppear: {
              loadMailingLists()
            }
          )
        }
        .tabItem {
          Image(systemName: "list.bullet")
          Text("Lists")
        }
        .tag(SidebarTab.lists)

        NavigationStack {
          FavoritesView(
            preference: preference
          )
        }
        .tabItem {
          Image(systemName: "star")
          Text("Favorites")
        }
        .tag(SidebarTab.favorites)

        NavigationStack {
          SettingsView()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .tabItem {
          Image(systemName: "gear")
          Text("Settings")
        }
        .tag(SidebarTab.settings)
      }
      .onAppear {
        favoriteMessageService.setModelContext(modelContext)
        favoriteMessageService.checkDataOnStartup()
        settingsManager.onDataCleared = {
          selectedSidebarTab = .lists
          // Reset mailing lists and reload
          mailingLists.removeAll()
          loadMailingLists()
        }
      }
    }
  #endif
}
