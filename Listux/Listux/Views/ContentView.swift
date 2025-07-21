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

  var body: some View {
    NavigationSplitView {
      SidebarView(
        selectedSidebarTab: $selectedSidebarTab,
        selectedList: $selectedList,
        mailingLists: mailingLists,
        isLoading: isLoadingMailingLists,
        searchText: $mailingListSearchText,
        onSelectList: { list in
          isLoadingMessages = true
          Task {
            do {
              let html = try await NetworkService.shared.fetchListPage(list.name)
              let messages = Parser.parseMsgsFromListPage(from: html, listName: list.name)
              await MainActor.run {
                list.orderedMessages = messages
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
      MessageListView(
        selectedSidebarTab: selectedSidebarTab, selectedList: selectedList,
        selectedMessage: $selectedMessage,
        isLoading: isLoadingMessages
      )
      .frame(minWidth: 400, idealWidth: 1000)
    } detail: {
      MessageDetailView(selectedMessage: selectedMessage)
        .frame(minWidth: 280, maxWidth: 400)
    }
    .onChange(of: selectedList) { _ in
      selectedMessage = nil
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
