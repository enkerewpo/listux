import SwiftUI

struct MessageMetadataView: View {
  let metadata: MessageMetadata

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Subject
      Text(metadata.subject)
        .font(.title2)
        .bold()
        .multilineTextAlignment(.leading)

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

struct DiffContentView: View {
  let diff: MessageDiff

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // File path header
      Text(diff.filePath)
        .foregroundColor(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(4)
        .font(.system(.caption2, design: .monospaced, weight: .bold))

      // Diff content with performance optimization
      LazyVStack(alignment: .leading, spacing: 2) {
        ForEach(Array(diff.context.enumerated()), id: \.offset) { index, line in
          DiffLineView(line: line)
            .id("context-\(index)")
        }

        ForEach(Array(diff.deletions.enumerated()), id: \.offset) { index, line in
          DiffLineView(line: line)
            .id("deletion-\(index)")
        }

        ForEach(Array(diff.additions.enumerated()), id: \.offset) { index, line in
          DiffLineView(line: line)
            .id("addition-\(index)")
        }
      }
      .font(.system(.caption, design: .monospaced))
    }
    .padding()
    .background(backgroundColor)
    .cornerRadius(8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var backgroundColor: Color {
    #if os(macOS)
      return Color(NSColor.windowBackgroundColor)
    #else
      return Color(.systemBackground)
    #endif
  }
}

struct DiffLineView: View {
  let line: DiffLine

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      // Line number
      if let lineNumber = line.lineNumber {
        Text("\(lineNumber)")
          .font(.caption2)
          .foregroundColor(.secondary)
          .frame(width: 40, alignment: .trailing)
          .monospacedDigit()
      } else {
        Text("")
          .frame(width: 40)
      }

      // Content with appropriate styling
      Text(line.content)
        .foregroundColor(lineColor)
        .background(lineBackgroundColor)
        .textSelection(.enabled)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var lineColor: Color {
    switch line.type {
    case .addition:
      return .green
    case .deletion:
      return .red
    case .context:
      return .primary
    case .header:
      return .blue
    }
  }

  private var lineBackgroundColor: Color {
    switch line.type {
    case .addition:
      return Color.green.opacity(0.1)
    case .deletion:
      return Color.red.opacity(0.1)
    case .context:
      return Color.clear
    case .header:
      return Color.blue.opacity(0.1)
    }
  }
}

struct OptimizedDiffListView: View {
  let diffs: [MessageDiff]

  var body: some View {
    LazyVStack(spacing: 12) {
      ForEach(Array(diffs.enumerated()), id: \.offset) { index, diff in
        DiffContentView(diff: diff)
          .id("diff-\(index)")
      }
    }
    .frame(maxWidth: .infinity)
  }
}

struct ThreadNavigationView: View {
  let navigation: ThreadNavigation
  let onNavigate: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Thread Navigation")
        .font(.headline)

      if let parentMessage = navigation.parentMessage {
        Button("↑ Parent Message") {
          onNavigate(parentMessage)
        }
        .buttonStyle(.bordered)
      }

      if !navigation.childMessages.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Child Messages:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(navigation.childMessages, id: \.self) { child in
            Button("↓ \(child)") {
              onNavigate(child)
            }
            .buttonStyle(.bordered)
            .font(.caption)
          }
        }
      }

      if !navigation.siblingMessages.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Sibling Messages:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(navigation.siblingMessages, id: \.self) { sibling in
            Button("↔ \(sibling)") {
              onNavigate(sibling)
            }
            .buttonStyle(.bordered)
            .font(.caption)
          }
        }
      }

      HStack {
        if let threadStart = navigation.threadStart {
          Button("⏮ Thread Start") {
            onNavigate(threadStart)
          }
          .buttonStyle(.bordered)
          .font(.caption)
        }

        if let threadEnd = navigation.threadEnd {
          Button("⏭ Thread End") {
            onNavigate(threadEnd)
          }
          .buttonStyle(.bordered)
          .font(.caption)
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
}

struct MessageContentView: View {
  let content: String
  @State private var showFullContent = false
  @State private var currentPage = 0

  private let maxPreviewLength = 5000
  private let pageSize = 5000

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Message Content")
          .font(.headline)

        Spacer()

        if content.count > maxPreviewLength {
          Button(showFullContent ? "Show Less" : "Show More") {
            showFullContent.toggle()
          }
          .buttonStyle(.bordered)
          .font(.caption)
        }
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if showFullContent {
            // Show paginated content
            PaginatedContentView(content: content, pageSize: pageSize)
          } else {
            // Show preview
            let previewContent = String(content.prefix(maxPreviewLength))
            let formattedContent = formatEmailContent(previewContent)

            Text(formattedContent)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)

            if content.count > maxPreviewLength {
              Text("... (content truncated)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .frame(maxHeight: .infinity)
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

  @State private var currentPage = 0

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
    VStack(alignment: .leading, spacing: 8) {
      // Top page navigation
      if totalPages > 1 {
        HStack {
          Button("← Previous") {
            if currentPage > 0 {
              currentPage -= 1
            }
          }
          .disabled(currentPage == 0)
          .buttonStyle(.bordered)

          Spacer()

          Text("Page \(currentPage + 1) of \(totalPages)")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          Button("Next →") {
            if currentPage < totalPages - 1 {
              currentPage += 1
            }
          }
          .disabled(currentPage == totalPages - 1)
          .buttonStyle(.bordered)
        }
        .padding(.horizontal)
      }

      // Content
      Text(currentPageContent)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)

      // Bottom page navigation
      if totalPages > 1 {
        HStack {
          Button("← Previous") {
            if currentPage > 0 {
              currentPage -= 1
            }
          }
          .disabled(currentPage == 0)
          .buttonStyle(.bordered)

          Spacer()

          Text("Page \(currentPage + 1) of \(totalPages)")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          Button("Next →") {
            if currentPage < totalPages - 1 {
              currentPage += 1
            }
          }
          .disabled(currentPage == totalPages - 1)
          .buttonStyle(.bordered)
        }
        .padding(.horizontal)
      }
    }
  }
}

struct EmailContentView: View {
  let content: String
  @State private var showFullContent = false

  private let maxPreviewLength = 3000

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Email Content")
          .font(.headline)

        Spacer()

        if content.count > maxPreviewLength {
          Button(showFullContent ? "Show Less" : "Show More") {
            showFullContent.toggle()
          }
          .buttonStyle(.bordered)
          .font(.caption)
        }
      }

      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          if showFullContent {
            // Show full content with pagination
            PaginatedEmailContentView(content: content)
          } else {
            // Show preview
            let previewContent = String(content.prefix(maxPreviewLength))
            let emailParts = parseEmailContent(previewContent)

            ForEach(emailParts, id: \.self) { part in
              EmailContentPartView(part: part)
            }

            if content.count > maxPreviewLength {
              Text("... (content truncated)")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
      .frame(maxHeight: .infinity)
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

  private func parseEmailContent(_ content: String) -> [String] {
    // Split content into logical parts (greeting, body, signature, etc.)
    let lines = content.components(separatedBy: .newlines)
    var parts: [String] = []
    var currentPart = ""

    for line in lines {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)

      // Check for email structure markers
      if trimmedLine.hasPrefix("Hi,") || trimmedLine.hasPrefix("Hello,")
        || trimmedLine.hasPrefix("Dear")
      {
        if !currentPart.isEmpty {
          parts.append(currentPart.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        currentPart = line
      } else if trimmedLine.hasPrefix("Best regards") || trimmedLine.hasPrefix("Thanks")
        || trimmedLine.hasPrefix("Regards") || trimmedLine.hasPrefix("Sincerely")
      {
        if !currentPart.isEmpty {
          parts.append(currentPart.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        currentPart = line
      } else {
        currentPart += "\n" + line
      }
    }

    if !currentPart.isEmpty {
      parts.append(currentPart.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return parts
  }
}

struct PaginatedEmailContentView: View {
  let content: String
  @State private var currentPage = 0

  private let pageSize = 3000
  private let maxLinesPerPage = 150

  private var totalPages: Int {
    let lines = content.components(separatedBy: .newlines)
    return (lines.count + maxLinesPerPage - 1) / maxLinesPerPage
  }

  private var currentPageContent: String {
    let lines = content.components(separatedBy: .newlines)
    let startIndex = currentPage * maxLinesPerPage
    let endIndex = min(startIndex + maxLinesPerPage, lines.count)
    return Array(lines[startIndex..<endIndex]).joined(separator: "\n")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Top page navigation
      if totalPages > 1 {
        HStack {
          Button("← Previous") {
            if currentPage > 0 {
              currentPage -= 1
            }
          }
          .disabled(currentPage == 0)
          .buttonStyle(.bordered)

          Spacer()

          Text("Page \(currentPage + 1) of \(totalPages)")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          Button("Next →") {
            if currentPage < totalPages - 1 {
              currentPage += 1
            }
          }
          .disabled(currentPage == totalPages - 1)
          .buttonStyle(.bordered)
        }
        .padding(.horizontal)
      }

      // Content
      let emailParts = parseEmailContent(currentPageContent)
      VStack(alignment: .leading, spacing: 8) {
        ForEach(emailParts, id: \.self) { part in
          EmailContentPartView(part: part)
        }
      }

      // Bottom page navigation
      if totalPages > 1 {
        HStack {
          Button("← Previous") {
            if currentPage > 0 {
              currentPage -= 1
            }
          }
          .disabled(currentPage == 0)
          .buttonStyle(.bordered)

          Spacer()

          Text("Page \(currentPage + 1) of \(totalPages)")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          Button("Next →") {
            if currentPage < totalPages - 1 {
              currentPage += 1
            }
          }
          .disabled(currentPage == totalPages - 1)
          .buttonStyle(.bordered)
        }
        .padding(.horizontal)
      }
    }
  }

  private func parseEmailContent(_ content: String) -> [String] {
    // Split content into logical parts (greeting, body, signature, etc.)
    let lines = content.components(separatedBy: .newlines)
    var parts: [String] = []
    var currentPart = ""

    for line in lines {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)

      // Check for email structure markers
      if trimmedLine.hasPrefix("Hi,") || trimmedLine.hasPrefix("Hello,")
        || trimmedLine.hasPrefix("Dear")
      {
        if !currentPart.isEmpty {
          parts.append(currentPart.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        currentPart = line
      } else if trimmedLine.hasPrefix("Best regards") || trimmedLine.hasPrefix("Thanks")
        || trimmedLine.hasPrefix("Regards") || trimmedLine.hasPrefix("Sincerely")
      {
        if !currentPart.isEmpty {
          parts.append(currentPart.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        currentPart = line
      } else {
        currentPart += "\n" + line
      }
    }

    if !currentPart.isEmpty {
      parts.append(currentPart.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    return parts
  }
}

struct EmailContentPartView: View {
  let part: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(part)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 4)
  }
}
