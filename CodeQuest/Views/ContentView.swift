import SwiftUI

struct ContentView: View {
    @State private var hasFinishedLaunch = false
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if hasFinishedLaunch {
                GameNavigationView()
            } else {
                SplashScreenView(onFinished: handleLaunchFinish)
            }

            if isTransitioning {
                Color.black.edgesIgnoringSafeArea(.all)
            }
        }
    }

    private func handleLaunchFinish() {
        withAnimation(.easeIn(duration: 0.75)) {
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
/// 放在 TabView 的背景，用來開/關 PageTabViewStyle 的滑動
struct TabSwipeDisabler: UIViewRepresentable {
    var isDisabled: Bool

    func makeUIView(context: Context) -> UIView { UIView() }

    func updateUIView(_ view: UIView, context: Context) {
        // 放到下一輪 runloop，確保階層已經建立
        DispatchQueue.main.async {
            guard let scrollView = view.findFirstPagingScrollViewInAncestors() else { return }
            // 只影響 TabView 的分頁滑動，不影響子視圖自己的 ScrollView
            scrollView.isScrollEnabled = !isDisabled
            scrollView.panGestureRecognizer.isEnabled = !isDisabled
        }
    }
}

private extension UIView {
    func findFirstPagingScrollViewInAncestors() -> UIScrollView? {
        // 往上找到 root，再由上往下找第一個 isPagingEnabled 的 UIScrollView
        var root: UIView = self
        while let s = root.superview { root = s }
        return root.firstPagingScrollView()
    }

    func firstPagingScrollView() -> UIScrollView? {
        if let sv = self as? UIScrollView, sv.isPagingEnabled { return sv }
        for sub in subviews {
            if let found = sub.firstPagingScrollView() { return found }
        }
        return nil
    }
}
struct GameNavigationView: View {
    @State private var selectedTab = 0
    @State private var selectedChapter: Int? = nil
    @State private var selectedStage: Int? = nil
    @State private var customReviewQuestions: [QuizQuestion]? = nil
    @State private var isOverlayActive = false
    
    @State private var showPersonalAlert = false
    
    @EnvironmentObject var languageManager: LanguageManager   // 👈 注入語言管理器

    private var shouldLockTabSwipe: Bool {
        selectedTab == 0 &&
        selectedChapter != nil &&
        selectedStage == nil &&
        customReviewQuestions == nil
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // 學習
            Group {
                if let questions = customReviewQuestions {
                    LevelView(
                        isGameActive: Binding(
                            get: { customReviewQuestions != nil },
                            set: { if !$0 { customReviewQuestions = nil; selectedTab = 1 } }
                        )
                    )
                    .environmentObject(GameViewModel(customQuestions: questions))

                } else if let stage = selectedStage {
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
                        onBack: { self.selectedChapter = nil },
                        isOverlayActive: $isOverlayActive
                    )
                } else {
                    ChapterSelectionView(
                        onChapterSelect: { chapterNumber in self.selectedChapter = chapterNumber },
                        onSelectReviewTab: { selectedTab = 1 }
                    )
                }
            }
            .tag(0)

            // 錯題複習
            StudyView(
                initialTab: 0, // 👉 預設錯題複習
                onStartReview: { questions in
                    self.customReviewQuestions = questions
                    self.selectedTab = 0
                },
                onBack: { selectedTab = 0 }
            )
            .tag(1)

            // 總複習
            StudyView(
                initialTab: 1, // 👉 預設總複習
                onStartReview: { questions in
                    self.customReviewQuestions = questions
                    self.selectedTab = 0
                },
                onBack: { selectedTab = 0 }
            )
            .tag(2)
        }

        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(TabSwipeDisabler(isDisabled: shouldLockTabSwipe))
        .ignoresSafeArea()
        .safeAreaInset(edge: .bottom) {
            if selectedStage == nil && customReviewQuestions == nil && !isOverlayActive {
                HStack {
                    BottomTabButton(iconName: "icon-1", title: "tab_study".localized(), tag: 0, isSelected: selectedTab == 0) {
                        withAnimation { selectedTab = 0 }
                    }
                    BottomTabButton(iconName: "icon-2", title: "tab_wrong".localized(), tag: 1, isSelected: selectedTab == 1) {
                        withAnimation { selectedTab = 1 }
                    }
                    BottomTabButton(iconName: "icon-3", title: "tab_review".localized(), tag: 2, isSelected: selectedTab == 2) {
                        withAnimation { selectedTab = 2 }
                    }
                    BottomTabButton(iconName: "icon-4", title: "tab_contact".localized(), tag: 3, isSelected: false, isEnabled: true) {
                        showPersonalAlert = true
                    }
                }
                .id(languageManager.currentLanguage)
                .padding(.horizontal, 30)
                .frame(maxWidth: .infinity)
                .frame(height: 70)
                .background(Color.black.opacity(0.3))
                .offset(y: 25)
            }
        }

        .alert("contact_alert_title".localized(), isPresented: $showPersonalAlert) {
            Button("contact_alert_button_ig".localized()) {
                openInstagram(username: "full_score_top")
            }
            Button("contact_alert_button_cancel".localized(), role: .cancel) { }
        } message: {
            Text("contact_alert_message".localized())
        }
    }
    
    private func openInstagram(username: String) {
        if let appURL = URL(string: "instagram://user?username=\(username)"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
        } else if let webURL = URL(string: "https://instagram.com/\(username)") {
            UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(LanguageManager.shared) // Add this line
}
