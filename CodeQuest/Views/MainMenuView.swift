import SwiftUI

struct MainMenuView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var showingDetailForStage: Int? = nil
    
    // MainMenuView 現在需要知道它是為哪個章節顯示的
    let chapterNumber: Int
    
    let onStageSelect: (Int) -> Void
    
    // ✨ [新增] 接收返回的動作
    let onBack: () -> Void
    
    // 計算這個章節包含哪些關卡 (假設每章 21 關)
    private var stagesForThisChapter: Range<Int> {
        let chapterSize = 21
        let startStage = (chapterNumber - 1) * chapterSize + 1
        let endStage = chapterNumber * chapterSize
        return startStage..<(endStage + 1)
    }

    var body: some View {
        ZStack {
            Image("stage-background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 50) {
                Text("第 \(chapterNumber) 章") // 標題顯示當前章節
                    .font(.custom("CEF Fonts CJK Mono", size: 40))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 5)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        ZStack(alignment: .center) {
                            Capsule()
                                .fill(Color.black.opacity(0.25))
                                .frame(height: 25)
                                .padding(.horizontal, 40)

                            HStack(spacing: 50) {
                                // ForEach 現在遍歷當前章節的關卡
                                ForEach(stagesForThisChapter, id: \.self) { stage in
                                    StageIconView(
                                        stageNumber: stage,
                                        isUnlocked: dataService.isStageUnlocked(stage),
                                        isNew: stage == dataService.highestUnlockedStage,
                                        result: dataService.getResult(for: stage),
                                        action: {
                                            self.showingDetailForStage = stage
                                        }
                                    )
                                    .id(stage)
                                }
                            }
                            .padding(.horizontal, 80)
                        }
                        .padding(.vertical, 40)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring()) {
                                // 自動滾動到這個章節中的最新關卡
                                proxy.scrollTo(dataService.highestUnlockedStage, anchor: .center)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, 60)
            
            // --- ✨ [主要修改處] 全新的返回按鈕設計 ---
            VStack {
                HStack {
                    Button(action: onBack) {
                        ZStack {
                            // 按鈕的底座，模仿木頭或石頭的質感
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .shadow(radius: 5)

                            // 內圈的邊框，增加立體感
                            Circle()
                                .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                                .padding(4)

                            // 返回的箭頭圖示
                            Image(systemName: "arrow.backward")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(width: 44, height: 44) // 標準的點擊目標尺寸
                    }
                    .padding(.horizontal, 65)
                    Spacer()
                }
                Spacer()
            }
            
            if let stage = showingDetailForStage {
                StageDetailView(
                    stageNumber: stage,
                    result: dataService.getResult(for: stage),
                    onStart: {
                        self.showingDetailForStage = nil
                        onStageSelect(stage)
                    },
                    onCancel: {
                        self.showingDetailForStage = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(), value: showingDetailForStage)
    }
}


// ✨ [主要修改處]
struct StageIconView: View {
    let stageNumber: Int
    let isUnlocked: Bool
    let isNew: Bool
    let result: StageResult?
    let action: () -> Void
    
    var isReviewStage: Bool {
        return stageNumber > 0 && stageNumber < 21 && stageNumber % 5 == 0
    }
    
    var isBossStage: Bool {
        return stageNumber == 21
    }
    
    var iconColor: Color {
        if !isUnlocked {
            return Color.gray.opacity(0.6)
        } else if isBossStage {
            return Color.red // 魔王關使用血紅色
        } else if isReviewStage {
            return Color(red: 70/255, green: 175/255, blue: 255/255)
        } else {
            return Color(red: 255/255, green: 180/255, blue: 0)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 4))
                        
                        if isUnlocked {
                            if let res = result {
                                Text(res.evaluation)
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            } else {
                                // ✨ 新的判斷邏輯在這裡 ✨
                                // 如果是魔王關，顯示皇冠
                                if isBossStage {
                                    Image(systemName: "crown.fill")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.white)
                                        .scaledToFit()
                                        .frame(width: 35, height: 35)
                                } else {
                                    // 否則，所有其他新關卡都用回您的自訂圖示
                                    Image("image_8b7251")
                                        .resizable().renderingMode(.template)
                                        .foregroundColor(.white)
                                        .frame(width: 35, height: 35)
                                }
                            }
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundColor(.black.opacity(0.5))
                        }
                    }
                    
                    if isNew && isUnlocked {
                        Text("NEW")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 8, y: -8)
                    }
                }
                
                Text(isBossStage ? "最終關" : "第 \(stageNumber) 關")
                    .font(.custom("CEF Fonts CJK Mono", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .disabled(!isUnlocked)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 8)
        .scaleEffect(isUnlocked ? 1.0 : 0.95)
        .animation(.spring(), value: isUnlocked)
    }
}

struct StageDetailView: View {
    let stageNumber: Int
    let result: StageResult?
    let onStart: () -> Void
    let onCancel: () -> Void
    
    var isBossStage: Bool {
        return stageNumber == 21
    }

    private let textColor = Color(red: 85/255, green: 65/255, blue: 50/255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture(perform: onCancel)
            
            VStack(spacing: 15) {
                Text(isBossStage ? "最終關" : "第 \(stageNumber) 關")
                    .font(.custom("CEF Fonts CJK Mono", size: 30))
                    .bold()
                    .foregroundColor(textColor)
                
                Divider()

                if let res = result {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("👑 最高紀錄").font(.custom("CEF Fonts CJK Mono", size: 20)).bold()
                        Text("評價: \(res.evaluation)")
                        Text("最高連擊: \(res.maxCombo)")
                        Text("答對題數: \(res.correctlyAnswered) / \(res.totalQuestions)")
                    }
                    .font(.custom("CEF Fonts CJK Mono", size: 18))
                    .foregroundColor(textColor)
                } else {
                    Text("尚未挑戰")
                        .font(.custom("CEF Fonts CJK Mono", size: 22))
                        .foregroundColor(.gray)
                        .padding(.vertical, 30)
                }
                
                Divider()
                
                HStack(spacing: 15) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.custom("CEF Fonts CJK Mono", size: 16))
                            .bold().padding().frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.3)).cornerRadius(10)
                    }
                    
                    Button(action: onStart) {
                        Text("開始挑戰")
                            .font(.custom("CEF Fonts CJK Mono", size: 16))
                            .bold().padding().frame(maxWidth: .infinity)
                            .background(Color.blue).cornerRadius(10)
                    }
                }
                .foregroundColor(.white)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(red: 240/255, green: 230/255, blue: 210/255))
                    .shadow(radius: 10)
            )
        }
    }
}

struct InteractiveMenuPreview: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var selectedStage: Int? = nil
    @State private var isGameActive = false

    var body: some View {
        // 這份預覽現在模擬的是「關卡選擇」畫面，而不是章節選擇
        // 所以我們直接建立一個 MainMenuView
        
        // ✨ [主要修改處]
        MainMenuView(
            chapterNumber: 1, // <-- 為預覽提供一個範例章節編號
            onStageSelect: { stageNumber in
                print("Preview: Stage \(stageNumber) was selected.")
                // 在預覽中，我們不實際跳轉，只印出訊息
            },
            // ✨ [修改] 為 Preview 提供一個假的 onBack 動作
            onBack: {
                print("Preview: Back button was tapped.")
            }
        )
        .overlay(alignment: .bottom) {
            HStack {
                // 清除資料的按鈕
                Button(action: { dataService.resetProgress() }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(.white).padding()
                        .background(Color.black.opacity(0.5)).clipShape(Circle())
                }
                Spacer()
                // 快速通關的按鈕
                Button(action: { dataService.unlockAllStages() }) {
                    Image(systemName: "chevron.right.2")
                        .foregroundColor(.white.opacity(0.8)).padding()
                        .background(Color.black.opacity(0.5)).clipShape(Circle())
                }
            }
            .font(.largeTitle)
            .padding()
        }
        .onAppear {
            dataService.objectWillChange.send()
        }
    }
}

#Preview("預設互動模式") {
    InteractiveMenuPreview()
}
