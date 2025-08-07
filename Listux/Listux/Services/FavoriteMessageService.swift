import Foundation
import SwiftData

@Observable
class FavoriteMessageService {
  static let shared = FavoriteMessageService()

  private var modelContext: ModelContext?

  private init() {}

  func setModelContext(_ context: ModelContext) {
    self.modelContext = context
  }

  // MARK: - Favorite Message Management

  func toggleFavorite(_ message: Message) {
    guard let modelContext = modelContext else {
      LogManager.shared.error("FavoriteMessageService: modelContext is nil")
      return
    }

    LogManager.shared.info(
      "FavoriteMessageService: Toggling favorite for message \(message.messageId)")
    LogManager.shared.debug(
      "FavoriteMessageService: Current isFavorite state: \(message.isFavorite)")

    if message.isFavorite {
      // Remove from favorites
      LogManager.shared.info("FavoriteMessageService: Removing from favorites")
      message.isFavorite = false
      message.tags = []
      removeFavorite(messageId: message.messageId)
    } else {
      // Add to favorites
      LogManager.shared.info("FavoriteMessageService: Adding to favorites")
      message.isFavorite = true
      if let favoriteMessage = message.toFavoriteMessage() {
        LogManager.shared.info("FavoriteMessageService: Created favorite message successfully")
        modelContext.insert(favoriteMessage)
        do {
          try modelContext.save()
          LogManager.shared.info("FavoriteMessageService: Saved to persistent storage successfully")
        } catch {
          LogManager.shared.error(
            "FavoriteMessageService: Failed to save to persistent storage: \(error)")
          message.isFavorite = false
        }
      } else {
        LogManager.shared.error("FavoriteMessageService: Failed to create favorite message")
        message.isFavorite = false
      }
    }
  }

  func removeFavorite(messageId: String) {
    guard let modelContext = modelContext else {
      LogManager.shared.error("FavoriteMessageService: modelContext is nil in removeFavorite")
      return
    }

    let descriptor = FetchDescriptor<FavoriteMessage>()

    do {
      let favorites = try modelContext.fetch(descriptor)
      let toRemove = favorites.filter { $0.messageId == messageId }
      LogManager.shared.info(
        "FavoriteMessageService: Found \(toRemove.count) favorites to remove for messageId: \(messageId)"
      )
      toRemove.forEach { modelContext.delete($0) }
      try modelContext.save()
      LogManager.shared.info(
        "FavoriteMessageService: Successfully removed favorite for messageId: \(messageId)")
    } catch {
      LogManager.shared.error("FavoriteMessageService: Error removing favorite: \(error)")
    }
  }

  func getFavoriteMessage(messageId: String) -> FavoriteMessage? {
    guard let modelContext = modelContext else {
      LogManager.shared.error("FavoriteMessageService: modelContext is nil in getFavoriteMessage")
      return nil
    }

    let descriptor = FetchDescriptor<FavoriteMessage>()

    do {
      let favorites = try modelContext.fetch(descriptor)
      let result = favorites.first { $0.messageId == messageId }
      LogManager.shared.debug(
        "FavoriteMessageService: getFavoriteMessage for \(messageId) - found: \(result != nil)")
      return result
    } catch {
      LogManager.shared.error("FavoriteMessageService: Error fetching favorite message: \(error)")
      return nil
    }
  }

  func getAllFavoriteMessages() -> [FavoriteMessage] {
    guard let modelContext = modelContext else {
      LogManager.shared.error(
        "FavoriteMessageService: modelContext is nil in getAllFavoriteMessages")
      return []
    }

    let descriptor = FetchDescriptor<FavoriteMessage>(
      sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
    )

    do {
      let favorites = try modelContext.fetch(descriptor)
      print(
        "FavoriteMessageService: Found \(favorites.count) favorite messages in persistent storage")
      for favorite in favorites {
        print(
          "FavoriteMessageService: - \(favorite.messageId): \(favorite.subject) (tags: \(favorite.tags))"
        )
      }
      return favorites
    } catch {
      print("FavoriteMessageService: Error fetching all favorite messages: \(error)")
      return []
    }
  }

  // MARK: - Tag Management

  func addTag(_ tag: String, to messageId: String) {
    guard let modelContext = modelContext,
      let favoriteMessage = getFavoriteMessage(messageId: messageId)
    else {
      print(
        "FavoriteMessageService: Failed to add tag '\(tag)' to messageId '\(messageId)' - favorite message not found"
      )
      return
    }

    favoriteMessage.addTag(tag)
    do {
      try modelContext.save()
      print("FavoriteMessageService: Successfully added tag '\(tag)' to messageId '\(messageId)'")
    } catch {
      print(
        "FavoriteMessageService: Failed to save tag '\(tag)' to messageId '\(messageId)': \(error)")
    }
  }

  func addTag(_ tag: String, to message: Message) {
    addTag(tag, to: message.messageId)
    if !message.tags.contains(tag) {
      message.tags.append(tag)
    }
  }

  func removeTag(_ tag: String, from messageId: String) {
    guard let modelContext = modelContext,
      let favoriteMessage = getFavoriteMessage(messageId: messageId)
    else {
      print(
        "FavoriteMessageService: Failed to remove tag '\(tag)' from messageId '\(messageId)' - favorite message not found"
      )
      return
    }

    favoriteMessage.removeTag(tag)
    do {
      try modelContext.save()
      print(
        "FavoriteMessageService: Successfully removed tag '\(tag)' from messageId '\(messageId)'")
    } catch {
      print(
        "FavoriteMessageService: Failed to save tag removal '\(tag)' from messageId '\(messageId)': \(error)"
      )
    }
  }

  func getTags(for messageId: String) -> [String] {
    return getFavoriteMessage(messageId: messageId)?.tags ?? []
  }

  func getAllTags() -> [String] {
    let allFavorites = getAllFavoriteMessages()
    let allTags = Set(allFavorites.flatMap { $0.tags })
    let sortedTags = Array(allTags).sorted()
    print("FavoriteMessageService: getAllTags returned \(sortedTags.count) tags: \(sortedTags)")
    return sortedTags
  }

  func getMessagesWithTag(_ tag: String) -> [String] {
    let allFavorites = getAllFavoriteMessages()
    let messageIds = allFavorites.compactMap { favorite in
      favorite.tags.contains(tag) ? favorite.messageId : nil
    }
    print("FavoriteMessageService: Found \(messageIds.count) messages with tag '\(tag)'")
    return messageIds
  }

  func getUntaggedMessages() -> [String] {
    let allFavorites = getAllFavoriteMessages()
    let messageIds = allFavorites.compactMap { favorite in
      favorite.tags.isEmpty ? favorite.messageId : nil
    }
    print("FavoriteMessageService: Found \(messageIds.count) untagged messages")
    return messageIds
  }

  // MARK: - Message Sync

  func syncMessageWithPersistentStorage(_ message: Message) {
    let favoriteMessage = getFavoriteMessage(messageId: message.messageId)
    Task { @MainActor in
      message.syncWithPersistentStorage(favoriteMessage)
    }
  }

  func syncMessagesWithPersistentStorage(_ messages: [Message]) {
    for message in messages {
      syncMessageWithPersistentStorage(message)
    }
  }

  // MARK: - Debug and Verification

  func verifyPersistence() {
    guard let modelContext = modelContext else {
      print("FavoriteMessageService: Cannot verify persistence - modelContext is nil")
      return
    }

    let descriptor = FetchDescriptor<FavoriteMessage>()
    do {
      let favorites = try modelContext.fetch(descriptor)
      print(
        "FavoriteMessageService: Persistence verification - Found \(favorites.count) favorite messages"
      )
      for favorite in favorites {
        print(
          "FavoriteMessageService: - \(favorite.messageId): \(favorite.subject) (tags: \(favorite.tags))"
        )
      }
    } catch {
      print("FavoriteMessageService: Error verifying persistence: \(error)")
    }
  }

  func forceSave() {
    guard let modelContext = modelContext else {
      print("FavoriteMessageService: Cannot force save - modelContext is nil")
      return
    }

    do {
      try modelContext.save()
      print("FavoriteMessageService: Force save completed successfully")
    } catch {
      print("FavoriteMessageService: Force save failed: \(error)")
    }
  }

  func checkDataOnStartup() {
    guard let modelContext = modelContext else {
      print("FavoriteMessageService: Cannot check data - modelContext is nil")
      return
    }

    let descriptor = FetchDescriptor<FavoriteMessage>()
    do {
      let favorites = try modelContext.fetch(descriptor)
      print("FavoriteMessageService: Startup check - Found \(favorites.count) favorite messages")
      for favorite in favorites {
        print(
          "FavoriteMessageService: - \(favorite.messageId): \(favorite.subject) (tags: \(favorite.tags))"
        )
      }
    } catch {
      print("FavoriteMessageService: Error checking data on startup: \(error)")
    }
  }
}
