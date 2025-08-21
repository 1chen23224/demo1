import SwiftUI

struct LevelView: View {
    @EnvironmentObject var viewModel: GameViewModel
    
    @State private var selectedOption: Int?
    @State private var isAnswerSubmitted = false
    @State private var wrongAttempts: [Int] = []

    var body: some View {
        // 根視圖使用 ZStack，以便我們可以自由地在任何層級疊加 UI 元件
        ZStack {
            // 主要的垂直背景佈局
            VStack(spacing: 0) {
                // --- 上半部：佔據螢幕 50% 的高度 ---
                ZStack(alignment: .bottom) {
                    // 天空背景
                    Color(red: 135/255, green: 206/255, blue: 235/255)

                    // 捲動世界，它會被 ZStack 的 alignment: .bottom 推到底部
                    ScrollingBackgroundView(scrollTrigger: viewModel.score)
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
                .clipped()

                // --- 下半部：佔據螢幕 50% 的高度 ---
                ZStack {
                    // 地面材質背景
                    Image("ground-texture")
                        .resizable()
                        .scaledToFill()
                        .clipped()

                    // 選項按鈕
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

                    // 將進度條放在下半部的頂部，並向上偏移
                    VStack {
                        ProgressBar(
                            progress: Double(viewModel.currentQuestionIndex) / Double(viewModel.totalQuestions),
                            totalSteps: viewModel.totalQuestions
                        )
                        .offset(y: -25) // 向上偏移，使其跨坐在中線上
                        Spacer()
                    }
                }
                .frame(height: UIScreen.main.bounds.height * 0.5)
            }
            
            // --- 疊加在最上層的 UI ---
            
            // ✨ [佈局修正] 將 QuestionBar 直接放到根 ZStack 中，並調整其垂直位置
            VStack {
                QuestionBar(text: viewModel.currentQuestion.text)
                    // 使用 padding 來控制垂直位置，0.15 大約是天空的中間位置
                    .padding(.top, UIScreen.main.bounds.height * 0.15)
                    .padding(.horizontal) // 保持水平方向的邊距
                Spacer()
            }

            // 心心放在右上角
            VStack {
                HStack {
                    Spacer()
                    HeartView(lives: viewModel.lives)
                        .padding(.trailing)
                        .padding(.top, 60) // 與頂部保持一個固定距離
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
// 輔助視圖的程式碼保持不變，但為了完整性，我依然附上

struct QuestionBar: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 36, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding()
            .background(.black.opacity(0.6))
            .cornerRadius(20)
            .shadow(radius: 5)
    }
}

struct ProgressBar: View {
    let progress: Double
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(min(totalSteps, Int(progress * Double(totalSteps)) + 1)) / \(totalSteps)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.black)
            
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.5)).frame(height: 12)
                Capsule().fill(Color.white).frame(width: max(12, 150 * progress), height: 12)
                    .animation(.spring, value: progress)
            }
            .frame(width: 150)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.9))
        .cornerRadius(20)
        .overlay(
            Capsule().stroke(Color.black.opacity(0.5), lineWidth: 2)
        )
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
    let option: Int
    @Binding var selectedOption: Int?
    @Binding var isSubmitted: Bool
    let correctAnswer: Int

    var body: some View {
        ZStack {
            Image("option-button-bg")
                .resizable()
                .scaledToFit()
            
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
