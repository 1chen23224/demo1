import Foundation
import SwiftUI

extension UIApplication {
    /// 取得第一個 keyWindow
    var firstKeyWindow: UIWindow? {
        return self.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

func restartApp() {
    guard let window = UIApplication.shared.firstKeyWindow else { return }
    let rootView = ContentView() // 🚀 你的 App 主入口 View
        .environmentObject(LanguageManager.shared)

    // 切換 rootViewController，達到「偽重啟」效果
    window.rootViewController = UIHostingController(rootView: rootView)
    window.makeKeyAndVisible()
}
// MARK: - Language Manager (ObservableObject)
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    // ✅ 步驟 1: 定義一個內部結構來同時儲存語言代碼和顯示名稱
    // 讓它符合 Identifiable，這樣在 ForEach 中使用更方便
    struct Language: Identifiable {
        let id: String // 使用 code 作為唯一標識符
        let code: String
        let name: String
    }

    // ✅ 步驟 2: 建立一個公開的、可供 View 使用的語言列表
    let availableLanguages: [Language] = [
        Language(id: "zh-Hant", code: "zh-Hant", name: "繁體中文"),
        Language(id: "zh-Hans", code: "zh-Hans", name: "简体中文"),
        Language(id: "en", code: "en", name: "English"),
        Language(id: "pt-PT", code: "pt-PT", name: "Português (Portugal)")
    ]

    // @Published 會在數值改變時通知所有 SwiftUI 視圖更新
    @Published var currentLanguage: String {
        didSet {
            // 將新的語言設定儲存到 UserDefaults
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    private init() {
        // 從 UserDefaults 讀取儲存的語言，如果沒有，則使用設備的預設語言
        if let savedLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages"),
           let firstLanguage = savedLanguages.first {
            // 我們只關心我們支援的語言
            // 使用 a flatMap a .map to get just the codes
            let supportedLanguageCodes = availableLanguages.map { $0.code }
            if supportedLanguageCodes.contains(firstLanguage) {
                self.currentLanguage = firstLanguage
            } else {
                self.currentLanguage = "zh-Hant" // 如果儲存的是不支援的語言，預設為繁中
            }
        } else {
            // 如果完全沒有儲存過，預設為繁中
            self.currentLanguage = "zh-Hant"
        }
    }

    // ✅ 步驟 3: 建立一個直接設定語言的新函式
    // 這個函式將被彈出視窗中的按鈕呼叫
    func changeLanguage(to languageCode: String) {
        if availableLanguages.contains(where: { $0.code == languageCode }) {
            currentLanguage = languageCode
            restartApp()
        }
    }
    
}

// MARK: - String Extension for easy localization
extension String {
    // 讓 "your_key".localized() 可以直接取得翻譯後的文字
    func localized() -> String {
        // 從 UserDefaults 讀取當前語言設定
        guard let languageCode = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first,
              let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            // 如果找不到，就用預設的本地化方法
            return NSLocalizedString(self, comment: "")
        }
        // 從指定語言的 Bundle 中尋找翻譯
        return NSLocalizedString(self, tableName: nil, bundle: bundle, comment: "")
    }
}

// MARK: - LocalizedText View Wrapper
// 這個 View 會自動響應 LanguageManager 的變化
struct LocalizedText: View {
    @EnvironmentObject var languageManager: LanguageManager
    let key: String

    var body: some View {
        // .id(languageManager.currentLanguage) 是關鍵
        // 它告訴 SwiftUI 當語言改變時，這個 Text 是一個全新的 View，需要重新渲染
        Text(key.localized())
            .id(languageManager.currentLanguage)
    }
}
