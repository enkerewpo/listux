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
  @State private var mailingListPageLinks: (next: String?, prev: String?, latest: String?) = (nil, nil, nil)
  @State private var messagePageLinks: (next: String?, prev: String?, latest: String?) = (nil, nil, nil)
  @State private var currentPage: Int = 1

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
            let base = "https://lore.kernel.org/"
            fullUrl = base + list.name + "/" + url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
          }
          let html = try await NetworkService.shared.fetchMessageRaw(url: fullUrl)
          let result = Parser.parseMsgsFromListPage(from: html, listName: list.name)
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
              let result = Parser.parseMsgsFromListPage(from: html, listName: list.name)
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
      .frame(minWidth: 180)
    } content: {
      VStack(spacing: 0) {
        HStack {
          if selectedList != nil {
            HStack(spacing: 24) {
              Button(action: {
                if let prev = messagePageLinks.prev { onPageLinkTapped(prev) }
              }) {
                Image(systemName: "chevron.left")
                  .imageScale(.large)
                  .help("Prev (Newer)")
              }
              .buttonStyle(.borderless)
              .disabled(messagePageLinks.prev == nil)
              Button(action: {
                if let latest = messagePageLinks.latest { onPageLinkTapped(latest) }
              }) {
                Image(systemName: "arrow.left.to.line")
                  .imageScale(.large)
                  .help("First Page")
              }
              .buttonStyle(.borderless)
              .disabled(messagePageLinks.latest == nil)
              Text("Page \(currentPage)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(minWidth: 60)
              Button(action: {
                if let next = messagePageLinks.next { onPageLinkTapped(next) }
              }) {
                Image(systemName: "chevron.right")
                  .imageScale(.large)
                  .help("Next (Older)")
              }
              .buttonStyle(.borderless)
              .disabled(messagePageLinks.next == nil)
            }
            .padding(.trailing, 16)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor).opacity(0.95))
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    } detail: {
      MessageDetailView(selectedMessage: selectedMessage)
        .frame(minWidth: 280, maxWidth: 400)
    }
    .onChange(of: selectedList) {
      selectedMessage = nil
      messagePageLinks = (nil, nil, nil)
      currentPage = 1
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
