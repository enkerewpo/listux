import Foundation
import os.log

class ThreadService {
  static let shared = ThreadService()
  private let baseURL = LORE_LINUX_BASE_URL.value
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!, category: String(describing: ThreadService.self))

  private init() {}

  /// Fetch thread page for a message
  /// - Parameter messageId: The message ID (can be full URL or just the ID part)
  /// - Returns: HTML content of the thread page in threaded order
  func fetchThread(messageId: String) async throws -> String {
    LogManager.shared.info("Fetching thread for message: \(messageId)")
    
    // Extract message ID from URL if needed
    var threadId = messageId
    if messageId.contains("/") {
      // Extract the message ID part (e.g., from "20250714070438.2399153-1-chenhuacai@loongson.cn")
      let components = messageId.split(separator: "/")
      if let lastComponent = components.last {
        threadId = String(lastComponent)
      }
    }
    
    // Build thread URL: https://lore.kernel.org/all/<Message-ID>/t/#u
    // Use threaded order (lowercase 't') for nested structure
    let urlString = "\(baseURL)/all/\(threadId)/t/"
    
    LogManager.shared.info("Thread URL: \(urlString)")
    
    guard let url = URL(string: urlString) else {
      LogManager.shared.error("Invalid thread URL: \(urlString)")
      throw ThreadError.invalidURL
    }
    
    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      
      if let httpResponse = response as? HTTPURLResponse {
        LogManager.shared.info("Thread response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
          LogManager.shared.error("HTTP error: \(httpResponse.statusCode)")
          throw ThreadError.httpError(httpResponse.statusCode)
        }
      }
      
      guard let html = String(data: data, encoding: .utf8) else {
        LogManager.shared.error("Failed to decode HTML content")
        throw ThreadError.decodeError
      }
      
      LogManager.shared.info("Thread content length: \(html.count) characters")
      return html
    } catch {
      LogManager.shared.error("Thread request failed: \(error.localizedDescription)")
      throw error
    }
  }
}

enum ThreadError: LocalizedError {
  case invalidURL
  case httpError(Int)
  case decodeError
  
  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid thread URL"
    case .httpError(let code):
      return "HTTP error: \(code)"
    case .decodeError:
      return "Failed to decode thread content"
    }
  }
}
