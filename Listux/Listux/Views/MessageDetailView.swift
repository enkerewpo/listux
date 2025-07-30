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
  @State private var diffExpanded: Bool = false
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

    if !detail.diffContent.isEmpty {
      tabs.append("Diff")
    }

    if detail.threadNavigation != nil {
      tabs.append("Thread")
    }

    return tabs
  }

  private var totalDiffLines: Int {
    guard let detail = parsedDetail else { return 0 }
    return detail.diffContent.reduce(0) { total, diff in
      total + diff.context.count + diff.additions.count + diff.deletions.count
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let msg = selectedMessage {
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

          // Content tabs
          if isLoadingHtml {
            VStack {
              ProgressView()
                .scaleEffect(0.8)
              Text("Loading message content...")
                .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if let detail = parsedDetail {
            // Tab selector
            if availableTabs.count > 1 {
              Picker("Content Type", selection: $selectedTab) {
                ForEach(Array(availableTabs.enumerated()), id: \.offset) { index, tab in
                  Text(tab).tag(index)
                }
              }
              .pickerStyle(SegmentedPickerStyle())
              .padding(.horizontal)
            }

            // Tab content
            if selectedTab < availableTabs.count {
              switch availableTabs[selectedTab] {
              case "Metadata":
                MessageMetadataView(metadata: detail.metadata)
              case "Content":
                if isPatchEmail {
                  MessageContentView(content: detail.content)
                } else {
                  EmailContentView(content: detail.content)
                }
              case "Diff":
                if detail.diffContent.isEmpty {
                  Text("No diff content available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                  VStack(alignment: .leading, spacing: 8) {
                    // Diff summary and controls
                    HStack {
                      Text("Diff Content")
                        .font(.headline)

                      Spacer()

                      Text("\(detail.diffContent.count) files, \(totalDiffLines) lines")
                        .font(.caption)
                        .foregroundColor(.secondary)

                      Button(action: {
                        diffExpanded.toggle()
                      }) {
                        Image(systemName: diffExpanded ? "chevron.up" : "chevron.down")
                          .font(.caption)
                      }
                      .buttonStyle(.plain)
                    }

                    if diffExpanded {
                      // Optimized diff list with virtualization
                      OptimizedDiffListView(diffs: detail.diffContent)
                    } else {
                      // Show first few diffs as preview
                      VStack(spacing: 8) {
                        ForEach(Array(detail.diffContent.prefix(3).enumerated()), id: \.offset) {
                          index, diff in
                          DiffContentView(diff: diff)
                        }

                        if detail.diffContent.count > 3 {
                          Button(
                            "Show all \(detail.diffContent.count) files (\(totalDiffLines) lines)"
                          ) {
                            diffExpanded = true
                          }
                          .buttonStyle(.bordered)
                        }
                      }
                    }
                  }
                }
              case "Thread":
                if let navigation = detail.threadNavigation {
                  ThreadNavigationView(navigation: navigation) { messageId in
                    // Handle navigation to other messages
                    print("Navigate to message: \(messageId)")
                  }
                }
              default:
                EmptyView()
              }
            }
          } else {
            Text("No parsed content available")
              .foregroundColor(.secondary)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          }

          Spacer()
        } else {
          Text("No message selected")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .padding()
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
    diffExpanded = false

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
