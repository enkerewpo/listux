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

  private var availableTabs: [String] {
    guard let detail = parsedDetail else { return [] }
    var tabs = ["Metadata", "Content"]

    if detail.threadNavigation != nil {
      tabs.append("Thread")
    }

    return tabs
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let msg = selectedMessage {
        // Fixed header section - NO SCROLLING
        VStack(alignment: .leading, spacing: 16) {
          // Header with favorite button
          HStack {
            Text(msg.subject)
              .font(.title2)
              .bold()
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

          Text(msg.timestamp, style: .date)
            .font(.caption)
            .foregroundColor(.secondary)

          Divider()

          // Message ID and copy functionality
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Message ID: \(msg.messageId)")
                .font(.caption)
                .foregroundColor(.secondary)

              Spacer()

              Button(action: {
                #if os(macOS)
                  NSPasteboard.general.clearContents()
                  NSPasteboard.general.setString(msg.messageId, forType: .string)
                #else
                  UIPasteboard.general.string = msg.messageId
                #endif
              }) {
                Image(systemName: "doc.on.doc")
                  #if os(macOS)
                    .font(.system(size: 12))
                  #else
                    .font(.system(size: 14))
                  #endif
                  .foregroundColor(.blue)
              }
              .buttonStyle(.plain)
              .help("Copy Message ID")
            }
          }

          // Tags section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              if isFavorite {
                Button(action: {
                  showingTagInput = true
                }) {
                  Image(systemName: "plus.circle")
                    #if os(macOS)
                      .font(.system(size: 16))
                    #else
                      .font(.system(size: 18))
                    #endif
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
              }
            }

            if !preference.getTags(for: msg.messageId).isEmpty {
              LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 4) {
                ForEach(preference.getTags(for: msg.messageId), id: \.self) { tag in
                  HStack {
                    Text(tag)
                      .font(.caption)
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(
                        RoundedRectangle(cornerRadius: 4)
                          .fill(Color.blue.opacity(0.2))
                      )

                    Button(action: {
                      preference.removeTag(tag, from: msg.messageId)
                    }) {
                      Image(systemName: "xmark.circle.fill")
                        #if os(macOS)
                          .font(.system(size: 12))
                        #else
                          .font(.system(size: 14))
                        #endif
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            } else {
              Text("No tags")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          Divider()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))

        // Fixed tab selector - NO SCROLLING
        if let detail = parsedDetail, availableTabs.count > 1 {
          Picker("", selection: $selectedTab) {
            ForEach(Array(availableTabs.enumerated()), id: \.offset) { index, tab in
              Text(tab).tag(index)
            }
          }
          .pickerStyle(SegmentedPickerStyle())
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(Color(NSColor.controlBackgroundColor))
        }

        // Content area with fixed controls and scrollable content
        if isLoadingHtml {
          VStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading message content...")
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          .padding()
        } else if let detail = parsedDetail {
          if selectedTab < availableTabs.count {
            VStack(alignment: .leading, spacing: 16) {
              switch availableTabs[selectedTab] {
              case "Metadata":
                MessageMetadataView(metadata: detail.metadata)
              case "Content":
                if isPatchEmail {
                  MessageContentView(content: detail.content)
                } else {
                  EmailContentView(content: detail.content)
                }
              case "Thread":
                if let navigation = detail.threadNavigation {
                  ThreadNavigationView(navigation: navigation) { messageId in
                    print("Navigate to message: \(messageId)")
                  }
                }
              default:
                EmptyView()
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
          }
        } else {
          Text("No parsed content available")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding()
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
      } else {
        parsedDetail = nil
        isLoadingHtml = false
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
            message.author = parsed.metadata.author
            message.recipients = parsed.metadata.recipients
            message.ccRecipients = parsed.metadata.ccRecipients
            message.rawHtml = parsed.rawHtml
            message.permalink = parsed.metadata.permalink
            message.rawUrl = parsed.metadata.rawUrl
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
