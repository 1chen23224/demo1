import Foundation

// 用於儲存單一關卡結果的結構
struct StageResult: Codable {
    var evaluation: String
    var maxCombo: Int
    var correctlyAnswered: Int
    var totalQuestions: Int
}

// 負責儲存和讀取所有遊戲進度的管家
class GameDataService: ObservableObject {
    static let shared = GameDataService() // Singleton，讓 App 中永遠只有一個實例
    
    // MARK: - Published Properties
    @Published var highestUnlockedChapter: Int
    @Published var highestUnlockedStage: Int
    @Published var stageResults: [Int: StageResult]
    
    // MARK: - UserDefaults Keys
    private let chapterKey = "gameData_highestUnlockedChapter"
    private let unlockedStageKey = "gameData_highestUnlockedStage"
    private let resultsKey = "gameData_stageResults"

    // MARK: - Initialization
    private init() {
        // 讀取已解鎖的章節，預設為第 1 章
        let savedChapter = UserDefaults.standard.integer(forKey: chapterKey)
        self.highestUnlockedChapter = (savedChapter == 0) ? 1 : savedChapter
        
        // 讀取已解鎖的關卡，預設為第 1 關
        let savedStage = UserDefaults.standard.integer(forKey: unlockedStageKey)
        self.highestUnlockedStage = (savedStage == 0) ? 1 : savedStage

        // 讀取已儲存的關卡紀錄
        if let data = UserDefaults.standard.data(forKey: resultsKey),
           let decodedResults = try? JSONDecoder().decode([Int: StageResult].self, from: data) {
            self.stageResults = decodedResults
        } else {
            self.stageResults = [:]
        }
    }
    
    // MARK: - Public Methods
    func getResult(for stage: Int) -> StageResult? {
        return stageResults[stage]
    }
    
    func isChapterUnlocked(_ chapter: Int) -> Bool {
        return chapter <= highestUnlockedChapter
    }
    
    func isStageUnlocked(_ stage: Int) -> Bool {
        return stage <= highestUnlockedStage
    }
    
    func updateStageResult(stage: Int, newResult: StageResult) {
        let oldResult = getResult(for: stage)
        let oldRankValue = rankValue(for: oldResult?.evaluation ?? "")
        let newRankValue = rankValue(for: newResult.evaluation)
        
        // 只有在新成績的評價更好時(S < A < B ...)，或首次通關時，才更新紀錄
        if newRankValue < oldRankValue {
            stageResults[stage] = newResult
        }
        
        // --- 解鎖邏輯 ---
        // 只有在成功通關了「當前最新」的關卡時，才嘗試解鎖
        if stage == highestUnlockedStage && newResult.evaluation != "F" {
            let totalChapters = 5
            let stagesPerChapter = 21 // 20 普通/複習關 + 1 魔王關
            
            // 解鎖下一關
            if highestUnlockedStage < (stagesPerChapter * totalChapters) {
                highestUnlockedStage += 1
            }
            
            // 檢查是否剛好完成一章的最後一關 (魔王關)
            if stage % stagesPerChapter == 0 {
                // 解鎖下一章
                if highestUnlockedChapter < totalChapters {
                    highestUnlockedChapter += 1
                }
            }
        }
        
        saveData()
        notifyUI()
    }

    // MARK: - Debug/Developer Methods
    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: chapterKey)
        UserDefaults.standard.removeObject(forKey: unlockedStageKey)
        UserDefaults.standard.removeObject(forKey: resultsKey)
        
        self.highestUnlockedChapter = 1
        self.highestUnlockedStage = 1
        self.stageResults = [:]
        
        saveData()
        notifyUI()
        print("✅ 玩家進度已重置！")
    }

    func unlockAllStages() {
        print("🔓 捷徑：解鎖所有關卡和章節...")
        let totalChapters = 5
        let stagesPerChapter = 21
        
        for i in 1...(totalChapters * stagesPerChapter) {
            // 只為非魔王關填上假成績
            if i % stagesPerChapter != 0 {
                let dummyResult = StageResult(evaluation: "S", maxCombo: 10, correctlyAnswered: 10, totalQuestions: 10)
                stageResults[i] = dummyResult
            }
        }
        
        highestUnlockedChapter = 5
        highestUnlockedStage = 105 // (5 * 21)
        
        saveData()
        notifyUI()
    }

    // MARK: - Private Helpers
    private func rankValue(for evaluation: String) -> Int {
        switch evaluation {
        case "S": return 0
        case "A": return 1
        case "B": return 2
        case "C": return 3
        case "F": return 4
        default: return 99 // 代表尚未有紀錄
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(highestUnlockedChapter, forKey: chapterKey)
        UserDefaults.standard.set(highestUnlockedStage, forKey: unlockedStageKey)
        if let data = try? JSONEncoder().encode(stageResults) {
            UserDefaults.standard.set(data, forKey: resultsKey)
        }
    }
    
    private func notifyUI() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}
