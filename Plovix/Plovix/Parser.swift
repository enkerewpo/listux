import Foundation
import os.log
import SwiftSoup

class Parser {
    private static let logger = Logger(subsystem: "com.wheatfox.plovix", category: "parser")
    
    static func parseMailingLists(from html: String) -> [(name: String, desc: String)] {
        logger.info("Starting to parse mailing lists from HTML")
        var lists: [(name: String, desc: String)] = []
        
        do {
            let doc = try SwiftSoup.parse(html)
            // Find all <pre> elements
            let preElements = try doc.select("pre")
            
            for pre in preElements {
                let content = try pre.text()
                // Split by newlines and process each line
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    if !trimmedLine.isEmpty {
                        // Assuming the format is "name - desc"
                        let components = trimmedLine.components(separatedBy: " - ")
                        if components.count >= 2 {
                            var name = components[1]
                            var desc = components[0]
                            // remove * and leading and trailing spaces
                            name = name.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
                            desc = desc.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
                            lists.append((name, desc))
                        }
                    }
                }
            }
            // sort by name in alphabetical order
            lists.sort { $0.name < $1.name }
            
            logger.info("Finished parsing mailing lists. Found \(lists.count) lists")
        } catch {
            logger.error("Error parsing HTML: \(error.localizedDescription)")
        }
        
        return lists
    }
} 