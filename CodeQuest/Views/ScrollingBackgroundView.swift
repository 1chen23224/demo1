import SwiftUI

struct ScrollingBackgroundView: View {
    let scrollTrigger: Int
    
    private let imageName = "world-background"
    
    @State private var offsetX: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width
            let scrollAmount = imageWidth / 4.0
            
            // ✨ [修改] 設置對齊方式為 .top，有助於佈局穩定
            HStack(alignment: .top, spacing: 0) {
                // 三圖片緩衝法保持不變
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: geometry.size.height)
                    .clipped()

                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: geometry.size.height)
                    .clipped()
                
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: geometry.size.height)
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

// Preview 程式碼不變
#Preview {
    struct PreviewWrapper: View {
        @State private var score = 0
        var body: some View {
            ZStack {
                ScrollingBackgroundView(scrollTrigger: score)
                    .frame(height: 300)
                
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
