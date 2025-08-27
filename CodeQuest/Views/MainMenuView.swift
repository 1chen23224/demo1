import SwiftUI

struct MainMenuView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var showingDetailForStage: Int? = nil

    // --- ✨ 過場動畫狀態 ---
    @State private var showTransitionOverlay = false
    @State private var overlayOpacity: Double = 1.0
    @State private var textOpacity: Double = 0.0   // 文字透明度
    @State private var pendingStage: Int? = nil

    // --- ✨ 新手教學狀態 ---
    @State private var showTutorial = false
    @State private var tutorialStep = 0
    @State private var arrowOffset: CGFloat = -80

    @State private var dimBackground = true
    @State private var tutorialTextAtBottom = false

    // --- ✨ 新增：過關祝賀 ---
    @State private var showCongrats = false

    // MainMenuView 需要知道它是第幾章
    let chapterNumber: Int

    let onStageSelect: (Int) -> Void
    let onBack: () -> Void
    
    // 👇 新增：傳出過場狀態給 GameNavigationView
    @Binding var isOverlayActive: Bool
    
    
    private var stagesForThisChapter: Range<Int> {
        let totalBefore = dataService.chapterStageCounts.prefix(chapterNumber - 1).reduce(0, +)
        let chapterSize = dataService.stagesInChapter(chapterNumber)
        let startStage = totalBefore + 1
        let endStage = totalBefore + chapterSize
        return startStage..<(endStage + 1)
    }

    var body: some View {
        ZStack {
            // --- 背景 ---
            Image("stage-background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            // --- 主內容 ---
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
                                    ZStack {
                                        StageIconView(
                                            stageNumber: stage,
                                            chapterNumber: chapterNumber,
                                            isUnlocked: dataService.isStageUnlocked(stage),
                                            isNew: stage == dataService.highestUnlockedStage,
                                            result: dataService.getResult(for: stage),
                                            action: {
                                                self.showingDetailForStage = stage
                                                if showTutorial && tutorialStep == 1 {
                                                    tutorialStep = 2
                                                }
                                            }
                                        )
                                        .id(stage)
                                    }
                                }
                            }
                            .padding(.horizontal, 80)
                        }
                        .padding(.vertical, 40)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring()) {
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
                        if showTutorial {
                            tutorialStep = 3
                        }
                        self.showingDetailForStage = nil
                        pendingStage = stage
                        showTransitionOverlay = true
                        overlayOpacity = 0.0
                        textOpacity = 0.0
                        
                        withAnimation(.easeIn(duration: 1)) {
                            overlayOpacity = 1.0
                        }
                        withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
                            textOpacity = 1.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            if let stage = pendingStage {
                                onStageSelect(stage)
                            }
                            withAnimation(.easeOut(duration: 1.0)) {
                                overlayOpacity = 0
                                textOpacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showTransitionOverlay = false
                                pendingStage = nil
                                if showTutorial && tutorialStep == 3 {
                                    showTutorial = false
                                }
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
                    let (chapter, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stage)
                    let isBossStage = stageInChapter == GameDataService.shared.stagesInChapter(chapter)
                    
                    Text(isBossStage
                         ? "-第 \(chapter) 章-\n\n\n  最終關"
                         : "-第 \(chapter) 章-\n\n\n  第\(stageInChapter)關")
                    .font(.custom("CEF Fonts CJK Mono", size: 30))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(textOpacity)
                }
            }

        
            // --- ✨ 教學引導 Overlay ---
            if showTutorial {
                Color.black.opacity(dimBackground ? 0.5 : 0.0)
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut(duration: 1.0), value: dimBackground)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    switch tutorialStep {
                    case 0:
                        tutorialTextBox(
                            "🎉 歡迎來到《滿分上路》！\n一起闖關練習，向筆試滿分邁進吧！",
                            buttonTitle: "下一步"
                        ) {
                            tutorialStep = 1
                        }

                    case 1:
                        tutorialTextBox("點擊畫面上的『第 1 關』圖示,\n開始第一個挑戰吧！")
                            .offset(y: tutorialTextAtBottom ? UIScreen.main.bounds.height/2 - 80 : 0)
                            .animation(.easeInOut(duration: 1.0), value: tutorialTextAtBottom)

                        if tutorialTextAtBottom {
                            Image(systemName: "arrow.down")
                                .resizable()
                                .frame(width: 30, height: 50)
                                .foregroundColor(.white)
                                .offset(x:-140,
                                        y: -290)
                        }

                    case 2:
                        tutorialTextBox("這裡會顯示關卡紀錄，點『開始挑戰』就能進入遊戲。")
                            .offset(y: tutorialTextAtBottom ? UIScreen.main.bounds.height/2 - 80 : 0)
                            .animation(.easeInOut(duration: 1.0), value: tutorialTextAtBottom)

                        if tutorialTextAtBottom {
                            Image(systemName: "arrow.down")
                                .resizable()
                                .frame(width: 30, height: 50)
                                .foregroundColor(.white)
                                .offset(x:80,
                                        y: -25)
                        }

                    default:
                        EmptyView()
                    }
                    Spacer()
                }
                .transition(.opacity)
                .onChange(of: tutorialStep) { newValue in
                    if newValue == 1 || newValue == 2 {
                        dimBackground = true
                        tutorialTextAtBottom = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                dimBackground = false
                                tutorialTextAtBottom = true
                            }
                        }
                    }
                }
            }

            // --- ✨ 祝賀畫面 Overlay ---
            if showCongrats {
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    if dataService.highestUnlockedStage == 2 {
                        // 🎉 第一關
                        Text("🎉 恭喜完成第 1 關！")
                            .font(.custom("CEF Fonts CJK Mono", size: 26))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("👏 繼續加油，挑戰更多關卡吧！")
                            .font(.custom("CEF Fonts CJK Mono", size: 20))
                            .foregroundColor(.yellow)

                    } else {
                        let (chapter, _) = dataService.chapterAndStageInChapter(for: dataService.highestUnlockedStage - 1)
                        let totalChapters = dataService.chapterStageCounts.count

                        if chapter == totalChapters {
                            // 🎉 最終章特別祝賀
                            Text("🏆 恭喜通過最終章！")
                                .font(.custom("CEF Fonts CJK Mono", size: 26))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("🎉 你已經完成所有挑戰，太厲害了！")
                                .font(.custom("CEF Fonts CJK Mono", size: 20))
                                .foregroundColor(.yellow)

                        } else {
                            // 🎉 一般章節
                            Text("🎉 恭喜完成第 \(chapter) 章！")
                                .font(.custom("CEF Fonts CJK Mono", size: 26))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("👏 繼續加油，挑戰下一章吧！")
                                .font(.custom("CEF Fonts CJK Mono", size: 20))
                                .foregroundColor(.yellow)
                        }
                    }

                    Button(action: { showCongrats = false }) {
                        Text("繼續前進 🚀")
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
                .padding()
                .transition(.scale.combined(with: .opacity))
            }


        }
        .animation(.spring(), value: showingDetailForStage)
        .onAppear {
            if dataService.highestUnlockedStage <= 1 {
                showTutorial = true
            }

            // ✅ 恭喜完成第 1 關（只顯示一次）
            if dataService.highestUnlockedStage == 2 {
                let shownFirst = UserDefaults.standard.bool(forKey: "shownFirstStageCongrats")
                if !shownFirst {
                    showCongrats = true
                    UserDefaults.standard.set(true, forKey: "shownFirstStageCongrats")
                }
            }

            // ✅ 恭喜完成某章最終關（只顯示一次）
            let justUnlocked = dataService.highestUnlockedStage
            let (chapter, stageInChapter) = dataService.chapterAndStageInChapter(for: justUnlocked - 1)

            if stageInChapter == dataService.stagesInChapter(chapter) {
                var shownChapters = UserDefaults.standard.array(forKey: "shownCongratsChapters") as? [Int] ?? []
                if !shownChapters.contains(chapter) {
                    showCongrats = true
                    shownChapters.append(chapter)
                    UserDefaults.standard.set(shownChapters, forKey: "shownCongratsChapters")
                }
            }
        }
        .onChange(of: showTransitionOverlay) { newValue in
            isOverlayActive = newValue
        }
        
    }

    // --- ✨ 教學文字盒子元件 ---
    @ViewBuilder
    private func tutorialTextBox(_ text: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .font(.custom("CEF Fonts CJK Mono", size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()

            if let buttonTitle = buttonTitle, let action = action {
                Button(buttonTitle, action: action)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
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

    // 章內相對編號
    private var relativeStage: Int {
        let (_, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stageNumber)
        return stageInChapter
    }


    var isReviewStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        let reviewCount = max(1, chapterSize / 6)
        let interval = chapterSize / (reviewCount + 1)
        let reviewStages = Set((1...reviewCount).map { $0 * interval })
        return reviewStages.contains(relativeStage) && relativeStage < chapterSize
    }

    var isBossStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        return relativeStage == chapterSize
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

                Text(isBossStage
                     ? "最終關"
                     : "第\(relativeStage)關")
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

    private var relativeStage: Int {
        let (_, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stageNumber)
        return stageInChapter
    }

    var isReviewStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        let reviewCount = max(1, chapterSize / 6)
        let interval = chapterSize / (reviewCount + 1)
        let reviewStages = Set((1...reviewCount).map { $0 * interval })
        return reviewStages.contains(relativeStage) && relativeStage < chapterSize
    }

    var isBossStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        return relativeStage == chapterSize
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
    @State private var isOverlayActive = false   // 👈 新增
    
    var body: some View {
        MainMenuView(
            chapterNumber: 1,
            onStageSelect: { stageNumber in
                print("Preview: Stage \(stageNumber) was selected.")
            },
            onBack: {
                print("Preview: Back button was tapped.")
            },
            isOverlayActive: $isOverlayActive    // 👈 傳入
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
