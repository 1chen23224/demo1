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
            guard cols.count > 12 else { return nil }

            let questionText = cols[2]
            let imageName = cols[3]
            

            let stageString = cols[12].trimmingCharacters(in: .whitespacesAndNewlines)
            let stage = Int(stageString) ?? 0
            let optionA = cols[4], optionB = cols[5], optionC = cols[6], optionD = cols[7]
            let correctAnswer = cols[8]
            let keyword = cols[10]

            let options = [optionA, optionB, optionC, optionD].shuffled()

            return QuizQuestion(
                questionID: Int(cols[0]) ?? 0,
                level: Int(cols[1]) ?? 0,
                questionText: questionText,
                imageName: imageName.isEmpty ? nil : imageName,
                options: options,
                correctAnswer: correctAnswer,
                keyword: keyword.isEmpty ? nil : keyword,
                type: Int(cols[11]) ?? 0,
                stage: stage   // ✅ 已經改成單一 stage
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
    }
    
    private func notifyUI() {
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
}

// ======================================================
// MARK: - StageType 判斷
// ======================================================

enum StageType {
    case normal(Int)   // 普通關（帶章內序號）
    case review        // 複習關
    case boss          // 最終關
}

extension GameDataService {
    func stageType(for stageNumber: Int) -> StageType {
        let (chapter, stageInChapter) = chapterAndStageInChapter(for: stageNumber)
        let total = stagesInChapter(chapter)
        
        // Boss：章內最後一關
        if stageInChapter == total {
            return .boss
        }
        
        // 複習：大約每 20–25% 出現一次
        let reviewInterval = max(4, total / 5) // 20% (例如15關 → 每3關，但保底4避免太頻繁)
        if stageInChapter % (reviewInterval + 1) == 0 {
            return .review
        }
        
        // 其餘是普通
        return .normal(stageInChapter)
    }
}
