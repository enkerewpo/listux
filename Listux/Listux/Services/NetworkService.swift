import Foundation
import os.log

class NetworkService {
  static let shared = NetworkService()
  private let baseURL = LORE_LINUX_BASE_URL.value
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: NetworkService.self))

  private init() {}

  func fetchHomePage() async throws -> String {
    LogManager.shared.info("Fetching main page from \(baseURL)")
    let url = URL(string: baseURL)!
    let (data, response) = try await URLSession.shared.data(from: url)
    if let httpResponse = response as? HTTPURLResponse {
      LogManager.shared.info("Main page response status: \(httpResponse.statusCode)")
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    LogManager.shared.info("Main page content length: \(html.count) characters")
    return html
  }

  func fetchListPage(_ listName: String) async throws -> String {
    LogManager.shared.info("Fetching mailing list: \(listName)")
    let url = URL(string: "\(baseURL)/\(listName)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    if let httpResponse = response as? HTTPURLResponse {
      LogManager.shared.info("Mailing list response status: \(httpResponse.statusCode)")
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    LogManager.shared.info("Mailing list content length: \(html.count) characters")
    return html
  }

  func fetchMessage(_ messageId: String) async throws -> String {
    LogManager.shared.info("Fetching message: \(messageId) from \(baseURL)")
    let url = URL(string: "\(baseURL)/\(messageId)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    if let httpResponse = response as? HTTPURLResponse {
      LogManager.shared.info("Message response status: \(httpResponse.statusCode) for \(messageId)")
    }
    let html = String(data: data, encoding: .utf8) ?? ""
    LogManager.shared.info("Message content length: \(html.count) characters for \(messageId)")
    return html
  }

  /// Fetch raw HTML from an arbitrary URL string, please make sure this is a message page
  func fetchMessageRaw(url: String) async throws -> String {
    LogManager.shared.info("Fetching raw message from URL: \(url)")

    guard let u = URL(string: url) else {
      LogManager.shared.error("Invalid URL: \(url)")
      throw URLError(.badURL)
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: u)

      if let httpResponse = response as? HTTPURLResponse {
        LogManager.shared.info("Raw fetch response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
          LogManager.shared.error("HTTP error: \(httpResponse.statusCode)")
          throw URLError(.badServerResponse)
        }
      }

      guard let html = String(data: data, encoding: .utf8) else {
        LogManager.shared.error("Failed to decode HTML content")
        throw URLError(.cannotDecodeContentData)
      }

      LogManager.shared.info("Raw fetch content length: \(html.count) characters")

      if html.isEmpty {
        LogManager.shared.info("Received empty HTML content")
      }

      return html
    } catch {
      LogManager.shared.error("Network request failed: \(error.localizedDescription)")
      throw error
    }
  }

  /// Fetch raw HTML from an arbitrary URL string
  func fetchURL(_ urlString: String) async throws -> String {
    LogManager.shared.info("Fetching content from URL: \(urlString)")

    guard let url = URL(string: urlString) else {
      LogManager.shared.error("Invalid URL: \(urlString)")
      throw URLError(.badURL)
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: url)

      if let httpResponse = response as? HTTPURLResponse {
        LogManager.shared.info("URL fetch response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode != 200 {
          LogManager.shared.error("HTTP error: \(httpResponse.statusCode)")
          throw URLError(.badServerResponse)
        }
      }

      guard let html = String(data: data, encoding: .utf8) else {
        LogManager.shared.error("Failed to decode HTML content")
        throw URLError(.cannotDecodeContentData)
      }

      LogManager.shared.info("URL fetch content length: \(html.count) characters")

      if html.isEmpty {
        LogManager.shared.info("Received empty HTML content")
      }

      return html
    } catch {
      LogManager.shared.error("Network request failed: \(error.localizedDescription)")
      throw error
    }
  }
}
