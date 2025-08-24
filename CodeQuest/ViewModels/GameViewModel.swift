import Foundation
import Combine

class GameViewModel: ObservableObject {
    // --- 原始屬性 ---
    private var quizQuestions: [QuizQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var lives: Int = 5
    @Published var isGameOver: Bool = false
    @Published var isQuizComplete: Bool = false
    @Published var isHintVisible = false
    private let maxLives = 5
    
    // ✨ [新增] 用於錯題本機制的狀態變數
    private var wronglyAnsweredQuestions: [QuizQuestion] = []
    private var isReviewingWrongQuestions = false
    
    // ✨ [新增] 專門用來計算進度的計數器
    @Published var correctlyAnsweredCount: Int = 0

    var totalQuestions: Int {
        quizQuestions.count
    }
    
    // ✨ [修改] currentQuestion 現在會根據是否在重做階段，提供不同的題目
    var currentQuestion: QuizQuestion {
        if isReviewingWrongQuestions {
            // 在重做階段，永遠顯示錯題本的第一題
            guard let question = wronglyAnsweredQuestions.first else {
                return QuizQuestion(questionID: 0, level: 0, questionText: "所有題目已完成！", imageName: nil, options: [], correctAnswer: "", keyword: nil, type: 0)
            }
            return question
        } else {
            // 在第一輪，正常顯示題目
            guard !quizQuestions.isEmpty, currentQuestionIndex < quizQuestions.count else {
                return QuizQuestion(questionID: 0, level: 0, questionText: "載入中...", imageName: nil, options: [], correctAnswer: "", keyword: nil, type: 0)
            }
            return quizQuestions[currentQuestionIndex]
        }
    }
    
    init() {
        loadQuizData()
    }
    
    func showHint() {
        isHintVisible = true
    }
    
    // ✨ [重構] submitAnswer 不再回傳 Bool，而是直接處理所有遊戲邏輯
    func submitAnswer(_ answer: String) {
        let isCorrect = answer == currentQuestion.correctAnswer
        
        if isCorrect {
            handleCorrectAnswer()
        } else {
            handleWrongAnswer()
        }
        
        // 延遲 1 秒後進入下一題，讓使用者有時間看到答對/答錯的視覺回饋
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.moveToNextState()
        }
    }

    private func handleCorrectAnswer() {
        score += 10
        // 只有答對時，才增加進度計數器
        correctlyAnsweredCount += 1
        
        if isReviewingWrongQuestions {
            // 如果在重做階段答對，將題目從錯題本中移除
            wronglyAnsweredQuestions.removeFirst()
        }
    }

    private func handleWrongAnswer() {
        loseLife()
        guard !isGameOver else { return }
        
        if isReviewingWrongQuestions {
            // 如果在重做階段答錯，將題目移到錯題本的末尾，稍後再做
            let question = wronglyAnsweredQuestions.removeFirst()
            wronglyAnsweredQuestions.append(question)
        } else {
            // 如果在第一輪答錯，將題目加入錯題本 (避免重複加入)
            if !wronglyAnsweredQuestions.contains(where: { $0.id == currentQuestion.id }) {
                wronglyAnsweredQuestions.append(currentQuestion)
            }
        }
    }

    // ✨ [新增] 這是新的核心邏輯，決定下一題是什麼或遊戲是否結束
    private func moveToNextState() {
        guard !isGameOver else { return }
        isHintVisible = false

        if isReviewingWrongQuestions {
            // 在重做階段
            if wronglyAnsweredQuestions.isEmpty {
                // 如果錯題本清空了，恭喜！遊戲完成
                isQuizComplete = true
            } else {
                // UI 會自動更新顯示錯題本的下一題
                objectWillChange.send()
            }
        } else {
            // 在第一輪
            if currentQuestionIndex < quizQuestions.count - 1 {
                // 還有下一題，繼續
                currentQuestionIndex += 1
            } else {
                // 第一輪結束，準備進入重做階段
                isReviewingWrongQuestions = true
                if wronglyAnsweredQuestions.isEmpty {
                    // 如果沒有錯題，代表全部答對，直接結束遊戲
                    isQuizComplete = true
                } else {
                    // 進入錯題本模式，UI 會自動更新
                    objectWillChange.send()
                }
            }
        }
    }

    private func loseLife() {
        if lives > 0 {
            lives -= 1
        }
        if lives == 0 {
            isGameOver = true
        }
    }
    
    // ✨ [修改] 重置所有狀態，包含新加入的變數
    func restartGame() {
        score = 0
        lives = maxLives
        currentQuestionIndex = 0
        isGameOver = false
        isQuizComplete = false
        isHintVisible = false
        
        wronglyAnsweredQuestions = []
        isReviewingWrongQuestions = false
        correctlyAnsweredCount = 0 // 重置進度計數器
        
        quizQuestions.shuffle()
    }
   
    private func loadQuizData() {
        // ... 此處程式碼與您提供的原始版本相同 ...
        guard let path = Bundle.main.path(forResource: "questions", ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("❌ 找不到或無法讀取 questions.csv")
            return
        }
        
        let rows = content.components(separatedBy: .newlines).dropFirst().filter { !$0.isEmpty }
        
        self.quizQuestions = rows.compactMap { row in
            let cols = row.components(separatedBy: ",")
            guard cols.count >= 11 else { return nil }
            let options = [cols[4], cols[5], cols[6], cols[7]].shuffled()
            let keyword = cols[10].trimmingCharacters(in: .whitespacesAndNewlines)
            
            return QuizQuestion(
                questionID: Int(cols[0]) ?? 0,
                level: Int(cols[1]) ?? 0,
                questionText: cols[2],
                imageName: cols[3].isEmpty ? nil : cols[3],
                options: options,
                correctAnswer: cols[8],
                keyword: keyword.isEmpty ? nil : keyword,
                type: cols.count > 11 ? Int(cols[11]) ?? 0 : 0
            )
        }
        
        self.quizQuestions.shuffle()
    }
}
