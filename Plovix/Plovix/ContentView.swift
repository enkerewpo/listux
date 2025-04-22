//
//  ContentView.swift
//  Plovix
//
//  Created by Mr wheatfox on 2025/3/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MailingList.name) private var mailingLists: [MailingList]
    @Query private var preferences: [Preference]
    @State private var selectedList: MailingList?
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
                list.name.localizedCaseInsensitiveContains(searchText) ||
                list.desc.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                
                List {
                    // Favorite lists section
                    if !filteredLists.filter({ preference.isFavorite($0) }).isEmpty {
                        Section("Favorites") {
                            ForEach(filteredLists.filter { preference.isFavorite($0) }) { list in
                                MailingListRow(list: list, preference: preference, hoveredList: $hoveredList)
                            }
                        }
                    }
                    
                    // All lists section
                    Section {
                        ForEach(filteredLists.filter { !preference.isFavorite($0) }) { list in
                            MailingListRow(list: list, preference: preference, hoveredList: $hoveredList)
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
            Text("Select a mailing list")
                .foregroundColor(.secondary)
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
            // Clear existing lists
            for list in mailingLists {
                modelContext.delete(list)
            }
            
            // Fetch and parse new lists
            let html = try await NetworkService.shared.fetchMainPage()
            let lists = Parser.parseMailingLists(from: html)
            
            // Create new MailingList objects
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
    let list: MailingList
    @State private var isLoading = false
    @State private var error: Error?
    @State private var expandedMessages: Set<String> = []
    
    var body: some View {
        List {
            ForEach(list.messages) { message in
                MessageRow(message: message, expandedMessages: $expandedMessages)
            }
        }
        .navigationTitle(list.name)
        .task {
            await loadMessages()
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let html = try await NetworkService.shared.fetchMailingList(list.name)
            let messages = Parser.parseMessages(from: html)
            
            // Clear existing messages
            list.messages.removeAll()
            
            // Add new messages
            for message in messages {
                list.messages.append(message)
            }
        } catch {
            self.error = error
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
        NavigationLink {
            MessageListView(list: list)
        } label: {
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

