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
  @State private var isLoadingMoreMessages: Bool = false
  @State private var hasReachedEndMessages: Bool = false
  @State private var uiUpdateTrigger: Bool = false
  @State private var rootMessages: [Message] = [] // Root messages for threaded view
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
        let result = Parser.parseMsgsFromListPage(from: html, mailingList: list, startingSeqId: 0)
        await MainActor.run {
          list.updateOrderedMessages(result.messages)
          // Sync messages with persistent storage
          favoriteMessageService.syncMessagesWithPersistentStorage(result.messages)
          messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
          rootMessages = result.rootMessages
          isLoadingMessages = false
        }
      } catch {
        await MainActor.run {
          isLoadingMessages = false
        }
      }
    }
  }

  private func loadMoreMessages() async {
    guard let list = selectedList, let nextURL = messagePageLinks.next, !hasReachedEndMessages,
      !isLoadingMoreMessages
    else {
      print(
        "ContentView: Skipping loadMoreMessages - selectedList: \(selectedList != nil), nextURL: \(messagePageLinks.next != nil), hasReachedEnd: \(hasReachedEndMessages), isLoadingMore: \(isLoadingMoreMessages)"
      )
      return
    }

    isLoadingMoreMessages = true
    print("ContentView: Loading more messages from \(nextURL)")

    do {
      let fullURL: String
      if nextURL.hasPrefix("http") {
        fullURL = nextURL
      } else if nextURL.hasPrefix("/") {
        // Absolute path from root
        fullURL = "\(LORE_LINUX_BASE_URL.value)\(nextURL)"
      } else {
        // Relative path, append to current list URL
        fullURL = "\(LORE_LINUX_BASE_URL.value)/\(list.name)/\(nextURL)"
      }

      print("ContentView: Fetching from full URL: \(fullURL)")
      let html = try await NetworkService.shared.fetchURL(fullURL)

      // Calculate starting seqId based on existing messages
      let startingSeqId =
        list.orderedMessages.isEmpty ? 0 : (list.orderedMessages.map { $0.seqId }.max() ?? -1) + 1
      print("ContentView: Using starting seqId: \(startingSeqId)")
      print(
        "ContentView: Current messages seqIds: \(list.orderedMessages.map { $0.seqId }.suffix(5))")
      let result = Parser.parseMsgsFromListPage(
        from: html, mailingList: list, startingSeqId: startingSeqId)

      await MainActor.run {
        // Replace messages instead of appending
        list.updateOrderedMessages(result.messages)
        rootMessages = result.rootMessages
        print("ContentView: Replaced with \(result.messages.count) messages, \(result.rootMessages.count) root messages")
        messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
        hasReachedEndMessages = result.nextURL == nil
        isLoadingMoreMessages = false

        // Update page number
        currentPage += 1

        // Force UI update by triggering objectWillChange
        list.objectWillChange.send()

        // Trigger UI update
        uiUpdateTrigger.toggle()

        print(
          "ContentView: Loaded \(result.messages.count) messages for page \(currentPage), hasReachedEnd: \(hasReachedEndMessages), nextURL: \(result.nextURL ?? "nil")"
        )
      }
    } catch {
      await MainActor.run {
        isLoadingMoreMessages = false
        print("ContentView: Failed to load more messages: \(error)")
      }
    }
  }

  private func loadPrevMessages() async {
    guard let list = selectedList, let prevURL = messagePageLinks.prev, !isLoadingMoreMessages
    else {
      print(
        "ContentView: Skipping loadPrevMessages - selectedList: \(selectedList != nil), prevURL: \(messagePageLinks.prev != nil), isLoadingMore: \(isLoadingMoreMessages)"
      )
      return
    }

    isLoadingMoreMessages = true
    print("ContentView: Loading previous messages from \(prevURL)")

    do {
      let fullURL: String
      if prevURL.hasPrefix("http") {
        fullURL = prevURL
      } else if prevURL.hasPrefix("/") {
        // Absolute path from root
        fullURL = "\(LORE_LINUX_BASE_URL.value)\(prevURL)"
      } else {
        // Relative path, append to current list URL
        fullURL = "\(LORE_LINUX_BASE_URL.value)/\(list.name)/\(prevURL)"
      }

      print("ContentView: Fetching from full URL: \(fullURL)")
      let html = try await NetworkService.shared.fetchURL(fullURL)

      // Calculate starting seqId based on existing messages
      let startingSeqId =
        list.orderedMessages.isEmpty ? 0 : (list.orderedMessages.map { $0.seqId }.min() ?? 0) - 1
      let result = Parser.parseMsgsFromListPage(
        from: html, mailingList: list, startingSeqId: startingSeqId)

      await MainActor.run {
        // Replace messages
        list.updateOrderedMessages(result.messages)
        rootMessages = result.rootMessages
        messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
        hasReachedEndMessages = result.nextURL == nil
        isLoadingMoreMessages = false

        // Update page number
        currentPage = max(1, currentPage - 1)

        // Force UI update
        list.objectWillChange.send()
        uiUpdateTrigger.toggle()

        print(
          "ContentView: Loaded \(result.messages.count) messages for page \(currentPage), hasReachedEnd: \(hasReachedEndMessages), prevURL: \(result.prevURL ?? "nil")"
        )
      }
    } catch {
      await MainActor.run {
        isLoadingMoreMessages = false
        print("ContentView: Failed to load previous messages: \(error)")
      }
    }
  }

  private func loadLatestMessages() async {
    guard let list = selectedList, let latestURL = messagePageLinks.latest, !isLoadingMoreMessages
    else {
      print(
        "ContentView: Skipping loadLatestMessages - selectedList: \(selectedList != nil), latestURL: \(messagePageLinks.latest != nil), isLoadingMore: \(isLoadingMoreMessages)"
      )
      return
    }

    isLoadingMoreMessages = true
    print("ContentView: Loading latest messages from \(latestURL)")

    do {
      let fullURL: String
      if latestURL.hasPrefix("http") {
        fullURL = latestURL
      } else if latestURL.hasPrefix("/") {
        // Absolute path from root
        fullURL = "\(LORE_LINUX_BASE_URL.value)\(latestURL)"
      } else {
        // Relative path, append to current list URL
        fullURL = "\(LORE_LINUX_BASE_URL.value)/\(list.name)/\(latestURL)"
      }

      print("ContentView: Fetching from full URL: \(fullURL)")
      let html = try await NetworkService.shared.fetchURL(fullURL)

      let result = Parser.parseMsgsFromListPage(
        from: html, mailingList: list, startingSeqId: 0)

      await MainActor.run {
        // Replace all messages with latest ones
        list.updateOrderedMessages(result.messages)
        rootMessages = result.rootMessages
        messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
        hasReachedEndMessages = result.nextURL == nil
        isLoadingMoreMessages = false

        // Reset page number to first page
        currentPage = 1

        // Force UI update
        list.objectWillChange.send()
        uiUpdateTrigger.toggle()

        print(
          "ContentView: Loaded \(result.messages.count) latest messages (page 1), hasReachedEnd: \(hasReachedEndMessages), nextURL: \(result.nextURL ?? "nil")"
        )
      }
    } catch {
      await MainActor.run {
        isLoadingMoreMessages = false
        print("ContentView: Failed to load latest messages: \(error)")
      }
    }
  }

  private func loadMessagesForList(_ list: MailingList) {
    isLoadingMessages = true
    currentPage = 1
    rootMessages = []
    Task {
      do {
        let html = try await NetworkService.shared.fetchListPage(list.name)
        let result = Parser.parseMsgsFromListPage(from: html, mailingList: list, startingSeqId: 0)
        await MainActor.run {
          list.updateOrderedMessages(result.messages)
          // Sync messages with persistent storage
          favoriteMessageService.syncMessagesWithPersistentStorage(result.messages)
          messagePageLinks = (result.nextURL, result.prevURL, result.latestURL)
          hasReachedEndMessages = result.nextURL == nil
          rootMessages = result.rootMessages
          isLoadingMessages = false
          print(
            "ContentView: Loaded \(result.messages.count) initial messages for \(list.name), \(result.rootMessages.count) root messages, hasReachedEnd: \(hasReachedEndMessages), nextURL: \(result.nextURL ?? "nil")"
          )
        }
      } catch {
        await MainActor.run {
          isLoadingMessages = false
          print("ContentView: Failed to load initial messages for \(list.name): \(error)")
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
          } else if selectedSidebarTab == .search {
            SearchView(selectedMessage: $selectedMessage)
              .frame(
                minWidth: 300,
                idealWidth: WindowLayoutManager.shared.loadLayoutPreferences().messageList,
                maxWidth: .infinity,
                maxHeight: .infinity
              )
          } else {
            Divider()
            ThreadedMessageListView(
              rootMessages: rootMessages,
              title: selectedList?.name ?? "",
              isLoading: isLoadingMessages,
              onLoadMore: {
                await loadMoreMessages()
              },
              hasReachedEnd: hasReachedEndMessages,
              selectedMessage: $selectedMessage,
              nextURL: messagePageLinks.next,
              prevURL: messagePageLinks.prev,
              latestURL: messagePageLinks.latest,
              onLoadPrev: {
                await loadPrevMessages()
              },
              onLoadLatest: {
                await loadLatestMessages()
              },
              pageNumber: $currentPage
            )
            .id(uiUpdateTrigger)  // Force view refresh when trigger changes
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
      .onChange(of: selectedSidebarTab) { _, newTab in
        if newTab == .search {
          selectedMessage = nil
        }
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
          SearchView(selectedMessage: $selectedMessage)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
        .tabItem {
          Image(systemName: "magnifyingglass")
          Text("Search")
        }
        .tag(SidebarTab.search)

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
      .animation(.none, value: selectedSidebarTab)
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
