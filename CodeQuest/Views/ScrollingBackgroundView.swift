import SwiftUI

struct ScrollingBackgroundView: View {
    let scrollTrigger: Int
    let imageName: String

    
    @State private var scrollPosition: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let imageWidth = geometry.size.width
            let scrollAmount = imageWidth / 4.0
            
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill() // 保持填充寬度
                    .frame(minHeight: 20) // ✨ 新增：設定最小高度
                    .offset(x: self.scrollPosition - imageWidth)
                    .ignoresSafeArea()

                Image(imageName)
                    .resizable()
                    .scaledToFill() // 保持填充寬度
                    .frame(minHeight: 20) // ✨ 新增：設定最小高度
                    .offset(x: self.scrollPosition)
                    .ignoresSafeArea()

                Image(imageName)
                    .resizable()
                    .scaledToFill() // 保持填充寬度
                    .frame(minHeight: 20) // ✨ 新增：設定最小高度
                    .offset(x: self.scrollPosition + imageWidth)
                    .ignoresSafeArea()
            }
            .clipped() // 確保超出部分被裁切
            .ignoresSafeArea()
            .onChange(of: scrollTrigger) { _ in
                guard scrollTrigger > 0 else { return }

                withAnimation(.linear(duration: 0.5)) {
                    self.scrollPosition -= scrollAmount
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if self.scrollPosition <= -imageWidth {
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
                
                ScrollingBackgroundView(
                    scrollTrigger: score,
                    imageName: "level1-1",
                )
                
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
