import SwiftData
import SwiftUI

#if os(iOS)
  import UIKit
#endif

struct MessageDetailView: View {
  var selectedMessage: Message?
  @State private var messageHtml: String = ""
  @State private var isLoadingHtml: Bool = false
  @State private var isFavoriteAnimating: Bool = false
  @State private var showingTagInput: Bool = false
  @State private var newTag: String = ""
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

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        if let msg = selectedMessage {
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

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Raw HTML Content")
                .font(.headline)
              Spacer()
              if isLoadingHtml {
                ProgressView()
                  .scaleEffect(0.8)
              }
            }

            if isLoadingHtml {
              Text("Loading message content...")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if messageHtml.isEmpty {
              Text("No HTML content loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              let displayHtml =
                messageHtml.prefix(3000)
                + (messageHtml.count > 3000
                  ? "\n\n... (content truncated, showing first 3000 characters)" : "")
              Text(displayHtml)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            }
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
        loadMessageHtml(message: message)
      } else {
        messageHtml = ""
        isLoadingHtml = false
      }
    }
    .onAppear {
      print("onAppear triggered - selectedMessage: \(selectedMessage?.subject ?? "nil")")
      if let message = selectedMessage {
        loadMessageHtml(message: message)
      }
    }
  }

  private func loadMessageHtml(message: Message) {
    print("loadMessageHtml called for message: \(message.subject)")

    isLoadingHtml = true
    messageHtml = ""

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

        await MainActor.run {
          messageHtml = html
          isLoadingHtml = false
        }
      } catch {
        print("Failed to load message HTML: \(error)")
        print("Error details: \(error.localizedDescription)")

        await MainActor.run {
          messageHtml = "Error loading message content: \(error.localizedDescription)"
          isLoadingHtml = false
        }
      }
    }
  }
}

#Preview {
  MessageDetailView(selectedMessage: nil)
}
