import Foundation
import AVFoundation

final class MusicPlayer {
    static let shared = MusicPlayer()
    
    private var audioPlayer: AVAudioPlayer?
    private var currentTrackName: String? // ✅ 新增：用來記錄目前正在播放的音軌

    private init() {}

    // ✅ 修改：函式現在需要一個明確的 `fileName`
    func startBackgroundMusic(fileName: String) {
        // 如果想播放的音樂就是現在正在播放的，就什麼都不做
        if fileName == currentTrackName, audioPlayer?.isPlaying ?? false {
            return
        }
        
        guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: nil) else {
            print("❌ BGM 檔案 \(fileName) 不存在。")
            return
        }
        
        let url = URL(fileURLWithPath: bundlePath)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // 無限循環
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            currentTrackName = fileName // ✅ 記錄下新的音軌名稱
            print("🎵 BGM 已切換並開始播放: \(fileName)")
        } catch {
            print("❌ 無法播放 BGM: \(error.localizedDescription)")
        }
    }
    
    func stopBackgroundMusic() {
        if audioPlayer?.isPlaying ?? false {
            audioPlayer?.stop()
            currentTrackName = nil // 清空記錄
            print("🔇 BGM 已停止。")
        }
    }
    // ✅ 新增：暫停 BGM
    func pauseBGM() {
        if audioPlayer?.isPlaying ?? false {
            audioPlayer?.pause()
            print("⏸️ BGM 已暫停。")
        }
    }
    
    // ✅ 新增：恢復 BGM
    func resumeBGM() {
        if let player = audioPlayer, !player.isPlaying {
            player.play()
            print("▶️ BGM 已恢復播放。")
        }
    }
    
}
