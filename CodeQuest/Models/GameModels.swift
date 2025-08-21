// MARK: - Models/GameModels.swift

import Foundation

// 數學題的結構
struct MathQuestion: Identifiable {
    let id = UUID()
    let text: String // 例如 "5 + 8 = ?"
    let correctAnswer: Int
    let options: [Int] // 包含正確答案的選項
}

// 題目生成器
struct QuestionGenerator {
    static func generate() -> MathQuestion {
        let a = Int.random(in: 1...20)
        let b = Int.random(in: 1...20)
        let correctAnswer = a + b
        
        var options = [correctAnswer]
        while options.count < 4 {
            let wrongAnswer = Int.random(in: (correctAnswer-10)...(correctAnswer+10))
            if !options.contains(wrongAnswer) && wrongAnswer > 0 {
                options.append(wrongAnswer)
            }
        }
        
        return MathQuestion(
            text: "\(a) + \(b) = ?",
            correctAnswer: correctAnswer,
            options: options.shuffled() // 打亂選項順序
        )
    }
}
