import SwiftUI
import SwiftData
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
              .transition(AnimationConstants.slideFromLeading)
            Spacer()
            Button(action: {
              withAnimation(AnimationConstants.springQuick) {
                preference.toggleFavoriteMessage(msg.messageId)
                isFavoriteAnimating = true
              }
              // Reset animation state after animation completes
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFavoriteAnimating = false
              }
            }) {
              Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundColor(isFavorite ? .yellow : .secondary)
                .scaleEffect(isFavoriteAnimating ? AnimationConstants.favoriteAnimationScale : 1.0)
                .rotationEffect(.degrees(isFavoriteAnimating ? 360 : 0))
            }
            .buttonStyle(.plain)
            .animation(AnimationConstants.springQuick, value: isFavorite)
          }
          .transition(AnimationConstants.slideFromTop)

          Text(msg.timestamp, style: .date)
            .font(.caption)
            .foregroundColor(.secondary)
            .transition(AnimationConstants.slideFromLeading)

          Divider()
            .transition(.opacity)

          // Message details section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Message ID: \(msg.messageId)")
                .font(.caption)
                .foregroundColor(.secondary)
                .transition(AnimationConstants.slideFromLeading)
              
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
                  .font(.caption)
                  .foregroundColor(.blue)
              }
              .buttonStyle(.plain)
              .help("Copy Message ID")
            }

            Text("Sequence ID: \(msg.seqId)")
              .font(.caption)
              .foregroundColor(.secondary)
              .transition(AnimationConstants.slideFromLeading)

            Text("Content URL: \(msg.content)")
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
              .truncationMode(.middle)
              .transition(AnimationConstants.slideFromLeading)
          }
          .transition(AnimationConstants.slideFromLeading)

          // Tag management section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Tags")
                .font(.headline)
                .transition(AnimationConstants.slideFromLeading)
              
              Spacer()
              
              Button(action: {
                showingTagInput = true
              }) {
                Image(systemName: "plus.circle")
                  .font(.caption)
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
                        .font(.caption2)
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
          .transition(AnimationConstants.slideFromLeading)

          Divider()
            .transition(.opacity)

          // Raw HTML section
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Raw HTML Content")
                .font(.headline)
                .transition(AnimationConstants.slideFromLeading)
              Spacer()
              if isLoadingHtml {
                ProgressView()
                  .scaleEffect(0.8)
                  .transition(.opacity.combined(with: .scale(scale: 0.8)))
              }
            }

            if isLoadingHtml {
              Text("Loading message content...")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AnimationConstants.fadeInOut)
            } else if messageHtml.isEmpty {
              Text("No HTML content loaded")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(AnimationConstants.fadeInOut)
            } else {
              Text(messageHtml)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .transition(AnimationConstants.slideFromBottom)
            }
          }
          .transition(AnimationConstants.slideFromTrailing)

          Spacer()
        } else {
          Text("No message selected")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(AnimationConstants.fadeInOut)
        }
      }
    }
    .padding()
    .animation(AnimationConstants.standard, value: selectedMessage?.id)
    .onChange(of: selectedMessage) { _, newMessage in
      if let message = newMessage {
        loadMessageHtml(message: message)
      } else {
        withAnimation(AnimationConstants.quick) {
          messageHtml = ""
          isLoadingHtml = false
        }
      }
    }
  }

  private func loadMessageHtml(message: Message) {
    withAnimation(AnimationConstants.quick) {
      isLoadingHtml = true
      messageHtml = ""
    }

    Task {
      do {
        // Use messageId which contains the full URL, or construct from content if needed
        let url: String
        if message.messageId.hasPrefix("http") {
          url = message.messageId
        } else {
          // Fallback to content field which should contain the relative URL
          let base = LORE_LINUX_BASE_URL.value + "/"
          url = base + message.content.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        let html = try await NetworkService.shared.fetchMessageRaw(url: url)
        await MainActor.run {
          withAnimation(AnimationConstants.standard) {
            messageHtml = html
            isLoadingHtml = false
          }
        }
      } catch {
        print("Failed to load message HTML: \(error)")
        await MainActor.run {
          withAnimation(AnimationConstants.quick) {
            messageHtml = "Error loading message content: \(error.localizedDescription)"
            isLoadingHtml = false
          }
        }
      }
    }
  }
}

#Preview {
  MessageDetailView(selectedMessage: nil)
}
