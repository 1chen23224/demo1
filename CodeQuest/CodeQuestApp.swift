import SwiftUI

@main
struct CodeQuestApp: App { // <-- 請改成你的 App 名稱
    // 建立 LanguageManager 的實例
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // ✅ 將 manager 注入到環境中，讓所有子視圖都能存取
                .environmentObject(languageManager)
        }
    }
}
