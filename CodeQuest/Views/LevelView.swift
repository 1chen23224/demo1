import SwiftUI

struct LevelView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    @State private var selectedOption: String?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [String] = []
    
    @State private var isImagePopupVisible = false

    // ✨ [修改] 進度條的計算方式
    // 現在的進度只跟「已答對題數」有關，完全符合您的要求
    private var currentProgress: Double {
        if viewModel.totalQuestions == 0 { return 0 }
        // 使用 ViewModel 中新的 correctlyAnsweredCount 屬性來計算進度
        return Double(viewModel.correctlyAnsweredCount) / Double(viewModel.totalQuestions)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // --- 上半部 ---
                ZStack(alignment: .bottom) {
                    Color(red: 95/255, green: 191/255, blue: 235/255)
                    // 假設您已有 ScrollingBackgroundView.swift 檔案
                    ScrollingBackgroundView(scrollTrigger: viewModel.score).offset(y:165)
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .clipped()

                // --- 下半部 ---
                ZStack {
                    Image("ground-texture").resizable().scaledToFill().clipped()
                    
                    VStack(spacing: 15) {
                        Spacer()
                        ForEach(viewModel.currentQuestion.options.filter { !$0.isEmpty }, id: \.self) { option in
                            OptionButton(
                                optionText: option,
                                selectedOption: $selectedOption,
                                isSubmitted: $isAnswerSubmitted,
                                correctAnswer: viewModel.currentQuestion.correctAnswer
                            )
                            // 假設您已有 ShakeEffect 的實作
                            .modifier(ShakeEffect(attempts: wrongAttempts.filter { $0 == option }.count))
                            .onTapGesture {
                                self.handleTap(on: option)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        ProgressBar(progress: currentProgress)
                        .offset(y: -25)
                        Spacer()
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            .edgesIgnoringSafeArea(.all)

            // --- 疊加 UI ---
            VStack {
                if let imageName = viewModel.currentQuestion.imageName {
                    Button(action: {
                        withAnimation(.spring()) { isImagePopupVisible = true }
                    }) {
                        QuestionBar(text: viewModel.currentQuestion.questionText, hasImage: true)
                    }
                } else {
                    QuestionBar(text: viewModel.currentQuestion.questionText, hasImage: false)
                }
                Spacer()
            }
            .padding(.top, 30)
            .padding(.horizontal)

            VStack {
                HStack {
                    Spacer()
                    HeartView(lives: viewModel.lives)
                        .padding(.trailing)
                        .padding(.top, 50)
                }
                Spacer()
            }
            
            HintView(
                keyword: viewModel.currentQuestion.keyword,
                isHintVisible: viewModel.isHintVisible,
                action: {
                    viewModel.showHint()
                }
            )
            
            if isImagePopupVisible, let imageName = viewModel.currentQuestion.imageName {
                ImagePopupView(imageName: imageName, isVisible: $isImagePopupVisible)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onChange(of: viewModel.currentQuestion.id) {
            isAnswerSubmitted = false
            selectedOption = nil
        }
        .alert("恭喜！", isPresented: $viewModel.isQuizComplete) {
            Button("重新開始", role: .cancel, action: viewModel.restartGame)
        } message: {
            Text("你已完成所有題目！\n最終得分: \(viewModel.score)")
        }
    }
    
    // ✨ [修改] handleTap 函式簡化
    private func handleTap(on option: String) {
        guard !isAnswerSubmitted else { return }
        
        isAnswerSubmitted = true
        selectedOption = option
        
        // 觸發答錯時的晃動效果
        if option != viewModel.currentQuestion.correctAnswer {
            wrongAttempts.append(option)
        }
        
        // 直接呼叫 ViewModel 的 submitAnswer，讓它處理所有後續邏輯
        viewModel.submitAnswer(option)
    }
}


// MARK: - Subviews for LevelView

struct HintView: View {
    let keyword: String?
    let isHintVisible: Bool
    let action: () -> Void
    
    var body: some View {
        VStack {
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
                
                Spacer()
            }
            .padding(.leading)
            .padding(.top, 60)
            
            Spacer()
        }
        .animation(.spring(), value: isHintVisible)
    }
}

struct ImagePopupView: View {
    let imageName: String
    @Binding var isVisible: Bool
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                .onTapGesture { withAnimation(.spring()) { isVisible = false } }
            Image(imageName)
                .resizable().scaledToFit()
                .frame(width: UIScreen.main.bounds.width * 0.7)
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
            Text(text)
                .font(.custom("CEF Fonts CJK Mono", size: 24))
                .fixedSize(horizontal: false, vertical: true)
            if hasImage {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24, weight: .bold))
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
        .shadow(radius: 5)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.3)
    }
}

struct ProgressBar: View {
    let progress: Double
    private let barWidth: CGFloat = 380
    private let barHeight: CGFloat = 12
    private let characterSize: CGFloat = 50

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.5)).frame(width: barWidth, height: barHeight)
            Capsule().fill(Color.yellow).frame(width: barWidth * progress, height: barHeight)
            Image("progress-character")
                .resizable().scaledToFit().frame(width: characterSize, height: characterSize)
                .offset(y: -characterSize / 2 + barHeight / 2)
                .offset(x: barWidth * progress - (characterSize / 2))
        }
        .frame(width: barWidth, height: characterSize)
        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: progress)
    }
}

struct HeartView: View {
    let lives: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(index < lives ? Color.red : Color.black.opacity(0.3))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            }
        }
    }
}

struct OptionButton: View {
    let optionText: String
    @Binding var selectedOption: String?
    @Binding var isSubmitted: Bool
    let correctAnswer: String

    var body: some View {
        Image("option-button-bg")
            .resizable().scaledToFit().frame(height: 93).cornerRadius(15)
            .overlay(
                Text(optionText)
                    .font(.custom("CEF Fonts CJK Mono", size: 26))
                    .fontWeight(.heavy)
                    .foregroundColor(Color(red: 60/255, green: 40/255, blue: 40/255))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .padding(.vertical, 15)
                    .padding(.horizontal, 30)
            )
        .opacity(buttonOpacity)
        .shadow(color: buttonColor.opacity(0.8), radius: 10)
        .scaleEffect(isSubmitted && optionText == selectedOption ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: selectedOption)
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


// 假設您的 App 入口是 ContentView()
#Preview {
    ContentView()
}
