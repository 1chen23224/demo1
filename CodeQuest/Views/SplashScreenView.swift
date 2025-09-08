import SwiftUI
import AVKit

// MARK: - Splash Screen (Optimized for iPad & Stability)
struct SplashScreenView: View {
    var onFinished: () -> Void
    // ✅ NEW: 建立一個計算屬性來動態選擇背景圖
    private var backgroundImageName: String {
        // 如果是 iPad (regular width), 使用 iPad 版圖片
        if sizeClass == .regular {
            return "loading_picture" // 或者你原來的圖片名稱 "loading_picture"
        } else {
            // 如果是 iPhone (compact width), 使用 iPhone 版的細長圖片
            return "loading_picture_iphone"
        }
    }
    // --- 狀態變數 ---
    @State private var videoDidFinish = false
    @State private var isPulsing = false
    @State private var player: AVPlayer
    @State private var showTermsOfService = false
    @State private var userAcceptedTerms = UserDefaults.standard.bool(forKey: "userAcceptedTerms")
    
    // ✅ 用於儲存影片播放結束的觀察者，以便後續移除
    @State private var playerObserver: Any?

    // --- 自適應 UI 變數 ---
    // ✅ 使用 SizeClass 來偵測設備類型（iPhone/iPad）
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // ✅ 根據設備類型，動態計算字體大小
    private var continueTextFontSize: CGFloat {
        sizeClass == .regular ? 34 : 22 // iPad 使用較大字體
    }
    
    // ✅ 根據設備類型，動態計算底部間距
    private var continueTextBottomPadding: CGFloat {
        sizeClass == .regular ? 300 : 200 // iPad 使用較大間距
    }

    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        
        if let url = Bundle.main.url(forResource: "loading_animation", withExtension: "mov") {
            _player = State(initialValue: AVPlayer(url: url))
        } else {
            print("❌ 找不到影片檔案 'loading_animation.mov'！")
            _player = State(initialValue: AVPlayer())
            _videoDidFinish = State(initialValue: true) // 若影片不存在，直接標記為完成
        }
    }

    var body: some View {
        ZStack {
            // ✅ 設定一個黑色底層，避免在圖片縮放時看到後方不一致的背景
            Color.black.edgesIgnoringSafeArea(.all)
            
            if videoDidFinish {
                // 影片播放完畢，根據是否同意條款來決定顯示內容
                if showTermsOfService && !userAcceptedTerms {
                    // 顯示使用條款頁面
                    TermsOfServiceView(userAcceptedTerms: $userAcceptedTerms, showTermsOfService: $showTermsOfService)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    // 顯示主要的「點擊繼續」畫面
                    mainContentView
                }
            } else {
                // 正在播放開場影片
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .disabled(true)
                    .aspectRatio(contentMode: .fill) // 使用 .fill 填滿螢幕
                    .onAppear(perform: playVideo)
            }
        }
        // ✅ 當 View 消失時，清理觀察者以防止記憶體洩漏
        .onDisappear(perform: cleanUpObserver)
    }
    
    // ✅ 將主內容畫面提取出來，使程式碼更清晰
    private var mainContentView: some View {
        ZStack {
            // ✅ 圖片使用 .scaledToFit 確保在所有設備上都能完整顯示
            Image(backgroundImageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            // ✅ 「點擊繼續」的文字提示
            VStack {
                Spacer()
                Text("click2start".localized())
                    // 使用動態計算的字體和間距
                    .font(.custom("CEF Fonts CJK Mono", size: continueTextFontSize))
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                    .opacity(isPulsing ? 1.0 : 0.6)
                    .padding(.bottom, continueTextBottomPadding)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                    isPulsing.toggle()
                }
                // ✅ 在這裡新增一行，開始播放 bgm_3
                MusicPlayer.shared.startBackgroundMusic(fileName: "bgm_3.mp3")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // 讓整個 ZStack 區域都可以被點擊
        .onTapGesture {
            
            SoundManager.shared.playSound(.proceed)

            if !userAcceptedTerms {
                // 如果還沒同意條款，顯示條款頁面
                withAnimation {
                    showTermsOfService = true
                }
            } else {
                MusicPlayer.shared.stopBackgroundMusic()
                
                onFinished()
            }
        }
    }
    
    // ✅ 播放影片並設定觀察者的邏輯
    private func playVideo() {
        player.play()
        // 為防止重複添加，先移除舊的觀察者
        cleanUpObserver()
        // 添加新的觀察者
        playerObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            withAnimation(.easeOut(duration: 0.5)) {
                self.videoDidFinish = true
            }
        }
    }
    
    // ✅ 清理觀察者的函數
    private func cleanUpObserver() {
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
            playerObserver = nil
        }
    }
}

// MARK: - 輔助 View：使用條款頁面
struct TermsOfServiceView: View {
    @Binding var userAcceptedTerms: Bool
    @Binding var showTermsOfService: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Text("termsofuse".localized())
                .font(.title.bold())
                .padding(.top)
            
            ScrollView {
                Text("terms".localized())
                .font(.body)
                .padding(.horizontal)
            }
            
            Button("acceptnagree".localized()) {
                UserDefaults.standard.set(true, forKey: "userAcceptedTerms") // 儲存同意狀態
                userAcceptedTerms = true
                withAnimation {
                    showTermsOfService = false // 關閉條款頁面，返回主畫面
                }
            }
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(15)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: 500) // 在 iPad 上限制最大寬度，使其更易讀
        .frame(maxHeight: .infinity)
        .background(
            // 使用毛玻璃背景，更具現代感
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .padding()
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
