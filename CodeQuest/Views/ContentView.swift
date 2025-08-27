import SwiftUI

struct ContentView: View {
    // --- 原有狀態 ---
    @State private var hasFinishedLaunch = false
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            // 新增一個永久的黑色背景，防止轉場時出現白色閃爍
            Color.black.edgesIgnoringSafeArea(.all)
            
            if hasFinishedLaunch {
                // 啟動流程完成後，顯示遊戲主體
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
    
    // 處理從啟動畫面到主選單的轉場 (您的版本)
    private func handleLaunchFinish() {
        withAnimation(.easeIn(duration: 0.75)) { // 調整為 0.75 秒
            isTransitioning = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            self.hasFinishedLaunch = true
            withAnimation(.easeOut(duration: 0.75)) {
                isTransitioning = false
            }
        }
    }
}

// ✨ [主要修改處]
// 我們將所有與「學習中心/錯題本」相關的導航邏輯，都整合到 GameNavigationView 中
struct GameNavigationView: View {
    // --- 原有狀態 ---
    @State private var selectedChapter: Int? = nil
    @State private var selectedStage: Int? = nil
    
    // ✨ [新增] 用於控制學習中心/錯題本畫面的顯示
    @State private var showStudyView = false
    @State private var customReviewQuestions: [QuizQuestion]? = nil

    var body: some View {
        NavigationView {
            ZStack {
                if let questions = customReviewQuestions {
                    // 狀態 5: 顯示由學習中心建立的特別複習關卡
                    LevelView(
                        isGameActive: Binding(
                            get: { customReviewQuestions != nil },
                            set: { if !$0 { customReviewQuestions = nil; showStudyView = true } }
                        )
                    )
                    .environmentObject(GameViewModel(customQuestions: questions))

                } else if showStudyView {
                    // 狀態 4: 顯示學習中心畫面 (StudyView)
                    StudyView(
                        onStartReview: { questions in
                            // 當 StudyView 中的按鈕被點擊時，設定自訂題目並跳轉
                            self.customReviewQuestions = questions
                            self.showStudyView = false // 關閉 StudyView 以顯示 LevelView
                        },
                        onBack: {
                            // 返回章節選擇畫面
                            self.showStudyView = false
                        }
                    )
                
                } else if let stage = selectedStage {
                    // 狀態 3: 顯示遊戲畫面 (LevelView)
                    LevelView(
                        isGameActive: Binding(
                            get: { selectedStage != nil },
                            set: { if !$0 { selectedStage = nil } }
                        )
                    )
                    .environmentObject(GameViewModel(stage: stage))
                    
                } else if let chapter = selectedChapter {
                    // 狀態 2: 顯示關卡選擇畫面 (MainMenuView)
                    MainMenuView(
                        chapterNumber: chapter,
                        onStageSelect: { stageNumber in self.selectedStage = stageNumber },
                        onBack: { self.selectedChapter = nil }
                    )
                    
                } else {
                    // 狀態 1: 顯示章節選擇畫面 (ChapterSelectionView)
                    ChapterSelectionView(
                        onChapterSelect: { chapterNumber in self.selectedChapter = chapterNumber },
                        // ✨ [新增] 將「顯示學習中心」的動作傳遞下去
                        onSelectReviewTab: { self.showStudyView = true }
                    )
                }
            }
            .animation(.default, value: selectedChapter)
            .animation(.default, value: selectedStage)
            .animation(.default, value: showStudyView)
            .animation(.default, value: customReviewQuestions != nil)
        }
        .navigationViewStyle(.stack)
    }
    
}

#Preview {
    ContentView()
}
