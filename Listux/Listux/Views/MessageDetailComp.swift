import SwiftUI

struct MessageMetadataView: View {
  let metadata: MessageMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {

      // Author and Date
      HStack {
        Label(metadata.author, systemImage: "person.circle")
          .font(.subheadline)
          .foregroundColor(.primary)

        Spacer()

        Text(metadata.date, style: .date)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      // Recipients
      if !metadata.recipients.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("To:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(metadata.recipients, id: \.self) { recipient in
            Text(recipient)
              .font(.caption)
              .foregroundColor(.primary)
          }
        }
      }

      // CC Recipients
      if !metadata.ccRecipients.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Cc:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(metadata.ccRecipients, id: \.self) { recipient in
            Text(recipient)
              .font(.caption)
              .foregroundColor(.primary)
          }
        }
      }

      // Links
      HStack {
        if !metadata.permalink.isEmpty {
          Link(
            "Permalink",
            destination: URL(string: metadata.permalink) ?? URL(string: "https://lore.kernel.org")!
          )
          .font(.caption)
        }

        if !metadata.rawUrl.isEmpty {
          Link(
            "Raw",
            destination: URL(string: metadata.rawUrl) ?? URL(string: "https://lore.kernel.org")!
          )
          .font(.caption)
        }

        Spacer()
      }
    }
    .padding()
    .background(backgroundColor)
    .cornerRadius(8)
  }

  private var backgroundColor: Color {
    #if os(macOS)
      return Color(NSColor.windowBackgroundColor)
    #else
      return Color(.systemBackground)
    #endif
  }
}

struct MessageContentView: View {
  let content: String
  let showFullContent: Bool
  let currentPage: Int

  private let maxPreviewLength = 5000
  private let pageSize = 5000

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyVStack(alignment: .leading, spacing: 8) {
        if showFullContent {
          // Show paginated content
          PaginatedContentView(content: content, pageSize: pageSize, currentPage: currentPage)
        } else {
          ScrollView {
            // Show preview
            let previewContent = String(content.prefix(maxPreviewLength))
            let formattedContent = formatEmailContent(previewContent)

            Text(formattedContent)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)

            if content.count > maxPreviewLength {
              Text("... (please click 'Show More' to see the full content)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .padding()
    .background(backgroundColor)
    .cornerRadius(8)
  }

  private var backgroundColor: Color {
    #if os(macOS)
      return Color(NSColor.windowBackgroundColor)
    #else
      return Color(.systemBackground)
    #endif
  }

  private func formatEmailContent(_ content: String) -> String {
    // Clean up the content for better display
    var formatted = content

    // Remove excessive whitespace
    formatted = formatted.replacingOccurrences(of: "\n\n\n", with: "\n\n")

    // Ensure proper paragraph spacing
    formatted = formatted.trimmingCharacters(in: .whitespacesAndNewlines)

    return formatted
  }
}

struct PaginatedContentView: View {
  let content: String
  let pageSize: Int
  let currentPage: Int

  private var totalPages: Int {
    (content.count + pageSize - 1) / pageSize
  }

  private var currentPageContent: String {
    let startIndex = content.index(content.startIndex, offsetBy: currentPage * pageSize)
    let endIndex = content.index(
      startIndex, offsetBy: min(pageSize, content.count - currentPage * pageSize))
    return String(content[startIndex..<endIndex])
  }

  var body: some View {
    VStack(spacing: 0) {
      // Scrollable content
      ScrollView {
        Text(currentPageContent)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .padding()
      }
    }
  }
}