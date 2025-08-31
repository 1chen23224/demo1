import SwiftUI
import CoreGraphics

// MARK: - 依圖片 alpha 定義點擊範圍（含效能優化 & yOffset 微調）
struct AlphaShape: Shape {
    let cgImage: CGImage
    var yOffset: CGFloat = -0.1   // 往上微移（0~1 的百分比）
    var debug: Bool = false       // Debug 開關

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = cgImage.width
        let height = cgImage.height
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return path }

        // stride 取樣降低計算量（每 3px 取樣一次）
        for y in stride(from: 0, to: height, by: 3) {
            for x in stride(from: 0, to: width, by: 3) {
                let pixelIndex = (y * width + x) * 4
                let alpha = ptr[pixelIndex + 3]
                if alpha > 0 {
                    let px = CGFloat(x) / CGFloat(width)
                    var py = CGFloat(y) / CGFloat(height)
                    py = min(max(py + yOffset, 0), 1) // ↑ 往上微移

                    let rectCell = CGRect(
                        x: px * rect.width,
                        y: py * rect.height,
                        width: 1,
                        height: 1
                    )
                    path.addRect(rectCell)
                }
            }
        }
        return path
    }
}

// MARK: - 模擬按下效果
struct AlwaysPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(0.6) // 👈 永遠模擬 pressed 狀態
    }
}

// MARK: - 教學引導（小手指 + 提示文字）
struct HandGuideView: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "hand.point.up.left.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
                .offset(x: animate ? -5 : 5, y: animate ? -5 : 5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
                .onAppear { animate = true }
                .allowsHitTesting(false)

            Text("點擊這裡開始")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.7), radius: 3, x: 1, y: 1)
                .allowsHitTesting(false)
        }
        
    }
}

// MARK: - 單一章節 Mask
struct ChapterMaskView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let chapterNumber: Int
    let onChapterSelect: (Int) -> Void
    var showDebugBorder: Bool = false
    var yOffset: CGFloat = 0   // 👈 接收外部調整
    @State private var isPulsing = false

    var body: some View {
        let isUnlocked = dataService.isChapterUnlocked(chapterNumber)
        let isNew = chapterNumber == dataService.highestUnlockedChapter
        
        if let uiImage = UIImage(named: "selecting-\(chapterNumber)"),
           let cgImage = uiImage.cgImage {

            Button {
                onChapterSelect(chapterNumber)
            } label: {
                Image("selecting-\(chapterNumber)")
                    .resizable().scaledToFit()
                    .overlay(
                        ZStack {
                            if !isUnlocked {
                                Color.black.opacity(0.785)
                            } else if isNew {
                                Color.yellow.opacity(isPulsing ? 0.8 : 0.2).blur(radius: 15)
                                Color.white.opacity(isPulsing ? 0.7 : 0.1).blur(radius: 5)
                            } else {
                                Color.black.opacity(0.001)
                            }
                        }
                        .mask(Image("selecting-\(chapterNumber)").resizable().scaledToFit())
                    )
            }
            .disabled(!isUnlocked)
            .contentShape(AlphaShape(cgImage: cgImage, yOffset: yOffset))
            .buttonStyle(
                (isUnlocked && !isNew) ? AlwaysPressedStyle() : .init()
            )
            
            // Debug: 顯示 AlphaShape 範圍
            .overlay {
                if showDebugBorder {
                    AlphaShape(cgImage: cgImage, yOffset: yOffset, debug: true)
                        .stroke(Color.red.opacity(0.5), lineWidth: 0.5)
                }
            }
            
            .onChange(of: isNew, initial: true) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                } else {
                    withAnimation { isPulsing = false }
                }
            }
        }
    }
}

// MARK: - 主畫面（章節地圖 + 功能按鈕 + 引導）
struct ChapterSelectionView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let onChapterSelect: (Int) -> Void
    let onSelectReviewTab: () -> Void
    
    @State private var selectedTabIndex: Int = 0
    @State private var showGuide: Bool = false
    var showDebugBorder: Bool = false
    
    // Debug: 動態調整 yOffset
    @State private var debugYOffset: CGFloat = 0
    
    // 章節相對配置（比例）
    let chapterConfigs: [(chapter: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        (1, 0.565, 0.275, 1.02, 0.28),  // 第一章
        (2, 0.42, 0.344, 0.42, 0.6),   // 第二章
        (3, 0.58, 0.377, 0.31, 0.28),  // 第三章
        (4, 0.205, 0.525, 0.36, 0.28), // 第四章
        (5, 0.475, 0.62, 0.84, 0.78)  // 第五章
    ]
    
    var body: some View {
        ZStack {
            // --- 地圖層 ---
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    // --- 修改開始 ---
                    // 將背景圖放在一個透明的 Color View 的 overlay 中
                    Color.clear // 建立一個佔滿全螢幕的透明基底
                        .overlay(
                            Image("selecting")
                                .resizable()
                                .scaledToFill() // 維持比例放大填滿
                                // 👇 關鍵：控制圖片如何對齊容器
                                // .topLeading 會將圖片的左上角對齊容器的左上角
                                // 您可以依據圖片的重點區域選擇不同的對齊方式
                                // 例如 .top, .center, .bottomTrailing 等
                                .frame(width: geo.size.width + 200, height: geo.size.height + 95, alignment: .topLeading)
                        )
                        .clipped() // 裁切掉超出螢幕範圍的部分
                        .ignoresSafeArea()
                    // --- 修改結束 ---
                    

                    // 依照比例擺放章節
                    ForEach(chapterConfigs, id: \.chapter) { config in
                        ChapterMaskView(
                            chapterNumber: config.chapter,
                            onChapterSelect: { chapter in
                                onChapterSelect(chapter)
                                dismissGuideIfNeeded()
                            },
                            showDebugBorder: showDebugBorder,
                            yOffset: debugYOffset
                        )
                        .frame(
                            width: geo.size.width * config.w,
                            height: geo.size.height * config.h
                        )
                        .position(
                            x: geo.size.width * config.x,
                            y: geo.size.height * config.y
                        )
                    }
                }
            }
            
            // --- 標題 ---
            VStack {
                Text("𝑴 𝑨 𝑷")
                    .font(.custom("CEF Fonts CJK Mono", size: 50))
                    .foregroundColor(.black)
                Spacer()
            }
            
            // --- 首次教學引導 ---
            if showGuide {
                HandGuideView()
                    .position(x: 250, y: 170)
                    .transition(.opacity)
            }
            
            // --- Debug 控制區 ---
            if showDebugBorder {
                VStack {
                    Spacer()
                    HStack {
                        Text("yOffset: \(String(format: "%.2f", debugYOffset))")
                            .foregroundColor(.yellow)
                        Slider(value: $debugYOffset, in: -0.3...0.3, step: 0.01)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(12)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            if dataService.highestUnlockedChapter == 1 {
                showGuide = true
            }
        }
        .navigationBarHidden(true)
    }
    
    private func dismissGuideIfNeeded() {
        if showGuide {
            withAnimation { showGuide = false }
        }
    }
}

// MARK: - 底部按鈕
struct BottomTabButton: View {
    let iconName: String
    let title: String
    let tag: Int
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(isEnabled ? (isSelected ? .yellow : .white) : .gray)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isEnabled ? (isSelected ? .yellow : .white) : .gray)
            }
            .padding(.horizontal, 20)
        }
        .disabled(!isEnabled)
    }
}

// MARK: - 預覽
struct ChapterSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterSelectionView(
            onChapterSelect: { chapter in
                print("Selected chapter: \(chapter)")
            },
            onSelectReviewTab: {
                print("Review Tab Selected")
            },
            showDebugBorder: true // 👈 開啟 Debug Mode
        )
        .previewDisplayName("章節地圖 Debug")
    }
}
