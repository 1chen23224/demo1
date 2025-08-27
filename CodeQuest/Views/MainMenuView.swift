import SwiftUI

struct MainMenuView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var showingDetailForStage: Int? = nil

    // --- ✨ 過場動畫狀態 ---
    @State private var showTransitionOverlay = false
    @State private var overlayOpacity: Double = 1.0
    @State private var textOpacity: Double = 0.0   // 文字透明度
    @State private var pendingStage: Int? = nil

    // MainMenuView 需要知道它是第幾章
    let chapterNumber: Int

    let onStageSelect: (Int) -> Void
    let onBack: () -> Void

    // 計算章節內的關卡範圍 (每章 21 關)
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
                Text("第 \(chapterNumber) 章")
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
                                ForEach(stagesForThisChapter, id: \.self) { stage in
                                    StageIconView(
                                        stageNumber: stage,
                                        chapterNumber: chapterNumber,
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
                                // 如果 highestUnlockedStage 在本章範圍內，會捲動到該 id
                                proxy.scrollTo(dataService.highestUnlockedStage, anchor: .center)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 60)

            // --- 返回按鈕 ---
            VStack {
                HStack {
                    Button(action: onBack) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.3))
                                .shadow(radius: 5)
                            Circle()
                                .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                                .padding(4)
                            Image(systemName: "arrow.backward")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 65)
                    Spacer()
                }
                Spacer()
            }

            // --- 關卡細節彈窗 ---
            if let stage = showingDetailForStage {
                StageDetailView(
                    stageNumber: stage,
                    chapterNumber: chapterNumber,
                    result: dataService.getResult(for: stage),
                    onStart: {
                        // 1. 關閉細節框
                        self.showingDetailForStage = nil
                        pendingStage = stage
                        showTransitionOverlay = true
                        overlayOpacity = 0.0
                        textOpacity = 0.0

                        // Step 1: 黑幕漸入
                        withAnimation(.easeIn(duration: 1)) {
                            overlayOpacity = 1.0
                        }
                        // Step 2: 文字延遲後漸入
                        withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
                            textOpacity = 1.0
                        }

                        // Step 3: 停留 + 進入關卡
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            if let stage = pendingStage {
                                onStageSelect(stage)
                            }

                            // Step 4: 黑幕 + 文字 一起漸出
                            withAnimation(.easeOut(duration: 1.0)) {
                                overlayOpacity = 0
                                textOpacity = 0
                            }

                            // Step 5: 收尾 (動畫結束後馬上移除)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showTransitionOverlay = false
                                pendingStage = nil
                            }
                        }
                    },
                    onCancel: {
                        self.showingDetailForStage = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }

            // --- ✨ 黑幕過場層 ---
            if showTransitionOverlay {
                Color.black
                    .opacity(overlayOpacity)
                    .edgesIgnoringSafeArea(.all)

                if let stage = pendingStage {
                    // 計算章內相對編號
                    let relative = stage - (chapterNumber - 1) * 21
                    let lastStage = chapterNumber * 21
                    Text(stage == lastStage ? "-第 \(chapterNumber) 章-\n\n\n  最終關" : "-第 \(chapterNumber) 章-\n\n\n  第\(relative)關")
                        .font(.custom("CEF Fonts CJK Mono", size: 30))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(textOpacity) // ✨ 只淡入淡出
                }
            }
        }
        .animation(.spring(), value: showingDetailForStage)
    }
}


// ✨ StageIconView
struct StageIconView: View {
    let stageNumber: Int          // 全域編號 (1..N)
    let chapterNumber: Int        // 目前頁面章節
    let isUnlocked: Bool
    let isNew: Bool
    let result: StageResult?
    let action: () -> Void

    // 章內相對編號 (1..21)
    private var relativeStage: Int {
        return stageNumber - (chapterNumber - 1) * 21
    }

    var isReviewStage: Bool {
        let relative = relativeStage
        return relative % 5 == 0 && relative < 21
    }

    var isBossStage: Bool {
        return relativeStage == 21
    }

    var iconColor: Color {
        if !isUnlocked {
            return Color.gray.opacity(0.6)
        } else if isBossStage {
            return Color.red
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
                                if isBossStage {
                                    Image(systemName: "crown.fill")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.white)
                                        .scaledToFit()
                                        .frame(width: 35, height: 35)
                                } else {
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

                Text(isBossStage ? "最終關" : "第 \(relativeStage) 關")
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


// ✨ StageDetailView
struct StageDetailView: View {
    let stageNumber: Int
    let chapterNumber: Int
    let result: StageResult?
    let onStart: () -> Void
    let onCancel: () -> Void

    // 章內相對編號
    private var relativeStage: Int {
        return stageNumber - (chapterNumber - 1) * 21
    }

    var isBossStage: Bool {
        return relativeStage == 21
    }

    private let textColor = Color(red: 85/255, green: 65/255, blue: 50/255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture(perform: onCancel)

            VStack(spacing: 15) {
                Text(isBossStage ? "最終關" : "第 \(relativeStage) 關")
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


// ✨ 預覽
struct InteractiveMenuPreview: View {
    @ObservedObject private var dataService = GameDataService.shared
    var body: some View {
        MainMenuView(
            chapterNumber: 2,
            onStageSelect: { stageNumber in
                print("Preview: Stage \(stageNumber) was selected.")
            },
            onBack: {
                print("Preview: Back button was tapped.")
            }
        )
        .overlay(alignment: .bottom) {
            HStack {
                Button(action: { dataService.resetProgress() }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(.white).padding()
                        .background(Color.black.opacity(0.5)).clipShape(Circle())
                }
                Spacer()
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
