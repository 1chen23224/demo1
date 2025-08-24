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
        case 3:
            return "S"
        case 2:
            if totalQuestions > 0 && Double(maxComboAchieved) > Double(totalQuestions) / 1.2 {
                return "A"
            } else {
                return "B"
            }
        case 1:
            return "C"
        default:
            return "F"
        }
    }
    
    var currentQuestion: QuizQuestion {
        if isReviewingWrongQuestions {
            guard let question = wronglyAnsweredQuestions.first else {
                return QuizQuestion(questionID: 0, level: 0, questionText: "所有題目已完成！", imageName: nil, options: [], correctAnswer: "", keyword: nil, type: 0, stages: [])
            }
            return question
        } else {
            guard !quizQuestions.isEmpty, currentQuestionIndex < quizQuestions.count else {
                return QuizQuestion(questionID: 0, level: 0, questionText: "載入中...", imageName: nil, options: [], correctAnswer: "", keyword: nil, type: 0, stages: [])
            }
            return quizQuestions[currentQuestionIndex]
        }
    }
    
    init(stage: Int = 1) {
        loadAllQuestionsFromCSV()
        if stage != 0 {
             startGame(stage: stage)
        }
    }
    
    convenience init() {
        self.init(stage: 0)
    }
    
    // ✨ [主要修改處]
    func startGame(stage: Int) {
        self.currentStage = stage
        
        // 判斷是否為魔王關
        if stage == 21 {
            // 是魔王關：篩選出 Level 為 1 的所有題目，洗牌後取前 30 題
            let bossQuestions = allQuestions.filter { $0.level == 1 }
            self.quizQuestions = Array(bossQuestions.shuffled().prefix(30))
            print("Starting BOSS stage 21 with \(self.quizQuestions.count) random Level 1 questions.")
            
        } else {
            // 是普通關或複習關
            let questionsForThisStage = allQuestions.filter { $0.stages.contains(stage) }

            if stage > 0 && stage % 5 == 0 {
                // 複習關
                self.quizQuestions = Array(questionsForThisStage.shuffled().prefix(15))
                print("Starting REVIEW stage \(stage) with \(self.quizQuestions.count) random questions.")
            } else {
                // 普通關
                self.quizQuestions = questionsForThisStage.shuffled()
                print("Starting stage \(stage) with \(self.quizQuestions.count) questions.")
            }
        }
        
        resetGameStates()
    }
    
    func restartGame() {
        startGame(stage: self.currentStage)
    }
    
    private func resetGameStates() {
        score = 0; lives = maxLives; currentQuestionIndex = 0; isGameOver = false; isQuizComplete = false; isHintVisible = false; wronglyAnsweredQuestions = []; isReviewingWrongQuestions = false; correctlyAnsweredCount = 0; comboCount = 0; maxComboAchieved = 0;
    }
    
    private func loadAllQuestionsFromCSV() {
        guard let path = Bundle.main.path(forResource: "questions", ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("❌ 找不到或無法讀取 questions.csv")
            return
        }
        
        let rows = content.components(separatedBy: .newlines).dropFirst().filter { !$0.isEmpty }
        
        self.allQuestions = rows.compactMap { row in
            let cols = row.components(separatedBy: ",")
            guard cols.count >= 13 else {
                print("⚠️ 警告：CSV 行欄位數不足，跳過此行: \(row)")
                return nil
            }
            
            // ✨ [主要修改處] 在這裡修正 stages 的解析邏輯
            
            let questionText = cols[2]
            let imageName = cols[3]
            let optionA = cols[4]
            let optionB = cols[5]
            let optionC = cols[6]
            let optionD = cols[7]
            let correctAnswer = cols[8]
            let keyword = cols[10]
            
            // 1. 先取得原始的 stage 字串
            var stageString = cols[12]
            
            // 2. 檢查並移除頭尾的雙引號
            if stageString.hasPrefix("\"") && stageString.hasSuffix("\"") {
                stageString = String(stageString.dropFirst().dropLast())
            }
            
            // 3. 再進行分割和轉換
            let stages: [Int] = stageString.split(separator: ";").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            
            let options = [optionA, optionB, optionC, optionD].shuffled()

            return QuizQuestion(
                questionID: Int(cols[0]) ?? 0, level: Int(cols[1]) ?? 0, questionText: questionText,
                imageName: imageName.isEmpty ? nil : imageName, options: options, correctAnswer: correctAnswer,
                keyword: keyword.isEmpty ? nil : keyword, type: Int(cols[11]) ?? 0, stages: stages
            )
        }
    }

    
    func showHint() { isHintVisible = true }
    func submitAnswer(_ answer: String) { let isCorrect = answer == currentQuestion.correctAnswer; if isCorrect { handleCorrectAnswer() } else { handleWrongAnswer() }; DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.moveToNextState() } }
    private func handleCorrectAnswer() { score += 10; correctlyAnsweredCount += 1; comboCount += 1; if comboCount > maxComboAchieved { maxComboAchieved = comboCount }; if isReviewingWrongQuestions { wronglyAnsweredQuestions.removeFirst() } }
    private func handleWrongAnswer() { loseLife(); comboCount = 0; guard !isGameOver else { return }; if isReviewingWrongQuestions { let question = wronglyAnsweredQuestions.removeFirst(); wronglyAnsweredQuestions.append(question) } else { if !wronglyAnsweredQuestions.contains(where: { $0.id == currentQuestion.id }) { wronglyAnsweredQuestions.append(currentQuestion) } } }
    
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
    
    private func loseLife() { if lives > 0 { lives -= 1 }; if lives == 0 { isGameOver = true } }
    
    private func saveGameResult() {
        let result = StageResult(
            evaluation: self.finalEvaluation, maxCombo: self.maxComboAchieved,
            correctlyAnswered: self.correctlyAnsweredCount, totalQuestions: self.totalQuestions
        )
        dataService.updateStageResult(stage: self.currentStage, newResult: result)
    }
}
