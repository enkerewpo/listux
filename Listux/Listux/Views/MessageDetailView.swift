import SwiftUI

struct MessageDetailView: View {
  var selectedMessage: Message?
  @State private var messageHtml: String = ""
  @State private var isLoadingHtml: Bool = false

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
              msg.isFavorite.toggle()
            }) {
              Image(systemName: msg.isFavorite ? "star.fill" : "star")
                .foregroundColor(msg.isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
          }
          Text(msg.timestamp, style: .date)
            .font(.caption)
            .foregroundColor(.secondary)
          Divider()

          // Message details section
          VStack(alignment: .leading, spacing: 8) {
            Text("Message ID: \(msg.messageId)")
              .font(.caption)
              .foregroundColor(.secondary)

            Text("Sequence ID: \(msg.seqId)")
              .font(.caption)
              .foregroundColor(.secondary)

            Text("Content URL: \(msg.content)")
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
              .truncationMode(.middle)
          }

          Divider()

          // Raw HTML section
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
              Text(messageHtml)
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
      if let message = newMessage {
        loadMessageHtml(message: message)
      } else {
        messageHtml = ""
        isLoadingHtml = false
      }
    }
  }

  private func loadMessageHtml(message: Message) {
    isLoadingHtml = true
    messageHtml = ""

    Task {
      do {
        // Use messageId which contains the full URL, or construct from content if needed
        let url: String
        if message.messageId.hasPrefix("http") {
          url = message.messageId
        } else {
          // Fallback to content field which should contain the relative URL
          let base = LORE_LINUX_BASE_URL + "/"
          url = base + message.content.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        let html = try await NetworkService.shared.fetchMessageRaw(url: url)
        await MainActor.run {
          messageHtml = html
          isLoadingHtml = false
        }
      } catch {
        print("Failed to load message HTML: \(error)")
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
