import Foundation
import Combine

class GameViewModel: ObservableObject {
    private var quizQuestions: [MathQuestion] = []
    
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var lives: Int = 5
    @Published var isGameOver: Bool = false
    @Published var isQuizComplete: Bool = false

    private let maxLives = 5
    
    var totalQuestions: Int { quizQuestions.count }
    var currentQuestion: MathQuestion {
        // 增加一個保護，避免在極端情況下崩潰
        guard currentQuestionIndex < quizQuestions.count else {
            return quizQuestions.last!
        }
        return quizQuestions[currentQuestionIndex]
    }

    init() {
        loadQuizData()
    }

    func submitAnswer(_ answer: Int) -> Bool {
        let isCorrect = answer == currentQuestion.correctAnswer
        
        if isCorrect {
            score += 10
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.nextQuestion()
            }
        } else {
            loseLife()
        }
        return isCorrect
    }
    
    private func nextQuestion() {
        // ✨ [關鍵修正] 修正導致崩潰的邏輯
        if currentQuestionIndex < quizQuestions.count - 1 {
            // 如果不是最後一題，正常 +1
            currentQuestionIndex += 1
        } else {
            // 如果是最後一題，不再增加 index，只設定完成狀態
            isQuizComplete = true
        }
    }
    
    private func loseLife() {
        if lives > 0 {
            lives -= 1
            if lives == 0 {
                isGameOver = true
            }
        }
    }
    
    func restartGame() {
        score = 0
        lives = maxLives
        currentQuestionIndex = 0
        isGameOver = false
        isQuizComplete = false
        quizQuestions.shuffle()
    }
    
    private func loadQuizData() {
        self.quizQuestions = (1...12).map { _ in QuestionGenerator.generate() }
    }
}
