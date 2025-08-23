import Foundation
import Combine

class GameViewModel: ObservableObject {
    private var quizQuestions: [QuizQuestion] = []
    
    @Published var currentQuestionIndex: Int = 0
    @Published var score: Int = 0
    @Published var lives: Int = 5
    @Published var isGameOver: Bool = false
    @Published var isQuizComplete: Bool = false

    private let maxLives = 5
    
    var totalQuestions: Int {
        quizQuestions.count
    }
    
    var currentQuestion: QuizQuestion {
        guard currentQuestionIndex < quizQuestions.count else {
            return quizQuestions.last!   // ⚠️ 這裡建議加安全處理
        }
        return quizQuestions[currentQuestionIndex]
    }
    
    init() {
        loadQuizData()
    }
    
    
    func submitAnswer(_ answer: String) -> Bool {
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
        if currentQuestionIndex < quizQuestions.count - 1 {
            currentQuestionIndex += 1
        } else {
            isQuizComplete = true
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
    
    func restartGame() {
        score = 0
        lives = maxLives
        currentQuestionIndex = 0
        isGameOver = false
        isQuizComplete = false
        quizQuestions.shuffle()
    }
    private func loadQuizData() {
        guard let path = Bundle.main.path(forResource: "questions", ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("❌ 找不到 quizData.csv")
            return
        }
        
        let rows = content.components(separatedBy: "\n").dropFirst() // 去掉 header
        
        var questions: [QuizQuestion] = rows.compactMap { row in
            let cols = row.components(separatedBy: ",")
            guard cols.count >= 10 else { return nil }  // 至少要有10欄（忽略 CorrectAnswer）
            
            let options = [cols[4], cols[5], cols[6], cols[7]].shuffled()
            
            return QuizQuestion(
                questionID: Int(cols[0]) ?? 0,
                level: Int(cols[1]) ?? 0,
                questionText: cols[2],
                imageName: cols[3].isEmpty ? nil : cols[3],
                options: options,
                correctAnswer: cols[8],   // ✅ 用 Answer 欄位
                keyword: nil,
                type: Int(cols[10]) ?? 0 // ✅ 跳過第 9 欄 CorrectAnswer
            )
        }
        
        // ✨ 載入後打亂順序
        questions.shuffle()
        
        self.quizQuestions = questions
    }

}
