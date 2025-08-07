import Foundation
import os.log

class NetworkService {
  static let shared = NetworkService()
  private let baseURL = LORE_LINUX_BASE_URL.value
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: NetworkService.self))

  private init() {}

  func fetchHomePage() async throws -> String {
    logger.info("Fetching main page from lore.kernel.org")
    let url = URL(string: baseURL)!
    let (data, response) = try await URLSession.shared.data(from: url)
    if let httpResponse = response as? HTTPURLResponse {
      logger.info("Main page response status: \(httpResponse.statusCode)")
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    logger.info("Main page content length: \(html.count) characters")
    // logger.debug("Main page content (first 500 chars):\n\(String(html.prefix(500)))")
    return html
  }

  func fetchListPage(_ listName: String) async throws -> String {
    logger.info("Fetching mailing list: \(listName)")
    let url = URL(string: "\(baseURL)/\(listName)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    if let httpResponse = response as? HTTPURLResponse {
      logger.info("Mailing list response status: \(httpResponse.statusCode)")
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    logger.info("Mailing list content length: \(html.count) characters")
    // logger.debug("Mailing list content (first 500 chars):\n\(String(html.prefix(500)))")
    return html
  }

  func fetchMessage(_ messageId: String) async throws -> String {
    logger.info("Fetching message: \(messageId)")
    let url = URL(string: "\(baseURL)/\(messageId)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    if let httpResponse = response as? HTTPURLResponse {
      logger.info("Message response status: \(httpResponse.statusCode)")
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    logger.info("Message content length: \(html.count) characters")
    // logger.debug("Message content (first 500 chars):\n\(String(html.prefix(500)))")
    return html
  }

  /// Fetch raw HTML from an arbitrary URL string, please make sure this is a message page
  func fetchMessageRaw(url: String) async throws -> String {
    logger.info("Fetching raw message from URL: \(url)")

    guard let u = URL(string: url) else {
      logger.error("Invalid URL: \(url)")
      throw URLError(.badURL)
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: u)

      if let httpResponse = response as? HTTPURLResponse {
        logger.info("Raw fetch response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
          logger.error("HTTP error: \(httpResponse.statusCode)")
          throw URLError(.badServerResponse)
        }
      }

      guard let html = String(data: data, encoding: .utf8) else {
        logger.error("Failed to decode HTML content")
        throw URLError(.cannotDecodeContentData)
      }

      logger.info("Raw fetch content length: \(html.count) characters")

      if html.isEmpty {
        logger.warning("Received empty HTML content")
      }

      return html
    } catch {
      logger.error("Network request failed: \(error.localizedDescription)")
      throw error
    }
  }
  
  /// Fetch raw HTML from an arbitrary URL string
  func fetchURL(_ urlString: String) async throws -> String {
    logger.info("Fetching content from URL: \(urlString)")

    guard let url = URL(string: urlString) else {
      logger.error("Invalid URL: \(urlString)")
      throw URLError(.badURL)
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: url)

      if let httpResponse = response as? HTTPURLResponse {
        logger.info("URL fetch response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
          logger.error("HTTP error: \(httpResponse.statusCode)")
          throw URLError(.badServerResponse)
        }
      }

      guard let html = String(data: data, encoding: .utf8) else {
        logger.error("Failed to decode HTML content")
        throw URLError(.cannotDecodeContentData)
      }

      logger.info("URL fetch content length: \(html.count) characters")

      if html.isEmpty {
        logger.warning("Received empty HTML content")
      }

      return html
    } catch {
      logger.error("Network request failed: \(error.localizedDescription)")
      throw error
    }
  }
}
