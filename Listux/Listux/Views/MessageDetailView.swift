import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct MessageDetailView: View {
  var selectedMessage: Message?
  @State private var parsedDetail: ParsedMessageDetail?
  @State private var isLoadingHtml: Bool = false
  @State private var isFavoriteAnimating: Bool = false
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""
  @State private var selectedTab: Int = 0
  @State private var showFullContent: Bool = false
  @State private var currentPage: Int = 0
  @Environment(\.modelContext) private var modelContext
  @Query private var preferences: [Preference]

  private var preference: Preference {
    if let existing = preferences.first {
      return existing
    } else {
      let new = Preference()
      modelContext.insert(new)
      return new
    }
  }

  private var isFavorite: Bool {
    guard let message = selectedMessage else { return false }
    return preference.isFavoriteMessage(message.messageId)
  }

  private var isPatchEmail: Bool {
    guard let detail = parsedDetail else { return false }
    return !detail.diffContent.isEmpty
  }
  
  private var hasMultiplePages: Bool {
    guard let detail = parsedDetail else { return false }
    if isPatchEmail {
      return detail.content.count > 5000
    } else {
      let lines = detail.content.components(separatedBy: .newlines)
      return lines.count > 150
    }
  }
  
  private var totalPages: Int {
    guard let detail = parsedDetail else { return 1 }
    if isPatchEmail {
      return (detail.content.count + 5000 - 1) / 5000
    } else {
      let lines = detail.content.components(separatedBy: .newlines)
      return (lines.count + 150 - 1) / 150
    }
  }

  private var availableTabs: [String] {
    guard let detail = parsedDetail else { return [] }
    return ["Metadata", "Content"]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let msg = selectedMessage {
        // Fixed header section - NO SCROLLING
        VStack(alignment: .leading, spacing: 8) {
          // Header with favorite button
          HStack {
            Text(msg.subject)
              .font(.headline)
              .bold()
              .lineLimit(2)
            Spacer()
            Button(action: {
              preference.toggleFavoriteMessage(msg.messageId)
              isFavoriteAnimating = true
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFavoriteAnimating = false
              }
            }) {
              Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .yellow : .secondary)
                .scaleEffect(isFavoriteAnimating ? 1.2 : 1.0)
            }
            .buttonStyle(.plain)
          }

          HStack {
            Text(msg.timestamp, style: .date)
              .font(.caption)
              .foregroundColor(.secondary)
            
            Spacer()
            
            // Message ID and copy functionality - compact version
            Button(action: {
              #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(msg.messageId, forType: .string)
              #else
                UIPasteboard.general.string = msg.messageId
              #endif
            }) {
              Image(systemName: "doc.on.doc")
                .font(.system(size: 12))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Copy Message ID")
          }

          // Tags section - compact version
          if isFavorite {
            HStack {
              Button(action: {
                showingTagInput = true
              }) {
                Image(systemName: "plus.circle")
                  .font(.system(size: 14))
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
                        preference.addTag(newTag, to: msg.messageId)
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

              if !preference.getTags(for: msg.messageId).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 4) {
                    ForEach(preference.getTags(for: msg.messageId), id: \.self) { tag in
                      HStack(spacing: 2) {
                        Text(tag)
                          .font(.caption2)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(
                            RoundedRectangle(cornerRadius: 3)
                              .fill(Color.blue.opacity(0.2))
                          )

                        Button(action: {
                          preference.removeTag(tag, from: msg.messageId)
                        }) {
                          Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                      }
                    }
                  }
                  .padding(.horizontal, 4)
                }
              }
            }
          }

          Divider()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        #if os(macOS)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(UIColor.systemBackground))
        #endif

        // Fixed toolbar - NO SCROLLING
        if let detail = parsedDetail {
          HStack(spacing: 8) {
            // Tab selector with icons
            if availableTabs.count > 1 {
              HStack(spacing: 0) {
                ForEach(Array(availableTabs.enumerated()), id: \.offset) { index, tab in
                  Button(action: {
                    selectedTab = index
                  }) {
                    HStack(spacing: 4) {
                      Image(systemName: tab == "Metadata" ? "info.circle" : "doc.text")
                        .font(.system(size: 12))
                      Text(tab)
                        .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedTab == index ? Color.accentColor.opacity(0.2) : Color.clear)
                    .foregroundColor(selectedTab == index ? .accentColor : .secondary)
                    .cornerRadius(4)
                  }
                  .buttonStyle(.plain)
                  
                  if index < availableTabs.count - 1 {
                    Divider()
                      .frame(height: 16)
                      .padding(.horizontal, 2)
                  }
                }
              }
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(6)
            }
            
            Spacer()
            
            // Content controls (only for Content tab)
            if selectedTab < availableTabs.count && availableTabs[selectedTab] == "Content" {
              // Show More/Less button
              if hasMultiplePages {
                Button(showFullContent ? "Show Less" : "Show More") {
                  showFullContent.toggle()
                  currentPage = 0
                }
                .buttonStyle(.bordered)
                .font(.caption2)
                .controlSize(.small)
              }
              
              // Pagination controls (only when showing full content)
              if showFullContent && totalPages > 1 {
                Button("←") {
                  if currentPage > 0 {
                    currentPage -= 1
                  }
                }
                .disabled(currentPage == 0)
                .buttonStyle(.bordered)
                .font(.caption2)
                .controlSize(.small)
                
                Text("\(currentPage + 1) / \(totalPages)")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .frame(minWidth: 50)
                
                Button("→") {
                  if currentPage < totalPages - 1 {
                    currentPage += 1
                  }
                }
                .disabled(currentPage == totalPages - 1)
                .buttonStyle(.bordered)
                .font(.caption2)
                .controlSize(.small)
              }
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
          #if os(macOS)
          .background(Color(NSColor.controlBackgroundColor))
          #else
          .background(Color(UIColor.systemBackground))
          #endif
        }

        // Content area with fixed controls and scrollable content
        GeometryReader { geometry in
          if isLoadingHtml {
            VStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("Loading message content...")
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: geometry.size.height, alignment: .top)
            .padding()
          } else if let detail = parsedDetail {
            if selectedTab < availableTabs.count {
              ScrollViewReader { proxy in
                ScrollView {
                  VStack(alignment: .leading, spacing: 16) {
                    switch availableTabs[selectedTab] {
                    case "Metadata":
                      MessageMetadataView(metadata: detail.metadata)
                    case "Content":
                      if isPatchEmail {
                        MessageContentView(
                          content: detail.content,
                          showFullContent: showFullContent,
                          currentPage: currentPage
                        )
                      } else {
                        EmailContentView(
                          content: detail.content,
                          showFullContent: showFullContent,
                          currentPage: currentPage
                        )
                      }
                    default:
                      EmptyView()
                    }
                  }
                  .padding()
                  .id("content-top")
                }
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height, alignment: .top)
                .onChange(of: currentPage) { _, _ in
                  withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("content-top", anchor: .top)
                  }
                }
                .onChange(of: showFullContent) { _, _ in
                  withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("content-top", anchor: .top)
                  }
                }
                .onChange(of: selectedTab) { _, _ in
                  // Reset content state when switching tabs
                  showFullContent = false
                  currentPage = 0
                }
              }
            }
          } else {
            Text("No parsed content available")
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, maxHeight: geometry.size.height, alignment: .top)
              .padding()
          }
        }
      } else {
        Text("No message selected")
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding()
      }
    }
    .onChange(of: selectedMessage) { _, newMessage in
      print("onChange triggered - newMessage: \(newMessage?.subject ?? "nil")")
      if let message = newMessage {
        loadMessageDetail(message: message)
        // Reset content state when switching messages
        showFullContent = false
        currentPage = 0
      } else {
        parsedDetail = nil
        isLoadingHtml = false
        showFullContent = false
        currentPage = 0
      }
    }
    .onAppear {
      print("onAppear triggered - selectedMessage: \(selectedMessage?.subject ?? "nil")")
      if let message = selectedMessage {
        loadMessageDetail(message: message)
      }
    }
  }

  private func loadMessageDetail(message: Message) {
    print("loadMessageDetail called for message: \(message.subject)")

    isLoadingHtml = true
    parsedDetail = nil

    Task {
      do {
        var url = message.messageId

        if !url.hasPrefix("http") {
          let base = LORE_LINUX_BASE_URL.value
          let relativePath = message.content.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
          url = "\(base)/\(message.mailingList?.name ?? "")/\(relativePath)"
        }

        print("Loading HTML from URL: \(url)")
        print("Message content field: \(message.content)")
        print("Message mailing list: \(message.mailingList?.name ?? "nil")")

        guard URL(string: url) != nil else {
          throw URLError(.badURL)
        }

        let html = try await NetworkService.shared.fetchMessageRaw(url: url)

        if html.isEmpty {
          print("Warning: Received empty HTML content")
        }

        // Parse the HTML content
        let parsed = MessageDetailParser.parseMessageDetail(
          from: html, messageId: message.messageId)

        // Update the message with parsed data
        if let parsed = parsed {
          await MainActor.run {
            // Only update if values have changed to prevent unnecessary SwiftData updates
            if message.author != parsed.metadata.author {
              message.author = parsed.metadata.author
            }
            if message.recipients != parsed.metadata.recipients {
              message.recipients = parsed.metadata.recipients
            }
            if message.ccRecipients != parsed.metadata.ccRecipients {
              message.ccRecipients = parsed.metadata.ccRecipients
            }
            if message.rawHtml != parsed.rawHtml {
              message.rawHtml = parsed.rawHtml
            }
            if message.permalink != parsed.metadata.permalink {
              message.permalink = parsed.metadata.permalink
            }
            if message.rawUrl != parsed.metadata.rawUrl {
              message.rawUrl = parsed.metadata.rawUrl
            }
          }
        }

        await MainActor.run {
          parsedDetail = parsed
          isLoadingHtml = false
        }
      } catch {
        print("Failed to load message detail: \(error)")
        print("Error details: \(error.localizedDescription)")

        await MainActor.run {
          parsedDetail = nil
          isLoadingHtml = false
        }
      }
    }
  }
}

#Preview {
  MessageDetailView(selectedMessage: nil)
}
