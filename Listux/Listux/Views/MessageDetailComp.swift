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
        case .subjectHeader(let header):
          SubjectDateHeaderCard(header: header)
        case .regular(let text):
          if !text.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(text.components(separatedBy: .newlines), id: \.self) { line in
                TokenizedLineView(line: line)
              }
            }
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
    var parsedHeader: SubjectHeaderInfo? = nil
    var didPassHeaderBoundary = false

    for (index, line) in lines.enumerated() {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      let isQuoted = isQuotedEmailLine(line)

      if !didPassHeaderBoundary {
        if parsedHeader == nil { parsedHeader = SubjectHeaderInfo() }
        if trimmedLine.isEmpty {
          if let header = parsedHeader, header.hasAnyField {
            sections.append(.subjectHeader(header))
            parsedHeader = nil
          }
          didPassHeaderBoundary = true
          continue
        }
        if trimmedLine.lowercased().hasPrefix("subject:") {
          let value = String(trimmedLine.dropFirst("subject:".count)).trimmingCharacters(in: .whitespaces)
          parsedHeader?.subject = value
        }
        if trimmedLine.lowercased().hasPrefix("date:") {
          let value = String(trimmedLine.dropFirst("date:".count)).trimmingCharacters(in: .whitespaces)
          parsedHeader?.dateText = value
        }
        if trimmedLine.lowercased().hasPrefix("from:") {
          let value = String(trimmedLine.dropFirst("from:".count)).trimmingCharacters(in: .whitespaces)
          if let emailRangeStart = value.firstIndex(of: "<"), let emailRangeEnd = value.firstIndex(of: ">"), emailRangeStart < emailRangeEnd {
            let name = String(value[..<emailRangeStart]).trimmingCharacters(in: .whitespaces)
            let email = String(value[value.index(after: emailRangeStart)..<emailRangeEnd])
            parsedHeader?.fromName = name.isEmpty ? email : name
            parsedHeader!.fromEmail = email
          } else {
            parsedHeader?.fromName = value
          }
        }
        if trimmedLine.lowercased().hasPrefix("message-id:") {
          if let id = firstAngleToken(in: trimmedLine) {
            parsedHeader?.messageId = id
          }
        }
        if trimmedLine.lowercased().hasPrefix("in-reply-to:") {
          let ids = angleTokens(in: trimmedLine)
          if !ids.isEmpty { parsedHeader?.inReplyToIds = ids }
        }
      }

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
    if let header = parsedHeader, header.hasAnyField {
      sections.insert(.subjectHeader(header), at: 0)
    }
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
  case subjectHeader(SubjectHeaderInfo)
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

struct SubjectHeaderInfo: Equatable {
  var subject: String? = nil
  var dateText: String? = nil
  var fromName: String? = nil
  var fromEmail: String? = nil
  var messageId: String? = nil
  var inReplyToIds: [String] = []
  var hasAnyField: Bool {
    (subject != nil) || (dateText != nil) || (fromName != nil) || (messageId != nil) || !inReplyToIds.isEmpty
  }
}

private func angleTokens(in line: String) -> [String] {
  var tokens: [String] = []
  var current: String = ""
  var isIn = false
  for ch in line {
    if ch == "<" {
      isIn = true
      current = ""
      continue
    }
    if ch == ">" && isIn {
      tokens.append(current)
      isIn = false
      continue
    }
    if isIn { current.append(ch) }
  }
  return tokens
}

private func firstAngleToken(in line: String) -> String? { angleTokens(in: line).first }

struct SubjectDateHeaderCard: View {
  let header: SubjectHeaderInfo

  private var backgroundColor: Color {
    #if os(macOS)
      return Color(NSColor.windowBackgroundColor)
    #else
      return Color(.systemBackground)
    #endif
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let subject = header.subject, !subject.isEmpty {
        Text(subject)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(.primary)
          .textSelection(.enabled)
      }
      if let dateText = header.dateText, !dateText.isEmpty {
        Text(dateText)
          .font(.caption)
          .foregroundColor(.secondary)
          .textSelection(.enabled)
      }
      // HStack(spacing: 6) {
      //   if let name = header.fromName {
      //     EmailChipView(name: name, email: header.fromEmail)
      //   }
      //   if let mid = header.messageId, !mid.isEmpty {
      //     MessageIdChipView(id: mid)
      //   }
      //   ForEach(header.inReplyToIds, id: \.self) { rid in
      //     MessageIdChipView(id: rid)
      //   }
      //   Spacer()
      // }
    }
    .padding()
    .background(backgroundColor)
    .cornerRadius(8)
  }
}

struct EmailChipView: View {
  let name: String
  let email: String?

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "person.crop.circle")
        .font(.system(size: 10))
      if let email = email, !email.isEmpty {
        Text("\(name) <\(email)>")
          .font(.caption2)
      } else {
        Text(name)
          .font(.caption2)
      }
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(Color.green.opacity(0.15))
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(Color.green.opacity(0.3), lineWidth: 1)
    )
    .cornerRadius(4)
  }
}

struct MessageIdChipView: View {
  let id: String

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "number")
        .font(.system(size: 10))
      Text("<\(id)>")
        .font(.caption2)
        .textSelection(.enabled)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(Color.purple.opacity(0.15))
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
    )
    .cornerRadius(4)
  }
}

// MARK: - Inline tokenization for regular content lines

private enum LineToken: Equatable {
  case text(String)
  case email(name: String, email: String)
  case messageId(String)
}

private func isMessageIdContext(_ line: String) -> Bool {
  let lower = line.trimmingCharacters(in: .whitespaces).lowercased()
  return lower.hasPrefix("message-id:") || lower.hasPrefix("in-reply-to:")
}

private func isLikelyMessageIdToken(_ token: String) -> Bool {
  // Heuristic: must contain '@' and at least 6 consecutive digits
  if token.contains("@") == false { return false }
  if token.range(of: "\\d{6,}", options: .regularExpression) != nil { return true }
  // Or contain two or more hyphens with digits around
  let hyphenDigit = token.range(of: "[0-9]+-+[0-9]+", options: .regularExpression) != nil
  return hyphenDigit
}

private func isEmailAddress(_ token: String) -> Bool {
  let pattern = "[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}"
  return token.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

private func splitTrailingName(from precedingText: String) -> (prefix: String, name: String)? {
  var text = precedingText
  if text.isEmpty { return nil }
  // Remove trailing spaces
  while text.last == " " { text.removeLast() }
  guard let colonIndex = text.lastIndex(of: ":") else {
    // No colon; try to take trailing word sequence as name if it has at least one letter
    let components = text.split(separator: " ")
    if components.isEmpty { return nil }
    let nameStartCount = min(components.count, 5) // avoid consuming entire line
    let nameComponents = components.suffix(nameStartCount)
    let name = nameComponents.joined(separator: " ")
    if name.range(of: "[A-Za-z]", options: .regularExpression) != nil {
      let prefixLen = text.count - name.count
      let prefix = String(text.prefix(prefixLen))
      return (prefix: prefix, name: name)
    }
    return nil
  }
  let afterColon = text.index(after: colonIndex)
  let namePart = text[afterColon...].trimmingCharacters(in: .whitespaces)
  if namePart.isEmpty { return nil }
  let prefix = String(text[..<afterColon]) + " "
  return (prefix: prefix, name: namePart)
}

private func tokenizeLine(_ line: String) -> [LineToken] {
  if line.isEmpty { return [.text("")] }
  var tokens: [LineToken] = []
  let nsLine = line as NSString
  let pattern = "<([^>]+)>"
  guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
    return [.text(line)]
  }
  var lastIndex = 0
  let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: nsLine.length))
  let midContext = isMessageIdContext(line)
  for match in matches {
    let range = match.range
    if range.location > lastIndex {
      let textSeg = nsLine.substring(with: NSRange(location: lastIndex, length: range.location - lastIndex))
      tokens.append(.text(textSeg))
    }
    let innerRange = match.range(at: 1)
    let inner = nsLine.substring(with: innerRange)
    if midContext {
      tokens.append(.messageId(inner))
    } else if isLikelyMessageIdToken(inner) {
      tokens.append(.messageId(inner))
    } else if isEmailAddress(inner) {
      // Try to merge preceding trailing name from last text token
      if case .text(let prevText)? = tokens.last {
        if let split = splitTrailingName(from: prevText) {
          // Replace last text with its prefix
          _ = tokens.popLast()
          if !split.prefix.isEmpty { tokens.append(.text(split.prefix)) }
          tokens.append(.email(name: split.name, email: inner))
        } else {
          tokens.append(.text("<" + inner + ">"))
        }
      } else {
        tokens.append(.text("<" + inner + ">"))
      }
    } else {
      tokens.append(.text("<" + inner + ">"))
    }
    lastIndex = range.location + range.length
  }
  if lastIndex < nsLine.length {
    let tail = nsLine.substring(from: lastIndex)
    tokens.append(.text(tail))
  }
  return tokens
}

struct TokenizedLineView: View {
  let line: String

  var body: some View {
    let parts = tokenizeLine(line)
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .firstTextBaseline, spacing: 0) {
        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
          switch part {
          case .text(let s):
            Text(s)
              .font(.system(.caption, design: .monospaced))
              .foregroundColor(.primary)
              .textSelection(.enabled)
          case .email(let name, let email):
            EmailChipView(name: name, email: email)
              .padding(.horizontal, 2)
          case .messageId(let id):
            MessageIdChipView(id: id)
              .padding(.horizontal, 2)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
