import Foundation
import SwiftData

@Model
final class Preference {
    var favoriteLists: [MailingList] = []
    var lastViewedList: MailingList?
    
    init() {}
    
    func toggleFavorite(_ list: MailingList) {
        if favoriteLists.contains(list) {
            favoriteLists.removeAll { $0.id == list.id }
        } else {
            favoriteLists.append(list)
        }
    }
    
    func isFavorite(_ list: MailingList) -> Bool {
        favoriteLists.contains { $0.id == list.id }
    }
} 