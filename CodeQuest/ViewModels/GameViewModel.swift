import Foundation
import Combine

class GameViewModel: ObservableObject {
    private let dataService = GameDataService.shared
    
    private(set) var allQuestions: [QuizQuestion] = []
    
    @Published var quizQuestions: [QuizQuestion] = []
    @Published var questionRefreshID = UUID()
    
    var availableStages: Set<Int> {
        Set(allQuestions.flatMap { $0.stages })
    }
    
    private(set) var currentStage: Int = 1
    
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var lives: Int = 3
    private let maxLives = 3
    @Published var isGameOver: Bool = false
    @Published var isQuizComplete: Bool = false
    @Published var isHintVisible = false
    private(set) var wronglyAnsweredQuestions: [QuizQuestion] = []
    private var isReviewingWrongQuestions = false
    @Published var correctlyAnsweredCount: Int = 0
    @Published var comboCount: Int = 0
    @Published var maxComboAchieved: Int = 0

    var totalQuestions: Int {
        quizQuestions.count
    }
    
    var finalEvaluation: String {
        if isGameOver { return "F" }
        switch lives {
        case 3: return "S"
        case 2:
            if totalQuestions > 0 && Double(maxComboAchieved) > Double(totalQuestions) / 1.2 {
                return "A"
            } else {
                return "B"
            }
        case 1: return "C"
        default: return "F"
        }
    }
    
    var currentQuestion: QuizQuestion {
        if isReviewingWrongQuestions {
            guard let question = wronglyAnsweredQuestions.first else {
                return QuizQuestion(
                    questionID: 0, level: 0,
                    questionText: "所有題目已完成！",
                    imageName: nil, options: [],
                    correctAnswer: "", keyword: nil,
                    type: 0, stages: []
                )
            }
            return question
        } else {
            guard !quizQuestions.isEmpty, currentQuestionIndex < quizQuestions.count else {
                return QuizQuestion(
                    questionID: 0, level: 0,
                    questionText: "載入中...",
                    imageName: nil, options: [],
                    correctAnswer: "", keyword: nil,
                    type: 0, stages: []
                )
            }
            return quizQuestions[currentQuestionIndex]
        }
    }
    
    // === 背景圖用 ===
    var backgroundImageName: String {
        if currentStage == -1 { return "level1-1" } // 學習中心建立的自訂複習關
        guard currentStage > 0 else { return "level1-1" }
        let chapterSize = 21
        let chapterNumber = ((currentStage - 1) / chapterSize) + 1
        let stageInChapter = ((currentStage - 1) % chapterSize) + 1
        let mapIndex = ((stageInChapter - 1) % 5) + 1
        return "level\(chapterNumber)-\(mapIndex)"
    }
    
    // === 初始化 ===
    init(stage: Int = 1, customQuestions: [QuizQuestion]? = nil) {
        self.allQuestions = dataService.allQuestions
        
        if let questions = customQuestions {
            self.currentStage = -1   // -1 = 自訂複習模式
            self.quizQuestions = questions
            print("Starting CUSTOM REVIEW with \(questions.count) questions.")
            resetGameStates()
        } else if stage != 0 {
            startGame(stage: stage)
        }
    }
    
    convenience init() {
        self.init(stage: 0)
    }
    
    // === 開始新遊戲 ===
    func startGame(stage: Int) {
        self.currentStage = stage

        // 🔧 以章為單位計算（每章 21 關，章內重新從 1 計數）
        let stagesPerChapter = 21
        let chapterNumber = ((stage - 1) / stagesPerChapter) + 1
        let stageInChapter = ((stage - 1) % stagesPerChapter) + 1
        
        // 🔧 改為以「章內關卡」與 CSV 的 level 分流
        if stageInChapter == stagesPerChapter {
            // 🔴 最終關（第 21 關）：從本章 (level == chapterNumber) 題庫中取題
            let bossQuestions = allQuestions.filter { $0.level == chapterNumber }
            self.quizQuestions = Array(bossQuestions.shuffled().prefix(30))
            print("Starting BOSS stage \(stageInChapter) of Chapter \(chapterNumber) with \(self.quizQuestions.count) random Level \(chapterNumber) questions.")
        } else {
            // 一般/複習關題庫來源
            // 🔧 先按照「章 + 章內關卡」抓該關題目（一般關）
            var questionsForThisStage = allQuestions.filter {
                $0.level == chapterNumber && $0.stages.contains(stageInChapter)
            }
            
            if stageInChapter > 0 && stageInChapter % 5 == 0 {
                // 🔵 複習關（5,10,15,20）：從本章所有題目抽樣
                let reviewPool = allQuestions.filter { $0.level == chapterNumber }
                self.quizQuestions = Array(reviewPool.shuffled().prefix(15))
                print("Starting REVIEW stage \(stageInChapter) of Chapter \(chapterNumber) with \(self.quizQuestions.count) random Level \(chapterNumber) questions.")
            } else {
                // ⚪ 一般關（章內 1~4,6~9,11~14,16~19）
                self.quizQuestions = questionsForThisStage.shuffled()
                print("Starting stage \(stageInChapter) of Chapter \(chapterNumber) with \(self.quizQuestions.count) questions.")
            }
        }
        
        resetGameStates()
    }
    
    func restartGame() {
        if currentStage == -1 {
            resetGameStates()
        } else {
            startGame(stage: self.currentStage)
        }
    }
    
    private func resetGameStates() {
        score = 0
        lives = maxLives
        currentQuestionIndex = 0
        isGameOver = false
        isQuizComplete = false
        isHintVisible = false
        wronglyAnsweredQuestions = []
        isReviewingWrongQuestions = false
        correctlyAnsweredCount = 0
        comboCount = 0
        maxComboAchieved = 0
    }

    // === 遊戲流程 ===
    func showHint() { isHintVisible = true }
    
    func submitAnswer(_ answer: String) {
        let isCorrect = answer == currentQuestion.correctAnswer
        if isCorrect { handleCorrectAnswer() }
        else { handleWrongAnswer() }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.moveToNextState()
        }
    }
    
    private func handleCorrectAnswer() {
        score += 10
        correctlyAnsweredCount += 1
        comboCount += 1
        if comboCount > maxComboAchieved { maxComboAchieved = comboCount }
        if isReviewingWrongQuestions { wronglyAnsweredQuestions.removeFirst() }
    }
    
    private func handleWrongAnswer() {
        loseLife()
        comboCount = 0
        dataService.addWrongQuestion(id: currentQuestion.questionID)
        
        guard !isGameOver else { return }
        
        if isReviewingWrongQuestions {
            let question = wronglyAnsweredQuestions.removeFirst()
            wronglyAnsweredQuestions.append(question)
        } else {
            if !wronglyAnsweredQuestions.contains(where: { $0.id == currentQuestion.id }) {
                wronglyAnsweredQuestions.append(currentQuestion)
            }
        }
    }
    
    private func moveToNextState() {
        guard !isGameOver else {
            saveGameResult()
            return
        }
        isHintVisible = false
        defer { questionRefreshID = UUID() }

        if isReviewingWrongQuestions {
            if wronglyAnsweredQuestions.isEmpty {
                isQuizComplete = true
                saveGameResult()
            } else {
                objectWillChange.send()
            }
        } else {
            if currentQuestionIndex < quizQuestions.count - 1 {
                currentQuestionIndex += 1
            } else {
                isReviewingWrongQuestions = true
                if wronglyAnsweredQuestions.isEmpty {
                    isQuizComplete = true
                    saveGameResult()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.isQuizComplete = true
                    }
                } else {
                    objectWillChange.send()
                }
            }
        }
    }
    
    private func loseLife() {
        if lives > 0 { lives -= 1 }
        if lives == 0 { isGameOver = true }
    }
    
    private func saveGameResult() {
        guard currentStage > 0 else { return }
        
        let result = StageResult(
            evaluation: self.finalEvaluation,
            maxCombo: self.maxComboAchieved,
            correctlyAnswered: self.correctlyAnsweredCount,
            totalQuestions: self.totalQuestions
        )
        dataService.updateStageResult(stage: self.currentStage, newResult: result)
    }
}
