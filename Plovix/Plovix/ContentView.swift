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
  @Query private var preferences: [Preference]
  @State private var selectedListID: UUID?
  @State private var isLoading = false
  @State private var error: Error?
  @State private var searchText = ""
  @State private var hoveredList: MailingList?

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      return new
    }
  }

  var filteredLists: [MailingList] {
    if searchText.isEmpty {
      return mailingLists
    } else {
      return mailingLists.filter { list in
        list.name.localizedCaseInsensitiveContains(searchText)
          || list.desc.localizedCaseInsensitiveContains(searchText)
      }
    }
  }

  var body: some View {
    NavigationSplitView {
      VStack {
        SearchBar(text: $searchText)
          .padding(.horizontal)
        List(selection: $selectedListID) {
          if !filteredLists.filter({ preference.isFavorite($0) }).isEmpty {
            Section("Favorites") {
              ForEach(filteredLists.filter { preference.isFavorite($0) }, id: \.id) { list in
                MailingListRow(list: list, preference: preference, hoveredList: $hoveredList)
                  .tag(list.id)
              }
            }
          }
          Section {
            ForEach(filteredLists.filter { !preference.isFavorite($0) }, id: \.id) { list in
              MailingListRow(list: list, preference: preference, hoveredList: $hoveredList)
                .tag(list.id)
            }
          }
        }
      }
      .navigationTitle("Linux Kernel Lists")
      .toolbar {
        ToolbarItem {
          Button(action: refreshLists) {
            Label("Refresh", systemImage: "arrow.clockwise")
          }
        }
      }
      .overlay {
        if isLoading {
          ProgressView()
        }
      }
    } detail: {
      if let selectedListID = selectedListID,
        let selectedList = mailingLists.first(where: { $0.id == selectedListID })
      {
        MessageListView(listID: selectedListID, mailingLists: mailingLists)
          .id(selectedListID)
      } else {
        Text("Select a mailing list")
          .foregroundColor(.secondary)
      }
    }
    .onChange(of: selectedListID) { newValue in
      if let id = newValue, let list = mailingLists.first(where: { $0.id == id }) {
        print("Selected MailingList: id=\(list.id), name=\(list.name)")
      } else {
        print("Selected MailingList: nil")
      }
    }
    .task {
      if mailingLists.isEmpty {
        await loadMailingLists()
      }
    }
  }

  private func refreshLists() {
    Task {
      await loadMailingLists()
    }
  }

  private func loadMailingLists() async {
    isLoading = true
    defer { isLoading = false }
    do {
      for list in mailingLists {
        modelContext.delete(list)
      }
      let html = try await NetworkService.shared.fetchHomePage()
      let lists = Parser.parseListsFromHomePage(from: html)
      for list in lists {
        let mailingList = MailingList(name: list.name, desc: list.desc)
        modelContext.insert(mailingList)
      }
    } catch {
      self.error = error
    }
  }

  private func deleteLists(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(mailingLists[index])
      }
    }
  }
}

struct SearchBar: View {
  @Binding var text: String

  var body: some View {
    HStack {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)

      TextField("Search mailing lists", text: $text)
        .textFieldStyle(RoundedBorderTextFieldStyle())

      if !text.isEmpty {
        Button(action: {
          text = ""
        }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

struct MessageListView: View {
  let listID: UUID
  let mailingLists: [MailingList]
  var logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: MessageListView.self))
  @State private var isLoading = false
  @State private var error: Error?

  var body: some View {
    if let list = mailingLists.first(where: { $0.id == listID }) {
      List {
        ForEach(list.orderedMessages) { message in
          MessageTreeView(message: message, level: 0)
        }
      }
      .navigationTitle(list.name)
      .task {
        print("[MessageListView] .task triggered for list: \(list.name), id: \(list.id)")
        await loadMessages(list: list)
      }
      .overlay {
        if isLoading {
          ProgressView()
        }
      }
    } else {
      Text("Mailing list not found")
    }
  }

  private func loadMessages(list: MailingList) async {
    print("[MessageListView] loadMessages called for list: \(list.name), id: \(list.id)")
    isLoading = true
    defer { isLoading = false }
    do {
      let html = try await NetworkService.shared.fetchListPage(list.name)
      let messages = Parser.parseMsgsFromListPage(from: html, listName: list.name)
      list.messages.removeAll()
      for message in messages {
        message.mailingList = list
        list.messages.append(message)
      }
      list.orderedMessages = messages
    } catch {
      self.error = error
    }
  }
}

struct MessageTreeView: View {
  let message: Message
  let level: Int
  @State private var isExpanded = false

  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<level, id: \.self) { _ in
        Rectangle()
          .frame(width: 1, height: 16)
          .foregroundColor(.secondary.opacity(0.3))
      }
      if !message.replies.isEmpty {
        Button {
          isExpanded.toggle()
        } label: {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.caption)
        }
        .buttonStyle(.plain)
      } else {
        Image(systemName: "chevron.right")
          .font(.caption)
          .opacity(0)
      }
      Text(message.subject)
        .font(.subheadline)
        .lineLimit(1)
      Text(message.timestamp, style: .date)
        .font(.caption2)
        .foregroundColor(.secondary)
        .lineLimit(1)
      Spacer()
    }
    .contentShape(Rectangle())
    .padding(.vertical, 2)
    if isExpanded && !message.replies.isEmpty {
      ForEach(message.replies) { reply in
        MessageTreeView(message: reply, level: level + 1)
      }
    }
  }
}

struct MessageRow: View {
  let message: Message
  @Binding var expandedMessages: Set<String>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        if message.parent != nil {
          Image(systemName: "arrowshape.turn.up.left.fill")
            .foregroundColor(.secondary)
            .imageScale(.small)
        }

        VStack(alignment: .leading) {
          Text(message.subject)
            .font(.headline)
          Text(message.timestamp, style: .date)
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()
      }
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
  }
}

struct MailingListRow: View {
  let list: MailingList
  let preference: Preference
  @Binding var hoveredList: MailingList?

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(list.name)
          .font(.headline)
        Text(list.desc)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      Spacer()
      if hoveredList == list || preference.isFavorite(list) {
        Button(action: {
          preference.toggleFavorite(list)
        }) {
          Image(systemName: preference.isFavorite(list) ? "star.fill" : "star")
            .foregroundColor(preference.isFavorite(list) ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
      }
    }
    .onHover { isHovered in
      hoveredList = isHovered ? list : nil
    }
  }
}

#Preview {
  ContentView()
    .modelContainer(for: [MailingList.self, Preference.self], inMemory: true)
}
