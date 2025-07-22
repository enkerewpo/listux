import SwiftUI

struct MessageDetailView: View {
  var selectedMessage: Message?
  @State private var messageHtml: String = ""
  @State private var isLoadingHtml: Bool = false
  @State private var isFavoriteAnimating: Bool = false

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
                msg.isFavorite.toggle()
                isFavoriteAnimating = true
              }
              // Reset animation state after animation completes
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFavoriteAnimating = false
              }
            }) {
              Image(systemName: msg.isFavorite ? "star.fill" : "star")
                .foregroundColor(msg.isFavorite ? .yellow : .secondary)
                .scaleEffect(isFavoriteAnimating ? AnimationConstants.favoriteAnimationScale : 1.0)
                .rotationEffect(.degrees(isFavoriteAnimating ? 360 : 0))
            }
            .buttonStyle(.plain)
            .animation(AnimationConstants.springQuick, value: msg.isFavorite)
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
            Text("Message ID: \(msg.messageId)")
              .font(.caption)
              .foregroundColor(.secondary)
              .transition(AnimationConstants.slideFromLeading)

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
