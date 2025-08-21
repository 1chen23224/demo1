// MARK: - Views/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()

    var body: some View {
        ZStack {
            // 使用我們自訂的背景色
            Color.appBackgroundFallback.edgesIgnoringSafeArea(.all)
            
            if viewModel.isGameOver {
                GameOverView(score: viewModel.score, restartAction: viewModel.restartGame)
                    .transition(.asymmetric(insertion: .scale, removal: .opacity))
            } else {
                LevelView()
                    .environmentObject(viewModel)
            }
        }
        .animation(.default, value: viewModel.isGameOver)
    }
}

// 遊戲結束畫面
struct GameOverView: View {
    let score: Int
    let restartAction: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("遊戲結束")
                .font(.system(size: 50, weight: .bold, design: .rounded))
                .foregroundColor(.primaryTextFallback)
            
            Text("你的分數: \(score)")
                .font(.system(size: 30, design: .rounded))
                .foregroundColor(.primaryTextFallback)
            
            Button(action: restartAction) {
                Text("再試一次")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(Color.correctGreenFallback)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
            }
        }
    }
}
