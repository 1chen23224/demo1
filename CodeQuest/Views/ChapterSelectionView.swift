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

struct ChapterMaskView: View {
    @ObservedObject private var dataService = GameDataService.shared
    
    let chapterNumber: Int
    let onChapterSelect: (Int) -> Void
    
    @State private var isPulsing = false
    @State private var handOffset: CGFloat = 0 // 手指動畫偏移
    @State private var handUp = false
    var body: some View {
        let isUnlocked = dataService.isChapterUnlocked(chapterNumber)
        let isNew = chapterNumber == dataService.highestUnlockedChapter
   

        ZStack {
            // --- 原本的章節按鈕 ---
            Button(action: {
                onChapterSelect(chapterNumber)
            }) {
                Image("selecting-\(chapterNumber)")
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Group {
                            if !isUnlocked {
                                // 未解鎖 = 黑遮罩
                                Color.black.opacity(0.78)
                            } else if isNew {
                                // ✨ 最新解鎖 = 黃色呼吸光暈
                                Color.yellow.opacity(isPulsing ? 1 : 0.3)
                                    .blur(radius: 25)
                                    // ✅ 只針對這層做動畫
                                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                               value: isPulsing)
                                Color.white.opacity(isPulsing ? 0.6 : 0.1) // 外層淡光
                                    .blur(radius: 40)                            }
                        }
                            .mask(Image("selecting-\(chapterNumber)").resizable().scaledToFit())
                    )
            }
            .disabled(!isUnlocked)
            
            
            if isUnlocked && isNew {
                VStack {
                    Image("paw")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .offset(y: handUp ? -20 : 0) // 只上下
                        .onAppear {
                            handUp = true
                        }
                        .onDisappear {
                            handUp = false
                        }
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: handUp
                        )
                        .zIndex(10) // 確保永遠在最上層
                        .allowsHitTesting(false)
                    Spacer().frame(height: 60)
                }
            }else if isUnlocked{
                // 🔢 已解鎖但不是最新章 → 顯示章節數字
                Text("\(chapterNumber)")
                    .font(.custom("CEF Fonts CJK Mono", size: 50))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
                    .offset(x:20,y: -30)
                    .offset(chapterNumber == 4 ? CGSize(width: -95, height: 60) : .zero) // ✅ 第4章換位置
                    .zIndex(10)
                    .allowsHitTesting(false) // 🛡 也不要擋點擊
            }
        }
        // ✅ 只控制 state，不用包 withAnimation
        .onChange(of: isNew, initial: true) { _, newValue in
            isPulsing = newValue
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
