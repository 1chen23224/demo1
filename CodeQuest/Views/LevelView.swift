import SwiftUI

struct LevelView: View {
    @Binding var isGameActive: Bool
    @EnvironmentObject var viewModel: GameViewModel
    
    @State private var selectedOption: String?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [String] = []
    @State private var isImagePopupVisible = false
    @State private var autoClosePopupTask: DispatchWorkItem?

    private var currentProgress: Double {
        if viewModel.totalQuestions == 0 { return 0 }
        return Double(viewModel.correctlyAnsweredCount) / Double(viewModel.totalQuestions)
    }

    // 計算當前章號
    private var currentChapter: Int {
        ((viewModel.currentStage - 1) / 21) + 1
    }
    
    // 根據章號決定角色圖
    private var characterImageName: String {
        return currentChapter >= 2 ? "character2" : "progress-character"
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
                    .offset(y:165)
                }
                .frame(height: UIScreen.main.bounds.height * 0.5).clipped()
                
                ZStack {
                    Image("ground-texture").resizable().scaledToFill().clipped()
                    VStack(spacing: 15) {
                        Spacer()
                        ForEach(viewModel.currentQuestion.options.filter { !$0.isEmpty }, id: \.self) { option in
                            OptionButton(optionText: option, selectedOption: $selectedOption, isSubmitted: $isAnswerSubmitted, correctAnswer: viewModel.currentQuestion.correctAnswer)
                                .modifier(ShakeEffect(attempts: wrongAttempts.filter { $0 == option }.count))
                                .onTapGesture { self.handleTap(on: option) }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    VStack {
                        ProgressBar(progress: currentProgress, characterImageName: characterImageName).offset(y: -25)
                        Spacer()
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            .edgesIgnoringSafeArea(.all)

    
        
            VStack {
                if let imageName = viewModel.currentQuestion.imageName {
                    Button(action: { withAnimation(.spring()) { isImagePopupVisible = true } }) {
                        QuestionBar(text: viewModel.currentQuestion.questionText, hasImage: true)
                    }
                } else {
                    QuestionBar(text: viewModel.currentQuestion.questionText, hasImage: false)
                }
                Spacer()
            }.padding(.top, 30).padding(.horizontal)
            
            if isImagePopupVisible, let imageName = viewModel.currentQuestion.imageName {
                ImagePopupView(imageName: imageName, isVisible: $isImagePopupVisible)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // --- 頂部UI ---
            VStack {
                HStack(alignment: .top) {
                    // 左上角
                    HStack(spacing: 16) {
                        Button(action: {
                            self.isGameActive = false
                        }) {
                            Image(systemName: "house.fill")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .shadow(radius: 5)
                        }
                        
                        HintView(keyword: viewModel.currentQuestion.keyword, isHintVisible: viewModel.isHintVisible, action: { viewModel.showHint() })
                    }
                    
                    Spacer()
                    
                    // 右上角
                    VStack(alignment: .trailing, spacing: 8) {
                        HeartView(lives: viewModel.lives)
                        ComboView(combo: viewModel.comboCount)
                            .animation(.spring(response: 0.4, dampingFraction: 0.5), value: viewModel.comboCount)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                Spacer()
            }
            
            // 結算畫面
            if viewModel.isQuizComplete || viewModel.isGameOver {
                ResultView(
                    stageNumber: viewModel.currentStage,
                    evaluation: viewModel.finalEvaluation,
                    maxCombo: viewModel.maxComboAchieved,
                    correctlyAnswered: viewModel.correctlyAnsweredCount,
                    totalQuestions: viewModel.totalQuestions,
                    backToMenuAction: {
                        self.isGameActive = false
                    }
                )
                .transition(.opacity.animation(.easeIn(duration: 0.5)))
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: viewModel.questionRefreshID) {
            handleNewQuestion()
        }
        .onAppear {
            handleNewQuestion()
        }
    }
    
    private var backgroundName: String {
        return viewModel.backgroundImageName
    }
    
    private func handleTap(on option: String) {
        guard !isAnswerSubmitted else { return }
        isAnswerSubmitted = true
        selectedOption = option
        if option != viewModel.currentQuestion.correctAnswer {
            wrongAttempts.append(option)
        }
        autoClosePopupTask?.cancel()
        viewModel.submitAnswer(option)
    }
    
    private func handleNewQuestion() {
        isAnswerSubmitted = false
        selectedOption = nil
        autoClosePopupTask?.cancel()
        if viewModel.currentQuestion.imageName != nil {
            let task = DispatchWorkItem {
                if isImagePopupVisible {
                    withAnimation(.spring()) {
                        isImagePopupVisible = false
                    }
                }
            }
            autoClosePopupTask = task
            withAnimation(.spring()) {
                isImagePopupVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: task)
        }
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
        return stageNumber % 21 == 0
    }

    private let textColor = Color(red: 85/255, green: 65/255, blue: 50/255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
            
            ZStack {
                Image("End")
                    .resizable()
                    .scaledToFill()
                
                ZStack {
                    
                    Text(isBossStage ? "第 \((stageNumber - 1) / 21 + 1) 章最終關" : "第 \((stageNumber - 1) / 21 + 1) 章第 \(stageNumber) 關")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(textColor)
                        .offset(x: 65, y: -24)
                    
                    evaluationText()
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .offset(x: 85, y: 36)
                    
                    comboText()
                        .foregroundColor(textColor)
                        .offset(x: 85, y: 94)
                    
                    Text("\(correctlyAnswered) / \(totalQuestions)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundColor(textColor)
                        .offset(x: 85, y: 151)
                    
                    Color.clear
                        .frame(width: 160, height: 50)
                        .contentShape(Rectangle())
                        .offset(y: 225)
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
            Text("FULL COMBO")
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
            text.foregroundStyle(LinearGradient(colors: [.red, .orange, .yellow, .green, .blue, .purple], startPoint: .leading, endPoint: .trailing))
        case "A":
            text.foregroundColor(.red)
        default:
            text.foregroundColor(textColor)
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
                Text("COMBO").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.7), radius: 2).padding(.leading, 4).offset(y: -5)
            }.transition(.asymmetric(insertion: .scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity), removal: .scale(scale: 0.5, anchor: .topTrailing).combined(with: .opacity).animation(.easeOut(duration: 0.3))))
        }
    }
}

struct ImagePopupView: View {
    let imageName: String
    @Binding var isVisible: Bool
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all).onTapGesture { withAnimation(.spring()) { isVisible = false } }
            Image(imageName)
                .resizable()
                // ✨ [主要修改處] 新增以下兩個修飾符
                .interpolation(.high) // 1. 使用高品質的圖片縮放插值
                .antialiased(true)    // 2. 開啟抗鋸齒效果
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.8) // 稍微放大一點點，看得更清楚
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.5), radius: 20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.yellow, lineWidth: 5))
        }
    }
}

struct QuestionBar: View {
    let text: String
    let hasImage: Bool
    var body: some View {
        HStack {
            Text(text).font(.custom("CEF Fonts CJK Mono", size: 24)).fixedSize(horizontal: false, vertical: true)
            if hasImage {
                Image(systemName: "photo.on.rectangle.angled").font(.system(size: 24, weight: .bold))
            }
        }.foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.black.opacity(0.6)).cornerRadius(20).shadow(radius: 5).frame(maxHeight: UIScreen.main.bounds.height * 0.3)
    }
}

struct ProgressBar: View {
    let progress: Double
    let characterImageName: String
    private let barWidth: CGFloat = 380
    private let barHeight: CGFloat = 12
    private let characterSize: CGFloat = 70
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.5)).frame(width: barWidth, height: barHeight)
            Capsule().fill(Color.yellow).frame(width: barWidth * progress, height: barHeight)
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
        Image("option-button-bg").resizable().scaledToFit().frame(height: 93).cornerRadius(15).overlay(
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
