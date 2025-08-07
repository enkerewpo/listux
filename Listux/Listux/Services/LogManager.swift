import AppKit
import Foundation
import os.log

class LogManager: ObservableObject {
  static let shared = LogManager()

  private let logger = Logger(subsystem: "com.listux.app", category: "main")
  private let fileManager = FileManager.default
  private var currentLogFileURL: URL?

  private var logDirectory: URL {
    let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("Listux/Logs")
  }

  private var currentLogFile: URL {
    if let url = currentLogFileURL {
      return url
    }
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
    let timestamp = dateFormatter.string(from: Date())
    let url = logDirectory.appendingPathComponent("listux_\(timestamp).log")
    currentLogFileURL = url
    return url
  }

  private init() {
    setupLogDirectory()
    startNewLogSession()
  }

  private func setupLogDirectory() {
    do {
      if !fileManager.fileExists(atPath: logDirectory.path) {
        try fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
      }
    } catch {
      logger.error("Failed to create log directory: \(error.localizedDescription)")
    }
  }

  private func startNewLogSession() {
    let sessionStart = """
      ========================================
      Listux Log Session Started
      Date: \(Date())
      Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
      Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
      ========================================

      """

    do {
      try sessionStart.write(to: currentLogFile, atomically: true, encoding: .utf8)
      logger.info("New log session started at: \(self.currentLogFile.path)")
    } catch {
      logger.error("Failed to create log file: \(error.localizedDescription)")
    }

    rotateLogs()
  }

  private func rotateLogs() {
    do {
      let logFiles = try fileManager.contentsOfDirectory(
        at: logDirectory, includingPropertiesForKeys: [.creationDateKey]
      )
      .filter { $0.pathExtension == "log" }
      .sorted { file1, file2 in
        let date1 =
          try file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
        let date2 =
          try file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
        return date1 > date2
      }

      // Keep only the 10 most recent log files
      if logFiles.count > 10 {
        let filesToDelete = logFiles.dropFirst(10)
        for file in filesToDelete {
          try fileManager.removeItem(at: file)
          logger.info("Deleted old log file: \(file.lastPathComponent)")
        }
      }
    } catch {
      logger.error("Failed to rotate logs: \(error.localizedDescription)")
    }
  }

  func log(_ message: String, level: OSLogType = .default) {
    let timestamp = DateFormatter.logTimestamp.string(from: Date())
    let logEntry = "[\(timestamp)] \(message)\n"

    do {
      if !fileManager.fileExists(atPath: currentLogFile.path) {
        try logEntry.write(to: currentLogFile, atomically: true, encoding: .utf8)
      } else {
        let handle = try FileHandle(forWritingTo: currentLogFile)
        handle.seekToEndOfFile()
        handle.write(logEntry.data(using: .utf8)!)
        handle.closeFile()
      }
    } catch {
      logger.error("Failed to write to log file: \(error.localizedDescription)")
    }

    switch level {
    case .debug:
      logger.debug("\(message)")
    case .info:
      logger.info("\(message)")
    case .error:
      logger.error("\(message)")
    case .fault:
      logger.fault("\(message)")
    default:
      logger.notice("\(message)")
    }
  }

  func debug(_ message: String) {
    log(message, level: .debug)
  }

  func info(_ message: String) {
    log(message, level: .info)
  }

  func error(_ message: String) {
    log(message, level: .error)
  }

  func fault(_ message: String) {
    log(message, level: .fault)
  }

  func openLogDirectory() {
    NSWorkspace.shared.open(logDirectory)
  }
}

extension DateFormatter {
  static let logTimestamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return formatter
  }()
}
