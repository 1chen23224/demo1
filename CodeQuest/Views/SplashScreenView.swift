import SwiftUI
import AVKit

struct SplashScreenView: View {
    var onFinished: () -> Void
    
    @State private var videoDidFinish = false
    @State private var isPulsing = false
    @State private var player: AVPlayer
    
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
                // 狀態二：影片播放完畢
                Image("loading_picture")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
                    // ✨ [修改] 為圖片加上向左的偏移
                    .offset(x: -35)
                    .onTapGesture(perform: onFinished)
                
                VStack {
                    Spacer()
                    Text("Touch to Start")
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
                
            } else {
                // 狀態一：正在播放影片
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .disabled(true)
                    // ✨ [修改] 為影片加上向左的偏移
                    .scaledToFill()
                    // ✨ [修改] 為圖片加上向左的偏移
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
    ContentView()
}
