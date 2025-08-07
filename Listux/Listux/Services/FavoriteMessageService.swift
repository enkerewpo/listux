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
            print("FavoriteMessageService: modelContext is nil")
            return 
        }
        
        print("FavoriteMessageService: Toggling favorite for message \(message.messageId)")
        print("FavoriteMessageService: Current isFavorite state: \(message.isFavorite)")
        
        if message.isFavorite {
            // Remove from favorites
            print("FavoriteMessageService: Removing from favorites")
            message.isFavorite = false
            message.tags = []
            removeFavorite(messageId: message.messageId)
        } else {
            // Add to favorites
            print("FavoriteMessageService: Adding to favorites")
            message.isFavorite = true
            if let favoriteMessage = message.toFavoriteMessage() {
                print("FavoriteMessageService: Created favorite message successfully")
                modelContext.insert(favoriteMessage)
                try? modelContext.save()
                print("FavoriteMessageService: Saved to persistent storage")
            } else {
                print("FavoriteMessageService: Failed to create favorite message")
                message.isFavorite = false
            }
        }
    }
    
    func removeFavorite(messageId: String) {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<FavoriteMessage>(
            predicate: #Predicate<FavoriteMessage> { $0.messageId == messageId }
        )
        
        do {
            let favorites = try modelContext.fetch(descriptor)
            favorites.forEach { modelContext.delete($0) }
            try modelContext.save()
        } catch {
            print("Error removing favorite: \(error)")
        }
    }
    
    func getFavoriteMessage(messageId: String) -> FavoriteMessage? {
        guard let modelContext = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<FavoriteMessage>(
            predicate: #Predicate<FavoriteMessage> { $0.messageId == messageId }
        )
        
        do {
            let favorites = try modelContext.fetch(descriptor)
            return favorites.first
        } catch {
            print("Error fetching favorite message: \(error)")
            return nil
        }
    }
    
    func getAllFavoriteMessages() -> [FavoriteMessage] {
        guard let modelContext = modelContext else { 
            print("FavoriteMessageService: modelContext is nil in getAllFavoriteMessages")
            return [] 
        }
        
        let descriptor = FetchDescriptor<FavoriteMessage>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let favorites = try modelContext.fetch(descriptor)
            print("FavoriteMessageService: Found \(favorites.count) favorite messages")
            for favorite in favorites {
                print("FavoriteMessageService: - \(favorite.messageId): \(favorite.subject)")
            }
            return favorites
        } catch {
            print("Error fetching all favorite messages: \(error)")
            return []
        }
    }
    
    // MARK: - Tag Management
    
    func addTag(_ tag: String, to messageId: String) {
        guard let modelContext = modelContext,
              let favoriteMessage = getFavoriteMessage(messageId: messageId) else { return }
        
        favoriteMessage.addTag(tag)
        try? modelContext.save()
    }
    
    func addTag(_ tag: String, to message: Message) {
        addTag(tag, to: message.messageId)
        if !message.tags.contains(tag) {
            message.tags.append(tag)
        }
    }
    
    func removeTag(_ tag: String, from messageId: String) {
        guard let modelContext = modelContext,
              let favoriteMessage = getFavoriteMessage(messageId: messageId) else { return }
        
        favoriteMessage.removeTag(tag)
        try? modelContext.save()
    }
    
    func getTags(for messageId: String) -> [String] {
        return getFavoriteMessage(messageId: messageId)?.tags ?? []
    }
    
    func getAllTags() -> [String] {
        let allFavorites = getAllFavoriteMessages()
        let allTags = Set(allFavorites.flatMap { $0.tags })
        return Array(allTags).sorted()
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
} 