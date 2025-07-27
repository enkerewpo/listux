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

  // Handle settings menu command
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
  
  private var taggedMessages: [Message] {
    guard let tag = selectedTag else { return [] }
    
    let messageIds: [String]
    if tag == "Untagged" {
      messageIds = preference.getUntaggedMessages()
    } else {
      messageIds = preference.getMessagesWithTag(tag)
    }
    
    // Get all messages from all lists and filter by message IDs
    var allMessages: [Message] = []
    for list in mailingLists {
      allMessages.append(contentsOf: list.messages)
    }
    
    return allMessages.filter { message in
      messageIds.contains(message.messageId)
    }.sorted { $0.timestamp > $1.timestamp }
  }

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
        selectedTag: $selectedTag,
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
        },
        onSelectTag: { tag in
          selectedTag = tag
          selectedMessage = nil
        }
      )
      .frame(minWidth: 240, idealWidth: 380, maxWidth: .infinity)
    } content: {
      VStack(spacing: 0) {
        // Show different content based on selected tab
        if selectedSidebarTab == .favorites {
          // Favorites view - show tagged messages
          if let tag = selectedTag {
            VStack(spacing: 0) {
              // Header showing selected tag
              HStack {
                Text("Tag: \(tag)")
                  .font(.headline)
                  .foregroundColor(.primary)
                Spacer()
                Text("\(taggedMessages.count) message\(taggedMessages.count == 1 ? "" : "s")")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
              .background(Color(.windowBackgroundColor).opacity(0.95))
              
              Divider()
              
              // Tagged messages list
              if taggedMessages.isEmpty {
                Text("No messages with tag '\(tag)'")
                  .foregroundColor(.secondary)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              } else {
                List(selection: $selectedMessage) {
                  ForEach(taggedMessages, id: \.messageId) { message in
                    TaggedMessageRowView(message: message, preference: preference, selectedMessage: $selectedMessage)
                      .onTapGesture {
                        withAnimation(Animation.userPreferenceQuick) {
                          selectedMessage = message
                        }
                      }
                  }
                }
                .listStyle(.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
            }
          } else {
            Text("Select a tag to view messages")
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }
        } else {
          // Lists view - show normal message list with pagination
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
          #if os(macOS)
            .background(Color(.windowBackgroundColor).opacity(0.95))
          #else
            .background(Color(.systemBackground).opacity(0.95))
          #endif
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

struct TaggedMessageRowView: View {
  let message: Message
  let preference: Preference
  @Binding var selectedMessage: Message?
  @State private var isHovered: Bool = false
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(message.subject)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
          
          HStack {
            Text(message.mailingList?.name ?? "Unknown")
              .font(.system(size: 10))
              .foregroundColor(.secondary)
            
            Spacer()
            
            Text(message.timestamp, style: .date)
              .font(.system(size: 8))
              .foregroundColor(.secondary)
          }
          
          // Message ID with copy functionality
          HStack {
            Text("ID: \(message.messageId)")
              .font(.system(size: 8))
              .foregroundColor(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
            
            Spacer()
            
            Button(action: {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(message.messageId, forType: .string)
            }) {
              Image(systemName: "doc.on.doc")
                .font(.system(size: 8))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Copy Message ID")
          }
        }
        
        Spacer()
        
        // Tag management
        HStack(spacing: 4) {
          // Show existing tags
          ForEach(preference.getTags(for: message.messageId), id: \.self) { tag in
            TagChipView(tag: tag) {
              preference.removeTag(tag, from: message.messageId)
            }
          }
          
          // Add tag button
          Button(action: {
            showingTagInput = true
          }) {
            Image(systemName: "plus.circle")
              .font(.system(size: 10))
              .foregroundColor(.blue)
          }
          .buttonStyle(.plain)
          .popover(isPresented: $showingTagInput) {
            VStack(spacing: 8) {
              Text("Add Tag")
                .font(.headline)
              
              TextField("Tag name", text: $newTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())
              
              HStack {
                Button("Cancel") {
                  showingTagInput = false
                  newTag = ""
                }
                
                Button("Add") {
                  if !newTag.isEmpty {
                    preference.addTag(newTag, to: message.messageId)
                    newTag = ""
                  }
                  showingTagInput = false
                }
                .disabled(newTag.isEmpty)
              }
            }
            .padding()
            .frame(width: 200)
          }
          
          // Unfavorite button
          Button(action: {
            withAnimation(Animation.userPreferenceQuick) {
              preference.toggleFavoriteMessage(message.messageId)
            }
          }) {
            Image(systemName: "star.fill")
              .font(.system(size: 10))
              .foregroundColor(.yellow)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 3)
        .fill(
          selectedMessage?.messageId == message.messageId
            ? Color.accentColor.opacity(0.1)
            : (isHovered ? Color.primary.opacity(0.1) : Color.clear)
        )
    )
    .onHover { hovering in
      withAnimation(Animation.userPreferenceQuick) {
        isHovered = hovering
      }
    }
    .animation(Animation.userPreferenceQuick, value: isHovered)
    .animation(Animation.userPreferenceQuick, value: selectedMessage?.messageId == message.messageId)
  }
}

struct TagChipView: View {
  let tag: String
  let onRemove: () -> Void
  
  var body: some View {
    HStack(spacing: 2) {
      Text(tag)
        .font(.system(size: 8))
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.blue.opacity(0.2))
        )
      
      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 8))
          .foregroundColor(.red)
      }
      .buttonStyle(.plain)
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
