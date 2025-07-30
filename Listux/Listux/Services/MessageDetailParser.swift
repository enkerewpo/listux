import Foundation
import SwiftSoup
import os.log

class MessageDetailParser {

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: MessageDetailParser.self)
  )

  // Performance constants
  private static let maxDiffLinesPerChunk = 1000
  private static let maxDiffFilesToParse = 50
  private static let maxContentLength = 50000  // 50KB limit for content
  private static let maxContentLines = 2000  // 2000 lines limit for content

  static func parseMessageDetail(from html: String, messageId: String) -> ParsedMessageDetail? {
    do {
      let doc = try SwiftSoup.parse(html)

      // Parse metadata
      let metadata = parseMetadata(from: doc, messageId: messageId)

      // Parse content with performance optimization
      let content = parseContentOptimized(from: doc)

      // Parse diff content with performance optimization
      let diffContent = parseDiffContentOptimized(from: doc)

      // Parse thread navigation
      let threadNavigation = parseThreadNavigation(from: doc)

      return ParsedMessageDetail(
        metadata: metadata,
        content: content,
        diffContent: diffContent,
        threadNavigation: threadNavigation,
        rawHtml: html
      )

    } catch {
      logger.error("Error parsing message detail: \(error.localizedDescription)")
      return nil
    }
  }

  private static func parseMetadata(from doc: Document, messageId: String) -> MessageMetadata {
    var author = ""
    var date = Date()
    var recipients: [String] = []
    var ccRecipients: [String] = []
    var subject = ""
    var permalink = ""
    var rawUrl = ""

    // Parse subject from title
    if let subjectElement = try? doc.select("title").first() {
      subject = (try? subjectElement.text()) ?? ""
    }

    // Parse metadata from pre elements
    if let preElements = try? doc.select("pre") {
      for pre in preElements {
        let text = (try? pre.text()) ?? ""
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
          let trimmedLine = line.trimmingCharacters(in: .whitespaces)

          // Parse author and date from format: "@ 2025-07-30 15:03 Ulrich Hecht"
          if trimmedLine.hasPrefix("@") {
            let parts = trimmedLine.components(separatedBy: " ")
            if parts.count >= 4 {
              let dateString = "\(parts[1]) \(parts[2])"
              let dateFormatter = DateFormatter()
              dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
              dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
              if let parsedDate = dateFormatter.date(from: dateString) {
                date = parsedDate
              }

              // Extract author name
              let authorParts = Array(parts[3...])
              author = authorParts.joined(separator: " ")
            }
          }

          // Parse recipients from format: "To: cip-dev@lists.cip-project.org, pavel@denx.de, ..."
          if trimmedLine.hasPrefix("To:") {
            let recipientsPart = trimmedLine.replacingOccurrences(of: "To:", with: "")
              .trimmingCharacters(in: .whitespaces)
            recipients = parseEmailList(recipientsPart)
          }

          // Parse CC recipients from format: "Cc: ..."
          if trimmedLine.hasPrefix("Cc:") {
            let ccPart = trimmedLine.replacingOccurrences(of: "Cc:", with: "").trimmingCharacters(
              in: .whitespaces)
            ccRecipients = parseEmailList(ccPart)
          }

          // Parse From field for regular emails
          if trimmedLine.hasPrefix("From:") {
            let fromPart = trimmedLine.replacingOccurrences(of: "From:", with: "")
              .trimmingCharacters(in: .whitespaces)
            if author.isEmpty {
              // Extract author name from email format: "Name <email@domain.com>"
              if let startBracket = fromPart.firstIndex(of: "<"),
                let endBracket = fromPart.lastIndex(of: ">")
              {
                let namePart = String(fromPart[..<startBracket]).trimmingCharacters(
                  in: .whitespaces)
                if !namePart.isEmpty {
                  author = namePart
                } else {
                  // Fallback to email part
                  let emailPart = String(fromPart[startBracket...endBracket])
                  author = emailPart.replacingOccurrences(of: "<", with: "").replacingOccurrences(
                    of: ">", with: "")
                }
              } else {
                author = fromPart
              }
            }
          }
        }
      }
    }

    // Parse permalink and raw URL from links
    if let permalinkElement = try? doc.select("a[href*=permalink]").first() {
      permalink = (try? permalinkElement.attr("href")) ?? ""
    }

    if let rawElement = try? doc.select("a[href*=raw]").first() {
      rawUrl = (try? rawElement.attr("href")) ?? ""
    }

    return MessageMetadata(
      author: author,
      date: date,
      recipients: recipients,
      ccRecipients: ccRecipients,
      subject: subject,
      messageId: messageId,
      permalink: permalink,
      rawUrl: rawUrl
    )
  }

  private static func parseContentOptimized(from doc: Document) -> String {
    var content = ""
    var lineCount = 0
    var contentLength = 0

    // Find the main content area (usually in pre tags after the header)
    if let preElements = try? doc.select("pre") {
      var foundHeader = false
      var contentLines: [String] = []
      var inContent = false

      for pre in preElements {
        let text = (try? pre.text()) ?? ""
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
          // Check performance limits
          if lineCount > maxContentLines {
            logger.warning("Stopping content parsing at \(lineCount) lines for performance")
            break
          }

          if contentLength > maxContentLength {
            logger.warning(
              "Stopping content parsing at \(contentLength) characters for performance")
            break
          }

          let trimmedLine = line.trimmingCharacters(in: .whitespaces)

          // Check if this is the header section
          if trimmedLine.hasPrefix("From:") || trimmedLine.hasPrefix("To:")
            || trimmedLine.hasPrefix("Cc:")
          {
            foundHeader = true
            continue
          }

          // Skip diff headers and navigation
          if trimmedLine.hasPrefix("diff --git") || trimmedLine.hasPrefix("index ")
            || trimmedLine.hasPrefix("--- ") || trimmedLine.hasPrefix("+++ ")
            || trimmedLine.hasPrefix("@@ ")
          {
            continue
          }

          // Skip thread navigation and other metadata
          if trimmedLine.contains("siblings") || trimmedLine.contains("replies")
            || trimmedLine.contains("permalink") || trimmedLine.contains("raw")
            || trimmedLine.contains("Thread overview")
          {
            continue
          }

          // If we've found the header and this isn't a metadata line, it's content
          if foundHeader && !trimmedLine.isEmpty && !trimmedLine.hasPrefix("--") {
            // Check if this looks like the start of actual content
            if !inContent
              && (trimmedLine.hasPrefix("Hi,") || trimmedLine.hasPrefix("Hello,")
                || trimmedLine.hasPrefix("Dear") || trimmedLine.hasPrefix("Best regards")
                || trimmedLine.hasPrefix("Thanks") || trimmedLine.hasPrefix("Regards")
                || trimmedLine.hasPrefix("Sincerely")
                || !trimmedLine.contains("@") && !trimmedLine.contains("http"))
            {
              inContent = true
            }

            if inContent {
              contentLines.append(line)
              lineCount += 1
              contentLength += line.count
            }
          }
        }
      }

      content = contentLines.joined(separator: "\n")
    }

    // Add truncation notice if content was limited
    if lineCount >= maxContentLines || contentLength >= maxContentLength {
      content += "\n\n... (content truncated for performance)"
    }

    return content
  }

  private static func parseDiffContentOptimized(from doc: Document) -> [MessageDiff] {
    var diffs: [MessageDiff] = []

    // Look for diff sections in the HTML
    if let diffElements = try? doc.select("span.head, span.hunk, span.add, span.del") {
      diffs = parseDiffFromStructuredHTML(diffElements)
    }

    // If no structured diff found, try to parse from plain text
    if diffs.isEmpty {
      diffs = parseDiffFromTextOptimized(from: doc)
    }

    // Limit the number of diffs for performance
    if diffs.count > maxDiffFilesToParse {
      logger.warning("Limiting diff files to \(maxDiffFilesToParse) for performance")
      diffs = Array(diffs.prefix(maxDiffFilesToParse))
    }

    return diffs
  }

  private static func parseDiffFromStructuredHTML(_ diffElements: Elements) -> [MessageDiff] {
    var diffs: [MessageDiff] = []
    var currentFilePath = ""
    var additions: [DiffLine] = []
    var deletions: [DiffLine] = []
    var context: [DiffLine] = []
    var lineCount = 0

    for element in diffElements {
      let className = (try? element.className()) ?? ""
      let text = (try? element.text()) ?? ""

      // Check if we're exceeding the line limit
      if lineCount > maxDiffLinesPerChunk {
        logger.warning("Stopping diff parsing at \(lineCount) lines for performance")
        break
      }

      switch className {
      case "head":
        // Save previous diff if exists
        if !currentFilePath.isEmpty {
          let diff = MessageDiff(
            filePath: currentFilePath,
            additions: additions,
            deletions: deletions,
            context: context
          )
          diffs.append(diff)
        }

        // Start new diff
        currentFilePath = text
        additions = []
        deletions = []
        context = []
        lineCount = 0

      case "hunk":
        // Parse hunk header
        let hunkLine = DiffLine(lineNumber: nil, content: text, type: .header)
        context.append(hunkLine)
        lineCount += 1

      case "add":
        // Parse addition
        let lineNumber = extractLineNumber(from: text)
        let content = extractContent(from: text)
        let additionLine = DiffLine(lineNumber: lineNumber, content: content, type: .addition)
        additions.append(additionLine)
        lineCount += 1

      case "del":
        // Parse deletion
        let lineNumber = extractLineNumber(from: text)
        let content = extractContent(from: text)
        let deletionLine = DiffLine(lineNumber: lineNumber, content: content, type: .deletion)
        deletions.append(deletionLine)
        lineCount += 1

      default:
        // Context line
        let lineNumber = extractLineNumber(from: text)
        let content = extractContent(from: text)
        let contextLine = DiffLine(lineNumber: lineNumber, content: content, type: .context)
        context.append(contextLine)
        lineCount += 1
      }
    }

    // Add the last diff
    if !currentFilePath.isEmpty {
      let diff = MessageDiff(
        filePath: currentFilePath,
        additions: additions,
        deletions: deletions,
        context: context
      )
      diffs.append(diff)
    }

    return diffs
  }

  private static func parseDiffFromTextOptimized(from doc: Document) -> [MessageDiff] {
    var diffs: [MessageDiff] = []

    if let preElements = try? doc.select("pre") {
      var currentFilePath = ""
      var additions: [DiffLine] = []
      var deletions: [DiffLine] = []
      var context: [DiffLine] = []
      var lineCount = 0

      for pre in preElements {
        let text = (try? pre.text()) ?? ""
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
          let trimmedLine = line.trimmingCharacters(in: .whitespaces)

          // Check if we're exceeding the line limit
          if lineCount > maxDiffLinesPerChunk {
            logger.warning("Stopping diff parsing at \(lineCount) lines for performance")
            break
          }

          // Check for diff header
          if trimmedLine.hasPrefix("diff --git") {
            // Save previous diff
            if !currentFilePath.isEmpty {
              let diff = MessageDiff(
                filePath: currentFilePath,
                additions: additions,
                deletions: deletions,
                context: context
              )
              diffs.append(diff)
            }

            // Extract file path
            let parts = trimmedLine.components(separatedBy: " ")
            if parts.count >= 3 {
              currentFilePath = parts[2]
            }

            additions = []
            deletions = []
            context = []
            lineCount = 0

          } else if trimmedLine.hasPrefix("--- ") {
            // Old file header
            let contextLine = DiffLine(lineNumber: nil, content: trimmedLine, type: .header)
            context.append(contextLine)
            lineCount += 1

          } else if trimmedLine.hasPrefix("+++ ") {
            // New file header
            let contextLine = DiffLine(lineNumber: nil, content: trimmedLine, type: .header)
            context.append(contextLine)
            lineCount += 1

          } else if trimmedLine.hasPrefix("@@ ") {
            // Hunk header
            let contextLine = DiffLine(lineNumber: nil, content: trimmedLine, type: .header)
            context.append(contextLine)
            lineCount += 1

          } else if trimmedLine.hasPrefix("+") {
            // Addition
            let content = String(trimmedLine.dropFirst())
            let additionLine = DiffLine(lineNumber: nil, content: content, type: .addition)
            additions.append(additionLine)
            lineCount += 1

          } else if trimmedLine.hasPrefix("-") {
            // Deletion
            let content = String(trimmedLine.dropFirst())
            let deletionLine = DiffLine(lineNumber: nil, content: content, type: .deletion)
            deletions.append(deletionLine)
            lineCount += 1

          } else if !trimmedLine.isEmpty {
            // Context line
            let contextLine = DiffLine(lineNumber: nil, content: trimmedLine, type: .context)
            context.append(contextLine)
            lineCount += 1
          }
        }
      }

      // Add the last diff
      if !currentFilePath.isEmpty {
        let diff = MessageDiff(
          filePath: currentFilePath,
          additions: additions,
          deletions: deletions,
          context: context
        )
        diffs.append(diff)
      }
    }

    return diffs
  }

  private static func parseThreadNavigation(from doc: Document) -> ThreadNavigation? {
    var parentMessage: String?
    var childMessages: [String] = []
    var siblingMessages: [String] = []
    var threadStart: String?
    var threadEnd: String?

    // Parse thread navigation links
    if let navElements = try? doc.select("a[href^=#]") {
      for element in navElements {
        let href = (try? element.attr("href")) ?? ""
        let text = (try? element.text()) ?? ""

        if href.contains("parent") || text.contains("parent") {
          parentMessage = href
        } else if href.contains("child") || text.contains("child") {
          childMessages.append(href)
        } else if href.contains("sibling") || text.contains("sibling") {
          siblingMessages.append(href)
        } else if href.contains("thread-start") || text.contains("thread start") {
          threadStart = href
        } else if href.contains("thread-end") || text.contains("thread end") {
          threadEnd = href
        }
      }
    }

    return ThreadNavigation(
      parentMessage: parentMessage,
      childMessages: childMessages,
      siblingMessages: siblingMessages,
      threadStart: threadStart,
      threadEnd: threadEnd
    )
  }

  private static func parseEmailList(_ emailString: String) -> [String] {
    return
      emailString
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  private static func extractLineNumber(from text: String) -> Int? {
    // Extract line number from diff line (e.g., "@@ -1,3 +1,3 @@")
    let pattern = #"@@ -(\d+)"#
    if let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
      match.numberOfRanges > 1
    {
      let range = match.range(at: 1)
      if let lineRange = Range(range, in: text) {
        return Int(String(text[lineRange]))
      }
    }
    return nil
  }

  private static func extractContent(from text: String) -> String {
    // Remove line numbers and diff markers
    return
      text
      .replacingOccurrences(of: #"^[+-]?\s*\d*\s*"#, with: "", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
  }
}
