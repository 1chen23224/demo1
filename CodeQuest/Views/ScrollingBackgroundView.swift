import SwiftUI

struct ScrollingBackgroundView: View {
    let scrollTrigger: Int
    private let imageName = "world-background"
    
    @State private var scrollPosition: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width
            let scrollAmount = imageWidth / 4.0
            
            ZStack {
                // 手動佈局三張圖片，這個邏輯是穩定的
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageWidth)
                    .offset(x: self.scrollPosition - imageWidth)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageWidth)
                    .offset(x: self.scrollPosition)

                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageWidth)
                    .offset(x: self.scrollPosition + imageWidth)
            }
            .onChange(of: scrollTrigger) { _, _ in
                guard scrollTrigger > 0 else { return }

                // 啟動 0.5 秒的捲動動畫
                withAnimation(.linear(duration: 0.5)) {
                    self.scrollPosition -= scrollAmount
                }
                
                // ✨ [關鍵修正] 延遲 0.5 秒後再執行位置重置檢查
                // 這確保了動畫有足夠的時間播放完畢
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // 當中間的圖片完全移出左邊界時
                    if self.scrollPosition <= -imageWidth {
                        // 我們立即將它向右「傳送」一個圖片的寬度
                        // 這個操作沒有動畫，所以是瞬間完成的
                        self.scrollPosition += imageWidth
                    }
                }
            }
        }
    }
}


// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var score = 0
        var body: some View {
            ZStack {
                Color.blue
                ScrollingBackgroundView(scrollTrigger: score)
                VStack {
                    Spacer()
                    Button("模擬答對一題 (score +10)") {
                        score += 10
                    }
                    .font(.headline).padding()
                    .background(.white.opacity(0.8)).cornerRadius(15)
                    .padding()
                }
            }
        }
    }
    return PreviewWrapper()
}
