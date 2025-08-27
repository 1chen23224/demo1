import Foundation

/// 遊戲的主要題目模型
struct QuizQuestion: Identifiable {
    /// SwiftUI List / ForEach 用的唯一 ID
    let id = UUID()
    
    /// 題目在題庫裡的唯一編號 (對應 CSV 的 col[0])
    let questionID: Int
    
    /// 題目所屬章節 (對應 CSV 的 col[1])
    let level: Int
    
    /// 題目文字 (對應 CSV 的 col[2])
    let questionText: String
    
    /// 題目圖片名稱，空字串會轉成 nil (對應 CSV 的 col[3])
    let imageName: String?
    
    /// 選項清單 (對應 CSV 的 col[4] ~ col[7])
    let options: [String]
    
    /// 正確答案 (對應 CSV 的 col[8])
    /// 如果讀不到 → 取第一個選項，若沒有選項則給空字串
    let correctAnswer: String
    
    /// 題目關鍵字，空字串會轉成 nil (對應 CSV 的 col[9])
    let keyword: String?
    
    /// 題目類型 (對應 CSV 的 col[10])
    let type: Int
    
    /// 額外資訊，代表題目所屬的不同 stage
    let stage: Int
}
