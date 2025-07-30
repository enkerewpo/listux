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
  @Query(sort: \MailingList.name) private var mailingLists: [MailingList]
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

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
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
      messageIds = preference.getUntaggedMessages()
    } else {
      messageIds = preference.getMessagesWithTag(tag)
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
          list.orderedMessages = result.messages
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
          list.orderedMessages = result.messages
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
          for list in lists {
            let mailingList = MailingList(name: list.name, desc: list.desc)
            modelContext.insert(mailingList)
          }
          isLoadingMailingLists = false
        } catch {
          isLoadingMailingLists = false
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
        .frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity)
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
              isLoading: isLoadingMessages
            )
            .frame(minWidth: 300, idealWidth: 700, maxWidth: .infinity, maxHeight: .infinity)
          }
        }
        .animation(Animation.userPreference, value: selectedSidebarTab)
        .animation(Animation.userPreference, value: selectedTag)
      } detail: {
        MessageDetailView(selectedMessage: selectedMessage)
          .frame(minWidth: 400, idealWidth: 600, maxWidth: .infinity)
      }
      .onChange(of: selectedList) {
        withAnimation(Animation.userPreference) {
          selectedMessage = nil
          messagePageLinks = (nil, nil, nil)
          currentPage = 1
        }
      }
      .onChange(of: selectedTag) {
        withAnimation(Animation.userPreference) {
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
        settingsManager.onDataCleared = {
          withAnimation(Animation.userPreference) {
            selectedTag = nil
            selectedMessage = nil
            selectedSidebarTab = .lists
          }
        }
      }
      .task {
        loadMailingLists()
      }
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
            preference: preference,
            allMailingLists: mailingLists
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
        settingsManager.onDataCleared = {
          selectedSidebarTab = .lists
        }
      }
    }
  #endif
}
