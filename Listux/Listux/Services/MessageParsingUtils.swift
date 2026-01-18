import Foundation

struct MessageParsingUtils {

  static func extractSubjectFromContent(_ content: String) -> String? {
    let lines = content.components(separatedBy: .newlines)

    for line in lines {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      if trimmedLine.lowercased().hasPrefix("subject:") {
        let value = String(trimmedLine.dropFirst("subject:".count)).trimmingCharacters(
          in: .whitespaces)
        if !value.isEmpty {
          return value
        }
      }

      if trimmedLine.isEmpty {
        break
      }
    }

    return nil
  }

  static func extractAuthorFromContent(_ content: String) -> String? {
    let lines = content.components(separatedBy: .newlines)

    for line in lines {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      if trimmedLine.lowercased().hasPrefix("from:") {
        let value = String(trimmedLine.dropFirst("from:".count)).trimmingCharacters(
          in: .whitespaces)
        if !value.isEmpty {
          if let emailRangeStart = value.firstIndex(of: "<"),
            let emailRangeEnd = value.firstIndex(of: ">"),
            emailRangeStart < emailRangeEnd
          {
            let name = String(value[..<emailRangeStart]).trimmingCharacters(in: .whitespaces)
            return name.isEmpty
              ? String(value[value.index(after: emailRangeStart)..<emailRangeEnd]) : name
          } else {
            return value
          }
        }
      }

      if trimmedLine.isEmpty {
        break
      }
    }

    return nil
  }

  static func extractDateFromContent(_ content: String) -> String? {
    let lines = content.components(separatedBy: .newlines)

    for line in lines {
      let trimmedLine = line.trimmingCharacters(in: .whitespaces)
      if trimmedLine.lowercased().hasPrefix("date:") {
        let value = String(trimmedLine.dropFirst("date:".count)).trimmingCharacters(
          in: .whitespaces)
        if !value.isEmpty {
          return value
        }
      }

      if trimmedLine.isEmpty {
        break
      }
    }

    return nil
  }

  private static func angleTokens(in line: String) -> [String] {
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

  private static func firstAngleToken(in line: String) -> String? {
    return angleTokens(in: line).first
  }
}
