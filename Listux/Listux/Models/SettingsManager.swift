import SwiftUI
import SwiftData

@Observable
class SettingsManager {
    static let shared = SettingsManager()
    
    var shouldOpenSettings: Bool = false
    var onDataCleared: (() -> Void)?
    
    private init() {}
    
    func openSettings() {
        shouldOpenSettings = true
    }
    
    // 清空本地持久化数据（收藏、标签等）
    func clearAllData(modelContext: ModelContext) {
        do {
            // 只清空Preference数据（收藏、标签、偏好设置）
            let preferenceDescriptor = FetchDescriptor<Preference>()
            let preferences = try modelContext.fetch(preferenceDescriptor)
            for preference in preferences {
                modelContext.delete(preference)
            }
            
            // 保存更改
            try modelContext.save()
            
            print("All local persistent data has been cleared successfully")
            
            // 通知数据已清空
            DispatchQueue.main.async {
                self.onDataCleared?()
            }
        } catch {
            print("Failed to clear local data: \(error)")
        }
    }
} 