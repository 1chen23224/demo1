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
                Text("點擊任意位置繼續")
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // 讓整個 ZStack 區域都可以被點擊
        .onTapGesture {
            if !userAcceptedTerms {
                // 如果還沒同意條款，顯示條款頁面
                withAnimation {
                    showTermsOfService = true
                }
            } else {
                // 如果已同意，直接結束
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
            Text("使用條款")
                .font(.title.bold())
                .padding(.top)
            
            ScrollView {
                Text("""
                1. 版權與所有權
                
                本應用程式內包含的所有內容（包括但不限於文字、圖片、圖表和設計），除非另有說明，均屬於其原版權所有者的財產，並且受版權法及國際條約的保護。用戶不得對這些內容進行任何形式的商業利用、再發佈或複製，除非獲得明確的書面授權。
                
                2. 內容來源與使用
                
                本應用程式部分內容來源於澳門特別行政區交通事務局的《駕駛理論測驗》公開資料（www.dsat.gov.mo）。
                
                3. 用戶責任
                
                使用本應用程式即表示您同意遵守所有的使用條款，並保證您不會使用本應用程式的內容進行任何形式的非法或不當行為。您同意不會對應用程式內容進行任何修改、再分發或商業化行為，除非您已經獲得適當的授權。
                
                4. 免責聲明
                
                本應用程式的所有內容，均以「現狀」提供。開發者不保證內容的準確性、完整性或可靠性，並對因使用本應用程式內容而產生的任何損害或損失不承擔任何責任。對於外部網站或服務的連結，本應用程式不負任何責任。
                
                5. 隱私與資料保護
                
                我們尊重並保護您的隱私。本應用程式是一款單機遊戲，因此不會收集、存儲或共享您的個人資料。我們不會要求或存取任何與您的裝置、位置、聯絡方式或遊戲過程相關的個人資訊。使用本應用程式時，您不需要提供任何私人資料，並且本應用程式不會向第三方提供您的任何資料。如有任何隱私政策的變動，我們將及時通知並更新條款。
                
                6. 變更與更新
                
                我們保留隨時修改或更新本使用條款的權利。當條款有所更動時，會在應用程式內及相關頁面發佈通知並標明更新日期。
                """)
                .font(.body)
                .padding(.horizontal)
            }
            
            Button("我已閱讀並同意") {
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
