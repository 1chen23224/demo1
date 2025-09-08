import SwiftUI
// In DrawingBoardView.swift, AFTER the main struct
// ✨ NEW: 用於儲存單一筆畫的資料結構
struct DrawingPath: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}
// MARK: - ✨ NEW: 核心繪圖畫布
struct DrawingCanvasView: View {
    @Binding var paths: [DrawingPath]
    @Binding var currentPath: DrawingPath
    
    var body: some View {
        Canvas { context, size in
            // 繪製所有已完成的路徑
            for path in paths {
                var pathObject = Path()
                pathObject.addLines(path.points)
                context.stroke(pathObject, with: .color(path.color), lineWidth: path.lineWidth)
            }
            
            // 繪製當前正在畫的路徑
            var currentPathObject = Path()
            currentPathObject.addLines(currentPath.points)
            context.stroke(currentPathObject, with: .color(currentPath.color), lineWidth: currentPath.lineWidth)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    currentPath.points.append(value.location)
                }
                .onEnded { value in
                    // 當手指離開螢幕，將當前路徑存入陣列並重置
                    paths.append(currentPath)
                    currentPath = DrawingPath(points: [], color: currentPath.color, lineWidth: currentPath.lineWidth)
                }
        )
    }
}
// MARK: - ✨ NEW: 整合式畫板教學視窗 (v2.0 - 支援問題詳情)
struct DrawingBoardView: View {
    let chapterNumber: Int
    let onClose: () -> Void
    
    // ------------------- 狀態屬性 (🔧 MODIFIED) -------------------
    
    // --- 畫板狀態 ---
    @State private var drawingPaths: [DrawingPath] = []
    @State private var currentDrawingPath: DrawingPath
    
    // --- 工具列狀態 ---
    @State private var selectedColor: Color = .red
    @State private var lineWidth: CGFloat = 5.0
    
    // --- ✨ NEW: 問題與圖片資料管理 ---
    /// 將問題按圖片名稱分組
    @State private var questionsByImage: [String: [QuizQuestion]] = [:]
    /// 所有不重複的圖片名稱列表
    @State private var allImageNames: [String] = []
    /// 當前選中的圖片名稱
    @State private var selectedImageName: String?
    /// 當前選中圖片對應的所有問題
    @State private var activeQuestionsForImage: [QuizQuestion] = []
    /// 當前顯示的問題索引
    @State private var currentQuestionIndex: Int = 0

    // 引入 sizeClass 以便製作自適應 UI
    @Environment(\.horizontalSizeClass) var sizeClass
    @EnvironmentObject var languageManager: LanguageManager //
    init(chapterNumber: Int, onClose: @escaping () -> Void) {
        self.chapterNumber = chapterNumber
        self.onClose = onClose
        // 初始化 currentDrawingPath
        _currentDrawingPath = State(initialValue: DrawingPath(points: [], color: .red, lineWidth: 5.0))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                
                // 主面板
                VStack(spacing: 0) {
                    titleBar
                    imageSelector
                    canvasArea
                    
                    // --- ✨ NEW: 問題詳情面板 ---
                    if !activeQuestionsForImage.isEmpty {
                        ScrollView {
                            QuestionDisplayView(
                                questions: activeQuestionsForImage,
                                questionIndex: $currentQuestionIndex
                            )
                            .padding()
                        }
                        .frame(maxHeight: sizeClass == .regular ? 220 : 180) // 限制高度
                        .background(Color(UIColor.systemBackground))
                    }
                    
                    toolsPanel
                }
                .frame(width: geometry.size.width * 0.95, height: geometry.size.height * 0.9)
                .background(Color(UIColor.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 20)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear(perform: loadChapterData) // 🔧 MODIFIED
        .onChange(of: selectedColor) {newColor in
            currentDrawingPath.color = newColor
        }
        .onChange(of: lineWidth) { newWidth in
            currentDrawingPath.lineWidth = newWidth
        }
        // --- ✨ NEW: 監聽圖片變化 ---
        .onChange(of: selectedImageName) { newImageName in
            guard let newImageName = newImageName,
                  let questions = questionsByImage[newImageName] else {
                activeQuestionsForImage = []
                return
            }
            activeQuestionsForImage = questions
            currentQuestionIndex = 0 // 每次切換圖片都從第一個問題開始
            clearDrawing() // 切換圖片時清空畫板
        }
    }
    
    // ------------------- 子視圖 (保持不變) -------------------
    
    @ViewBuilder
    private var titleBar: some View {
        // ... (這部分程式碼與之前相同，無需修改)
        HStack {
            Text(String(format: "chapter_board".localized(), chapterNumber))
                .font(.custom("CEF Fonts CJK Mono", size: sizeClass == .regular ? 22 : 18))
                .bold()
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(sizeClass == .regular ? .title : .title2)
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
    }
    
    @ViewBuilder
    private var imageSelector: some View {
        // ... (這部分程式碼與之前相同，只需將 allChapterImages 改為 allImageNames)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(allImageNames, id: \.self) { imageName in
                    Button(action: {
                        selectedImageName = imageName
                    }) {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: sizeClass == .regular ? 80 : 60)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedImageName == imageName ? Color.blue : Color.gray.opacity(0.5), lineWidth: selectedImageName == imageName ? 4 : 2)
                            )
                    }
                }
            }
            .padding()
        }
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    @ViewBuilder
    private var canvasArea: some View {
        // ... (這部分程式碼與之前相同，無需修改)
        ZStack {
            if let imageName = selectedImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(Rectangle())
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                    Text("select_an_img".localized())
                        .font(.custom("CEF Fonts CJK Mono", size: 16))
                        .padding(.top, 8)
                }
                .foregroundColor(.gray)
            }
            DrawingCanvasView(paths: $drawingPaths, currentPath: $currentDrawingPath)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var toolsPanel: some View {
        // ... (這部分程式碼與之前相同，無需修改)
        let isIPad = sizeClass == .regular
        Group {
            if isIPad {
                HStack(spacing: 20) { toolControls }
            } else {
                VStack(spacing: 10) { toolControls }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
    }
    
    @ViewBuilder
    private var toolControls: some View {
        // ... (這部分程式碼與之前相同，無需修改)
        ColorPicker("pen_color".localized(), selection: $selectedColor, supportsOpacity: false)
            .labelsHidden()
        HStack {
            Image(systemName: "scribble")
            Slider(value: $lineWidth, in: 2...30)
                .frame(maxWidth: 200)
            Text("\(Int(lineWidth))")
        }
        Button(action: setEraser) {
            Label("eraser".localized(), systemImage: "eraser.fill")
        }
        .buttonStyle(.bordered)
        Button(action: clearDrawing) {
            Label("all_clear".localized(), systemImage: "trash.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }
    
    // ------------------- 邏輯函式 (🔧 MODIFIED) -------------------
    
    // ✨ MODIFIED: 載入資料的邏輯已升級
    private func loadChapterData() {
        let chapterQuestions = GameDataService.shared.allQuestions.filter {
            $0.level == self.chapterNumber && $0.imageName != nil && !$0.imageName!.isEmpty
        }
        
        // 使用 Swift 的 Dictionary(grouping:by:) 按圖片名稱將問題分組
        self.questionsByImage = Dictionary(grouping: chapterQuestions, by: { $0.imageName! })
        
        // 獲取所有不重複的圖片名稱並排序
        self.allImageNames = questionsByImage.keys.sorted()
        
        // 預設選中第一張圖
        if selectedImageName == nil {
            self.selectedImageName = self.allImageNames.first
        }
    }
    
    private func clearDrawing() {
        drawingPaths.removeAll()
    }
    
    private func setEraser() {
        selectedColor = Color(UIColor.systemBackground)
    }
}


// MARK: - ✨ NEW: 用於顯示單個問題詳情的輔助 View
struct QuestionDetailRowView: View {
    // ... (將第一步的程式碼貼在這裡)
    let question: QuizQuestion
    @EnvironmentObject var languageManager: LanguageManager // ✅ 新增
    private var langCode: String { // ✅ 新增
        languageManager.currentLanguage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.questionText(for: langCode))
                .font(.custom("CEF Fonts CJK Mono", size: 16))
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(question.options(for: langCode).filter { !$0.isEmpty }, id: \.self) { option in
                    HStack {
                        Image(systemName: option == question.correctAnswer(for: langCode) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(option == question.correctAnswer(for: langCode) ? .green : .secondary)
                        Text(option)
                            .font(.custom("CEF Fonts CJK Mono", size: 15))
                            .foregroundColor(option == question.correctAnswer(for: langCode) ? .primary : .secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}


// MARK: - ✨ NEW: 包含問題切換邏輯的容器 View
struct QuestionDisplayView: View {
    // ... (將第一步的程式碼貼在這裡)
    let questions: [QuizQuestion]
    @Binding var questionIndex: Int
    
    var body: some View {
        VStack {
            if questions.count > 1 {
                HStack {
                    Text(String(format: "related_question_progress".localized(),
                                questionIndex + 1,
                                questions.count))
                        .font(.custom("CEF Fonts CJK Mono", size: 14))
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        if questionIndex > 0 {
                            questionIndex -= 1
                        }
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                    }
                    .disabled(questionIndex == 0)
                    
                    Button {
                        if questionIndex < questions.count - 1 {
                            questionIndex += 1
                        }
                    } label: {
                        Image(systemName: "chevron.right.circle.fill")
                    }
                    .disabled(questionIndex == questions.count - 1)
                }
                .font(.title2)
                .padding(.horizontal)
            }
            
            QuestionDetailRowView(question: questions[questionIndex])
                .id(questions[questionIndex].id)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.2), value: questionIndex)
        }
    }
}

// MARK: - ✨ FINAL: The Bulletproof Tutorial Overlay
struct TutorialOverlayView: View {
    @Binding var showTutorial: Bool
    @Binding var tutorialStep: Int
    let highlights: [Int: CGRect]

    private var tutorialText: String {
        switch tutorialStep {
        case 0:
            return "welcome_message".localized()
        case 1:
            return "welcome_message2".localized()
        case 2:
            return "welcome_message3".localized()
        case 3:
            return "welcome_message4".localized()
        case 4:
            return "welcome_message5".localized()
        case 5:
            return "welcome_message6".localized()
        default:
            return ""
        }
    }
    
    private var showNextButton: Bool {
        return tutorialStep != 3 && tutorialStep != 5
    }
    
    var body: some View {
        ZStack {
            // LAYER 1: The visual background overlay.
            // This entire layer is made NON-INTERACTIVE. Taps will pass through it.
            Color.black.opacity(0.7)
                .mask(
                    // We create a mask that is a full rectangle WITH A HOLE CUT OUT.
                    Rectangle()
                        .overlay(
                            // This is the hole
                            cutoutShape()
                                .blendMode(.destinationOut)
                        )
                )
                .compositingGroup() // Needed for the blend mode to work correctly
                .allowsHitTesting(false) // THE MOST IMPORTANT PART!

            // LAYER 2: The interactive text box.
            VStack(spacing: 20) {
                Text(tutorialText)
                    .font(.custom("CEF Fonts CJK Mono", size: 20))
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue.opacity(0.8))
                    .cornerRadius(15)
                    .shadow(radius: 10)
                
                if showNextButton {
                    Button(action: advanceStep) {
                        Text("next".localized())
                            .font(.custom("CEF Fonts CJK Mono", size: 18))
                            .bold()
                            .foregroundColor(.blue)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .position(tutorialTextPosition())
            // For debugging: You can see the frame of the text box.
            // .border(Color.red)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    // A helper function to create the cutout shape based on the highlight rect
    @ViewBuilder
    private func cutoutShape() -> some View {
        if let highlightRect = highlights[tutorialStep], tutorialStep != 2 {
            RoundedRectangle(cornerRadius: 15)
                .frame(width: highlightRect.width + 16, height: highlightRect.height + 16)
                .position(x: highlightRect.midX, y: highlightRect.midY)
        } else {
            // Return an empty view if there's no highlight
            EmptyView()
        }
    }
    
    private func advanceStep() {
        withAnimation {
            if tutorialStep < 5 {
                tutorialStep += 1
            }
        }
    }
    
    private func tutorialTextPosition() -> CGPoint {
        if tutorialStep == 0 || tutorialStep == 2 {
            return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
        }
        
        if let highlightRect = highlights[tutorialStep] {
            if highlightRect.midY < UIScreen.main.bounds.midY {
                return CGPoint(x: UIScreen.main.bounds.midX, y: highlightRect.maxY + 100)
            } else {
                return CGPoint(x: UIScreen.main.bounds.midX, y: highlightRect.minY - 120)
            }
        }
        
        return CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY + 200)
    }
}
// 🔧 MODIFIED: 全面重構 MainMenuView 以實現完美的頂部 UI 對齊
struct MainMenuView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var showingDetailForStage: Int? = nil

    // --- 過場動畫狀態 ---
    @State private var showTransitionOverlay = false
    @State private var overlayOpacity: Double = 1.0
    @State private var textOpacity: Double = 0.0
    @State private var pendingStage: Int? = nil

    // --- ✨ NEW: 重構後的新手教學狀態 ---
    @State private var showTutorial = false // 是否顯示教學
    @State private var tutorialStep = 0   // 目前教學步驟
    @State private var tutorialHighlights: [Int: CGRect] = [:] // 儲存高亮位置

    // --- 過關祝賀 ---
    @State private var showCongrats = false
    @State private var showSummary = false
    @State private var showGuidebook = false
    
    @State private var showDrawingBoard = false
    // ✨ NEW: 新增這個狀態    // ✨ NEW: 引入 sizeClass 以便製作自適應 UI
    @Environment(\.horizontalSizeClass) var sizeClass
    
    let chapterNumber: Int
    let onStageSelect: (Int) -> Void
    let onBack: () -> Void
    @Binding var isOverlayActive: Bool
    
    private var stagesForThisChapter: Range<Int> {
        let totalBefore = dataService.chapterStageCounts.prefix(chapterNumber - 1).reduce(0, +)
        let chapterSize = dataService.stagesInChapter(chapterNumber)
        let startStage = totalBefore + 1
        let endStage = totalBefore + chapterSize
        return startStage..<(endStage + 1)
    }
    
    // ✨ NEW: 為章節標題定義自適應字體大小
    private var chapterTitleFontSize: CGFloat {
        sizeClass == .regular ? 50 : 27
    }
    // 👇 在這裡新增教學文字的自適應字體大小
    private var tutorialFontSize: CGFloat {
        sizeClass == .regular ? 24 : 13
    }
    private var scrollViewOffsetY: CGFloat {
        sizeClass == .regular ? 0 : 0
    }

    var body: some View {
        ZStack {
            // --- 主內容 (關卡捲軸) ---
            VStack {
                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .center) {
                                Capsule()
                                    .fill(Color.black.opacity(0.25))
                                    .frame(height: 25)
                                    .padding(.horizontal, geo.size.width * -0.01)
                                
                                HStack(spacing: geo.size.width * 0.13) {
                                    ForEach(stagesForThisChapter, id: \.self) { stage in
                                        StageIconView(
                                            stageNumber: stage,
                                            chapterNumber: chapterNumber,
                                            isUnlocked: dataService.isStageUnlocked(stage),
                                            isNew: stage == dataService.highestUnlockedStage,
                                            result: dataService.getResult(for: stage),
                                            action: {
                                                self.showingDetailForStage = stage
                                                // ✨ NEW: 當玩家點擊第一關時，推進教學
                                                if showTutorial && tutorialStep == 3 {
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                        withAnimation {
                                                            tutorialStep = 4
                                                        }
                                                    }
                                                }
                                            }
                                        )
                                        .id(stage)
                                        // ✨ NEW: 標記第一關為教學步驟 2 的高亮目標
                                        .if(stage == 1) { view in
                                            view.modifier(TutorialHighlightModifier(step: 3))
                                        }
                                    }
                                    }
                                .padding(.horizontal, geo.size.width * 0.08)
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
                    .frame(height: 180)
                    .offset(y: scrollViewOffsetY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Image("stage-background\(chapterNumber)")
                    .resizable()
                    .scaledToFill()
                    .edgesIgnoringSafeArea(.all)
            )
            .safeAreaInset(edge: .top) {
                topBar
            }

            // --- Overlay 區塊 (全螢幕) ---
            if let stage = showingDetailForStage {
                ZStack {
                    Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                    StageDetailView(
                        stageNumber: stage,
                        chapterNumber: chapterNumber,
                        result: dataService.getResult(for: stage),
                        isTutorialActive: showTutorial,
                        onStart: {
                            // ✨ NEW: 玩家點擊開始，結束教學
                            if showTutorial {
                                dataService.markTutorialAsSeen() // Call the new function
                                showTutorial = false
                            }
                            
                            self.showingDetailForStage = nil
                            pendingStage = stage
                            showTransitionOverlay = true
                            overlayOpacity = 0.0
                            textOpacity = 0.0
                            
                            withAnimation(.easeIn(duration: 1)) { overlayOpacity = 1.0 }
                            withAnimation(.easeIn(duration: 0.8).delay(0.8)) { textOpacity = 1.0 }
                            
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
                        onCancel: { self.showingDetailForStage = nil }
                    )
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(50)
            }

            if showSummary {
                ZStack {
                    Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                    SummaryView(
                        chapterNumber: chapterNumber,
                        onClose: { showSummary = false }
                    )
                }
                .transition(.opacity) // ✨ MODIFIED
                .zIndex(50)
            }

            if showGuidebook {
                ZStack {
                    Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                    GuidebookView(
                        chapterNumber: chapterNumber,
                        onClose: { showGuidebook = false }
                    )
                }
                .transition(.opacity) // ✨ MODIFIED
                .zIndex(50)
            }
            // --- ✨ NEW: 繪圖板彈出視窗 ---
            if showDrawingBoard {
                DrawingBoardView(
                    chapterNumber: chapterNumber,
                    onClose: { showDrawingBoard = false }
                )
                .transition(.opacity) // ✨ MODIFIED
                .zIndex(60) // 確保它在其他視窗之上
            }
            // --- 黑幕過場層 ---
            if showTransitionOverlay {
                Color.black
                    .opacity(overlayOpacity)
                    .edgesIgnoringSafeArea(.all)
                
                if let stage = pendingStage {
                    let (chapter, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stage)
                    let isBossStage = stageInChapter == GameDataService.shared.stagesInChapter(chapter)
                    
                    Text(isBossStage
                        // 如果是 Boss 關
                        ? String(format: "boss_stage_title".localized(),
                                 chapter)
                        // 如果是普通關
                        : String(format: "normal_stage_title".localized(),
                                 chapter,
                                 stageInChapter)
                    )
                    
                    .font(.custom("CEF Fonts CJK Mono", size: 30))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(textOpacity)
                }
            }
            // --- ✨ CORRECTED: The New Tutorial Layer System ---
            if showTutorial {
                TutorialOverlayView(
                    showTutorial: $showTutorial,
                    tutorialStep: $tutorialStep,
                    highlights: tutorialHighlights
                )
                .zIndex(100) // Ensure it's the topmost item
            }
            
        }
        .animation(.spring(), value: showingDetailForStage)
        .animation(.default, value: showGuidebook)
        .animation(.default, value: showSummary)
        .onPreferenceChange(TutorialHighlightKey.self) { value in
            self.tutorialHighlights = value
        }
        
        .onAppear {
            // Use your new `hasSeenTutorial` flag to check!
            if !dataService.hasSeenTutorial && chapterNumber == 1 {
                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                       showTutorial = true
                    }
                 }
            }
        }
        .onChange(of: showTransitionOverlay) {newValue in
            isOverlayActive = newValue
        }
    }

    // --- TopBar ---
    @ViewBuilder
    private var topBar: some View {
        ZStack {
            Text(String(format: "chapter_title".localized(), chapterNumber))
                .font(.custom("CEF Fonts CJK Mono", size: chapterTitleFontSize))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 5, y: 5)
                .lineLimit(1)

            HStack {
                Button(action: onBack) {
                    ZStack {
                        Circle().fill(Color.black.opacity(0.3)).shadow(radius: 5)
                        Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 2).padding(4)
                        Image(systemName: "arrow.backward")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    // --- ✨ NEW: 新增畫筆按鈕 (僅限第二章) ---
                    if chapterNumber == 2 {
                        Button(action: {
                            withAnimation {
                                showSummary = false
                                showGuidebook = false
                                showDrawingBoard = true
                            }
                        }) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            showGuidebook = false
                            showDrawingBoard = false // 確保關閉畫板
                            showSummary = true
                        }
                    }) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.yellow)
                    }
                    
                    Button(action: {
                        withAnimation {
                            showSummary = false
                            showDrawingBoard = false // 確保關閉畫板
                            showGuidebook = true
                        }
                    }) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.2))
                            .clipShape(Circle())
                    }
                }
                // ✨ NEW: 標記右上角按鈕區域為教學步驟 1 的高亮目標
                .modifier(TutorialHighlightModifier(step: 1))
            }
        }
        .frame(height: 60)
        .padding(.horizontal)
        .background(.ultraThinMaterial.opacity(0.2))
    }
}
// ✨ NEW: 增加一個 if modifier 讓程式碼更簡潔
extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - ✨ NEW: 重點整理資料模型 (懶人包內容)
struct SummaryContent: Identifiable {
    let id = UUID()
    let chapterNumber: Int
    let title: String
    let sections: [SummarySection]
}

struct SummarySection: Identifiable {
    let id = UUID()
    let heading: String
    let icon: String
    let items: [String]
}

// 存放所有懶人包內容的資料來源
struct SummaryDataProvider {

    // ✅ 新增這個靜態函式，它會在每次被呼叫時，建立一個全新的、本地化的陣列
    static func loadLocalizedSummaries() -> [SummaryContent] {
        // 把原本 static let 裡的所有內容，原封不動地搬到這裡面
        let summaries: [SummaryContent] = [
            // MARK: 🔧 MODIFIED: 第二章 - 整合您的最新小筆記
            SummaryContent(chapterNumber: 2, title: String(format: "summary_ch2_title_format".localized(), 2), sections: [
                SummarySection(heading: "summary_ch2_sec1_heading".localized(), icon: "arrow.triangle.swap", items: [
                    "summary_ch2_sec1_item1".localized(),
                    "summary_ch2_sec1_item2".localized(),
                    "summary_ch2_sec1_item3".localized()
                ]),
                SummarySection(heading: "summary_ch2_sec2_heading".localized(), icon: "list.number", items: [
                    "summary_ch2_sec2_item1".localized(),
                    "summary_ch2_sec2_item2".localized(),
                    "summary_ch2_sec2_item3".localized(),
                    "summary_ch2_sec2_item4".localized(),
                    "summary_ch2_sec2_item5".localized(),
                    "summary_ch2_sec2_item6".localized(),
                    "summary_ch2_sec2_item7".localized()
                ]),
                SummarySection(heading: "summary_ch2_sec3_heading".localized(), icon: "xmark.octagon.fill", items: [
                    "summary_ch2_sec3_item1".localized(),
                    "summary_ch2_sec3_item2".localized(),
                    "summary_ch2_sec3_item3".localized()
                ])
            ]),
            
            // 第 3 章
            SummaryContent(chapterNumber: 3, title: String(format: "summary_ch3_title_format".localized(), 3), sections: [
                SummarySection(heading: "summary_ch3_sec1_heading".localized(), icon: "calendar", items: [
                    "summary_ch3_sec1_item1".localized(),
                    "summary_ch3_sec1_item2".localized(),
                    "summary_ch3_sec1_item3".localized()
                ]),
                SummarySection(heading: "summary_ch3_sec2_heading".localized(), icon: "dollarsign.circle", items: [
                    "summary_ch3_sec2_item1".localized(),
                    "summary_ch3_sec2_item2".localized(),
                    "summary_ch3_sec2_item3".localized(),
                    "summary_ch3_sec2_item4".localized()
                ])
            ]),
            // MARK: 🔧 MODIFIED: 第四章終極整合版筆記
            SummaryContent(chapterNumber: 4, title: String(format: "summary_ch4_title_format".localized(), 4), sections: [
                SummarySection(heading: "summary_ch4_sec1_heading".localized(), icon: "key.fill", items: [
                    "summary_ch4_sec1_item1".localized(),
                    "summary_ch4_sec1_item2".localized()
                ]),
                SummarySection(heading: "summary_ch4_sec2_heading".localized(), icon: "list.bullet.rectangle.portrait.fill", items: [
                    "summary_ch4_sec2_item1".localized(),
                    "summary_ch4_sec2_item2".localized(),
                    "summary_ch4_sec2_item3".localized(),
                    "summary_ch4_sec2_item4".localized(),
                    "summary_ch4_sec2_item5".localized()
                ]),
                SummarySection(heading: "summary_ch4_sec3_heading".localized(), icon: "brain.head.profile", items: [
                    "summary_ch4_sec3_item1".localized(),
                    "summary_ch4_sec3_item2".localized(),
                    "summary_ch4_sec3_item3".localized(),
                    "summary_ch4_sec3_item4".localized()
                ]),
                SummarySection(heading: "summary_ch4_sec4_heading".localized(), icon: "arrow.up.arrow.down.circle", items: [
                    "summary_ch4_sec4_item1".localized(),
                    "summary_ch4_sec4_item2".localized(),
                    "summary_ch4_sec4_item3".localized(),
                    "summary_ch4_sec4_item4".localized()
                ]),
                SummarySection(heading: "summary_ch4_sec5_heading".localized(), icon: "shield.lefthalf.filled.slash", items: [
                    "summary_ch4_sec5_item1".localized(),
                    "summary_ch4_sec5_item2".localized(),
                    "summary_ch4_sec5_item3".localized()
                ])
            ])
        ]
        return summaries
    }

    // ✅ 修改這個函式，讓它先呼叫載入函式，再進行查找
    static func getSummary(for chapter: Int) -> SummaryContent? {
        // 每次查找時，都先取得最新的、完整本地化的列表
        let localizedSummaries = loadLocalizedSummaries()
        return localizedSummaries.first { $0.chapterNumber == chapter }
    }
}


// MARK: - ✨ NEW: 重點整理彈出視窗 (SummaryView)
// 🔧 MODIFIED: 尺寸改為自適應，佔螢幕 80%
struct SummaryView: View {
    let chapterNumber: Int
    let onClose: () -> Void
    
    @State private var summary: SummaryContent?
    
    var body: some View {
        // ✨ 用 GeometryReader 包住來取得螢幕尺寸
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                
                VStack(spacing: 0) {
                    // 標題列
                    HStack {
                        Text(summary?.title ?? "summary".localized())
                            .font(.custom("CEF Fonts CJK Mono", size: 22))
                            .bold()
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemBackground))
                    
                    Divider()
                    
                    // 內容
                    if let summary = summary {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(summary.sections) { section in
                                    SummarySectionView(section: section)
                                }
                            }
                            .padding()
                        }
                    } else {
                        Spacer()
                        Text("no_summary".localized())
                            .font(.custom("CEF Fonts CJK Mono", size: 18))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                // ✨ 使用螢幕尺寸的 80% 作為 View 的大小
                .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.9)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20)) // 使用 clipShape 效果更好
                .shadow(radius: 20)
                // ✨ 將 View 精準置中
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
        .onAppear {
            self.summary = SummaryDataProvider.getSummary(for: chapterNumber)
        }
    }
}

// MARK: - ✨ NEW: 重點整理的區塊 (SummarySectionView)
struct SummarySectionView: View {
    let section: SummarySection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 區塊標題
            Label(section.heading, systemImage: section.icon)
                .font(.custom("CEF Fonts CJK Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            // 項目列表
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.items, id: \.self) { item in
                    Label {
                        // 使用 AttributedString 來處理 **粗體** 標記
                        Text(markdownToAttributedString(item))
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                    .font(.custom("CEF Fonts CJK Mono", size: 17))
                }
            }
            .padding(.leading, 10) // 列表內容縮排
        }
    }
    
    // 將 Markdown 的 **粗體** 轉換為 AttributedString
    private func markdownToAttributedString(_ string: String) -> AttributedString {
        do {
            return try AttributedString(markdown: string)
        } catch {
            return AttributedString(string)
        }
    }
}


// MARK: - 導覽書主畫面 (GuidebookView)
// 🔧 MODIFIED: 尺寸改為自適應，佔螢幕 80%
struct GuidebookView: View {
    let chapterNumber: Int
    let onClose: () -> Void
    
    @State private var allQuestions: [QuizQuestion] = []
    @State private var zoomedImageName: String? = nil
    @State private var searchText = ""
    @EnvironmentObject var languageManager: LanguageManager // ✅ 新增

    private var langCode: String { // ✅ 新增
        languageManager.currentLanguage
    }

    private var filteredQuestions: [QuizQuestion] {
        if searchText.isEmpty {
            return allQuestions
        } else {
            return allQuestions.filter {
                // 🔧 更改：搜尋時也使用多語言函式
                $0.questionText(for: langCode).localizedCaseInsensitiveContains(searchText) ||
                $0.correctAnswer(for: langCode).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        // ✨ 用 GeometryReader 包住來取得螢幕尺寸
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)            // 導覽書主體 (NavigationStack)
                NavigationStack {
                    ZStack {
                        // 卡片的背景色
                        Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                        
                        VStack(spacing: 0) {
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(filteredQuestions) { question in
                                        GuidebookRowView(
                                            question: question,
                                            chapterNumber: self.chapterNumber,
                                            onImageTap: { imageName in
                                                withAnimation(.spring()) {
                                                    self.zoomedImageName = imageName
                                                }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .navigationTitle(String(format: "chapter_guidebook_title".localized(), chapterNumber))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: onClose) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        // 放大圖片的 Overlay
                        if let imageName = zoomedImageName {
                            ZoomedImageView(
                                imageName: imageName,
                                zoomedImageName: $zoomedImageName
                            )
                        }
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "search".localized())
                .onAppear(perform: loadQuestions)
                // ✨ 使用螢幕尺寸的 80% 作為 View 的大小
                .frame(width: geometry.size.width * 0.9, height: geometry.size.height * 0.9)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 15)
                // ✨ 將 View 精準置中
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
    
    private func loadQuestions() {
        let allChapterQuestions = GameDataService.shared.allQuestions.filter { $0.level == chapterNumber }
        self.allQuestions = allChapterQuestions.sorted { $0.questionID < $1.questionID }
    }
}

// MARK: - 導覽書的區塊 (GuidebookRowView)
struct GuidebookRowView: View {
    let question: QuizQuestion
    let chapterNumber: Int
    let onImageTap: (String) -> Void
    
    @State private var isExpanded = false
    @EnvironmentObject var languageManager: LanguageManager // ✅ 新增
    private var langCode: String { // ✅ 新增
        languageManager.currentLanguage
    }

    var body: some View {
        VStack(spacing: 0) {
            // 根據章節編號決定要顯示哪種排版
            if chapterNumber <= 2 {
                imageBasedLayout // 樣式 1: 有圖模式
            } else {
                textBasedLayout // 樣式 2: 純文字模式
            }
            Divider()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
    
    // --- 樣式 1: 有圖模式 (第 1-2 章)，已升級為可展開 ---
    private var imageBasedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- 可點擊的標頭區域 ---
            HStack(spacing: 15) {
                // 左側圖片
                if let imageName = question.imageName, !imageName.isEmpty {
                    Image(imageName)
                        .resizable().scaledToFit().frame(width: 100, height: 75)
                        .background(Color.black).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .onTapGesture { onImageTap(imageName) }
                } else {
                    placeholderView
                }
                
                // 中間的問題與答案
                VStack(alignment: .leading, spacing: 4) {
                    // 🔧 更改：使用多語言函式
                    Text(question.questionText(for: langCode))
                        .font(.custom("CEF Fonts CJK Mono", size: 15))
                        .foregroundColor(.secondary)
                
                    // 🔧 更改：使用多語言函式
                    Text(question.correctAnswer(for: langCode))
                        .font(.custom("CEF Fonts CJK Mono", size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 右側的箭頭圖示
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            
            // --- 可展開的選項區域 ---
            if isExpanded {
                optionsView
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    // --- 樣式 2: 純文字模式 ---
    private var textBasedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 15) {
                // 左側的題號圖示
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBlue).opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "number")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                // 中間的題目與答案
                VStack(alignment: .leading, spacing: 4) {
                    // 🔧 更改：使用多語言函式
                    Text(question.questionText(for: langCode))
                        .font(.custom("CEF Fonts CJK Mono", size: 15))
                        .foregroundColor(.secondary)
                
                    // 🔧 更改：使用多語言函式
                    Text(question.correctAnswer(for: langCode))
                        .font(.custom("CEF Fonts CJK Mono", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 右側的箭頭圖示
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            
            // --- 可展開的選項區域 ---
            if isExpanded {
                optionsView
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    // --- 可重用的選項列表子視圖 ---
    @ViewBuilder
    private var optionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(question.options(for: langCode).filter { !$0.isEmpty }, id: \.self) { option in
                HStack(spacing: 12) {
                    if option == question.correctAnswer(for: langCode) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    Text(option)
                        .font(.custom("CEF Fonts CJK Mono", size: 16))
                        .fontWeight(option == question.correctAnswer(for: langCode) ? .bold : .regular)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemGray5))
        )
    }

    // --- 共用的圖片佔位符 ---
    private var placeholderView: some View {
        ZStack {
             RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray5))
             Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundColor(Color(UIColor.systemGray2))
        }
        .frame(width: 100, height: 75)
    }
}

// ✨ NEW: 負責顯示放大圖片的全新 View
struct ZoomedImageView: View {
    let imageName: String
    @Binding var zoomedImageName: String? // 使用 Binding 來關閉自己

    var body: some View {
        ZStack {
            // 半透明黑色背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    closeView()
                }
            
            // 圖片本身
            Image(imageName)
                .resizable()
                .scaledToFit()
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.5), radius: 20)
                .padding(70) // 讓圖片與螢幕邊緣保持距離

            // 右上角的關閉按鈕
            VStack {
                HStack {
                    Spacer()
                    Button(action: closeView) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(60)
                }
                Spacer()
            }
            .padding()
        }
        // 為整個放大畫面的出現/消失加上過場動畫
        .transition(.scale.combined(with: .opacity))
        // 使用 .id 確保每次圖片名稱變化時，動畫都能正確執行
        .id(imageName)
    }
    
    private func closeView() {
        withAnimation(.spring()) {
            zoomedImageName = nil
        }
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
                     // 如果是 Boss 關，直接用 "stage_final" Key
                     ? "stage_final".localized()
                     // 如果是普通關，用 "stage_with_number" Key 並傳入參數
                     : String(format: "stage_with_number".localized(), relativeStage)
                )
                
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
    let isTutorialActive: Bool // ✨ NEW: 接收教學狀態
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
                Text(isBossStage
                     ? "stage_final".localized()
                     : String(format: "stage_with_number".localized(), relativeStage)
                )
                    .font(.custom("CEF Fonts CJK Mono", size: 30))
                    .bold()
                    .foregroundColor(textColor)

                Divider()

                if let res = result {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("record_title".localized())
                            .font(.custom("CEF Fonts CJK Mono", size: 20))
                            .bold()
                        Text(String(format: "record_evaluation".localized(), res.evaluation))
                        Text(String(format: "record_max_combo".localized(), res.maxCombo))
                        Text(String(format: "record_correct_questions".localized(), res.correctlyAnswered, res.totalQuestions))
                    }
                    .font(.custom("CEF Fonts CJK Mono", size: 18))
                    .foregroundColor(textColor)
                } else {
                    Text("no_record".localized())
                        .font(.custom("CEF Fonts CJK Mono", size: 22))
                        .foregroundColor(.gray)
                        .padding(.vertical, 30)
                }

                Divider()

                HStack(spacing: 15) {
                    Button(action: onCancel) {
                        Text("cancel".localized())
                            .font(.custom("CEF Fonts CJK Mono", size: 16))
                            .bold().padding().frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.3)).cornerRadius(10)
                    }

                    Button(action: onStart) {
                        Text("game_start".localized())
                            .font(.custom("CEF Fonts CJK Mono", size: 16))
                            .bold().padding().frame(maxWidth: .infinity)
                            .background(Color.blue).cornerRadius(10)
                    }
                    // ✨ NEW: 在教學模式下，標記開始按鈕
                    .if(isTutorialActive) { view in
                        view.modifier(TutorialHighlightModifier(step: 5))
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
            // ✨ NEW: 標記整個彈出視窗為教學步驟 3
            .if(isTutorialActive) { view in
                view.modifier(TutorialHighlightModifier(step: 4))
            }
        }
    }
}

// ✨ 預覽
struct InteractiveMenuPreview: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var isOverlayActive = false   // 👈 新增
    
    var body: some View {
        MainMenuView(
            chapterNumber: 2,
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
// MARK: - ✨ NEW: 教學系統所需的 PreferenceKey 和 Modifier
struct TutorialHighlightKey: PreferenceKey {
    // 我們用一個字典來儲存每個教學步驟 (Int) 對應的 UI 元素位置 (CGRect)
    typealias Value = [Int: CGRect]
    
    static var defaultValue: Value = [:]
    
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// 建立一個方便使用的 View Modifier，用來標記需要被教學系統高亮的 View
struct TutorialHighlightModifier: ViewModifier {
    let step: Int
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: TutorialHighlightKey.self,
                                    // 將這個 View 在全域座標系中的位置傳遞出去
                                    value: [step: geometry.frame(in: .global)])
                }
            )
    }
}
