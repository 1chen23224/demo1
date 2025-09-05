import Foundation

struct StageResult: Codable {
    var evaluation: String
    var maxCombo: Int
    var correctlyAnswered: Int
    var totalQuestions: Int
}

// ======================================================
// MARK: - GameDataService
// ======================================================

class GameDataService: ObservableObject {
    
    // ✅ ADD THIS NEW FUNCTION
    func markTutorialAsSeen() {
        guard !hasSeenTutorial else { return } // If already seen, do nothing
        hasSeenTutorial = true
        saveData()
        print("👍 Tutorial has been marked as seen and saved.")
    }
    static let shared = GameDataService()
    
    private(set) var allQuestions: [QuizQuestion] = []
    
    @Published var highestUnlockedChapter: Int
    @Published var highestUnlockedStage: Int
    @Published var stageResults: [Int: StageResult]
    @Published var wrongQuestionIDs: Set<Int>
    @Published var hasSeenTutorial: Bool   // ✅ 新增
    
    
    private let chapterKey = "gameData_highestUnlockedChapter"
    private let unlockedStageKey = "gameData_highestUnlockedStage"
    private let resultsKey = "gameData_stageResults"
    private let wrongQuestionsKey = "gameData_wrongQuestionIDs"
    private let tutorialKey = "gameData_hasSeenTutorial"   // ✅ 新增
    
    
    // ✨ 每章的關卡數，可自由修改
    let chapterStageCounts: [Int] = [21, 12, 19, 16, 15]

    private init() {
        let savedChapter = UserDefaults.standard.integer(forKey: chapterKey)
        self.highestUnlockedChapter = (savedChapter == 0) ? 1 : savedChapter
        
        let savedStage = UserDefaults.standard.integer(forKey: unlockedStageKey)
        self.highestUnlockedStage = (savedStage == 0) ? 1 : savedStage

        if let data = UserDefaults.standard.data(forKey: resultsKey),
           let decodedResults = try? JSONDecoder().decode([Int: StageResult].self, from: data) {
            self.stageResults = decodedResults
        } else {
            self.stageResults = [:]
        }
        
        if let data = UserDefaults.standard.data(forKey: wrongQuestionsKey),
           let decodedIDs = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            self.wrongQuestionIDs = decodedIDs
        } else {
            self.wrongQuestionIDs = []
        }
        self.hasSeenTutorial = UserDefaults.standard.bool(forKey: tutorialKey)  // ✅ 預設 false

        loadAllQuestionsFromCSV()
    }

    // ======================================================
    // MARK: - 載入 CSV 題庫
    // ======================================================
    private func loadAllQuestionsFromCSV() {
        guard let path = Bundle.main.path(forResource: "questions", ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("❌ 找不到或無法讀取 questions.csv")
            return
        }
        let rows = content.components(separatedBy: .newlines).dropFirst().filter { !$0.isEmpty }
        self.allQuestions = rows.compactMap { row -> QuizQuestion? in
            let cols = row.components(separatedBy: ",")
            // ✅ 確保 CSV 至少有 29 欄 (索引到 28)，以支援簡體中文
            guard cols.count > 28 else { return nil }

            // --- 中文資料 ---
            let questionText_zh = cols[2]
            let options_zh = [cols[4], cols[5], cols[6], cols[7]]
            let correctAnswer_zh = cols[8]
            
            // --- 英文資料 ---
            let questionText_en = cols[11]
            let options_en = [cols[12], cols[13], cols[14], cols[15]]
            let correctAnswer_en = cols[16]

            // --- 葡文資料 ---
            let questionText_pt = cols[17]
            let options_pt = [cols[18], cols[19], cols[20], cols[21]]
            let correctAnswer_pt = cols[22]

            // --- 簡體中文資料 (新增) ---
            let questionText_zh_hans = cols[23]
            let options_zh_hans = [cols[24], cols[25], cols[26], cols[27]]
            let correctAnswer_zh_hans = cols[28] // 假設答案在欄位 28

            // --- 通用資料 ---
            let imageName = cols[3]
            let stageString = cols[10].trimmingCharacters(in: .whitespacesAndNewlines)
            let stage = Int(stageString) ?? 0

            return QuizQuestion(
                questionID: Int(cols[0]) ?? 0,
                level: Int(cols[1]) ?? 0,
                imageName: imageName.isEmpty ? nil : imageName,
                stage: stage,
                // ✅ 填充新的多語言 Dictionary
                questionText: [
                    "zh-Hant": questionText_zh,
                    "en": questionText_en,
                    "pt-PT": questionText_pt,
                    "zh-Hans": questionText_zh_hans // 新增簡體中文
                ],
                options: [
                    "zh-Hant": options_zh,
                    "en": options_en,
                    "pt-PT": options_pt,
                    "zh-Hans": options_zh_hans // 新增簡體中文
                ],
                correctAnswer: [
                    "zh-Hant": correctAnswer_zh,
                    "en": correctAnswer_en,
                    "pt-PT": correctAnswer_pt,
                    "zh-Hans": correctAnswer_zh_hans // 新增簡體中文
                ]
            )
        }
    }
    // ======================================================
    // MARK: - 關卡工具
    // ======================================================
    func stagesInChapter(_ chapter: Int) -> Int {
        guard chapter > 0 && chapter <= chapterStageCounts.count else { return 0 }
        return chapterStageCounts[chapter - 1]
    }

    func chapterAndStageInChapter(for stage: Int) -> (chapter: Int, stageInChapter: Int) {
        var total = 0
        for (i, count) in chapterStageCounts.enumerated() {
            let start = total + 1
            let end = total + count
            if stage >= start && stage <= end {
                return (i + 1, stage - total)
            }
            total += count
        }
        return (1, stage)
    }
    
    // ======================================================
    // MARK: - Public Methods
    // ======================================================
    func getResult(for stage: Int) -> StageResult? {
        return stageResults[stage]
    }
    
    func isChapterUnlocked(_ chapter: Int) -> Bool {
        return chapter <= highestUnlockedChapter
    }
    
    func isStageUnlocked(_ stage: Int) -> Bool {
        return stage <= highestUnlockedStage
    }
    
    func addWrongQuestion(id: Int) {
        wrongQuestionIDs.insert(id)
        saveData()
        print("📝 錯題本增加了題目 ID: \(id)。目前總錯題數: \(wrongQuestionIDs.count)")
    }

    func clearWrongQuestions() {
        wrongQuestionIDs.removeAll()
        saveData()
    }
    
    func updateStageResult(stage: Int, newResult: StageResult) {
        let oldResult = getResult(for: stage)
        let oldRankValue = rankValue(for: oldResult?.evaluation ?? "")
        let newRankValue = rankValue(for: newResult.evaluation)
        
        if newRankValue < oldRankValue {
            stageResults[stage] = newResult
        }
        
        if stage == highestUnlockedStage && newResult.evaluation != "F" {
            let totalStages = chapterStageCounts.reduce(0, +)
            if highestUnlockedStage < totalStages { highestUnlockedStage += 1 }
            
            let (chapter, stageInChapter) = chapterAndStageInChapter(for: stage)
            if stageInChapter == stagesInChapter(chapter) {
                if highestUnlockedChapter < chapterStageCounts.count {
                    highestUnlockedChapter += 1
                }
            }
        }
        
        saveData()
        notifyUI()
    }

    // ======================================================
    // MARK: - Debug 工具
    // ======================================================
    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: chapterKey)
        UserDefaults.standard.removeObject(forKey: unlockedStageKey)
        UserDefaults.standard.removeObject(forKey: resultsKey)
        UserDefaults.standard.removeObject(forKey: wrongQuestionsKey)
        self.highestUnlockedChapter = 1
        self.highestUnlockedStage = 1
        self.stageResults = [:]
        self.wrongQuestionIDs = []
        saveData()
        notifyUI()
        print("✅ 玩家進度已重置！")
    }
    /// 清除所有儲存在 UserDefaults 的玩家資料，並重置 App 狀態回到初始狀態。
    func resetAllData() {
        // 1. 取得所有 UserDefaults 的 keys
        let dictionary = UserDefaults.standard.dictionaryRepresentation()
        
        // 2. 遍歷所有 keys，移除跟我們 App 相關的資料
        //    這樣做的好處是，未來即使新增了儲存項目，也不用回來修改這個函式。
        dictionary.keys.forEach { key in
            // 根據您 App 的儲存鍵，移除相關資料
            // 以下是一些您可能用到的 key，您可以自行增減
            if key == "highestUnlockedChapter" ||
               key == "highestUnlockedStage" ||
               key == "stageResults" ||
               key == "hasSeenTutorial" {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        // 3. 🛑 最關鍵的一步：
        //    手動將記憶體中的 @Published 變數重置為初始值。
        //    這會立即觸發 SwiftUI 的畫面更新，讓玩家感覺 App 瞬間回到了全新狀態。
        DispatchQueue.main.async {
            // 假設初始值為第一章、第一關
            self.highestUnlockedChapter = 1
            self.highestUnlockedStage = 1
            
            // 假設 stageResults 是一個儲存成績的字典
            // self.stageResults = [:] // 如果您有這個屬性，請取消註解
            
            // 假設 hasSeenTutorial 是一個布林值
            // self.hasSeenTutorial = false // 如果您有這個屬性，請取消註解
            
            // 強制發布變更，確保所有訂閱此物件的 View 都會刷新
            self.objectWillChange.send()
        }
    }
    func unlockAllStages() {
        var stageIndex = 1
        for (_, chapterSize) in chapterStageCounts.enumerated() {
            for stageInChapter in 1...chapterSize {
                if stageInChapter != chapterSize {
                    let dummyResult = StageResult(evaluation: "S", maxCombo: 10, correctlyAnswered: 10, totalQuestions: 10)
                    stageResults[stageIndex] = dummyResult
                }
                stageIndex += 1
            }
        }
        highestUnlockedChapter = chapterStageCounts.count
        highestUnlockedStage = chapterStageCounts.reduce(0, +)
        saveData()
        notifyUI()
    }

    // ======================================================
    // MARK: - Private
    // ======================================================
    private func rankValue(for evaluation: String) -> Int {
        switch evaluation {
        case "S": return 0
        case "A": return 1
        case "B": return 2
        case "C": return 3
        case "F": return 4
        default: return 99
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(highestUnlockedChapter, forKey: chapterKey)
        UserDefaults.standard.set(highestUnlockedStage, forKey: unlockedStageKey)
        if let data = try? JSONEncoder().encode(stageResults) {
            UserDefaults.standard.set(data, forKey: resultsKey)
        }
        if let data = try? JSONEncoder().encode(wrongQuestionIDs) {
            UserDefaults.standard.set(data, forKey: wrongQuestionsKey)
        }
        UserDefaults.standard.set(self.hasSeenTutorial, forKey: tutorialKey)
    }
    
    private func notifyUI() {
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
}

// ======================================================
// MARK: - StageType 判斷
// ======================================================

enum StageType {
    case normal
    case review
    case boss
}

extension GameDataService {
    func getStageType(for stageNumber: Int) -> StageType {
        let (chapter, stageInChapter) = chapterAndStageInChapter(for: stageNumber)
        let chapterSize = stagesInChapter(chapter)
        
        // 1. 判斷是否為 Boss 關
        if stageInChapter == chapterSize {
            return .boss
        }
        
        // 2. 使用 GameViewModel 中的判斷邏輯來判斷複習關
        // 這是你目前實際使用的邏輯，我們把它統一到這裡
        let reviewCount = max(1, chapterSize / 6)
        guard reviewCount > 0 else { return .normal } // 如果章節太小，沒有複習關
        
        let interval = chapterSize / (reviewCount + 1)
        let reviewStages = Set((1...reviewCount).map { $0 * interval })
        
        if reviewStages.contains(stageInChapter) {
            return .review
        }
        
        // 3. 都不是，就是普通關
        return .normal
    }
}
