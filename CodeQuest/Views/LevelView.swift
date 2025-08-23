import SwiftUI

struct LevelView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    @State private var selectedOption: String?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [String] = []
    
    @State private var isImagePopupVisible = false

    private var currentProgress: Double {
        if viewModel.isQuizComplete { return 1.0 }
        return Double(viewModel.currentQuestionIndex) / Double(viewModel.totalQuestions)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // --- 上半部 ---
                ZStack(alignment: .bottom) {
                    Color(red: 95/255, green: 191/255, blue: 235/255)
                    ScrollingBackgroundView(scrollTrigger: viewModel.score).offset(y:165)
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .clipped()

                // --- 下半部 ---
                ZStack {
                    Image("ground-texture").resizable().scaledToFill().clipped()
                    
                    VStack(spacing: 15) {
                        Spacer()
                        ForEach(viewModel.currentQuestion.options, id: \.self) { option in
                            OptionButton(
                                optionText: option,
                                selectedOption: $selectedOption,
                                isSubmitted: $isAnswerSubmitted,
                                correctAnswer: viewModel.currentQuestion.correctAnswer
                            )
                            .modifier(ShakeEffect(attempts: wrongAttempts.filter { $0 == option }.count))
                            .onTapGesture {
                                handleTap(on: option)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        ProgressBar(progress: currentProgress)
                        .offset(y: 6)
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
            .padding(.top, 60)
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
    
    private func handleTap(on option: String) {
        guard !isAnswerSubmitted else { return }
        isAnswerSubmitted = true
        selectedOption = option
        let isCorrect = viewModel.submitAnswer(option)
        if !isCorrect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isAnswerSubmitted = false
                selectedOption = nil
                wrongAttempts.append(option)
            }
        }
    }
}


// MARK: - Subviews for LevelView

struct ImagePopupView: View {
    let imageName: String
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation(.spring()) { isVisible = false }
                }
            
            Image(imageName)
                .resizable()
                .scaledToFit()
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
                .font(.custom("CEF Fonts CJK Mono", size: 24))                .fixedSize(horizontal: false, vertical: true)
            
            if hasImage {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 24, weight: .bold))
            }
        }
        .font(.system(size: 30, weight: .heavy, design: .rounded))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(.black.opacity(0.6))
        .cornerRadius(20)
        .shadow(radius: 5)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.3)
    }
}

struct ProgressBar: View {
    let progress: Double
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.black.opacity(0.5))
            Capsule().fill(Color.supercarGold).frame(width: 380 * progress)
        }
        .frame(width: 380, height: 12)
        .padding(0)
        .background(Capsule().fill(Color.white.opacity(0.9)))
        .overlay(Capsule().stroke(Color.black.opacity(0.5), lineWidth: 2))
        .animation(.spring(), value: progress)
    }
}

struct HeartView: View {
    let lives: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                Image(systemName: "heart.fill")
                    .font(.title2).foregroundColor(index < lives ? Color.red : Color.black.opacity(0.3))
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
            .resizable()
            .scaledToFit()
            // ✨ [修改] 按鈕放大 1.2 倍 (原為 75)
            .frame(height: 93)
            .cornerRadius(15)
            .overlay(
                Text(optionText)
                    .font(.custom("CEF Fonts CJK Mono", size: 26)) // 用你的字體名稱
                    .fontWeight(.heavy)                     // 如果字體有支援粗體，會生效
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


#Preview {
    ContentView()
}
