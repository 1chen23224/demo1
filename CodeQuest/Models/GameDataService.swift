import Foundation

struct StageResult: Codable {
    var evaluation: String
    var maxCombo: Int
    var correctlyAnswered: Int
    var totalQuestions: Int
}

class GameDataService: ObservableObject {
    static let shared = GameDataService()
    
    // ✨ [新增] 存放所有從 CSV 讀取的題目
    private(set) var allQuestions: [QuizQuestion] = []
    
    @Published var highestUnlockedChapter: Int
    @Published var highestUnlockedStage: Int
    @Published var stageResults: [Int: StageResult]
    @Published var wrongQuestionIDs: Set<Int>

    private let chapterKey = "gameData_highestUnlockedChapter"
    private let unlockedStageKey = "gameData_highestUnlockedStage"
    private let resultsKey = "gameData_stageResults"
    private let wrongQuestionsKey = "gameData_wrongQuestionIDs"

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
        // ✨ [新增] 在初始化時就先載入所有題目
        loadAllQuestionsFromCSV()
    }
    // ✨ [新增] 將 loadAllQuestionsFromCSV 函式搬到這裡
    private func loadAllQuestionsFromCSV() {
        guard let path = Bundle.main.path(forResource: "questions", ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("❌ 找不到或無法讀取 questions.csv")
            return
        }
        let rows = content.components(separatedBy: .newlines).dropFirst().filter { !$0.isEmpty }
        self.allQuestions = rows.compactMap { row in
            let cols = row.components(separatedBy: ",")
            guard cols.count >= 13 else { return nil }
            var stageString = cols[12]
            if stageString.hasPrefix("\"") && stageString.hasSuffix("\"") { stageString = String(stageString.dropFirst().dropLast()) }
            let stages: [Int] = stageString.split(separator: ";").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            let questionText = cols[2], imageName = cols[3], optionA = cols[4], optionB = cols[5], optionC = cols[6], optionD = cols[7], correctAnswer = cols[8], keyword = cols[10]
            let options = [optionA, optionB, optionC, optionD].shuffled()
            return QuizQuestion(questionID: Int(cols[0]) ?? 0, level: Int(cols[1]) ?? 0, questionText: questionText, imageName: imageName.isEmpty ? nil : imageName, options: options, correctAnswer: correctAnswer, keyword: keyword.isEmpty ? nil : keyword, type: Int(cols[11]) ?? 0, stages: stages)
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
    
    // ✨ [修正] 將這兩個函式移到 init() 的外面
    func addWrongQuestion(id: Int) {
        wrongQuestionIDs.insert(id)
        saveData()
        print("📝 錯題本增加了題目 ID: \(id)。目前總錯題數: \(wrongQuestionIDs.count)")
    }

    func clearWrongQuestions() {
        wrongQuestionIDs.removeAll()
        saveData()   // 確保同步到 UserDefaults
    }
    
    func updateStageResult(stage: Int, newResult: StageResult) {
        let oldResult = getResult(for: stage)
        let oldRankValue = rankValue(for: oldResult?.evaluation ?? "")
        let newRankValue = rankValue(for: newResult.evaluation)
        
        if newRankValue < oldRankValue {
            stageResults[stage] = newResult
        }
        
        if stage == highestUnlockedStage && newResult.evaluation != "F" {
            let totalChapters = 5
            let stagesPerChapter = 21
            if highestUnlockedStage < (stagesPerChapter * totalChapters) { highestUnlockedStage += 1 }
            if stage % stagesPerChapter == 0 {
                if highestUnlockedChapter < totalChapters { highestUnlockedChapter += 1 }
            }
        }
        
        saveData()
        notifyUI()
    }

    // MARK: - Debug/Developer Methods
    func resetProgress() {
        UserDefaults.standard.removeObject(forKey: chapterKey); UserDefaults.standard.removeObject(forKey: unlockedStageKey); UserDefaults.standard.removeObject(forKey: resultsKey); UserDefaults.standard.removeObject(forKey: wrongQuestionsKey)
        self.highestUnlockedChapter = 1; self.highestUnlockedStage = 1; self.stageResults = [:]; self.wrongQuestionIDs = []
        saveData(); notifyUI(); print("✅ 玩家進度已重置！")
    }

    func unlockAllStages() {
        let totalChapters = 5; let stagesPerChapter = 21
        for i in 1...(totalChapters * stagesPerChapter) {
            if i % stagesPerChapter != 0 {
                let dummyResult = StageResult(evaluation: "S", maxCombo: 10, correctlyAnswered: 10, totalQuestions: 10); stageResults[i] = dummyResult
            }
        }
        highestUnlockedChapter = 5; highestUnlockedStage = 105
        saveData(); notifyUI()
    }

    // MARK: - Private Helpers
    private func rankValue(for evaluation: String) -> Int {
        switch evaluation {
        case "S": return 0; case "A": return 1; case "B": return 2
        case "C": return 3; case "F": return 4; default: return 99
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(highestUnlockedChapter, forKey: chapterKey)
        UserDefaults.standard.set(highestUnlockedStage, forKey: unlockedStageKey)
        if let data = try? JSONEncoder().encode(stageResults) { UserDefaults.standard.set(data, forKey: resultsKey) }
        if let data = try? JSONEncoder().encode(wrongQuestionIDs) { UserDefaults.standard.set(data, forKey: wrongQuestionsKey) }
    }
    
    private func notifyUI() { DispatchQueue.main.async { self.objectWillChange.send() } }
}
