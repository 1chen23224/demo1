import SwiftUI

struct ChapterSelectionView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let onChapterSelect: (Int) -> Void
    
    // ✨ [新增] 用於追蹤下方按鈕列的狀態
    @State private var selectedTabIndex = 0 // 0: 學習, 1: 複習, 2: 個人

    var body: some View {
        ZStack {
            // --- 地圖與標題層 (您的佈局保持不變) ---
            ZStack {
                Image("selecting")
                    .resizable()
                    .scaledToFill()
                
                ZStack {
                    ChapterMaskView(chapterNumber: 1, onChapterSelect: onChapterSelect)
                        .frame(width: 320, height: 215).offset(x: 25, y: -175)
                    ChapterMaskView(chapterNumber: 2, onChapterSelect: onChapterSelect)
                        .frame(width: 170, height: 160).offset(x: -30, y: -115)
                    ChapterMaskView(chapterNumber: 3, onChapterSelect: onChapterSelect)
                        .frame(width: 125, height: 100).offset(x: 33, y: -89)
                    ChapterMaskView(chapterNumber: 4, onChapterSelect: onChapterSelect)
                        .frame(width: 220, height: 175).offset(x: -115, y: 22)
                    ChapterMaskView(chapterNumber: 5, onChapterSelect: onChapterSelect)
                        .frame(width: 500, height: 385).offset(x: -10, y: 95)
                }
            }
            .offset(x: -30)
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text("𝑴 𝑨 𝑷")
                    .font(.custom("CEF Fonts CJK Mono", size: 50))
                    .foregroundColor(.black)
                Spacer()
            }
            
            // --- ✨ [新增] 底部按鈕列 ---
            VStack {
                Spacer() // 將按鈕推至底部
                
                HStack {
                    // 學習按鈕
                    BottomTabButton(
                        iconName: "icon-1", title: "", tag: 0,
                        isSelected: selectedTabIndex == 0,
                        action: { selectedTabIndex = 0 }
                    )
                    
                    // 複習按鈕
                    BottomTabButton(
                        iconName: "icon-2", title: "", tag: 1,
                        isSelected: selectedTabIndex == 1,
                        action: { selectedTabIndex = 1 }
                    )
                    
                    // 個人按鈕
                    BottomTabButton(
                        iconName: "icon-3", title: "", tag: 2,
                        isSelected: selectedTabIndex == 2,
                        action: { selectedTabIndex = 2 }
                    )
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(25)
                .padding(.horizontal)
                // ✨ [修改] 增加一點底部間距，避免完全貼齊邊緣
                .padding(.bottom, 0)
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .navigationBarHidden(true)
    }
}

// ✨ [新增] 底部按鈕的獨立 View，讓程式碼更乾淨
struct BottomTabButton: View {
    let iconName: String
    let title: String
    let tag: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                
                Text(title)
                    .font(.custom("CEF Fonts CJK Mono", size: 12))
            }
            // ✨ 根據 isSelected 改變顏色深度
            // 選中時為白色實心，未選中時為半透明
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
// ✨ [主要修改處] 將 chapterMask 輔助函式，重構為一個獨立、完整的 View 結構
struct ChapterMaskView: View {
    @ObservedObject private var dataService = GameDataService.shared
    
    let chapterNumber: Int
    let onChapterSelect: (Int) -> Void
    
    // 動畫狀態儲存在自己的 View 結構中
    @State private var isPulsing = false
    
    var body: some View {
        let isUnlocked = dataService.isChapterUnlocked(chapterNumber)
        let isNew = chapterNumber == dataService.highestUnlockedChapter

        // 使用 Button 取代 .onTapGesture，點擊偵測更精準，解決 Bug
        Button(action: {
            onChapterSelect(chapterNumber)
        }) {
            Image("selecting-\(chapterNumber)")
                .resizable()
                .scaledToFit()
                .overlay(
                    ZStack {
                        if !isUnlocked {
                            // 未解鎖：深灰色遮罩
                            Color.black.opacity(0.785)
                        } else if isNew {
                            // 最新可玩：黃色呼吸光暈
                            Color.white.opacity(isPulsing ? 0.5 : 0.15)
                                .blur(radius: 15)
                        }
                    }
                    .mask(Image("selecting-\(chapterNumber)").resizable().scaledToFit())
                )
        }
        .disabled(!isUnlocked) // 未解鎖的按鈕會被禁用，無法點擊
        // ✨ 使用 onChange 來監聽 isNew 的變化，並在初次顯示時也觸發
        .onChange(of: isNew, initial: true) { _, newValue in
            if newValue {
                // 如果 isNew 變為 true，啟動動畫
                // 加上延遲是為了讓切換效果更自然
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            } else {
                // 如果 isNew 變為 false，移除動畫
                withAnimation {
                    isPulsing = false
                }
            }
        }
    }
}

struct ChapterStatePreview: View {
    @ObservedObject private var dataService = GameDataService.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            ChapterSelectionView { chapter in
                print("Preview: Tapped Chapter \(chapter)")
            }

            // --- ✨ [主要修改處] 預覽專用的控制器 ---
            VStack(spacing: 12) {
                Text("預覽控制器")
                    .font(.headline.weight(.bold))
                
                // 重新設計 Stepper 佈局以適應螢幕寬度
                HStack {
                    Text("最高解鎖章節:")
                    Spacer()
                    // Stepper 現在只顯示數字和按鈕，更緊湊
                    Stepper("\(dataService.highestUnlockedChapter)",
                            value: $dataService.highestUnlockedChapter,
                            in: 1...6) // 範圍 1~5 關 + 1 格看全破狀態
                }
                
                Button(action: {
                    dataService.resetProgress()
                }) {
                    // 將文字和圖示放在一起
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("重置進度 (Reset)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(15)
            .foregroundColor(.white)
            .padding(.horizontal, 100) // 稍微減少 padding 讓面板更小巧
            .padding(.bottom, 10)
        }
    }
}


#Preview {
    ChapterStatePreview()
}
