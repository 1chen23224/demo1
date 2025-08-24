import SwiftUI

struct ContentView: View {
    // 追蹤啟動流程是否已完成
    @State private var hasFinishedLaunch = false
    
    // 用於「全黑漸變」轉場
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            if hasFinishedLaunch {
                // 啟動流程完成後，顯示我們之前做好的遊戲主體
                GameNavigationView()
            } else {
                // App 剛打開時，顯示啟動畫面
                SplashScreenView(onFinished: handleLaunchFinish)
            }
            
            // 用於轉場的黑色覆蓋層
            if isTransitioning {
                Color.black.edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    // 處理從啟動畫面到主選單的轉場
    private func handleLaunchFinish() {
        // 1. 淡入全黑
        withAnimation(.easeIn(duration: 0.5)) {
            isTransitioning = true
        }
        
        // 2. 等待動畫完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 3. 在背景切換主畫面
            self.hasFinishedLaunch = true
            
            // 4. 淡出全黑，顯示主畫面
            withAnimation(.easeOut(duration: 0.5)) {
                isTransitioning = false
            }
        }
    }
}

// 我們將原本的導航邏輯，乾淨地封裝在這個 View 中
struct GameNavigationView: View {
    @State private var selectedChapter: Int? = nil
    @State private var selectedStage: Int? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                if let stage = selectedStage {
                    LevelView(
                        isGameActive: Binding(
                            get: { selectedStage != nil },
                            set: { if !$0 { selectedStage = nil } }
                        )
                    )
                    .environmentObject(GameViewModel(stage: stage))
                } else if let chapter = selectedChapter {
                    MainMenuView(
                        chapterNumber: chapter,
                        onStageSelect: { stageNumber in self.selectedStage = stageNumber },
                        onBack: { self.selectedChapter = nil }
                    )
                } else {
                    ChapterSelectionView(
                        onChapterSelect: { chapterNumber in self.selectedChapter = chapterNumber }
                    )
                }
            }
            .animation(.default, value: selectedChapter)
            .animation(.default, value: selectedStage)
        }
        .navigationViewStyle(.stack)
    }
    
    private var navigationTitleText: String {
        if let stage = selectedStage {
            return "第 \(stage) 關"
        } else if let chapter = selectedChapter {
            return "第 \(chapter) 章"
        } else {
            return "滿分上路"
        }
    }
}

#Preview {
    ContentView()
}
