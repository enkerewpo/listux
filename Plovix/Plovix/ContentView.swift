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
    @State private var selectedList: MailingList?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var searchText = ""
    
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
            List {
                ForEach(filteredLists) { list in
                    NavigationLink {
                        MessageListView(list: list)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(list.name)
                                .font(.headline)
                            Text(list.desc)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteLists)
            }
            .searchable(text: $searchText, prompt: "Search mailing lists")
            .navigationTitle("Linux Kernel Mailing Lists")
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if message.parent != nil {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .foregroundColor(.secondary)
                        .imageScale(.small)
                }
                
                Text(message.subject)
                    .font(.headline)
                
                Spacer()
                
                if !message.replies.isEmpty {
                    Button(action: {
                        if expandedMessages.contains(message.id) {
                            expandedMessages.remove(message.id)
                        } else {
                            expandedMessages.insert(message.id)
                        }
                    }) {
                        Image(systemName: expandedMessages.contains(message.id) ? "chevron.down" : "chevron.right")
                    }
                }
            }
            
            HStack {
                Text(message.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(message.date, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if expandedMessages.contains(message.id) {
                ForEach(message.replies) { reply in
                    MessageRow(message: reply, expandedMessages: $expandedMessages)
                        .padding(.leading, 20)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: MailingList.self, inMemory: true)
}
