import SwiftUI
// ✨ NEW: 定義提示按鈕的三種狀態，讓 UI 邏輯更清晰
enum HintState {
    case available      // 可用
    case activeOnQuestion // 在本題已啟用
    case disabled       // 本關已用完
}

struct LevelView: View {
    @Binding var isGameActive: Bool
    @EnvironmentObject var viewModel: GameViewModel
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var selectedOption: String?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [String] = []
    @State private var isImagePopupVisible = false
    @State private var autoClosePopupTask: DispatchWorkItem?
    @State private var comboDisplayVisible = false
    @State private var autoCloseComboTask: DispatchWorkItem?
    // --- Tutorial 狀態 ---
    @State private var tutorialStep: Int? = nil    // nil 表示沒有進行教學
    @State private var showTutorialTip = false
    
    // --- 答對/答錯動畫狀態 ---
    @State private var feedbackColor: Color? = nil
    @State private var showFeedbackOverlay = false
    
    @State private var glowingOption: String? = nil
    // ✨ NEW: 定義自適應的按鈕間距
    private var buttonSpacing: CGFloat {
        sizeClass == .regular ? 25 : 18 // iPad 間距 25, iPhone 間距 15
    }
    // ✨ NEW: 計算當前的提示狀態
    private var hintState: HintState {
        if !viewModel.canUseHint {
            return .disabled //  viewModel 說本關沒次數了 -> 禁用
        }
        if glowingOption != nil {
            return .activeOnQuestion // 本題已經有選項在發光了 -> 暫時失效
        }
        return .available // 其他情況 -> 可用
    }
    
    private var currentProgress: Double {
        if viewModel.totalQuestions == 0 { return 0 }
        return Double(viewModel.correctlyAnsweredCount) / Double(viewModel.totalQuestions)
    }
    
    /// 計算當前章節編號
    private var chapterx: Int {
        GameDataService.shared.chapterAndStageInChapter(for: viewModel.currentStage).0
    }
    
    /// 根據章節編號決定要顯示的角色圖片名稱
    private var characterImageName: String {
        "character\(min(chapterx, 5))"
    }
    
    // ✨ NEW: 根據裝置類型決定垂直偏移量
    private var verticalOffset: CGFloat {
        if sizeClass == .regular { // 如果是 iPad
            return -5 // iPad 向上移動 80 點
        } else { // 如果是 iPhone
            return -10 // iPhone 向上移動 40 點
        }
    }
    var body: some View {
        // ⭐️ 將 GeometryReader 作為最外層的視圖，獲取整個螢幕的真實尺寸
        GeometryReader { geometry in
            ZStack {
                // --- 主要遊戲畫面 (天空 & 地面) ---
                VStack(spacing: 0) {
                    // --- 天空部分 ---
                    ZStack {
                        Color(red: 95/255, green: 191/255, blue: 235/255)
                        ScrollingBackgroundView(
                            scrollTrigger: viewModel.correctlyAnsweredCount + 1,
                            
                            imageName: backgroundName
                        )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.4) // ✨ 基於全螢幕高度計算
                    .clipped()
                    .zIndex(1)
                    
                    // --- 地面部分 ---
                    ZStack {
                        // 地面紋理
                        Image("ground-texture")
                            .resizable()
                            .scaledToFill()
                            .clipped()
                        
                        // --- 選項按鈕 ---
                        VStack(spacing: buttonSpacing) {
                            Spacer()
                            ForEach(viewModel.currentQuestion.options.filter { !$0.isEmpty }, id: \.self) { option in
                                OptionButton(
                                    optionText: option,
                                    selectedOption: $selectedOption,
                                    isSubmitted: $isAnswerSubmitted,
                                    correctAnswer: viewModel.currentQuestion.correctAnswer,
                                    glowingOption: glowingOption
                                )
                                .modifier(ShakeEffect(attempts: wrongAttempts.filter { $0 == option }.count))
                                .onTapGesture { self.handleTap(on: option) }
                            }
                            Spacer()
                                
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // ✨ CORRECTED LINE
                        
                        .padding(.horizontal, sizeClass == .regular ? 80 : 22)
                        
                        .offset(y: verticalOffset) // ✨ 使用自適應的偏移量變數
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.6)
                    .clipped() // 順便加上 .clipped() 確保內容不會溢出
                }
                    // --- 進度條 (天空與地面的交界處) ---
                    ProgressBar(
                        progress: currentProgress,
                        characterImageName: characterImageName,
                        currentQuestion: min(viewModel.correctlyAnsweredCount + 1, max(1, viewModel.totalQuestions)),
                        totalQuestions: viewModel.totalQuestions
                    )
                    .position(
                        x: geometry.size.width / 2,
                        y: geometry.size.height * 0.4
                    )
                    .zIndex(2) // 確保在最上層
                    
                    // --- 題目列（最上層 UI） ---
                    Color.clear // 透明背景，僅用於附加 .safeAreaInset
                        .safeAreaInset(edge: .top) {
                            QuestionBar(
                                text: viewModel.currentQuestion.questionText,
                                // 舊的寫法：
                                // hasImage: viewModel.currentQuestion.imageName != nil,
                                // ✨ 新的寫法：
                                imageName: viewModel.currentQuestion.imageName,
                                shouldAnimateIcon: false,
                                showHandHint: false,
                                onImageTap: { openImageFromIcon() }
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 60)
                        }
                    
                    // --- 自動圖片彈窗 ---
                    if isImagePopupVisible, let imageName = viewModel.currentQuestion.imageName {
                        ImagePopupView(imageName: imageName, isVisible: $isImagePopupVisible)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    // --- 頂部UI (按鈕, 愛心等) ---
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
                                    state: hintState,
                                    remainingCount: viewModel.hintsRemaining,
                                    action: { useHint() }
                                )
                            }
                            Spacer()
                            // 右上角
                            VStack(alignment: .trailing, spacing: 5) {
                                HeartView(lives: viewModel.lives)
                                
                                Text("第 \(min(viewModel.correctlyAnsweredCount + 1, max(1, viewModel.totalQuestions)))/\(viewModel.totalQuestions) 題")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(8)
                                
                                if comboDisplayVisible {
                                    ComboView(combo: viewModel.comboCount)
                                        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: viewModel.comboCount)
                                        .transition(.opacity)
                                }
                            }
                        }
                        // 將 padding 應用到安全區域內，避免按鈕被瀏海遮擋
                        .padding(.top, geometry.safeAreaInsets.top + 60)
                        .padding(.horizontal, 10)
                        
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
                            backToMenuAction: {
                                viewModel.resetFlagsForNewGame() // ✨ 在返回主選單前重置
                                self.isGameActive = false
                            }
                            
                        )
                        .transition(.opacity.animation(.easeIn(duration: 0.5)))
                    }
                    
                    // --- 答對/答錯色調 Overlay ---
                    if showFeedbackOverlay, let color = feedbackColor {
                        color.opacity(0.35)
                            .transition(.opacity)
                            .zIndex(99)
                    }
                    
                    // --- Tutorial Overlay ---
                    if let step = tutorialStep {
                        TutorialOverlay(step: step) {
                            nextTutorialStep()
                        }
                        .zIndex(100) // 確保教學層在最最最上層
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .edgesIgnoringSafeArea(.all) // 確保 GeometryReader 佔滿整個螢幕
        // This handles changes AFTER the view has appeared
        .onChange(of: viewModel.questionRefreshID) { _ in
            handleNewQuestion()
        }
            .onChange(of: viewModel.comboCount) { newComboCount in
                if newComboCount > 1 {
                    self.autoCloseComboTask?.cancel()
                    withAnimation(.easeIn) {
                        self.comboDisplayVisible = true
                    }
                    let task = DispatchWorkItem {
                        withAnimation(.easeOut) {
                            self.comboDisplayVisible = false
                        }
                    }
                    self.autoCloseComboTask = task
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
                }
            }
        // ✨ 合併兩個 .onAppear
        .onAppear {
            handleNewQuestion()
            if GameDataService.shared.highestUnlockedStage == 1 {
                tutorialStep = 1
            }
        }
        .gesture(DragGesture(), including: .all)
    }
        
        // ... [所有 private func 保持不變] ...
        private var backgroundName: String { viewModel.backgroundImageName }
        
        private func useHint() {
            guard hintState == .available else { return }
            if viewModel.useHint() {
                withAnimation(.easeInOut(duration: 0.5)) {
                    glowingOption = viewModel.currentQuestion.correctAnswer
                }
            }
        }
        
        private func handleTap(on option: String) {
            guard !isAnswerSubmitted else { return }
            isAnswerSubmitted = true
            selectedOption = option
            glowingOption = nil
            if option != viewModel.currentQuestion.correctAnswer {
                wrongAttempts.append(option)
                triggerFeedback(.red)
            } else {
                triggerFeedback(.green)
            }
            autoClosePopupTask?.cancel()
            viewModel.submitAnswer(option)
            if tutorialStep == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tutorialStep = 5
                }
            }
        }
        
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
            glowingOption = nil
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
// 🔧 MODIFIED: 全面重構 TutorialOverlay，改用自適應佈局並修復錯位問題
struct TutorialOverlay: View {
    let step: Int
    let onNext: () -> Void
    
    // ✨ NEW: 引入 sizeClass 來讓提示框在 iPad 上可以更寬
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // ✨ NEW: 讓提示框的最大寬度自適應
    private var tipMaxWidth: CGFloat {
        sizeClass == .regular ? 450 : 300
    }
    
    var body: some View {
        // 使用 ZStack 的 alignment 特性來定位，而不是寫死的 .position()
        ZStack {
            // 背景遮罩，點擊它會觸發 onNext()
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { onNext() }

            // 使用 GeometryReader 來獲取安全區域的邊距，讓定位更精準
            GeometryReader { geometry in
                switch step {
                case 1:
                    // 定位在右上角
                    tipView(text: "這是你的生命值 ❤️ 和提示 💡答錯會扣心，提示能幫助你！", color: .blue)
                        .padding(.top, geometry.safeAreaInsets.top + 80)
                        .padding(.trailing)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        
                case 2:
                    // 定位在上方中央
                    tipView(text: "這裡是題目，按下可顯示圖片，請仔細觀察 🖼️", color: .green)
                        .padding(.top, geometry.safeAreaInsets.top + 180)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                case 3:
                     // 定位在下方
                    tipView(text: "從這裡選擇正確答案 ✅\n點擊後會立即知道對錯", color: .orange)
                        .padding(.bottom, geometry.safeAreaInsets.bottom + 250) // 從底部安全區往上推
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        
                case 4:
                    // 定位在畫面中央
                    tipView(text: "這裡顯示本關總題數和目前進度\n🚗車子要往終點前進", color: .purple)
                        .padding(.top, geometry.safeAreaInsets.top + 400)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    
                case 5:
                    // 定位在上方（略低於題目）
                    tipView(text: "答對了會獲得分數和連擊獎勵 🎉\n答錯會扣生命！", color: .red)
                        .padding(.top, geometry.safeAreaInsets.top + 350)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        
                default:
                    EmptyView()
                }
            }
            // 讓 GeometryReader 本身不接收點擊，這樣點擊才能穿透到底下的背景遮罩
            .allowsHitTesting(false)
        }
    }
    
    // ✨ NEW: 將重複的 Text 樣式提取成一個輔助 View，方便管理
    @ViewBuilder
    private func tipView(text: String, color: Color) -> some View {
        Text(text)
            .font(.title2)
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: tipMaxWidth) // 使用自適應寬度
            .background(color.opacity(0.9))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 10)
    }
}
    
    // ------------------ Subviews ------------------
    
// 🔧 MODIFIED: 進一步優化 ResultView 的高度適應性，特別是在 iPhone 上
struct ResultView: View {
    let stageNumber: Int
    let evaluation: String
    let maxCombo: Int
    let correctlyAnswered: Int
    let totalQuestions: Int
    let backToMenuAction: () -> Void
    
    @Environment(\.horizontalSizeClass) var sizeClass


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
    
    // ✨ UPDATED & NEW: 自適應的尺寸變數
    private var cardMaxWidth: CGFloat {
        sizeClass == .regular ? 550 : 370 // iPad 550, iPhone 370
    }
    private var cardMaxHeight: CGFloat {
        // ✨ NEW: 增加最大高度限制，確保在 iPhone 上不會過高
        sizeClass == .regular ? 650 : 550 // iPad 最大 650, iPhone 最大 550
    }
    private var evaluationFontSize: CGFloat {
        sizeClass == .regular ? 90 : 60
    }
    private var scoreFontSize: CGFloat {
        sizeClass == .regular ? 40 : 27
    }
    private var evaluationTextFontSize: CGFloat {
        sizeClass == .regular ? 64 : 46
    }
    private var buttonOffsetY: CGFloat {
        sizeClass == .regular ? 180 : 120
    }
    private var verticalContentPadding: CGFloat {
        // ✨ UPDATED: 垂直 padding 在 iPhone 上更小
        sizeClass == .regular ? 60 : 30 // iPad 60, iPhone 30
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
            
            GeometryReader { geometry in // ✨ NEW: 再次引入 GeometryReader 以便使用其尺寸
                ZStack {
                    // 文字內容
                    evaluationText()
                        .font(.system(size: evaluationFontSize, weight: .heavy, design: .rounded))
                        .offset(x: 3, y: -3)
                    
                    Text("\(correctlyAnswered) / \(totalQuestions)")
                        .font(.system(size: scoreFontSize, weight: .heavy, design: .rounded))
                        .foregroundColor(textColor)
                        .font(.custom("CEF Fonts CJK Mono", size: scoreFontSize))
                        .offset(x: 3, y: sizeClass == .regular ? 70 : 40)
                    
                    // 返回按鈕的點擊區域
                    Color.clear
                        .frame(width: 90, height: 50)
                        .contentShape(Rectangle())
                        .offset(y: buttonOffsetY)
                        .onTapGesture {
                            backToMenuAction()
                        }
                }
                // ✨ UPDATED: 使用新的 verticalContentPadding
                .padding(.vertical, verticalContentPadding)
                // ✨ NEW: 同時限制 maxWidth 和 maxHeight
                .frame(maxWidth: cardMaxWidth, maxHeight: cardMaxHeight)
                // ✨ NEW: 使用 .aspectRatio 確保背景圖片在框內盡量顯示
                .background(
                    Image("End")
                        .resizable()
                        .scaledToFit() // ✨ 從 .scaledToFill() 改為 .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // 確保圖片填滿背景區塊
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(color: .black.opacity(0.4), radius: 20)
                // ✨ NEW: 將整個 ResultView 居中顯示
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }.zIndex(10)
    }

    @ViewBuilder
    private func evaluationText() -> some View {
        let text = Text(evaluation)
        switch evaluation {
        case "S":
            text.foregroundColor(.yellow)
                .font(.custom("CEF Fonts CJK Mono", size: evaluationTextFontSize))
        case "A":
            text.foregroundColor(.red)
                .font(.custom("CEF Fonts CJK Mono", size: evaluationTextFontSize))
        default:
            text.foregroundColor(textColor)
                .font(.custom("CEF Fonts CJK Mono", size: evaluationTextFontSize))
        }
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
// 🔧 MODIFIED: 全面重構 ImagePopupView 以完美適應 iPhone 和 iPad
struct ImagePopupView: View {
    let imageName: String
    @Binding var isVisible: Bool
    
    // ✨ NEW: 引入 sizeClass 來判斷裝置
    @Environment(\.horizontalSizeClass) var sizeClass
    
    // --- 手勢狀態保持不變 ---
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    // ✨ NEW: 根據裝置決定彈窗的垂直偏移量
    private var popupVerticalOffset: CGFloat {
        if sizeClass == .regular { // 如果是 iPad
            return -350 // iPad 向上移動 80 點
        } else { // 如果是 iPhone
            return -210 // iPhone 向上移動 40 點
        }
    }
    // ✨ NEW: 根據裝置決定彈窗的外部邊距，這是控制大小的關鍵
    private var adaptivePadding: CGFloat {
        // 在 iPad (regular) 上設置較大的邊距，讓彈窗內容集中在中間
        // 在 iPhone (compact) 上則用較小的邊距
        return sizeClass == .regular ? 220 : 50
    }
    
    var body: some View {
        // ✨ CHANGED: 簡化整體佈局，直接使用 ZStack 置中
        ZStack {
            
            // 背景遮罩 (不變)
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring()) {
                        isVisible = false
                    }
                }

            // --- 彈窗內容 ---
            // 移除了 VStack, Spacer 和內層的 GeometryReader
            Image(imageName)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                // 移除固定的 .frame(maxWidth: 300, maxHeight: 300)
                .padding() // 這是圖片與白色背景之間的內部間距
                .background(Color.white)
                .cornerRadius(16)
                .shadow(radius: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.yellow, lineWidth: 4)
                )
                // ✨ 使用自適應的外部邊距來控制彈窗的整體大小和位置
                .padding(adaptivePadding)
                .offset(y: popupVerticalOffset)
            // --- 將手勢直接應用於圖片彈窗上 ---
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        // 捏合縮放
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                scale *= delta
                                scale = min(max(scale, minScale), maxScale)
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
                        
                        // 拖曳平移
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { value in
                                lastOffset = offset // 更新最後的偏移量
                                // 拖曳邊界回彈效果 (需要 GeometryReader，我們在 ZStack 外層補上)
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
        .allowsHitTesting(isVisible)
        .zIndex(3)
        // 讓彈窗的出現和消失有動畫效果
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .animation(.spring(), value: isVisible)
    }
    
    // ... boundedOffset 函數保持不變 ...
    private func boundedOffset(for offset: CGSize, in size: CGSize) -> CGSize {
        let maxX = (scale - 1) * size.width / 2
        let maxY = (scale - 1) * size.height / 2
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }
}
    // 🔧 MODIFIED: 大幅更新 HintView，讓它能顯示不同狀態和計數
    struct HintView: View {
        let state: HintState
        let remainingCount: Int
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                ZStack {
                    // --- 按鈕背景 ---
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 50, height: 50)
                        .shadow(color: shadowColor.opacity(0.5), radius: 5)
                    
                    // --- 圖示 ---
                    Image(systemName: iconName)
                        .font(.title)
                        .foregroundColor(iconColor)
                    
                    // --- 剩餘次數計數 ---
                    if state == .available && remainingCount > 0 {
                        Text("\(remainingCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Color.white))
                            .offset(x: 18, y: -18)
                            .transition(.scale.animation(.spring()))
                    }
                }
            }
            // ✨ NEW: 根據狀態決定按鈕是否可點擊
            .disabled(state != .available)
            .animation(.spring(), value: state)
        }
        
        // --- 根據狀態決定圖示 ---
        private var iconName: String {
            switch state {
            case .available:
                return "lightbulb.fill"
            case .activeOnQuestion:
                return "lightbulb.fill" // 已啟用時圖示不變，但顏色會變
            case .disabled:
                return "lightbulb.slash" // 用完時顯示劃掉的圖示
            }
        }
        
        // --- 根據狀態決定圖示和陰影顏色 ---
        private var iconColor: Color {
            switch state {
            case .available:
                return .yellow
            case .activeOnQuestion, .disabled:
                return .gray.opacity(0.7)
            }
        }
        
        private var shadowColor: Color {
            state == .available ? .yellow : .clear
        }
    }
    
// 🔧 MODIFIED: 將「查看圖片」按鈕改為圖片預覽
struct QuestionBar: View {
    let text: String
    // ✨ STEP 1: 修改傳入的參數，從 Bool 改為可選的 String
    let imageName: String?
    let shouldAnimateIcon: Bool
    let showHandHint: Bool
    let onImageTap: () -> Void
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    @State private var pressPulse = false
    @State private var breath = false
    @State private var showImageHint = false
    
    private var questionFontSize: CGFloat {
        return sizeClass == .regular ? 32 : 22
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                
                // 題目文字 (自動換行 + 捲動) - 這部分不變
                ScrollView(.vertical, showsIndicators: false) {
                    Text(text)
                        .font(.custom("CEF Fonts CJK Mono", size: questionFontSize))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                }
                .frame(maxHeight: 120)
                .padding(.leading, 8)
                
                // ✨ STEP 2: 修改條件判斷，從 if hasImage 改為 if let
                if let imageName = imageName {
                    // ✨ STEP 3: 這是核心改動！用實際圖片預覽取代舊的圖示和文字
                    Button(action: {
                        // 按鈕的點擊動畫邏輯保持不變
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { pressPulse = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { pressPulse = false }
                        }
                        onImageTap()
                        
                        showImageHint = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                            withAnimation { showImageHint = false }
                        }
                    }) {
                        // --- 新的圖片預覽 UI ---
                        Image(imageName) // 直接使用傳入的圖片名稱
                            .resizable()
                            .scaledToFit()
                            .frame(width: sizeClass == .regular ? 200 : 110,
                                   height: sizeClass == .regular ? 200 : 110) // 給定一個固定的縮圖大小
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                            .scaleEffect(pressPulse ? 1.1 : (shouldAnimateIcon || breath ? 1.08 : 1.0))
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // 動畫邏輯保持不變
                        if shouldAnimateIcon {
                            withAnimation(.easeInOut(duration: 0.8).repeatCount(2, autoreverses: true)) {
                                breath = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.2)) { breath = false }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.85))
            .cornerRadius(20)
            .shadow(radius: 5)
            .frame(maxHeight: UIScreen.main.bounds.height * 0.3)
        }
    }
}
    
    // ------------------ ProgressBar（不再顯示題數） ------------------
    
    struct ProgressBar: View {
        let progress: Double
        let characterImageName: String
        let currentQuestion: Int
        let totalQuestions: Int
        
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
            GeometryReader { geo in
                let barWidth = geo.size.width
                
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
                .frame(height: characterSize)
            }
            .frame(height: characterSize) // 記得給高度，否則 GeometryReader 會佔滿整個螢幕
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: progress)
        }
    }
    
// 🔧 MODIFIED: 直接控制選項方塊的上下高度，並為 iPhone/iPad 設定不同值
struct OptionButton: View {
    let optionText: String
    @Binding var selectedOption: String?
    @Binding var isSubmitted: Bool
    let correctAnswer: String
    let glowingOption: String?

    @Environment(\.horizontalSizeClass) var sizeClass

    private var isGlowing: Bool {
        glowingOption == optionText && !isSubmitted
    }

    // ✨ NEW: 定義一個自適應的高度值
    // 您可以自由調整這兩個數字來達到最理想的視覺效果
    private var adaptiveHeight: CGFloat {
        // iPad (regular) 的高度設為 85，iPhone (compact) 設為 70
        return sizeClass == .regular ? 153 : 100
    }

    // ✨ NEW: iPad 上的字體也稍微調整以適應新的按鈕高度
    private var fontSize: CGFloat {
        return sizeClass == .regular ? 42 : 33
    }
    
    var body: some View {
        // ✨ CHANGED: 核心修改部分
        Image("option-button-bg")
            .resizable()
            // 1. 改用 scaledToFill，讓背景圖填滿框架而不是按比例縮放
            .scaledToFill()
            // 2. 使用我們上面定義的自適應高度
            .frame(height: adaptiveHeight)
            // 3. 加上圓角和裁切，確保背景圖不會超出按鈕範圍
            .cornerRadius(15)
            .clipped()
            .overlay(
                Text(optionText)
                    .font(.custom("CEF Fonts CJK Mono", size: fontSize))
                    .fontWeight(.heavy)
                    .foregroundColor(Color(red: 60/255, green: 40/255, blue: 40/255))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.3)
                    .padding(.vertical, 15)
                    .padding(.horizontal, sizeClass == .regular ? 40 : 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.yellow, lineWidth: isGlowing ? 4 : 0)
                    .shadow(color: .yellow.opacity(0.8), radius: isGlowing ? 10 : 0)
                    
            )
            .opacity(buttonOpacity)
            .shadow(color: buttonColor.opacity(0.8), radius: 10)
            .scaleEffect(isSubmitted && optionText == selectedOption ? 1.05 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: selectedOption)
            .animation(.easeInOut(duration: 0.5), value: isGlowing)
            .padding(.horizontal, 30)
    }

    // ... [buttonColor 和 buttonOpacity 保持不變] ...
    private var buttonColor: Color {
        guard isSubmitted, let selected = selectedOption, optionText == selected else { return .clear }
        return selected == correctAnswer ? .green : .red
    }
    
    private var buttonOpacity: Double {
        if isSubmitted {
            guard let selected = selectedOption else { return 1.0 }
            return optionText == selected ? 1.0 : 0.5
        }
        
        if let glowing = glowingOption {
            return optionText == glowing ? 1.0 : 0.7
        }
        
        return 1.0
    }
}
#Preview {
    ContentView()
}
