import Foundation
import os.log

class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "https://lore.kernel.org"
    private let logger = Logger(subsystem: "com.wheatfox.plovix", category: "network")
    
    private init() {}
    
    func fetchMainPage() async throws -> String {
        logger.info("Fetching main page from lore.kernel.org")
        let url = URL(string: baseURL)!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("Main page response status: \(httpResponse.statusCode)")
        }
        let html = String(data: data, encoding: .utf8) ?? ""
        logger.info("Main page content length: \(html.count) characters")
        logger.debug("Main page content (first 1000 chars):\n\(String(html.prefix(1000)))")
        return html
    }
    
    func fetchMailingList(_ listName: String) async throws -> String {
        logger.info("Fetching mailing list: \(listName)")
        let url = URL(string: "\(baseURL)/\(listName)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse {
            logger.info("Mailing list response status: \(httpResponse.statusCode)")
        }
        let html = String(data: data, encoding: .utf8) ?? ""
        logger.info("Mailing list content length: \(html.count) characters")
        logger.debug("Mailing list content (first 1000 chars):\n\(String(html.prefix(1000)))")
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
        logger.debug("Message content (first 1000 chars):\n\(String(html.prefix(1000)))")
        return html
    }
} 