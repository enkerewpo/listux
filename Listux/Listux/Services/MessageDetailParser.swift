import Foundation
import SwiftSoup
import os.log

class MessageDetailParser {

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: MessageDetailParser.self)
  )

  static func parseMessageDetail(from html: String, messageId: String) -> ParsedMessageDetail? {
    do {
      let doc = try SwiftSoup.parse(html)

      // Parse metadata
      let metadata = parseMetadata(from: doc, messageId: messageId)

      // Extract plain text content as rendered by HTML
      let content: String
      if let preElements = try? doc.select("pre"), preElements.array().isEmpty == false {
        var blocks: [String] = []
        for pre in preElements {
          blocks.append((try? pre.text()) ?? "")
        }
        content = blocks.joined(separator: "\n")
      } else {
        content = (try? doc.text()) ?? ""
      }

      // Parse diff content with performance optimization
      // let diffContent = parseDiffContentOptimized(from: doc)

      // Parse thread navigation
      // let threadNavigation = parseThreadNavigation(from: doc)

      return ParsedMessageDetail(
        metadata: metadata,
        content: content,
        // diffContent: diffContent,
        // threadNavigation: threadNavigation,
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

  private static func parseEmailList(_ emailString: String) -> [String] {
    return
      emailString
      .components(separatedBy: ",")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}
