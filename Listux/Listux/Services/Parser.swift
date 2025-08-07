import Foundation
import SwiftSoup
import os.log

class Parser {

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: Parser.self))

  struct MessagePageResult {
    var messages: [Message]
    /// URL for the next (older) page, if available
    var nextURL: String?
    /// URL for the previous (newer) page, if available
    var prevURL: String?
    /// URL for the latest page, if available
    var latestURL: String?
  }

  /// Extract timestamp from message URL
  /// URL format: https://lore.kernel.org/loongarch/20250714070438.2399153-1-chenhuacai@loongson.cn
  /// The timestamp is encoded in the URL path: 20250714070438 (YYYYMMDDHHMMSS)
  private static func extractTimestampFromURL(_ url: String) -> Date? {
    // Extract the timestamp part from the URL
    // Pattern: /YYYYMMDDHHMMSS-identifier/
    let pattern = #"/(\d{14})-"#

    guard let regex = try? NSRegularExpression(pattern: pattern),
      let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
      match.numberOfRanges > 1
    else {
      return nil
    }

    let timestampRange = match.range(at: 1)
    guard let range = Range(timestampRange, in: url) else { return nil }

    let timestampString = String(url[range])

    // Parse YYYYMMDDHHMMSS format
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMddHHmmss"
    dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

    return dateFormatter.date(from: timestampString)
  }

  static func parseMsgsFromListPage(from html: String, mailingList: MailingList)
    -> MessagePageResult
  {
    LogManager.shared.info("Parsing messages at list \(mailingList.name)")
    var rootMessages: [Message] = []
    var messageMap: [String: Message] = [:]
    var orderedMessages: [Message] = []
    var nextURL: String?
    var prevURL: String?
    var latestURL: String?

    do {
      let doc = try SwiftSoup.parse(html)
      let links = try doc.select("a[href$=/T/#t], a[href$=/T/#u]")

      var seqId = 0  // Sequential id counter
      var lastRootMessage: Message? = nil
      var seenUrls = Set<String>()  // Track seen URLs to avoid duplicates

      for link in links {
        // logger.debug("link=\(link)")
        let url = try link.attr("href")

        // Skip if we've already seen this URL
        if seenUrls.contains(url) {
          LogManager.shared.info("Skipping duplicate URL: \(url)")
          continue
        }
        seenUrls.insert(url)

        let subject = try link.text()
        let parent = link.parent()
        let dateText = try parent?.text() ?? ""

        // Try to extract timestamp from URL first, fallback to parsing date text
        var timestamp: Date
        if let urlTimestamp = extractTimestampFromURL(url) {
          timestamp = urlTimestamp
          LogManager.shared.info("Extracted timestamp from URL: \(timestamp)")
        } else {
          // Fallback to parsing the date text from the page
          let dateFormatter = DateFormatter()
          dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
          dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
          timestamp = dateFormatter.date(from: dateText) ?? Date()
          LogManager.shared.info("Parsed timestamp from text: \(timestamp)")
        }

        var fullUrl =
          LORE_LINUX_BASE_URL.value + "/" + mailingList.name + "/"
          + url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // fullUrl maybe end with /T/#u or /T/#t, remove the last /T/#u or /T/#t because we just want to render one mail now :) - wheatfox
        if fullUrl.hasSuffix("/T/#u") {
          fullUrl = String(fullUrl.dropLast(5))
        } else if fullUrl.hasSuffix("/T/#t") {
          fullUrl = String(fullUrl.dropLast(5))
        }

        LogManager.shared.info("Constructing messageId: \(fullUrl)")

        // Check if message already exists in the mailing list
        let existingMessage = mailingList.messages.first { $0.messageId == fullUrl }
        let message: Message

        if let existing = existingMessage {
          // Use existing message and update its properties
          message = existing
          message.subject = subject
          message.timestamp = timestamp
          message.seqId = seqId
          LogManager.shared.info("Using existing message: \(fullUrl)")
        } else {
          // Create new message
          message = Message(
            subject: subject,
            content: url,
            timestamp: timestamp,
            seqId: seqId,
            messageId: fullUrl
          )
          // Set mailingList reference for new messages
          message.mailingList = mailingList
          LogManager.shared.info("Created new message: \(fullUrl)")
        }

        seqId += 1

        let messageId = url.split(separator: "/").first.map(String.init) ?? ""
        messageMap[messageId] = message
        orderedMessages.append(message)

        if let range = html.range(of: url) {
          let startIndex = range.lowerBound
          if startIndex >= html.index(html.startIndex, offsetBy: 20) {
            let beforeIndex = html.index(startIndex, offsetBy: -20)
            let prefix = html[beforeIndex..<startIndex]
            LogManager.shared.info("before=\(prefix)")
            if prefix.contains("` ") {
              message.parent = lastRootMessage
              lastRootMessage?.replies.append(message)
            } else {
              rootMessages.append(message)
              lastRootMessage = message
            }
          } else {
            LogManager.shared.info("before is not enough, trying to find from beginning")
            let prefix = html[..<startIndex]
            LogManager.shared.info("prefix=\(prefix)")
            if prefix.contains("` ") {
              message.parent = lastRootMessage
              lastRootMessage?.replies.append(message)
            } else {
              rootMessages.append(message)
              lastRootMessage = message
            }
          }
        } else {
          LogManager.shared.error("not found in original html, this should not happen")
        }
        // dump message
        LogManager.shared.info("message=\(String(describing: message))")
      }

      // Parse pagination links: "next (older)", "prev (newer)", and "latest" if they exist
      let linkElements = try doc.select("a")
      for link in linkElements {
        let caption = try link.text().lowercased()
        let href = try link.attr("href")
        if caption.contains("next (older)") {
          nextURL = href
        } else if caption.contains("prev (newer)") {
          prevURL = href
        } else if caption.contains("latest") {
          latestURL = href
        }
      }
    } catch {
      LogManager.shared.error("Error parsing HTML: \(error.localizedDescription)")
    }

    LogManager.shared.info(
      "Parsed \(rootMessages.count) root messages for list \(mailingList.name)")
    return MessagePageResult(
      messages: orderedMessages, nextURL: nextURL, prevURL: prevURL, latestURL: latestURL)
  }

  /// Parse the mailing list home page and return a list of (name, desc) tuples.
  static func parseListsFromHomePage(from html: String) -> [(name: String, desc: String)] {
    LogManager.shared.info("Starting to parse mailing lists from HTML")
    var lists: [(name: String, desc: String)] = []
    do {
      let doc = try SwiftSoup.parse(html)
      let preElements = try doc.select("pre")
      for pre in preElements {
        let content = try pre.text()
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
          let trimmedLine = line.trimmingCharacters(in: .whitespaces)
          if !trimmedLine.isEmpty {
            let components = trimmedLine.components(separatedBy: " - ")
            if components.count >= 2 {
              var name = components[1]
              var desc = components[0]
              name = name.replacingOccurrences(of: "*", with: "").trimmingCharacters(
                in: .whitespaces)
              desc = desc.replacingOccurrences(of: "*", with: "").trimmingCharacters(
                in: .whitespaces)
              lists.append((name, desc))
            }
          }
        }
      }
      lists.sort { $0.name < $1.name }
      LogManager.shared.info("Finished parsing mailing lists. Found \(lists.count) lists")
    } catch {
      LogManager.shared.error("Error parsing HTML: \(error.localizedDescription)")
    }
    return lists
  }
}
