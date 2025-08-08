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

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      LazyVStack(alignment: .leading, spacing: 8) {
        ScrollView {
          let formattedContent = formatEmailContent(content)
          InlineContentView(content: formattedContent)
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

struct InlineContentView: View {
  let content: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      let sections = splitContentIntoSections(content)

      ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
        switch section {
        case .regular(let text):
          if !text.isEmpty {
            Text(text)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .fixedSize(horizontal: false, vertical: true)
          }
        case .gitDiff(let diffContent):
          GitDiffCard(content: diffContent)
        }
      }
    }
  }

  private func splitContentIntoSections(_ content: String) -> [ContentSection] {
    let lines = content.components(separatedBy: .newlines)
    var sections: [ContentSection] = []
    var currentRegularLines: [String] = []
    var currentGitDiffLines: [String] = []
    var inGitDiff = false

    for (index, line) in lines.enumerated() {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      let isQuoted = isQuotedEmailLine(line)

      if !inGitDiff && !isQuoted && isGitSummaryLine(line) {
        if !currentRegularLines.isEmpty {
          sections.append(.regular(currentRegularLines.joined(separator: "\n")))
          currentRegularLines = []
        }
        inGitDiff = true
        currentGitDiffLines.append(line)
        continue
      }

      if !inGitDiff && !isQuoted && trimmedLine.hasPrefix("diff --git") {
        if !currentRegularLines.isEmpty {
          sections.append(.regular(currentRegularLines.joined(separator: "\n")))
          currentRegularLines = []
        }
        inGitDiff = true
        currentGitDiffLines.append(line)
        continue
      }

      // Check for git diff start pattern: starts with "---" (includes summary)
      if line.hasPrefix("---") && !inGitDiff && !isQuoted {
        // Look ahead to see if this is a git diff by checking for "diff --git" or "+++" in the next few lines
        var foundGitDiff = false
        for i in 1...5 {  // Check next 5 lines
          if index + i < lines.count {
            let nextLine = lines[index + i].trimmingCharacters(in: .whitespaces)
            if nextLine.hasPrefix("diff --git") || nextLine.hasPrefix("+++") {
              foundGitDiff = true
              break
            }
          }
        }

        if foundGitDiff {
          // Save any accumulated regular content
          if !currentRegularLines.isEmpty {
            sections.append(.regular(currentRegularLines.joined(separator: "\n")))
            currentRegularLines = []
          }

          inGitDiff = true
          currentGitDiffLines.append(line)
          continue
        }
      }

      // Check for git diff end pattern: line that is just "--"
      if inGitDiff && trimmedLine == "--" {
        currentGitDiffLines.append(line)
        inGitDiff = false

        // Save the git diff section
        sections.append(.gitDiff(currentGitDiffLines.joined(separator: "\n")))
        currentGitDiffLines = []
        continue
      }

      if inGitDiff {
        currentGitDiffLines.append(line)
      } else {
        currentRegularLines.append(line)
      }
    }

    // Add any remaining content
    if !currentRegularLines.isEmpty {
      sections.append(.regular(currentRegularLines.joined(separator: "\n")))
    }
    if inGitDiff && !currentGitDiffLines.isEmpty {
      sections.append(.gitDiff(currentGitDiffLines.joined(separator: "\n")))
    }

    return sections
  }
}

enum ContentSection {
  case regular(String)
  case gitDiff(String)
}

private func isGitSummaryLine(_ line: String) -> Bool {
  if isQuotedEmailLine(line) { return false }
  let trimmedLine = line.trimmingCharacters(in: .whitespaces)
  let pattern = #"^(?!>(?:\s*>)*).* \| \d+ [+-]+$"#
  return (try? NSRegularExpression(pattern: pattern))?.firstMatch(
    in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) != nil
}

private func isQuotedEmailLine(_ line: String) -> Bool {
  let pattern = #"^\s*>(?:\s*>)*"#
  if let regex = try? NSRegularExpression(pattern: pattern) {
    let range = NSRange(line.startIndex..., in: line)
    if regex.firstMatch(in: line, range: range) != nil { return true }
  }
  let nbsp = Character("\u{00A0}")
  var index = line.startIndex
  func isWs(_ ch: Character) -> Bool { ch == " " || ch == "\t" || ch == nbsp }
  while index < line.endIndex, isWs(line[index]) { index = line.index(after: index) }
  var sawGt = false
  while index < line.endIndex, line[index] == ">" {
    sawGt = true
    index = line.index(after: index)
    while index < line.endIndex, isWs(line[index]) { index = line.index(after: index) }
  }
  return sawGt
}

struct GitDiffCard: View {
  let content: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "doc.text")
          .foregroundColor(.blue)
        Text("Git Diff")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(.blue)
        Spacer()

        Button(action: {
          #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)
          #else
            UIPasteboard.general.string = content
          #endif
        }) {
          Image(systemName: "doc.on.doc")
            .font(.system(size: 12))
            .foregroundColor(.blue)
        }
        .buttonStyle(.plain)
        .help("Copy Git Diff")
      }

      ScrollView(.horizontal, showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(content.components(separatedBy: .newlines).enumerated()), id: \.offset) {
            index, line in
            HStack(alignment: .top, spacing: 0) {
              if isGitSummaryLine(line) {
                SummaryLineView(line: line)
              } else {
                Text(line)
                  .font(.system(.caption, design: .monospaced))
                  .foregroundColor(colorForLine(line))
                  .textSelection(.enabled)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
          }
        }
      }
    }
    .padding()
    .background(Color.blue.opacity(0.1))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
    )
  }

  private func colorForLine(_ line: String) -> Color {
    let trimmedLine = line.trimmingCharacters(in: .whitespaces)

    // Special case: final "--" line (git diff end marker)
    if trimmedLine == "--" {
      return .secondary
    }

    // File headers
    if trimmedLine.hasPrefix("--- ") || trimmedLine.hasPrefix("+++ ") {
      return .purple
    }

    // Hunk headers
    if trimmedLine.hasPrefix("@@ ") {
      return .orange
    }

    // Additions
    if trimmedLine.hasPrefix("+") && !trimmedLine.hasPrefix("+++") {
      return .green
    }

    // Deletions
    if trimmedLine.hasPrefix("-") && !trimmedLine.hasPrefix("---") {
      return .red
    }

    // Context lines
    return .secondary
  }
}

struct SummaryLineView: View {
  let line: String

  var body: some View {
    HStack(spacing: 0) {
      if let pipeIndex = line.firstIndex(of: "|") {
        // Filename part (before |)
        let filename = String(line[..<pipeIndex])
        Text(filename)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)

        // Pipe character
        Text("|")
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)

        // Statistics part (after |)
        let stats = String(line[line.index(after: pipeIndex)...])
        ForEach(Array(stats.enumerated()), id: \.offset) { index, char in
          Text(String(char))
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(colorForChar(char))
        }
      } else {
        // Fallback if no pipe found
        Text(line)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
      }
    }
    .textSelection(.enabled)
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
  }

  private func colorForChar(_ char: Character) -> Color {
    switch char {
    case "+":
      return .green
    case "-":
      return .red
    default:
      return .secondary
    }
  }
}

// Removed pagination; full content is rendered directly
