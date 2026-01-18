import Foundation
import os.log

class SearchService {
  static let shared = SearchService()
  private let baseURL = LORE_LINUX_BASE_URL.value
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: SearchService.self))

  private init() {}

  /// Perform a search query on lore.kernel.org
  /// - Parameters:
  ///   - query: The search query string (supports Xapian query syntax)
  ///   - page: Optional page number for pagination
  /// - Returns: HTML content of the search results page
  func search(query: String, page: Int = 1) async throws -> String {
    LogManager.shared.info("Searching for: \(query) (page: \(page))")

    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw SearchError.emptyQuery
    }

    // Build search URL
    // lore.kernel.org/all/?q=query&page=page
    var urlString = "\(baseURL)/all/"
    var components = URLComponents(string: urlString)
    var queryItems: [URLQueryItem] = []

    // Add search query
    queryItems.append(URLQueryItem(name: "q", value: query))

    // Add page number if > 1
    if page > 1 {
      queryItems.append(URLQueryItem(name: "page", value: String(page)))
    }

    components?.queryItems = queryItems

    guard let url = components?.url else {
      LogManager.shared.error("Invalid search URL")
      throw SearchError.invalidURL
    }

    LogManager.shared.info("Search URL: \(url.absoluteString)")

    do {
      let (data, response) = try await URLSession.shared.data(from: url)

      if let httpResponse = response as? HTTPURLResponse {
        LogManager.shared.info("Search response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
          LogManager.shared.error("HTTP error: \(httpResponse.statusCode)")
          throw SearchError.httpError(httpResponse.statusCode)
        }
      }

      guard let html = String(data: data, encoding: .utf8) else {
        LogManager.shared.error("Failed to decode HTML content")
        throw SearchError.decodeError
      }

      LogManager.shared.info("Search content length: \(html.count) characters")
      return html
    } catch {
      LogManager.shared.error("Search request failed: \(error.localizedDescription)")
      throw error
    }
  }
}

enum SearchError: LocalizedError {
  case emptyQuery
  case invalidURL
  case httpError(Int)
  case decodeError

  var errorDescription: String? {
    switch self {
    case .emptyQuery:
      return "Search query cannot be empty"
    case .invalidURL:
      return "Invalid search URL"
    case .httpError(let code):
      return "HTTP error: \(code)"
    case .decodeError:
      return "Failed to decode search results"
    }
  }
}
