import SwiftUI
import AVKit

struct SplashScreenView: View {
    var onFinished: () -> Void
    
    @State private var videoDidFinish = false
    @State private var isPulsing = false
    @State private var player: AVPlayer
    @State private var showTermsOfService = false
    @State private var userAcceptedTerms = UserDefaults.standard.bool(forKey: "userAcceptedTerms") // 讀取 UserDefaults
    
    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        
        if let url = Bundle.main.url(forResource: "loading_animation", withExtension: "mov") {
            _player = State(initialValue: AVPlayer(url: url))
        } else {
            print("❌ 找不到影片檔案 'loading_animation.mov'！請檢查檔案是否已從 Assets 移出，且 Target Membership 已勾選。")
            _player = State(initialValue: AVPlayer())
            _videoDidFinish = State(initialValue: true) // 直接跳過影片
        }
    }

    var body: some View {
        ZStack {
            if videoDidFinish {
                // 如果影片播放完畢，顯示條款頁面
                if showTermsOfService && !userAcceptedTerms {
                    // 顯示使用條款視圖
                    VStack {
                        ScrollView {
                            Text("""
                                使用條款

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
                                .padding()
                            
                            Button("我同意") {
                                userAcceptedTerms = true
                                UserDefaults.standard.set(true, forKey: "userAcceptedTerms") // 儲存同意狀態
                                showTermsOfService = false
                                onFinished()
                            }
                            .font(.title)
                            .foregroundColor(.blue)
                            .padding()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(20)
                    .padding()
                } else {
                    // 狀態二：影片播放完畢且玩家同意條款後，顯示遊戲畫面
                    Image("loading_picture")
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                        .offset(x: -35)
                        .onTapGesture {
                            if !userAcceptedTerms {
                                showTermsOfService = true
                            } else {
                                onFinished()
                            }
                        }
                    
                    VStack {
                        Spacer()
                        Text("點擊任意位置繼續")
                            .font(.custom("CEF Fonts CJK Mono", size: 22))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                            .opacity(isPulsing ? 1.0 : 0.6)
                            .padding(.bottom, 200)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
                            isPulsing.toggle()
                        }
                    }
                }
            } else {
                // 狀態一：正在播放影片
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .disabled(true)
                    .scaledToFill()
                    .offset(x: -5)
                    .onAppear {
                        player.play()
                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
                            withAnimation {
                                self.videoDidFinish = true
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}
