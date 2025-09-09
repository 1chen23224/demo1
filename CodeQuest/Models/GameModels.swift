import Foundation

// In your QuizQuestion.swift file (or wherever it's defined)

struct QuizQuestion: Identifiable, Codable, Hashable {
    var id = UUID() // For Identifiable
    let questionID: Int
    let level: Int
    let imageName: String?
    let stage: Int

    // ❌ REMOVE the old single-language properties
    // let questionText: String
    // let options: [String]
    // let correctAnswer: String

    // ✅ ADD these new multi-language properties
    let questionText: [String: String]   // e.g., ["zh-Hant": "問題", "en": "Question"]
    let options: [String: [String]]    // e.g., ["zh-Hant": ["A", "B"], "en": ["A_en", "B_en"]]
    let correctAnswer: [String: String]  // e.g., ["zh-Hant": "答案", "en": "Answer"]

    // ✅ ADD these helper functions to easily get the text for the current language
    // This makes using it in the UI much cleaner.
    func questionText(for langCode: String) -> String {
        return questionText[langCode] ?? questionText["zh-Hant"] ?? ""
    }

    func options(for langCode: String) -> [String] {
        return options[langCode] ?? options["zh-Hant"] ?? []
    }

    func correctAnswer(for langCode: String) -> String {
        return correctAnswer[langCode] ?? correctAnswer["zh-Hant"] ?? ""
    }
    
    // Make sure Codable and Hashable still work with the new structure
    // We can define what makes a question unique for hashing purposes
    static func == (lhs: QuizQuestion, rhs: QuizQuestion) -> Bool {
        lhs.questionID == rhs.questionID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(questionID)
    }
}
