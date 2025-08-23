import SwiftUI

struct LevelView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    @State private var selectedOption: Int?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [Int] = []

    private var currentProgress: Double {
        if viewModel.isQuizComplete {
            return 1.0
        }
        return Double(viewModel.currentQuestionIndex) / Double(viewModel.totalQuestions)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // --- 上半部 ---
                ZStack(alignment: .bottom) {
                    Color(red: 95/255, green: 191/255, blue: 235/255)
                    ScrollingBackgroundView(scrollTrigger: viewModel.score).offset(y: 160)                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .clipped()

                // --- 下半部 ---
                ZStack {
                    Image("ground-texture")
                        .resizable()
                        .scaledToFill()
                        .clipped()

                    VStack {
                        Spacer()
                        ForEach(viewModel.currentQuestion.options, id: \.self) { option in
                            OptionButton(
                                option: option,
                                selectedOption: $selectedOption,
                                isSubmitted: $isAnswerSubmitted,
                                correctAnswer: viewModel.currentQuestion.correctAnswer
                            )
                            .modifier(ShakeEffect(attempts: wrongAttempts.filter { $0 == option }.count))
                            .onTapGesture {
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
                        Spacer()
                    }
                    .padding(.horizontal)

                    VStack {
                        ProgressBar(progress: currentProgress)
                        .offset(y: -10)
                        Spacer()
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            .edgesIgnoringSafeArea(.all)

            // --- 疊加 UI ---
            VStack {
                QuestionBar(text: viewModel.currentQuestion.text)
                    .padding(.top, 80)
                    .padding(.horizontal, 30)
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    HeartView(lives: viewModel.lives)
                        .padding(.trailing)
                        .padding(.top, 20)
                }
                Spacer()
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
}


// MARK: - Subviews for LevelView

struct QuestionBar: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            // ✨ [新增] 讓 Text 優先填滿所有可用寬度
            .frame(maxWidth: .infinity)
            .padding()
            .background(.black.opacity(0.6))
            .cornerRadius(20)
            .shadow(radius: 5)
    }
}

struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        // ✨ [結構修正] 我們將 padding 和 background/overlay 直接應用在 ZStack 上
        ZStack(alignment: .leading) {
            // 背景層
            Capsule().fill(Color.black.opacity(0.5))
            
            // 金色填充層
            Capsule().fill(Color.supercarGold)
                .frame(width: 400 * progress) // 使用你設定的 400 寬度
        }
        .frame(width: 400, height: 12)
        .padding(0)
        // ✨ [關鍵修正] 直接使用一個 Capsule 作為背景，而不是方形背景
        .background(
            Capsule().fill(Color.white.opacity(0.9))
        )
        .overlay(
            Capsule().stroke(Color.black.opacity(0.5), lineWidth: 2)
        )
        .animation(.spring(), value: progress) // 將動畫應用到整個元件
    }
}

// HeartView 保持不變
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

// OptionButton 保持不變
struct OptionButton: View {
    let option: Int
    @Binding var selectedOption: Int?
    @Binding var isSubmitted: Bool
    let correctAnswer: Int

    var body: some View {
        ZStack {
            Image("option-button-bg").resizable().scaledToFit()
            Text("\(option)")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundColor(Color(red: 60/255, green: 40/255, blue: 40/255))
        }
        .frame(height: 75)
        .opacity(buttonOpacity)
        .shadow(color: isSubmitted && option == selectedOption ? buttonColor.opacity(0.8) : .clear, radius: 10)
        .scaleEffect(isSubmitted && option == selectedOption ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: selectedOption)
        .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isSubmitted)
    }
    
    private var buttonColor: Color {
        guard isSubmitted, let selected = selectedOption, option == selected else { return .clear }
        return selected == correctAnswer ? .green : .red
    }
    
    private var buttonOpacity: Double {
        guard isSubmitted else { return 1.0 }
        guard let selected = selectedOption else { return 1.0 }
        if option == selected { return 1.0 }
        return 0.5
    }
}


// MARK: - Preview
#Preview {
    ContentView()
}
