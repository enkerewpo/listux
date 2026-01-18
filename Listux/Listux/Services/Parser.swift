import Foundation
import SwiftSoup
import os.log

class Parser {

  /// Decode HTML entities in a string
  /// Handles both named entities (like &quot;) and numeric entities (like &#34; or &#x22;)
  private static func decodeHTMLEntities(_ text: String) -> String {
    var result = text

    // First, try using Foundation's String extension if available
    // Otherwise, manually decode common entities

    // Decode numeric entities (&#34;, &#39;, etc.)
    // Pattern: &#number; or &#xhex;
    let numericEntityPattern = #"&#(\d+);|&#x([0-9a-fA-F]+);"#
    if let regex = try? NSRegularExpression(pattern: numericEntityPattern, options: []) {
      let nsString = result as NSString
      let matches = regex.matches(
        in: result, options: [], range: NSRange(location: 0, length: nsString.length))

      // Process matches in reverse order to maintain indices
      for match in matches.reversed() {
        var replacement: String?

        if match.range(at: 1).location != NSNotFound {
          // Decimal entity: &#34;
          let numberRange = match.range(at: 1)
          if let numberString = Range(numberRange, in: result),
            let number = Int(result[numberString]),
            let unicodeScalar = UnicodeScalar(number)
          {
            replacement = String(Character(unicodeScalar))
          }
        } else if match.range(at: 2).location != NSNotFound {
          // Hexadecimal entity: &#x22;
          let hexRange = match.range(at: 2)
          if let hexString = Range(hexRange, in: result),
            let number = Int(result[hexString], radix: 16),
            let unicodeScalar = UnicodeScalar(number)
          {
            replacement = String(Character(unicodeScalar))
          }
        }

        if let replacement = replacement {
          result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
      }
    }

    // Decode named entities (after numeric entities to avoid conflicts)
    // Note: numeric entities like &#34; are already decoded above
    let namedEntities: [String: String] = [
      "&quot;": "\"",
      "&amp;": "&",
      "&lt;": "<",
      "&gt;": ">",
      "&apos;": "'",
      "&nbsp;": " ",
      "&copy;": "©",
      "&reg;": "®",
      "&trade;": "™",
      "&hellip;": "…",
      "&mdash;": "—",
      "&ndash;": "–",
      "&lsquo;": "'",
      "&rsquo;": "'",
      "&ldquo;": "\"",
      "&rdquo;": "\"",
      "&sbquo;": ",",
      "&bdquo;": ",,",
      "&dagger;": "†",
      "&Dagger;": "‡",
      "&permil;": "‰",
      "&lsaquo;": "‹",
      "&rsaquo;": "›",
      "&oline;": "‾",
      "&euro;": "€",
      "&pound;": "£",
      "&yen;": "¥",
      "&cent;": "¢",
    ]

    for (entity, replacement) in namedEntities {
      result = result.replacingOccurrences(of: entity, with: replacement)
    }

    return result
  }

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: Parser.self))

  struct MessagePageResult {
    var messages: [Message]
    var rootMessages: [Message]  // Root messages (top-level threads)
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

  static func parseMsgsFromListPage(
    from html: String, mailingList: MailingList, startingSeqId: Int = 0
  )
    -> MessagePageResult
  {
    LogManager.shared.info(
      "Parsing messages at list \(mailingList.name) with starting seqId: \(startingSeqId)")
    var rootMessages: [Message] = []
    var messageMap: [String: Message] = [:]
    var orderedMessages: [Message] = []
    var nextURL: String?
    var prevURL: String?
    var latestURL: String?

    do {
      let doc = try SwiftSoup.parse(html)
      let links = try doc.select("a[href$=/T/#t], a[href$=/T/#u]")

      LogManager.shared.info("Found \(links.count) message links in HTML")

      var seqId = startingSeqId  // Use the provided starting seqId
      var lastRootMessage: Message? = nil
      var seenUrls = Set<String>()  // Track seen URLs to avoid duplicates
      var seenMessageIds = Set<String>()  // Track seen message IDs to avoid duplicates

      for link in links {
        // logger.debug("link=\(link)")
        let url = try link.attr("href")

        // Skip if we've already seen this URL
        if seenUrls.contains(url) {
          LogManager.shared.info("Skipping duplicate URL: \(url)")
          continue
        }
        seenUrls.insert(url)

        // Build full URL early to check for duplicates by messageId
        var fullUrl =
          LORE_LINUX_BASE_URL.value + "/" + mailingList.name + "/"
          + url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Remove /T/#u or /T/#t suffix to get the base messageId
        if fullUrl.hasSuffix("/T/#u") {
          fullUrl = String(fullUrl.dropLast(5))
        } else if fullUrl.hasSuffix("/T/#t") {
          fullUrl = String(fullUrl.dropLast(5))
        }

        // Skip if we've already seen this messageId (avoid duplicates with different URL suffixes)
        if seenMessageIds.contains(fullUrl) {
          LogManager.shared.info("Skipping duplicate messageId: \(fullUrl)")
          continue
        }
        seenMessageIds.insert(fullUrl)

        // Extract subject - try multiple methods to get complete text
        let titleAttr = try link.attr("title")
        let linkText = try link.text()
        let linkHtml = try link.outerHtml()

        LogManager.shared.info("Link HTML (first 200 chars): \(String(linkHtml.prefix(200)))")
        LogManager.shared.info("Link title attribute: '\(titleAttr)' (length: \(titleAttr.count))")
        LogManager.shared.info("Link text: '\(linkText)' (length: \(linkText.count))")

        // Decode HTML entities in title attribute and link text
        var subject = decodeHTMLEntities(titleAttr)
        if subject.isEmpty {
          subject = decodeHTMLEntities(linkText)

          // Try to extract complete text from raw HTML, especially for first-level replies
          // which might have truncated text in SwiftSoup's text() method
          if let urlRange = html.range(of: url) {
            let linkStartPattern = "<a"
            // Search backwards up to 200 characters to find the link start
            let searchStart =
              html.index(urlRange.lowerBound, offsetBy: -200, limitedBy: html.startIndex)
              ?? html.startIndex
            let searchRange = searchStart..<urlRange.upperBound

            if let linkStartRange = html.range(
              of: linkStartPattern, options: .backwards, range: searchRange)
            {
              let linkStartIndex = linkStartRange.lowerBound

              // Find the closing </a> tag
              if let linkEndRange = html.range(of: "</a>", range: linkStartIndex..<html.endIndex) {
                let linkContentRange = linkStartIndex..<linkEndRange.upperBound
                let fullLinkHtml = String(html[linkContentRange])

                LogManager.shared.info(
                  "Full link HTML from raw: \(String(fullLinkHtml.prefix(400)))")

                // Extract text between > and </a>
                if let textStartRange = fullLinkHtml.range(
                  of: ">", range: fullLinkHtml.startIndex..<fullLinkHtml.endIndex)
                {
                  let textStartIndex = fullLinkHtml.index(textStartRange.upperBound, offsetBy: 0)
                  let textEndIndex = fullLinkHtml.index(fullLinkHtml.endIndex, offsetBy: -4)

                  if textStartIndex < textEndIndex {
                    let rawText = String(fullLinkHtml[textStartIndex..<textEndIndex])
                    // Decode HTML entities first
                    var cleanedRawText = decodeHTMLEntities(rawText)
                    // Then clean up whitespace
                    cleanedRawText =
                      cleanedRawText
                      .replacingOccurrences(of: "\n", with: " ")
                      .replacingOccurrences(of: "\r", with: " ")
                      .replacingOccurrences(of: "\t", with: " ")
                      .replacingOccurrences(of: "  ", with: " ")
                      .trimmingCharacters(in: CharacterSet.whitespaces)

                    // Use the longer text if available
                    if !cleanedRawText.isEmpty && cleanedRawText.count > linkText.count {
                      LogManager.shared.info(
                        "Found longer text from raw HTML: '\(cleanedRawText)' (length: \(cleanedRawText.count)) vs linkText: '\(linkText)' (length: \(linkText.count))"
                      )
                      subject = cleanedRawText
                    } else if !cleanedRawText.isEmpty {
                      // Even if not longer, use cleaned text if linkText seems incomplete
                      subject = cleanedRawText
                    }
                  }
                }
              }
            }
          }

          LogManager.shared.info("Title attribute is empty, using link text or extended text")
        } else {
          LogManager.shared.info("Using title attribute")
        }

        let parent = link.parent()
        let dateText = try parent?.text() ?? ""

        if let parentElement = parent {
          let parentHtml = try? parentElement.outerHtml()
          LogManager.shared.info(
            "Parent HTML (first 300 chars): \(String((parentHtml ?? "").prefix(300)))")
        }

        LogManager.shared.info(
          "Final subject for seqId \(seqId): '\(subject)' (length: \(subject.count))")

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

        LogManager.shared.info("Message timestamp: \(timestamp) for seqId: \(seqId)")

        // fullUrl was already constructed and cleaned above
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
          LogManager.shared.info(
            "Updated existing message subject: '\(message.subject)' (length: \(message.subject.count))"
          )
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
          LogManager.shared.info(
            "New message subject: '\(message.subject)' (length: \(message.subject.count))")
        }

        seqId += 1

        let messageId = url.split(separator: "/").first.map(String.init) ?? ""
        messageMap[messageId] = message
        orderedMessages.append(message)
        LogManager.shared.info(
          "Added message to orderedMessages: seqId=\(message.seqId), subject=\(message.subject)")

        // Check for backtick (`) character before the link to identify first-level replies
        // Root messages don't have ` before them, first-level replies have ` before the <a> tag
        if let range = html.range(of: url) {
          let startIndex = range.lowerBound
          // Look back further to find the backtick, as it might be on the previous line
          // Check up to 100 characters before the URL to find ` character
          let lookBackDistance = min(100, html.distance(from: html.startIndex, to: startIndex))
          if lookBackDistance > 0 {
            let beforeIndex = html.index(startIndex, offsetBy: -lookBackDistance)
            let prefix = html[beforeIndex..<startIndex]
            LogManager.shared.info("Checking prefix for backtick: \(String(prefix.suffix(50)))")

            // Check if there's a backtick followed by space or newline before the <a> tag
            // Pattern: ` <a or `\n<a or `\r\n<a
            if prefix.contains("` <") || prefix.contains("`\n<") || prefix.contains("`\r\n<")
              || prefix.contains("`\r<")
            {
              // This is a first-level reply
              if let root = lastRootMessage {
                // Check if this message is already in the root's replies to avoid duplicates
                if !root.replies.contains(where: { $0.messageId == message.messageId }) {
                  message.parent = root
                  root.replies.append(message)
                  LogManager.shared.info("Identified as first-level reply to: \(root.subject)")
                } else {
                  LogManager.shared.info(
                    "Skipping duplicate reply: \(message.messageId) already in root's replies")
                }
              } else {
                // No root found, treat as root anyway
                rootMessages.append(message)
                lastRootMessage = message
                LogManager.shared.info("Backtick found but no root message, treating as root")
              }
            } else {
              // This is a root message
              rootMessages.append(message)
              lastRootMessage = message
              LogManager.shared.info("Identified as root message: \(message.subject)")
            }
          } else {
            // Can't look back, treat as root
            rootMessages.append(message)
            lastRootMessage = message
            LogManager.shared.info("Cannot look back, treating as root message")
          }
        } else {
          LogManager.shared.error("URL not found in original html, this should not happen")
          // Fallback: treat as root
          rootMessages.append(message)
          lastRootMessage = message
        }
        // dump message
        LogManager.shared.info("message=\(String(describing: message))")
      }

      // Parse pagination links: "next (older)", "prev (newer)", and "latest" if they exist
      // Also check for rel="next" attribute for ?t=timestamp format
      let linkElements = try doc.select("a")
      for link in linkElements {
        let caption = try link.text().lowercased()
        let href = try link.attr("href")
        let rel = try link.attr("rel").lowercased()

        // Check rel attribute first (for ?t=timestamp format)
        if rel == "next" {
          nextURL = href
          LogManager.shared.info("Found next URL via rel=next: \(href)")
        } else if rel == "prev" {
          prevURL = href
          LogManager.shared.info("Found prev URL via rel=prev: \(href)")
        }
        // Then check text content
        else if caption.contains("next (older)") || caption.contains("next") {
          if nextURL == nil {
            nextURL = href
            LogManager.shared.info("Found next URL: \(href)")
          }
        } else if caption.contains("prev (newer)") || caption.contains("prev") {
          if prevURL == nil {
            prevURL = href
            LogManager.shared.info("Found prev URL: \(href)")
          }
        } else if caption.contains("latest") {
          latestURL = href
          LogManager.shared.info("Found latest URL: \(href)")
        }
      }

      LogManager.shared.info(
        "Pagination URLs - next: \(nextURL ?? "nil"), prev: \(prevURL ?? "nil"), latest: \(latestURL ?? "nil")"
      )
    } catch {
      LogManager.shared.error("Error parsing HTML: \(error.localizedDescription)")
    }

    LogManager.shared.info(
      "Parsed \(rootMessages.count) root messages for list \(mailingList.name)")
    return MessagePageResult(
      messages: orderedMessages, rootMessages: rootMessages, nextURL: nextURL, prevURL: prevURL,
      latestURL: latestURL)
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

  /// Parse search results page and return messages
  /// The search results page has a similar structure to list pages
  static func parseSearchResults(from html: String) -> MessagePageResult {
    LogManager.shared.info("Parsing search results from HTML")
    var messages: [Message] = []
    var nextURL: String?
    var prevURL: String?
    var latestURL: String?

    do {
      let doc = try SwiftSoup.parse(html)

      // Search results have a different format - links are in numbered list items
      // Format: <pre>      1. <b><a href="message-id/">Subject</a></b> ... </pre>
      // We need to find links that are inside numbered list items (1., 2., etc.)
      // These links typically end with / or are message IDs
      // Exclude navigation section (pre#t) and form sections
      let allLinks = try doc.select("pre:not(#t):not([id=t]) a[href]")
      var messageLinks: [Element] = []

      for link in allLinks {
        let href = try link.attr("href")

        // Check if this link is in a numbered list item (starts with number and dot)
        // Also check if href looks like a message ID (contains @ or is a timestamp-like pattern)
        if href.hasSuffix("/") && !href.contains("?") && !href.contains("#") {
          // Check if ancestor context suggests this is a search result item
          // Search results are typically in format: "1. <b><a>Subject</a></b> - by Author @ date"
          // The " - by " text is in the <pre> tag, not in the immediate parent <b> tag
          do {
            var current: Element? = link.parent()
            var foundSearchResultPattern = false

            // Walk up the ancestor chain to find the <pre> tag that contains " - by "
            while let element = current {
              let elementText = try element.text()
              let elementHtml = try element.outerHtml()

              // Check if this element or its text contains the search result pattern
              if elementText.contains(" - by ") || elementHtml.contains(" - by ") {
                foundSearchResultPattern = true
                break
              }

              // Stop if we've reached a <pre> tag (the container for search results)
              if element.tagName().lowercased() == "pre" {
                // Even if we don't find " - by " in this pre, check if it's a numbered list item
                if elementText.range(of: #"^\s*\d+\."#, options: .regularExpression) != nil {
                  foundSearchResultPattern = true
                }
                break
              }

              current = element.parent()
            }

            if foundSearchResultPattern {
              messageLinks.append(link)
            }
          } catch {
            // Skip if we can't traverse ancestors
            continue
          }
        }
      }

      // Fallback: also try to find links ending in /T/#t or /T/#u (for nested view)
      let threadLinks = try doc.select("a[href$=/T/#t], a[href$=/T/#u]")
      for link in threadLinks {
        let linkHref = try link.attr("href")
        let isDuplicate = messageLinks.contains { existingLink in
          do {
            return try existingLink.attr("href") == linkHref
          } catch {
            return false
          }
        }
        if !isDuplicate {
          messageLinks.append(link)
        }
      }

      LogManager.shared.info(
        "Found \(messageLinks.count) potential message links in search results")

      var seqId = 0
      var seenUrls = Set<String>()

      for link in messageLinks {
        let url = try link.attr("href")

        // Skip if we've already seen this URL
        if seenUrls.contains(url) {
          continue
        }
        seenUrls.insert(url)

        // Extract subject from title attribute or link text
        let titleAttr = try link.attr("title")
        let linkText = try link.text()
        let subject = titleAttr.isEmpty ? linkText : titleAttr

        // Try to extract timestamp from URL
        var timestamp: Date
        if let urlTimestamp = extractTimestampFromURL(url) {
          timestamp = urlTimestamp
        } else {
          // Fallback to current date if we can't extract from URL
          timestamp = Date()
        }

        // Construct full URL
        var fullUrl = url
        if !url.hasPrefix("http") {
          if url.hasPrefix("/") {
            fullUrl = LORE_LINUX_BASE_URL.value + url
          } else {
            fullUrl =
              LORE_LINUX_BASE_URL.value + "/"
              + url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
          }
        }

        // Remove /T/#u or /T/#t suffix if present
        if fullUrl.hasSuffix("/T/#u") {
          fullUrl = String(fullUrl.dropLast(5))
        } else if fullUrl.hasSuffix("/T/#t") {
          fullUrl = String(fullUrl.dropLast(5))
        }

        // Create a temporary mailing list for search results (or use a generic one)
        // Since search results can be from multiple lists, we'll create a message without a specific list
        let message = Message(
          subject: subject,
          content: url,
          timestamp: timestamp,
          seqId: seqId,
          messageId: fullUrl
        )

        messages.append(message)
        seqId += 1
      }

      // Parse pagination links - they are in the navigation section with id="t"
      // Format: <pre id=t>Results 1-200 of ~6000000  <a href="?q=test&o=200" rel=next>next (older)</a> ... </pre>
      let navSection = try doc.select("pre#t, pre[id=t]")
      if !navSection.isEmpty() {
        let navLinks = try navSection.select("a")
        for link in navLinks {
          let caption = try link.text().lowercased()
          let href = try link.attr("href")
          let rel = try link.attr("rel").lowercased()

          // Check rel attribute first (most reliable)
          if rel == "next" || caption.contains("next (older)") {
            nextURL = href
            LogManager.shared.info("Found next URL: \(href)")
          } else if caption.contains("prev (newer)") || caption.contains("prev")
            || caption.contains("previous")
          {
            prevURL = href
            LogManager.shared.info("Found prev URL: \(href)")
          } else if caption.contains("reverse") {
            // "reverse" link is usually the prev link in search results
            prevURL = href
            LogManager.shared.info("Found prev URL (reverse): \(href)")
          } else if caption.contains("latest") {
            latestURL = href
            LogManager.shared.info("Found latest URL: \(href)")
          }
        }
      }

      // Fallback: if no navigation section found, try to find pagination links more carefully
      if nextURL == nil && prevURL == nil {
        let allLinks = try doc.select("a")
        for link in allLinks {
          let caption = try link.text().lowercased()
          let href = try link.attr("href")
          // Only consider links with query parameters (like ?q=test&o=200) as pagination
          if href.contains("?q=") && (href.contains("&o=") || href.contains("o=")) {
            if caption.contains("next (older)") || caption.contains("next") {
              nextURL = href
              LogManager.shared.info("Found next URL (fallback): \(href)")
            } else if caption.contains("prev (newer)") || caption.contains("prev")
              || caption.contains("previous") || caption.contains("reverse")
            {
              prevURL = href
              LogManager.shared.info("Found prev URL (fallback): \(href)")
            }
          }
        }
      }

      // Also check for pagination in URL query parameters or specific pagination elements
      // Some search result pages might have different pagination structure
      if nextURL == nil && prevURL == nil {
        // Try to find pagination in a different format
        let paginationLinks = try doc.select("a[href*='page=']")
        for pagLink in paginationLinks {
          let href = try pagLink.attr("href")
          let text = try pagLink.text().lowercased()
          if text.contains("next") || text.contains("older") {
            nextURL = href
          } else if text.contains("prev") || text.contains("newer") || text.contains("previous") {
            prevURL = href
          }
        }
      }

      LogManager.shared.info(
        "Parsed \(messages.count) search results - next: \(nextURL ?? "nil"), prev: \(prevURL ?? "nil"), latest: \(latestURL ?? "nil")"
      )
    } catch {
      LogManager.shared.error("Error parsing search results: \(error.localizedDescription)")
    }

    // Extract root messages (messages without parent)
    let rootMessages = messages.filter { $0.parent == nil }
    return MessagePageResult(
      messages: messages, rootMessages: rootMessages, nextURL: nextURL, prevURL: prevURL,
      latestURL: latestURL)
  }

  /// Parse thread page and return the complete thread structure
  /// Thread pages use nested structure with indentation to show hierarchy
  static func parseThreadPage(from html: String, rootMessageId: String, mailingList: MailingList)
    -> [Message]
  {
    LogManager.shared.info("Parsing thread page for root message: \(rootMessageId)")
    var threadMessages: [Message] = []
    var messageMap: [String: Message] = [:]

    do {
      let doc = try SwiftSoup.parse(html)

      // Thread pages use nested structure, links are in <a> tags with href ending in /T/#t or /T/#u
      // The nesting is indicated by indentation or specific HTML structure
      let links = try doc.select("a[href$=/T/#t], a[href$=/T/#u], a[href*=/T/]")

      LogManager.shared.info("Found \(links.count) message links in thread HTML")

      var seqId = 0
      var seenUrls = Set<String>()
      var parentStack: [Message] = []  // Stack to track parent messages based on nesting

      for link in links {
        let url = try link.attr("href")

        // Skip if we've already seen this URL
        if seenUrls.contains(url) {
          continue
        }
        seenUrls.insert(url)

        // Extract subject and decode HTML entities
        let titleAttr = try link.attr("title")
        let linkText = try link.text()
        let subject = decodeHTMLEntities(titleAttr.isEmpty ? linkText : titleAttr)

        // Try to extract timestamp from URL
        var timestamp: Date
        if let urlTimestamp = extractTimestampFromURL(url) {
          timestamp = urlTimestamp
        } else {
          timestamp = Date()
        }

        // Construct full URL
        var fullUrl = url
        if !url.hasPrefix("http") {
          if url.hasPrefix("/") {
            fullUrl = LORE_LINUX_BASE_URL.value + url
          } else {
            fullUrl =
              LORE_LINUX_BASE_URL.value + "/" + mailingList.name + "/"
              + url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
          }
        }

        // Remove /T/#u or /T/#t suffix
        if fullUrl.hasSuffix("/T/#u") {
          fullUrl = String(fullUrl.dropLast(5))
        } else if fullUrl.hasSuffix("/T/#t") {
          fullUrl = String(fullUrl.dropLast(5))
        }

        // Check if message already exists
        let existingMessage = mailingList.messages.first { $0.messageId == fullUrl }
        let message: Message

        if let existing = existingMessage {
          message = existing
          message.subject = subject
          message.timestamp = timestamp
        } else {
          message = Message(
            subject: subject,
            content: url,
            timestamp: timestamp,
            seqId: seqId,
            messageId: fullUrl
          )
          message.mailingList = mailingList
        }

        seqId += 1

        // Determine parent based on HTML structure
        // In thread pages, nested messages are typically indented or in nested elements
        // We'll use the link's parent elements to determine nesting level
        if let parentElement = link.parent() {
          // Count nesting level by checking parent structure
          var nestingLevel = 0
          var currentElement: Element? = parentElement
          while let element = currentElement {
            // Check if this is a nested structure (e.g., in a list or div with indentation)
            let tagName = element.tagName().lowercased()
            if tagName == "li" || tagName == "div" {
              nestingLevel += 1
            }
            currentElement = element.parent()

            // Limit depth check
            if nestingLevel > 10 {
              break
            }
          }

          // Find appropriate parent from stack
          // If nesting level is 0 or 1, it's a root or direct child
          // Higher nesting levels indicate deeper nesting
          if nestingLevel <= 1 {
            // Root message or direct child
            if parentStack.isEmpty {
              // This is a root message
              parentStack = [message]
            } else {
              // Direct child of the last root
              if let parent = parentStack.first {
                message.parent = parent
                parent.replies.append(message)
                parentStack = [parent, message]
              }
            }
          } else {
            // Nested deeper - find parent at appropriate level
            let targetLevel = nestingLevel - 1
            if targetLevel < parentStack.count {
              let parent = parentStack[targetLevel]
              message.parent = parent
              parent.replies.append(message)

              // Update stack - remove deeper levels and add this message
              parentStack = Array(parentStack.prefix(targetLevel + 1))
              parentStack.append(message)
            } else if let lastParent = parentStack.last {
              // Fallback: add as child of last parent
              message.parent = lastParent
              lastParent.replies.append(message)
              parentStack.append(message)
            }
          }
        }

        messageMap[fullUrl] = message
        threadMessages.append(message)
      }

      LogManager.shared.info("Parsed \(threadMessages.count) messages in thread")
    } catch {
      LogManager.shared.error("Error parsing thread HTML: \(error.localizedDescription)")
    }

    return threadMessages
  }
}
