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
  @State private var rootMessages: [Message] = []  // Root messages for threaded view
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

  /// Load next page (replaces existing messages)
  private func loadNextPages() async {
    guard let list = selectedList, let nextURL = messagePageLinks.next, !hasReachedEndMessages,
      !isLoadingMoreMessages
    else {
      return
    }

    isLoadingMoreMessages = true
    await loadPagesForList(list, pageCount: 1, startingSeqId: 0, startURL: nextURL)
    await MainActor.run {
      currentPage += 1
      isLoadingMoreMessages = false
      uiUpdateTrigger.toggle()
    }
  }

  /// Load previous page (replaces existing messages)
  private func loadPrevPages() async {
    guard let list = selectedList, let prevURL = messagePageLinks.prev, !isLoadingMoreMessages
    else {
      return
    }

    isLoadingMoreMessages = true
    await loadPagesForList(list, pageCount: 1, startingSeqId: 0, startURL: prevURL)
    await MainActor.run {
      currentPage = max(1, currentPage - 1)
      isLoadingMoreMessages = false
      uiUpdateTrigger.toggle()
    }
  }

  /// Load latest page (replaces existing messages)
  private func loadLatestPages() async {
    guard let list = selectedList, !isLoadingMoreMessages else {
      return
    }

    isLoadingMoreMessages = true
    await loadPagesForList(list, pageCount: 1, startingSeqId: 0, startURL: nil)
    await MainActor.run {
      currentPage = 1
      isLoadingMoreMessages = false
      uiUpdateTrigger.toggle()
    }
  }

  private func loadMessagesForList(_ list: MailingList) {
    isLoadingMessages = true
    currentPage = 1
    rootMessages = []
    Task {
      // Load initial 3 pages
      await loadPagesForList(list, pageCount: 1, startingSeqId: 0)
      await MainActor.run {
        isLoadingMessages = false
      }
    }
  }

  /// Load a page for a mailing list (replaces existing messages)
  /// - Parameters:
  ///   - list: The mailing list to load messages for
  ///   - pageCount: Number of pages to load (default: 1)
  ///   - startingSeqId: Starting sequence ID for messages
  ///   - startURL: Optional starting URL (if nil, starts from homepage)
  private func loadPagesForList(
    _ list: MailingList, pageCount: Int = 1, startingSeqId: Int = 0, startURL: String? = nil
  ) async {
    var currentSeqId = startingSeqId
    var nextPageURL: String? = nil
    var loadedPages = 0
    var allMessages: [Message] = []
    var allRootMessages: [Message] = []

    do {
      // Load first page
      let firstPageHtml: String
      if let startURL = startURL {
        firstPageHtml = try await fetchPageWithURL(startURL, for: list.name)
      } else {
        firstPageHtml = try await NetworkService.shared.fetchListPage(list.name)
      }

      let result = Parser.parseMsgsFromListPage(
        from: firstPageHtml, mailingList: list, startingSeqId: currentSeqId)

      allMessages.append(contentsOf: result.messages)
      allRootMessages.append(contentsOf: result.rootMessages)
      nextPageURL = result.nextURL
      currentSeqId = (result.messages.map { $0.seqId }.max() ?? currentSeqId) + 1
      loadedPages = 1
      print(
        "ContentView: Loaded page 1 - \(result.messages.count) messages, \(result.rootMessages.count) root messages, nextURL: \(result.nextURL ?? "nil")"
      )

      // Load additional pages by following next links
      while loadedPages < pageCount {
        guard let url = nextPageURL else {
          print("ContentView: No more pages to load (nextURL is nil)")
          break
        }

        print("ContentView: Loading page \(loadedPages + 1) from URL: \(url)")
        let pageHtml = try await fetchPageWithURL(url, for: list.name)
        let pageResult = Parser.parseMsgsFromListPage(
          from: pageHtml, mailingList: list, startingSeqId: currentSeqId)

        allMessages.append(contentsOf: pageResult.messages)
        allRootMessages.append(contentsOf: pageResult.rootMessages)
        nextPageURL = pageResult.nextURL
        currentSeqId = (pageResult.messages.map { $0.seqId }.max() ?? currentSeqId) + 1
        loadedPages += 1
        print(
          "ContentView: Loaded page \(loadedPages) - \(pageResult.messages.count) messages, \(pageResult.rootMessages.count) root messages, nextURL: \(pageResult.nextURL ?? "nil")"
        )
      }

      // Get prevURL and latestURL from the first page we loaded
      var finalPrevURL: String? = nil
      var finalLatestURL: String? = nil

      // Parse the first page to get prevURL and latestURL
      if loadedPages > 0 {
        let firstPageHtml: String
        if let startURL = startURL {
          firstPageHtml = try await fetchPageWithURL(startURL, for: list.name)
        } else {
          firstPageHtml = try await NetworkService.shared.fetchListPage(list.name)
        }
        let firstPageResult = Parser.parseMsgsFromListPage(
          from: firstPageHtml, mailingList: list, startingSeqId: 0)
        finalPrevURL = firstPageResult.prevURL
        finalLatestURL = firstPageResult.latestURL
      }

      // Replace all messages at once
      await MainActor.run {
        list.updateOrderedMessages(allMessages)
        favoriteMessageService.syncMessagesWithPersistentStorage(allMessages)
        rootMessages = allRootMessages
        messagePageLinks = (nextPageURL, finalPrevURL, finalLatestURL)
        hasReachedEndMessages = nextPageURL == nil

        // Force UI update
        list.objectWillChange.send()
        uiUpdateTrigger.toggle()

        print(
          "ContentView: Finished loading \(loadedPages) pages, total messages: \(allMessages.count), total roots: \(allRootMessages.count), hasReachedEnd: \(hasReachedEndMessages)"
        )
      }
    } catch {
      LogManager.shared.error(
        "Failed to load pages for \(list.name): \(error.localizedDescription)")
    }
  }

  /// Fetch a page using the ?t=timestamp URL format
  private func fetchPageWithURL(_ url: String, for listName: String) async throws -> String {
    let fullURL: String
    if url.hasPrefix("http") {
      fullURL = url
    } else if url.hasPrefix("?") {
      // Relative URL with query parameter: ?t=timestamp
      fullURL = "\(LORE_LINUX_BASE_URL.value)/\(listName)\(url)"
    } else if url.hasPrefix("/") {
      fullURL = LORE_LINUX_BASE_URL.value + url
    } else {
      fullURL = "\(LORE_LINUX_BASE_URL.value)/\(listName)/\(url)"
    }

    LogManager.shared.info("Fetching page: \(fullURL)")
    return try await NetworkService.shared.fetchURL(fullURL)
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
              isLoading: isLoadingMessages || isLoadingMoreMessages,
              onLoadMore: {
                await loadNextPages()
              },
              hasReachedEnd: hasReachedEndMessages,
              selectedMessage: $selectedMessage,
              nextURL: messagePageLinks.next,
              prevURL: messagePageLinks.prev,
              latestURL: messagePageLinks.latest,
              onLoadPrev: {
                await loadPrevPages()
              },
              onLoadLatest: {
                await loadLatestPages()
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
