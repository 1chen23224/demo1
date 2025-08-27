import Foundation
import Combine

// ✨ 關卡佈局管理器
struct ChapterLayout {
    static let chapterSizes: [Int: Int] = [
        1: 21,
        2: 12,
        3: 19,
        4: 16,
        5: 15
    ]
    
    static func getStageCount(for chapter: Int) -> Int {
        return chapterSizes[chapter, default: 0]
    }
    
    static func isBossStage(chapter: Int, stageInChapter: Int) -> Bool {
        return stageInChapter == getStageCount(for: chapter)
    }
    
    static func isReviewStage(chapter: Int, stageInChapter: Int) -> Bool {
        guard !isBossStage(chapter: chapter, stageInChapter: stageInChapter) else { return false }
        let totalStages = getStageCount(for: chapter)
        let numberOfReviewStages = Int((Double(totalStages) * 0.25).rounded())
        guard numberOfReviewStages > 0 else { return false }
        let interval = Double(totalStages) / Double(numberOfReviewStages + 1)
        for i in 1...numberOfReviewStages {
            let reviewStagePosition = (interval * Double(i)).rounded()
            if Int(reviewStagePosition) == stageInChapter {
                return true
            }
        }
        return false
    }
}

class GameViewModel: ObservableObject {
    private let dataService = GameDataService.shared
    private(set) var allQuestions: [QuizQuestion] = []
    
    @Published var quizQuestions: [QuizQuestion] = []
    @Published var questionRefreshID = UUID()
    
    var availableStages: Set<Int> {
        Set(allQuestions.map { $0.stage })
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

    var totalQuestions: Int { quizQuestions.count }
    
    var finalEvaluation: String {
        if isGameOver { return "F" }
        switch lives {
        case 3: return "S"
        case 2: return (totalQuestions > 0 && Double(maxComboAchieved) > Double(totalQuestions) / 1.2) ? "A" : "B"
        case 1: return "C"
        default: return "F"
        }
    }
    
    var currentQuestion: QuizQuestion {
        if isReviewingWrongQuestions {
            return wronglyAnsweredQuestions.first ?? QuizQuestion(
                questionID: 0, level: 0,
                questionText: "所有題目已完成！",
                imageName: nil, options: [], correctAnswer: "",
                keyword: nil, type: 0, stage:0
            )
        } else {
            guard !quizQuestions.isEmpty, currentQuestionIndex < quizQuestions.count else {
                return QuizQuestion(
                    questionID: 0, level: 0,
                    questionText: "載入中...",
                    imageName: nil, options: [], correctAnswer: "",
                    keyword: nil, type: 0, stage: 0
            )
            }
            return quizQuestions[currentQuestionIndex]
        }
    }
    
    // === 背景圖用 ===
    var backgroundImageName: String {
        if currentStage == -1 { return "level1-1" }
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
            self.currentStage = -1
            self.quizQuestions = questions
            print("Starting CUSTOM REVIEW with \(questions.count) questions.")
            resetGameStates()
        } else if stage != 0 {
            startGame(stage: stage)
        }
    }
    
    convenience init() { self.init(stage: 0) }
    
    func startGame(stage: Int) {
        self.currentStage = stage
        let (chapterNumber, stageInChapter) = dataService.chapterAndStageInChapter(for: stage)
        let chapterSize = dataService.stagesInChapter(chapterNumber)
        
        let reviewCount = max(1, chapterSize / 6)
        let interval = chapterSize / (reviewCount + 1)
        let reviewStages = Set((1...reviewCount).map { $0 * interval })
        
        if stageInChapter == chapterSize {
            // Boss
            let bossQuestions = allQuestions.filter { $0.level == chapterNumber }
            self.quizQuestions = Array(bossQuestions.shuffled().prefix(30))
        } else if reviewStages.contains(stageInChapter) {
            // Review
            let questions = allQuestions.filter { $0.level == chapterNumber }
            self.quizQuestions = Array(questions.shuffled().prefix(15))
        } else {
            // Normal
            let questionsForThisStage = allQuestions.filter {
                $0.level == chapterNumber && $0.stage == stageInChapter   // ✅ 改成單一 stage
            }
            self.quizQuestions = questionsForThisStage.shuffled()
        }
        
        resetGameStates()
    }
    
    func restartGame() {
        if currentStage == -1 { resetGameStates() }
        else { startGame(stage: self.currentStage) }
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
