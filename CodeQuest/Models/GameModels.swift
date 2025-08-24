import Foundation

struct QuizQuestion: Identifiable {
    
    let id = UUID()
    let questionID: Int
    let level: Int
    let questionText: String
    let imageName: String?     // 空字串 → 轉成 nil
    let options: [String]      // 若某欄缺值 → 空字串
    let correctAnswer: String  // 若無法判定 → 取 options.first 或空字串
    let keyword: String?       // 空字串 → 轉成 nil
    let type: Int
    let stages: [Int]

}
