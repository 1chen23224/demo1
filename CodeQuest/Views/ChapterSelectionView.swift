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

// MARK: - 單一章節 Mask（外觀用原本 Image + mask，點擊用 AlphaShape）
// ✨ [主要修改處]
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
                            }
                        }
                        .mask(Image("selecting-\(chapterNumber)").resizable().scaledToFit())
                    )
                    .overlay {
                        // ✨ [新增] 如果是最新關卡，顯示「按我」提示
                        if isNew && chapterNumber == 1{
                            Text("點擊開始")
                                .font(.custom("CEF Fonts CJK Mono", size: 30))
                                .bold()
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.7), radius: 5)
                                .opacity(isPulsing ? 1.0 : 0.8)
                                .padding(.top, -50)
                                .padding(.horizontal, 80)
                        }
                    }
                    .overlay {
                        if showDebugBorder {
                            AlphaShape(cgImage: cgImage).stroke(Color.red, lineWidth: 1).opacity(0.6)
                        }
                    }
            }
            .disabled(!isUnlocked)
            .contentShape(AlphaShape(cgImage: cgImage))
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
// MARK: - 主畫面（章節地圖 + 章節點擊區 + 底部三顆功能按鈕）
struct ChapterSelectionView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let onChapterSelect: (Int) -> Void
    // ✨ [新增] 新增一個閉包，用於通知 ContentView 要跳轉到複習頁面
    let onSelectReviewTab: () -> Void
    // 底部按鈕選擇狀態
    @State private var selectedTabIndex: Int = 0
    // Debug：是否顯示紅框
    var showDebugBorder: Bool = false

    var body: some View {
        ZStack {
            // --- 地圖層 ---
            ZStack {
                Image("selecting")
                    .resizable()
                    .scaledToFill()

                // --- 章節圖層（外觀維持原本 mask；點擊用 AlphaShape）---
                ZStack {
                    ChapterMaskView(chapterNumber: 1, onChapterSelect: onChapterSelect, showDebugBorder: showDebugBorder)
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
            .offset(x: -30)
            .ignoresSafeArea()

            // --- 標題 ---
            VStack {
                Text("𝑴 𝑨 𝑷")
                    .font(.custom("CEF Fonts CJK Mono", size: 50))
                    .foregroundColor(.black)
                Spacer()
            }
            .padding(.top, 0)

            // --- ✨ 底部按鈕列（學習 / 複習 / 個人）---
            VStack {
                Spacer()
                HStack {
                    BottomTabButton(
                        iconName: "icon-1", title: "學習", tag: 0,
                        isSelected: selectedTabIndex == 0,
                        action: { selectedTabIndex = 0 }
                    )
                    BottomTabButton(
                        iconName: "icon-2", title: "複習", tag: 1,
                        isSelected: selectedTabIndex == 1,
                        action: { onSelectReviewTab()}
                    )
                    BottomTabButton(
                        iconName: "icon-3", title: "個人", tag: 2,
                        isSelected: selectedTabIndex == 2,
                        action: { selectedTabIndex = 2 }
                    )
                }
                .padding(.horizontal, 45)
                .padding(.top, 0)           // 👈 上方留一點距離
                .padding(.bottom, -15)       // 👈 把按鈕往下壓
                .frame(maxWidth: .infinity)
                .frame(height: 30) // 固定高度
                .background(Color.black.opacity(0.3))
            }
            .ignoresSafeArea(.keyboard, edges: .bottom) // 避免鍵盤擋住
        }
        .navigationBarHidden(true)
    }
}

// MARK: - 底部按鈕組件
struct BottomTabButton: View {
    let iconName: String
    let title: String
    let tag: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(isSelected ? .yellow : .white)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? .yellow : .white)
            }
            .padding(.horizontal, 20)
        }
    }
}
