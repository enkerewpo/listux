//
//  ContentView.swift
//  Plovix
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

  // Handle settings menu command
  @State private var settingsManager = SettingsManager.shared

  var body: some View {
    // Define the pagination handler closure so it can be used in both the toolbox bar and MessageListView
    let onPageLinkTapped: (String) -> Void = { url in
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
          print("Failed to load messages for list \(list.name): \(error)")
          await MainActor.run {
            isLoadingMessages = false
          }
        }
      }
    }

    NavigationSplitView {
      SidebarView(
        selectedSidebarTab: $selectedSidebarTab,
        selectedList: $selectedList,
        mailingLists: mailingLists,
        isLoading: isLoadingMailingLists,
        searchText: $mailingListSearchText,
        onSelectList: { list in
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
              print("Failed to load messages for list \(list.name): \(error)")
              await MainActor.run {
                isLoadingMessages = false
              }
            }
          }
        }
      )
      .frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity)
    } content: {
      VStack(spacing: 0) {
        HStack {
          if selectedList != nil {
            HStack(spacing: 24) {
              PaginationButton(
                systemName: "chevron.left",
                help: "Prev (Newer)",
                isEnabled: messagePageLinks.prev != nil
              ) {
                if let prev = messagePageLinks.prev { onPageLinkTapped(prev) }
              }

              PaginationButton(
                systemName: "arrow.left.to.line",
                help: "First Page",
                isEnabled: messagePageLinks.latest != nil
              ) {
                if let latest = messagePageLinks.latest { onPageLinkTapped(latest) }
              }

              Text("Page \(currentPage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(minWidth: 60)
                .transition(AnimationConstants.fadeInOut)
                .animation(Animation.userPreferenceQuick, value: currentPage)

              PaginationButton(
                systemName: "chevron.right",
                help: "Next (Older)",
                isEnabled: messagePageLinks.next != nil
              ) {
                if let next = messagePageLinks.next { onPageLinkTapped(next) }
              }
            }
            .padding(.trailing, 16)
            .transition(AnimationConstants.slideFromTop)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.95))
        Divider()
        MessageListView(
          selectedSidebarTab: selectedSidebarTab, selectedList: selectedList,
          selectedMessage: $selectedMessage,
          isLoading: isLoadingMessages,
          nextURL: messagePageLinks.next,
          prevURL: messagePageLinks.prev,
          latestURL: messagePageLinks.latest,
          currentPage: currentPage,
          onPageLinkTapped: onPageLinkTapped
        )
        .frame(minWidth: 300, idealWidth: 700, maxWidth: .infinity, maxHeight: .infinity)
      }
      .animation(Animation.userPreference, value: selectedList != nil)
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
    .onChange(of: settingsManager.shouldOpenSettings) { _, newValue in
      if newValue {
        withAnimation(Animation.userPreference) {
          selectedSidebarTab = .settings
        }
        settingsManager.shouldOpenSettings = false
      }
    }
    .task {
      if mailingLists.isEmpty {
        isLoadingMailingLists = true
        do {
          let html = try await NetworkService.shared.fetchHomePage()
          let lists = Parser.parseListsFromHomePage(from: html)
          for list in lists {
            let mailingList = MailingList(name: list.name, desc: list.desc)
            modelContext.insert(mailingList)
          }
          isLoadingMailingLists = false
        } catch {
          print("Failed to load mailing lists: \(error)")
          isLoadingMailingLists = false
        }
      }
    }
  }
}

struct PaginationButton: View {
  let systemName: String
  let help: String
  let isEnabled: Bool
  let action: () -> Void

  @State private var isHovered: Bool = false

  var body: some View {
    Button(action: action) {
      Image(systemName: systemName)
        .imageScale(.large)
        .foregroundColor(isEnabled ? (isHovered ? .accentColor : .primary) : .secondary)
        .scaleEffect(isHovered ? 1.1 : 1.0)
        .help(help)
    }
    .buttonStyle(.borderless)
    .disabled(!isEnabled)
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .animation(Animation.userPreferenceQuick, value: isHovered)
  }
}
