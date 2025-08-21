import SwiftUI

struct ScrollingBackgroundView: View {
    let scrollTrigger: Int
    
    private let imageName = "world-background"
    
    @State private var offsetX: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width
            let scrollAmount = imageWidth / 4.0
            
            HStack(spacing: 0) {
                // 三圖片緩衝法保持不變
                
                // ✨ [關鍵修正] 將 .scaledToFit() 改回 .scaledToFill()
                // 現在因為父視圖有明確的高度和靠底對齊，這個模式會正確運作
                Image(imageName)
                    .resizable()
                    .scaledToFill() // <--- 修改點
                    .frame(width: imageWidth, height: geometry.size.height) // 明確指定高度
                    .clipped()

                Image(imageName)
                    .resizable()
                    .scaledToFill() // <--- 修改點
                    .frame(width: imageWidth, height: geometry.size.height) // 明確指定高度
                    .clipped()
                
                Image(imageName)
                    .resizable()
                    .scaledToFill() // <--- 修改點
                    .frame(width: imageWidth, height: geometry.size.height) // 明確指定高度
                    .clipped()
            }
            .offset(x: self.offsetX)
            .onChange(of: scrollTrigger) { _, _ in
                guard scrollTrigger > 0 else { return }

                withAnimation(.linear(duration: 0.5)) {
                    self.offsetX -= scrollAmount
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if abs(self.offsetX) >= imageWidth {
                        self.offsetX += imageWidth
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}


// MARK: - Preview
#Preview {
    // 這個 Preview 僅用於單獨測試此元件
    struct PreviewWrapper: View {
        @State private var score = 0
        var body: some View {
            ZStack {
                ScrollingBackgroundView(scrollTrigger: score)
                    .frame(height: 300) // 給予一個預覽高度
                
                VStack {
                    Spacer()
                    Button("模擬答對一題 (score +10)") {
                        score += 10
                    }
                    .font(.headline)
                    .padding()
                    .background(.white.opacity(0.8))
                    .cornerRadius(15)
                    .padding()
                }
            }
        }
    }
    return PreviewWrapper()
}
