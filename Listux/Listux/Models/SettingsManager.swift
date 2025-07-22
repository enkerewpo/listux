import SwiftUI

@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    var shouldOpenSettings: Bool = false
    
    private init() {}
    
    func openSettings() {
        shouldOpenSettings = true
    }
} 