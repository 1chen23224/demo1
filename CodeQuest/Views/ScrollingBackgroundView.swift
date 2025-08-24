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
                
                // ✨ [修正] 在 Preview 中提供一個範例圖片檔名
                ScrollingBackgroundView(
                    scrollTrigger: score,
                    imageName: "level1-1"
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
