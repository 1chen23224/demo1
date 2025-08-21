// MARK: - ViewModels/GameViewModel.swift

import Foundation
import Combine

class GameViewModel: ObservableObject {
    // ✨[修改] 靜態的問題列表
    private var quizQuestions: [MathQuestion] = []
    
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var lives: Int = 5
    @Published var isGameOver: Bool = false
    @Published var isQuizComplete: Bool = false

    private let maxLives = 5
    
    // ✨[新增] 方便獲取當前問題和總數
    var totalQuestions: Int { quizQuestions.count }
    var currentQuestion: MathQuestion { quizQuestions[currentQuestionIndex] }

    init() {
        loadQuizData() // 載入我們的 12 個問題
    }

    // 提交答案的邏輯不變
    func submitAnswer(_ answer: Int) -> Bool {
        let isCorrect = answer == currentQuestion.correctAnswer
        
        if isCorrect {
            score += 10 // 分數依然可以作為捲動觸發器
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                self.nextQuestion()
            }
        } else {
            loseLife()
        }
        return isCorrect
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < quizQuestions.count - 1 {
            currentQuestionIndex += 1
        } else {
            // 所有題目都答完了
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
        quizQuestions.shuffle() // ✨[新增] 重新開始時打亂題目順序，增加可玩性
    }

    // ✨[新增] 載入固定的 12 個問題
    private func loadQuizData() {
        // 這裡我為你產生 12 道題目作為範例
        self.quizQuestions = (1...12).map { _ in QuestionGenerator.generate() }
        // 在真實產品中，你可以從一個 JSON 檔案或伺服器載入這些問題
    }
}
