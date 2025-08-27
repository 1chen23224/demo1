import SwiftUI
import CoreGraphics

// MARK: - 依圖片 alpha 定義點擊範圍（含效能優化 & yOffset 微調）
struct AlphaShape: Shape {
    let cgImage: CGImage
    var yOffset: CGFloat = -0.1   // 往上微移（0~1 的百分比）

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

                    path.addRect(CGRect(
                        x: px * rect.width,
                        y: py * rect.height,
                        width: 1,
                        height: 1
                    ))
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
        VStack(spacing: 8) {
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
            .contentShape(AlphaShape(cgImage: cgImage))
            .buttonStyle(
                (isUnlocked && !isNew) ? AlwaysPressedStyle() : .init()
            )
            
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
    
    var body: some View {
        ZStack {
            // --- 地圖層 ---
            ZStack {
                GeometryReader { geo in
                    ZStack {
                        Color.black.ignoresSafeArea()
                        Image("selecting")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .ignoresSafeArea()
                    }
                }

                ZStack {
                    ChapterMaskView(chapterNumber: 1, onChapterSelect: { chapter in
                        onChapterSelect(chapter)
                        dismissGuideIfNeeded()
                    }, showDebugBorder: showDebugBorder)
                    .frame(width: 320, height: 215).offset(x: 25, y: -175)
                    
                    ChapterMaskView(chapterNumber: 2, onChapterSelect: onChapterSelect, showDebugBorder: showDebugBorder)
                        .frame(width: 170, height: 160).offset(x: -30, y: -115)
                    ChapterMaskView(chapterNumber: 3, onChapterSelect: onChapterSelect, showDebugBorder: showDebugBorder)
                        .frame(width: 125, height: 100).offset(x: 33, y: -89)
                    ChapterMaskView(chapterNumber: 4, onChapterSelect: onChapterSelect, showDebugBorder: showDebugBorder)
                        .frame(width: 220, height: 175).offset(x: -115, y: 22)
                    ChapterMaskView(chapterNumber: 5, onChapterSelect: onChapterSelect, showDebugBorder: showDebugBorder)
                        .frame(width: 500, height: 385).offset(x: -10, y: 95)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 25) // 想要的「左移」效果
            
            .ignoresSafeArea()
            
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
                    .offset(x: 100, y: -200) // 指向第一章
                    .transition(.opacity)
            }
        }
        .onAppear {
            // ✅ 判斷條件：最高解鎖章節 == 1，表示玩家沒打過任何關
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
    var isEnabled: Bool = true   // 👈 新增，預設可用
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
        .disabled(!isEnabled) // 👈 不可點擊
    }
}

