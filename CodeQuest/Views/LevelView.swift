import SwiftUI

struct LevelView: View {
    @Binding var isGameActive: Bool
    @EnvironmentObject var viewModel: GameViewModel

    @State private var selectedOption: String?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [String] = []
    @State private var isImagePopupVisible = false
    @State private var autoClosePopupTask: DispatchWorkItem?
    @State private var comboDisplayVisible = false
    // ... LevelView 的其他狀態變數
    @State private var autoCloseComboTask: DispatchWorkItem?
    // --- Tutorial 狀態 ---
    @State private var tutorialStep: Int? = nil    // nil 表示沒有進行教學
    @State private var showTutorialTip = false

    // --- 答對/答錯動畫狀態 ---
    @State private var feedbackColor: Color? = nil
    @State private var showFeedbackOverlay = false

    private var currentProgress: Double {
        if viewModel.totalQuestions == 0 { return 0 }
        return Double(viewModel.correctlyAnsweredCount) / Double(viewModel.totalQuestions)
    }

    /// 計算當前章節編號
    private var chapterx: Int {
        // 假設 GameDataService.shared.chapterAndStageInChapter(for:)
        // 是一個方法，會回傳一個元組 (章節編號, 章節內關卡編號)
        // 我們只取回傳元組中的第一個值，也就是章節編號
        GameDataService.shared.chapterAndStageInChapter(for: viewModel.currentStage).0
    }

    /// 根據章節編號決定要顯示的角色圖片名稱
    private var characterImageName: String {
        // 取得當前章節編號，並取其與 5 之間的最小值
        // 這樣可以確保角色圖片名稱不會超過 "character5"
        "character\(min(chapterx, 5))"
    }
    

    var body: some View {
        ZStack {
            // --- 主要遊戲畫面 ---
            VStack(spacing: 0) {
                ZStack(alignment: .bottom) {
                    Color(red: 95/255, green: 191/255, blue: 235/255)
                    ScrollingBackgroundView(
                        scrollTrigger: viewModel.score,
                        imageName: backgroundName
                    )
                    .offset(y: 165)
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .clipped()

                ZStack {
                    Image("ground-texture")
                        .resizable()
                        .scaledToFill()
                        .clipped()

                    VStack(spacing: 15) {
                        Spacer()
                        ForEach(viewModel.currentQuestion.options.filter { !$0.isEmpty }, id: \.self) { option in
                            OptionButton(
                                optionText: option,
                                selectedOption: $selectedOption,
                                isSubmitted: $isAnswerSubmitted,
                                correctAnswer: viewModel.currentQuestion.correctAnswer
                            )
                            .modifier(ShakeEffect(attempts: wrongAttempts.filter { $0 == option }.count))
                            .onTapGesture { self.handleTap(on: option) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .offset(y: -10)

                    VStack {
                        ProgressBar(
                            progress: currentProgress,
                            characterImageName: characterImageName,
                            currentQuestion: min(viewModel.correctlyAnsweredCount + 1, max(1, viewModel.totalQuestions)),
                            totalQuestions: viewModel.totalQuestions
                        )
                        .offset(y: -30)
                        Spacer()
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            .edgesIgnoringSafeArea(.all)

            // --- 題目列（左文字 / 右圖示按鈕） ---
            VStack {
                QuestionBar(
                    text: viewModel.currentQuestion.questionText,
                    hasImage: viewModel.currentQuestion.imageName != nil,
                    shouldAnimateIcon: false,
                    showHandHint: false,
                    onImageTap: { openImageFromIcon() }
                )
                .padding(.top, 40)
                .padding(.horizontal)
                Spacer()
            }

            // --- 自動圖片彈窗 ---
            if isImagePopupVisible, let imageName = viewModel.currentQuestion.imageName {
                ImagePopupView(imageName: imageName, isVisible: $isImagePopupVisible)
                    .transition(.scale.combined(with: .opacity))
            }

            // --- 頂部UI ---
            VStack {
                HStack(alignment: .top) {
                    // 左上角
                    HStack(spacing: 16) {
                        Button(action: { self.isGameActive = false }) {
                            Image(systemName: "house.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .shadow(radius: 5)
                        }
                        HintView(
                            keyword: viewModel.currentQuestion.keyword,
                            isHintVisible: viewModel.isHintVisible,
                            action: { viewModel.showHint() }
                        )
                    }
                    Spacer()
                    // 右上角
                    VStack(alignment: .trailing, spacing: 5) {
                        HeartView(lives: viewModel.lives)

                        // 👉 題數顯示放在心心下方
                        Text("第 \(min(viewModel.correctlyAnsweredCount + 1, max(1, viewModel.totalQuestions)))/\(viewModel.totalQuestions) 題")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)

                        // ... 在右上角 VStack 中
                        if comboDisplayVisible {
                            ComboView(combo: viewModel.comboCount)
                                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: viewModel.comboCount)
                                .transition(.opacity) // 讓它淡入淡出
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 34)
                Spacer()
            }

            // --- 結算畫面 ---
            if viewModel.isQuizComplete || viewModel.isGameOver {
                ResultView(
                    stageNumber: viewModel.currentStage,
                    evaluation: viewModel.finalEvaluation,
                    maxCombo: viewModel.maxComboAchieved,
                    correctlyAnswered: viewModel.correctlyAnsweredCount,
                    totalQuestions: viewModel.totalQuestions,
                    backToMenuAction: { self.isGameActive = false }
                )
                .transition(.opacity.animation(.easeIn(duration: 0.5)))
            }

            // --- 答對/答錯色調 Overlay ---
            if showFeedbackOverlay, let color = feedbackColor {
                color.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(99)
            }

            // --- Tutorial Overlay ---
            if let step = tutorialStep {
                TutorialOverlay(step: step) {
                    nextTutorialStep()
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: viewModel.questionRefreshID) { handleNewQuestion() }
        .onChange(of: viewModel.comboCount)
        { _, newComboCount in
            // 如果連對數大於 1，才顯示連對
            if newComboCount > 1 {
                // 先取消舊的計時器，避免衝突
                self.autoCloseComboTask?.cancel()

                // 顯示連對
                withAnimation(.easeIn) {
                    self.comboDisplayVisible = true
                }

                // 設定新的計時器，3 秒後隱藏
                let task = DispatchWorkItem {
                    withAnimation(.easeOut) {
                        self.comboDisplayVisible = false
                    }
                }
                self.autoCloseComboTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
            }
        }
        .onAppear {
            handleNewQuestion()
            // 玩家第一次遊玩 → 啟動教學
            if GameDataService.shared.highestUnlockedStage == 1 {
                tutorialStep = 1
            }
        }
        .gesture(DragGesture(), including: .all)
    }

    private var backgroundName: String { viewModel.backgroundImageName }

    private func handleTap(on option: String) {
        guard !isAnswerSubmitted else { return }
        isAnswerSubmitted = true
        selectedOption = option
        if option != viewModel.currentQuestion.correctAnswer {
            wrongAttempts.append(option)
            triggerFeedback(.red)
        } else {
            triggerFeedback(.green)
        }
        autoClosePopupTask?.cancel()
        viewModel.submitAnswer(option)

        // 教學流程：首次答題後顯示提示
        if tutorialStep == 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                tutorialStep = 5
            }
        }
    }

    // 🎨 觸發答對/答錯顏色特效
    private func triggerFeedback(_ color: Color) {
        feedbackColor = color
        withAnimation(.easeIn(duration: 0.2)) {
            showFeedbackOverlay = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                showFeedbackOverlay = false
            }
        }
    }

    private func openImageFromIcon() {
        if let _ = viewModel.currentQuestion.imageName {
            withAnimation(.spring()) { isImagePopupVisible = true }
        }
    }

    private func handleNewQuestion() {
        isAnswerSubmitted = false
        selectedOption = nil
        autoClosePopupTask?.cancel()

        // 🚀 如果題目有圖片，自動彈窗並在 2.5 秒後關閉
        if let _ = viewModel.currentQuestion.imageName {
            withAnimation(.spring()) {
                isImagePopupVisible = true
            }

            let task = DispatchWorkItem {
                withAnimation {
                    isImagePopupVisible = false
                }
            }
            autoClosePopupTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
        }
    }

    private func nextTutorialStep() {
        if let step = tutorialStep {
            if step < 5{
                tutorialStep = step + 1
            } else {
                tutorialStep = nil

            }
        }
    }
}

// --- Tutorial Overlay 元件 ---
struct TutorialOverlay: View {
    let step: Int
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack {
                switch step {
                case 1:
                    Text("這是你的生命值 ❤️ 和提示 💡\n答錯會扣心，提示能幫助你！")
                        .font(.title2).foregroundColor(.white)
                        .padding()
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(12)
                        .position(x: UIScreen.main.bounds.width - 150, y: 100) // 右上角
                case 2:
                    Text("這裡是題目，按下可顯示圖片，\n請仔細觀察 🖼️")
                        .font(.title2).foregroundColor(.white)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(12)
                        .position(x: UIScreen.main.bounds.width - 180, y: 100) // 右上角
                case 3:
                    Text("從這裡選擇正確答案 ✅\n點擊後會立即知道對錯")
                        .font(.title2).foregroundColor(.white)
                        .padding()
                        .background(Color.orange.opacity(0.8))
                        .cornerRadius(12)
                        .position(x: UIScreen.main.bounds.width - 250, y: 550) // 右上角
                case 4:
                    Text("這裡顯示本關總題數和目前進度\n🚗車子要往終點前進")
                        .font(.title2).foregroundColor(.white)
                        .padding()
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(12)
                case 5:
                    
                    Text("答對了會獲得分數和連擊獎勵 🎉\n答錯會扣生命！")
                        .font(.title2).foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                default:
                    EmptyView()
                }
            }
            .padding()
        }
        .onTapGesture { onNext() }
    }
}

// ------------------ Subviews ------------------

struct ResultView: View {
    let stageNumber: Int
    let evaluation: String
    let maxCombo: Int
    let correctlyAnswered: Int
    let totalQuestions: Int
    let backToMenuAction: () -> Void

    var isBossStage: Bool {
        let (chapter, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stageNumber)
        return stageInChapter == GameDataService.shared.stagesInChapter(chapter)
    }
    var stageText: String {
        let (chapter, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stageNumber)
        if isBossStage {
            return "第 \(chapter) 章最終關"
        } else {
            return "第 \(chapter) 章第 \(stageInChapter) 關"
        }
    }
    
    private let textColor = Color(red: 85/255, green: 65/255, blue: 50/255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
            
            ZStack {
                Image("End")
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(0.5) // 比例縮小 80%
                    .frame(width: 400, height: 800) // 也可以限制一個範圍
                
                
                ZStack {
                    
                    
                    evaluationText()
                        .font(.system(size: 60, weight: .heavy, design: .rounded))
                        .offset(x: 3, y: -3)
                    
                    Text("\(correctlyAnswered) / \(totalQuestions)")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundColor(textColor)
                        .font(.custom("CEF Fonts CJK Mono", size: 26))
                        .offset(x: 3, y: 40)
                    
                    Color.clear
                        .frame(width: 90, height: 50)
                        .contentShape(Rectangle())
                        .offset(y: 120)
                        .onTapGesture {
                            backToMenuAction()
                        }
                }
            }
            .frame(width: 370, height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.4), radius: 20)
        }
    }
    
    @ViewBuilder
    private func comboText() -> some View {
        if evaluation == "S" {
            Text("全部連對")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
        } else {
            Text("\(maxCombo)")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
        }
    }
    
    @ViewBuilder
    private func evaluationText() -> some View {
        let text = Text(evaluation)
        switch evaluation {
        case "S":
            text.foregroundColor(.yellow)
                .font(.custom("CEF Fonts CJK Mono", size: 46))
        case "A":
            text.foregroundColor(.red)
                .font(.custom("CEF Fonts CJK Mono", size: 46))
        default:
            text.foregroundColor(textColor)
            .font(.custom("CEF Fonts CJK Mono", size: 46))
        }
    }
}


struct HintView: View {
    let keyword: String?
    let isHintVisible: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: "lightbulb.fill")
                    .font(.title)
                    .foregroundColor(isHintVisible ? .gray : .yellow)
                    .padding(12)
                    .background(Circle().fill(Color.black.opacity(0.5)))
                    .shadow(radius: 5)
            }
            .disabled(keyword == nil || isHintVisible)

            if isHintVisible, let kw = keyword {
                Text(kw)
                    .font(.custom("CEF Fonts CJK Mono", size: 26))
                    .fontWeight(.heavy)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.8)))
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: isHintVisible)
    }
}

struct HeartView: View {
    let lives: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(index < lives ? Color.red : Color.black.opacity(0.3))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            }
        }
    }
}

struct ComboView: View {
    let combo: Int
    var body: some View {
        if combo >= 2 {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(combo)").font(.system(size: 50, weight: .heavy, design: .rounded)).background(ZStack { Text("\(combo)").font(.system(size: 50, weight: .heavy, design: .rounded)).offset(x: 2, y: 2).foregroundColor(.black.opacity(0.6)); Text("\(combo)").font(.system(size: 50, weight: .heavy, design: .rounded)).offset(x: -2, y: -2).foregroundColor(.black.opacity(0.6)) }).foregroundStyle(LinearGradient(gradient: Gradient(colors: [.white, .white, .orange]), startPoint: .top, endPoint: .bottom)).shadow(color: .black.opacity(0.5), radius: 3, x: 4, y: 4)
                    .allowsHitTesting(false)
                Text("連對").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.7), radius: 2).padding(.leading, 4).offset(y: -5)
                    .allowsHitTesting(false)
            }.transition(.asymmetric(insertion: .scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity), removal: .scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity).animation(.easeOut(duration: 0.3))))
                .offset(x: 14) // 👈 向右移 40pt
        }
    }
}
struct ImagePopupView: View {
    let imageName: String
    @Binding var isVisible: Bool
    
    // 縮放 & 拖曳狀態
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 最大最小縮放
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        ZStack {
            // --- 點擊黑色背景關閉 ---
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        isVisible = false
                    }
                }
            
            VStack {
                Spacer()
                
                GeometryReader { geo in
                    Image(imageName)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.yellow, lineWidth: 4)
                        )
                        .padding(.horizontal, 35)
                        .padding(.top, 120)
                        
                        // 縮放 & 拖曳
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                // 捏合縮放
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        scale *= delta
                                        scale = min(max(scale, minScale), maxScale) // 限制範圍
                                        lastScale = value
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale <= minScale {
                                            withAnimation {
                                                scale = minScale
                                                offset = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    },
                                
                                // 拖曳平移 + 慣性滑動
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { value in
                                        // 慣性滑動
                                        let velocity = value.predictedEndTranslation
                                        let predicted = CGSize(
                                            width: lastOffset.width + velocity.width,
                                            height: lastOffset.height + velocity.height
                                        )
                                        
                                        withAnimation(.easeOut(duration: 0.5)) {
                                            offset = predicted
                                        }
                                        
                                        // 限制邊界 + 回彈
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                offset = boundedOffset(for: offset, in: geo.size)
                                                lastOffset = offset
                                            }
                                        }
                                    }
                            )
                        )
                        // 雙擊放大縮小
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                }
                
                Spacer()
                
            }
        }
    }
    
    // 限制圖片偏移範圍，避免拖太遠
    private func boundedOffset(for offset: CGSize, in size: CGSize) -> CGSize {
        let maxX = (scale - 1) * size.width / 2
        let maxY = (scale - 1) * size.height / 2
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}

struct QuestionBar: View {
    let text: String
    let hasImage: Bool
    let shouldAnimateIcon: Bool
    let showHandHint: Bool
    let onImageTap: () -> Void
    
    @State private var pressPulse = false
    @State private var breath = false
    @State private var showImageHint = false
    
    var body: some View {
        VStack(spacing: 8) {
            // --- 題目區塊 ---
            HStack(alignment: .center, spacing: 12) {
                
                // 題目文字 (自動換行 + 捲動)
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text)
                        .font(.custom("CEF Fonts CJK Mono", size: 22))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                }
                .frame(maxHeight: 120)
                .padding(.leading, 8)
                
                // 圖片按鈕
                if hasImage {
                    ZStack(alignment: .topTrailing) {
                        Button(action: {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressPulse = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { pressPulse = false }
                            }
                            onImageTap()
                            
                            // 顯示提示文字 5 秒
                            showImageHint = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                withAnimation { showImageHint = false }
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Circle().fill(Color.black.opacity(0.35)))
                                    .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                                    .scaleEffect(pressPulse ? 1.1 : (shouldAnimateIcon || breath ? 1.08 : 1.0))
                                Text("查看圖片")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if shouldAnimateIcon {
                                withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                                    breath = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    withAnimation(.easeOut(duration: 0.2)) { breath = false }
                                }
                            }
                        }
                        
                        if showHandHint {
                            Text("👆")
                                .font(.system(size: 20))
                                .offset(x: 6, y: -18)
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .shadow(radius: 5)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.3)
            
            // --- 圖片提示文字 ---
            if showImageHint {
                Text("可隨時點 🖼️ 圖示重看圖片")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.yellow)
                    .padding(.top, -100)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut, value: showImageHint)
    }
}

// ------------------ ProgressBar（不再顯示題數） ------------------

struct ProgressBar: View {
    let progress: Double
    let characterImageName: String
    let currentQuestion: Int
    let totalQuestions: Int
    
    private let barWidth: CGFloat = 380
    private let barHeight: CGFloat = 12
    private let characterSize: CGFloat = 70
    
    private var gradient: LinearGradient {
        let colors: [Color]
        switch progress {
        case 0..<0.34:
            colors = [.red, .orange]
        case 0.34..<0.67:
            colors = [.orange, .yellow]
        default:
            colors = [.yellow, .green]
        }
        return LinearGradient(gradient: Gradient(colors: colors),
                              startPoint: .leading,
                              endPoint: .trailing)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.black.opacity(0.5))
                .frame(width: barWidth, height: barHeight)
            
            Capsule()
                .fill(gradient)
                .frame(width: barWidth * progress, height: barHeight)
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            Image(characterImageName)
                .resizable()
                .scaledToFit()
                .frame(width: characterSize, height: characterSize)
                .offset(y: -characterSize / 3.3 + barHeight / 2)
                .offset(x: barWidth * progress - (characterSize / 2))
        }
        .frame(width: barWidth, height: characterSize)
        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: progress)
    }
}

struct OptionButton: View {
    let optionText: String
    @Binding var selectedOption: String?
    @Binding var isSubmitted: Bool
    let correctAnswer: String
    var body: some View {
        Image("option-button-bg").resizable().scaledToFit().frame(height: 90).cornerRadius(15).overlay(
            Text(optionText).font(.custom("CEF Fonts CJK Mono", size: 26)).fontWeight(.heavy).foregroundColor(Color(red: 60/255, green: 40/255, blue: 40/255)).multilineTextAlignment(.center).minimumScaleFactor(0.5).padding(.vertical, 15).padding(.horizontal, 30)
        ).opacity(buttonOpacity).shadow(color: buttonColor.opacity(0.8), radius: 10).scaleEffect(isSubmitted && optionText == selectedOption ? 1.05 : 1.0).animation(.spring(response: 0.4, dampingFraction: 0.5), value: selectedOption)
    }
    private var buttonColor: Color {
        guard isSubmitted, let selected = selectedOption, optionText == selected else { return .clear }
        return selected == correctAnswer ? .green : .red
    }
    private var buttonOpacity: Double {
        guard isSubmitted else { return 1.0 }
        guard let selected = selectedOption else { return 1.0 }
        if optionText == selected { return 1.0 }
        return 0.5
    }
}

#Preview {
    ContentView()
}
