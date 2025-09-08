import Foundation
import AVFoundation

final class SoundManager {
    
    static let shared = SoundManager()
    
    // ✅ 1. 新增：一個快取字典，用來存放所有「已經準備好的」音效播放器
    private var players: [String: AVAudioPlayer] = [:]

    // ✅ 2. 修改：在你的 enum 宣告後加上 ", CaseIterable"
    // 這讓我們可以遍歷 enum 裡的所有音效，方便進行預載
    enum SoundEffect: String, CaseIterable {
        case proceed = "continue_sound.wav"
        case islandSelect = "island_select.mp3"
        case pageTurn = "page_turn.mp3"
        case createLevel = "create_level_sound.mp3"
        case drawingBoardOpen = "pencil_sketch.mp3"
        case stageSelect = "stage_click.wav"
        case challengeStart = "challenge_start.mp3"
        case backButton = "whoosh_sound.mp3"
        case answerCorrect = "answer_correct.mp3"
        case answerWrong = "answer_wrong.mp3"
        case useHint = "use_hint_bell.mp3"
        case imageTap = "image_tap_shutter.mp3"
        case resultsFanfare = "results_fanfare.mp3"
        case resultsConfirm = "results_confirm.mp3"
    }
    
    
    private init() {
        // 在初始化時，就呼叫預載函式
        preloadSounds()
    }
    
    // ✅ 4. 新增：預先載入所有音效的函式
    private func preloadSounds() {
        // 遍歷 SoundEffect enum 中的每一個 case
        for effect in SoundEffect.allCases {
            let fileName = effect.rawValue
            
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else {
                print("⚠️ [Preload] 找不到音效檔案: \(fileName)")
                continue // 找不到就跳過，繼續載入下一個
            }
            
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                // 關鍵：.prepareToPlay() 會預先把音訊解碼並載入到記憶體緩衝區
                player.prepareToPlay()
                
                // 將準備好的播放器存入我們的快取字典
                players[fileName] = player
                print("✅ [Preload] 成功預載音效: \(fileName)")
            } catch {
                print("❌ [Preload] 預載音效時發生錯誤 \(fileName): \(error.localizedDescription)")
            }
        }
    }

    // ✅ 5. 修改並簡化 playSound 函式
    func playSound(_ effect: SoundEffect) {
        let fileName = effect.rawValue
        
        // 從字典中尋找已經準備好的播放器
        if let player = players[fileName] {
            // 如果音效正在播放，先把它倒回開頭，這樣才能連續觸發
            if player.isPlaying {
                player.currentTime = 0
            }
            // 直接播放！
            player.play()
        } else {
            // 如果因為某些原因（例如檔案遺失）沒有預載成功，就印出錯誤
            print("❌ [Playback] 找不到預載的播放器: \(fileName)")
        }
    }
    
}
