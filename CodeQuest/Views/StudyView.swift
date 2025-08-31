import SwiftUI

// MARK: - 主視圖 (StudyView)
struct StudyView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @StateObject private var viewModel = GameViewModel()
    
    let onStartReview: ([QuizQuestion]) -> Void
    let onBack: () -> Void
    @State private var selectedReviewType = 0

    // ✅ RESTORED: Add the missing @State variable here
    @State private var showGuideOverlay = true

    // ✨ NEW: 用於控制錯題導覽書的顯示狀態
    @State private var showWrongQuestionsGuide = false
    
    var body: some View {
        ZStack {
            // 🔹 背景 & 內容
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image("stage-background6")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height + 100)
                        .clipped()
                        .ignoresSafeArea()
                }
            }

            
            VStack(spacing: 20) {
                TabView(selection: $selectedReviewType) {
                    WrongQuestionsReviewView(
                        allQuestions: viewModel.allQuestions,
                        onStartReview: onStartReview,
                        showGuideAction: { showWrongQuestionsGuide = true } // ✨ NEW: 傳入觸發 Action
                    )
                    .tag(0)

                    AllQuestionsReviewView(
                        allQuestions: viewModel.allQuestions,
                        onStartReview: onStartReview
                    )
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .padding(.top, 20)

            // ✨ NEW: 如果 showWrongQuestionsGuide 為 true，則顯示錯題導覽書
            if showWrongQuestionsGuide {
                // 取得所有錯題
                let wrongQuestions = viewModel.allQuestions.filter {
                    dataService.wrongQuestionIDs.contains($0.questionID)
                }
                
                ReviewGuidebookView(
                    title: "錯題導覽書",
                    questions: wrongQuestions,
                    onClose: { showWrongQuestionsGuide = false }
                )
            }
            
            // 👉 第一次進來的提示 Overlay
            if showGuideOverlay {
                // 背景半透明，但不擋觸控
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)
                    .allowsHitTesting(false)
                
                VStack(spacing: 20) {
                    Text("提示")
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)
                    Text("你可以向右滑動切換到『總複習』頁面")
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.yellow)
                        .padding(.top, 10)
                    
                    Button("我知道了") {
                        withAnimation {
                            showGuideOverlay = false
                        }
                        UserDefaults.standard.set(true, forKey: "hasSeenStudyGuide")
                    }
                    .padding()
                    .background(Color.white.opacity(0.9))
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .padding()
                .zIndex(1) // 確保提示在最上層
            }
        }
        .onAppear {
            if UserDefaults.standard.bool(forKey: "hasSeenStudyGuide") {
                showGuideOverlay = false
            }
        }
    }
}


// MARK: - 錯題重溫視圖
struct WrongQuestionsReviewView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let allQuestions: [QuizQuestion]
    let onStartReview: ([QuizQuestion]) -> Void
    
    // ✨ NEW: 接收一個 Action 來觸發導覽書
    let showGuideAction: () -> Void
    
    @State private var chapterPercentages: [Int: Double] = [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0]
    // ✨ NEW: 將彈窗狀態移到這裡
    @State private var showClearAlert = false

    private var totalQuestionsToReview: Int {
        var total = 0
        for (chapter, percentage) in chapterPercentages {
            let wrongQuestions = getWrongQuestions(for: chapter)
            total += Int(Double(wrongQuestions.count) * percentage)
        }
        return total
    }

    var body: some View {
        VStack(spacing: 15) {
            // ✨ NEW: 標題和導覽書按鈕
            HStack {
                Spacer()
                Text("錯題重溫")
                    .font(.custom("CEF Fonts CJK Mono", size: 32)).bold().foregroundColor(.white)
                Spacer()
                // 只有當有錯題時才顯示導覽書按鈕
                if !dataService.wrongQuestionIDs.isEmpty {
                    // ✨ NEW: 垃圾桶按鈕
                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title2) // 統一圖示大小
                            .foregroundColor(.red)
                    }
                    
                    Button(action: showGuideAction) {
                        Image(systemName: "book.closed.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }
            
            ForEach(1...5, id: \.self) { chapter in
                let wrongQuestionsInChapter = getWrongQuestions(for: chapter)
                // ✨ [修正] 現在 isChapterUnlocked 應該由 dataService 判斷
                if dataService.isChapterUnlocked(chapter) && !wrongQuestionsInChapter.isEmpty {
                    ReviewChapterRow(
                        title: "第 \(chapter) 章",
                        totalCount: wrongQuestionsInChapter.count,
                        percentage: Binding(
                            get: { self.chapterPercentages[chapter, default: 1.0] },
                            set: { self.chapterPercentages[chapter] = $0 }
                        )
                    )
                }
            }
            Spacer()
            Button("建立錯題重溫關卡") {
                var reviewQuestions: [QuizQuestion] = []
                for (chapter, percentage) in chapterPercentages {
                    let wrongQuestions = getWrongQuestions(for: chapter)
                    let countToTake = Int(Double(wrongQuestions.count) * percentage)
                    reviewQuestions.append(contentsOf: wrongQuestions.shuffled().prefix(countToTake))
                }
                
                if !reviewQuestions.isEmpty { onStartReview(reviewQuestions.shuffled()) }
            }
            .buttonStyle(.borderedProminent)
            .font(.custom("CEF Fonts CJK Mono", size: 20))
            .padding(.bottom, 33)
            .disabled(totalQuestionsToReview == 0) // 如果總數為 0，禁用按鈕
        }
        .padding()
        // ✨ NEW: 將 .alert 彈窗修飾符加到這裡
        .alert("確定要清除所有錯題嗎？", isPresented: $showClearAlert) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                GameDataService.shared.clearWrongQuestions()
            }
        } message: {
            Text("此操作無法復原，錯題紀錄將會消失。")
        }
    }
    
    // ✨ [主要修改處] 改用 question.level 來判斷章節
    private func getWrongQuestions(for chapter: Int) -> [QuizQuestion] {
        return allQuestions.filter { question in
            dataService.wrongQuestionIDs.contains(question.questionID) &&
            question.level == chapter // <-- 使用 level 來判斷章節
        }
    }
}

// MARK: - 總複習視圖 (已修正)
struct AllQuestionsReviewView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let allQuestions: [QuizQuestion]
    let onStartReview: ([QuizQuestion]) -> Void
    
    @State private var chapterPercentages: [Int: Double] = [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2]

    // 計算總共要複習的題目數量
    private var totalQuestionsToReview: Int {
        var total = 0
        for (chapter, percentage) in chapterPercentages {
            if dataService.isChapterUnlocked(chapter) {
                let questions = getQuestions(for: chapter)
                total += Int(Double(questions.count) * percentage)
            }
        }
        return total
    }

    var body: some View {
        VStack(spacing: 15) {
            Text("總複習").font(.custom("CEF Fonts CJK Mono", size: 32)).bold().foregroundColor(.white)
            
            ForEach(1...5, id: \.self) { chapter in
                let questionsInChapter = getQuestions(for: chapter)
                if dataService.isChapterUnlocked(chapter) && !questionsInChapter.isEmpty {
                    ReviewChapterRow(
                        title: "第 \(chapter) 章",
                        totalCount: questionsInChapter.count,
                        percentage: Binding(
                            get: { self.chapterPercentages[chapter, default: 0.2] },
                            set: { self.chapterPercentages[chapter] = $0 }
                        )
                    )
                }
            }
            Spacer()
            
            // ✨ NEW: 模擬考比例按鈕
            // 條件：必須已解鎖第五章
            if dataService.isChapterUnlocked(5) {
                Button(action: setMockExamRatio) {
                    Label("設為模擬考比例", systemImage: "graduationcap.fill")
                }
                .buttonStyle(.bordered) // 使用不同樣式以區分
                .tint(.yellow)
            }
            
            Button("建立總複習關卡") {
                var reviewQuestions: [QuizQuestion] = []
                for (chapter, percentage) in chapterPercentages {
                    if dataService.isChapterUnlocked(chapter) {
                        let questions = getQuestions(for: chapter)
                        let countToTake = Int(Double(questions.count) * percentage)
                        reviewQuestions.append(contentsOf: questions.shuffled().prefix(countToTake))
                    }
                }
                if !reviewQuestions.isEmpty { onStartReview(reviewQuestions.shuffled()) }
            }
            .buttonStyle(.borderedProminent)
            .font(.custom("CEF Fonts CJK Mono", size: 20))
            .padding(.bottom, 33)
            .disabled(totalQuestionsToReview == 0) // 如果總數為 0，禁用按鈕
        }
        .padding()
    }
    
    // ✨ [主要修改處] 改用 question.level 來判斷章節
    private func getQuestions(for chapter: Int) -> [QuizQuestion] {
        return allQuestions.filter { $0.level == chapter }
    }
    // ✨ NEW: 設定模擬考比例的函式
    private func setMockExamRatio() {
        let mockExamCounts: [Int: Int] = [1: 12, 2: 8, 3: 10, 4: 10, 5: 10]
        
        withAnimation {
            for chapter in 1...5 {
                let totalQuestionsInChapter = getQuestions(for: chapter).count
                guard totalQuestionsInChapter > 0 else { continue } // 如果該章沒題目，則跳過
                
                // 取得目標題目數，並確保不超過該章節的總題數
                let targetCount = min(mockExamCounts[chapter, default: 0], totalQuestionsInChapter)
                
                // 計算所需比例
                let percentage = Double(targetCount) / Double(totalQuestionsInChapter)
                
                // 更新比例，觸發 Slider UI 更新
                self.chapterPercentages[chapter] = percentage
            }
        }
    }
    
}
// MARK: - ✨ NEW: 可重用的複習導覽書 (ReviewGuidebookView)
// 這是一個更通用的導覽書，可以顯示任何傳入的問題列表，並按章節分類
struct ReviewGuidebookView: View {
    let title: String
    let questions: [QuizQuestion] // 直接接收一個問題陣列
    let onClose: () -> Void
    
    @State private var zoomedImageName: String? = nil
    @State private var searchText = ""
    
    // 按章節分組的問題
    private var chapters: [Int] {
        // 從問題列表中提取所有不重複的章節號碼，並排序
        Array(Set(questions.map { $0.level })).sorted()
    }
    
    private func questionsForChapter(_ chapter: Int) -> [QuizQuestion] {
        let chapterQuestions = questions.filter { $0.level == chapter }
        if searchText.isEmpty {
            return chapterQuestions
        } else {
            return chapterQuestions.filter {
                $0.questionText.localizedCaseInsensitiveContains(searchText) ||
                $0.correctAnswer.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                
                if questions.isEmpty {
                    Text("目前沒有任何題目")
                        .font(.title2)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        ForEach(chapters, id: \.self) { chapter in
                            // 檢查搜尋後該章節是否還有題目
                            let filteredQuestions = questionsForChapter(chapter)
                            if !filteredQuestions.isEmpty {
                                Section(header: Text("第 \(chapter) 章")
                                    .font(.headline).padding(.leading).padding(.top)) {
                                    LazyVStack(spacing: 0) {
                                        ForEach(filteredQuestions) { question in
                                            GuidebookRowView(
                                                question: question,
                                                chapterNumber: chapter,
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
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").font(.title3).foregroundColor(.gray)
                    }
                }
            }
            .overlay { // 使用 overlay 來疊加放大圖片
                if let imageName = zoomedImageName {
                    ZoomedImageView(imageName: imageName, zoomedImageName: $zoomedImageName)
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋問題或答案")
        // 👇 2. 把圓角、陰影、邊距修飾符，加在 NavigationStack 的外面
        .cornerRadius(20)
        .shadow(radius: 15)
        // MARK: 在這裡調整整個錯題導覽書的大小
        .padding(.horizontal, 25) // 👈 調整【寬度】，數字越小越寬
        .padding(.vertical, 42)   // 👈 調整【高度】，數字越小越高
    }
}// MARK: - 可重用的 UI 元件 (進度條)
struct ReviewChapterRow: View {
    let title: String
    let totalCount: Int
    @Binding var percentage: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(title): 共 \(totalCount) 題")
                    .padding(.horizontal,10)
                Spacer()
                Text("題目比例: \(Int(percentage * 100))%")
                .padding(.horizontal,10)
            }
            .font(.custom("CEF Fonts CJK Mono", size: 14)) // 縮小一點
            
            Slider(value: $percentage, in: 0...1, step: 0.01)

        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .foregroundColor(.white)
    }
}
#Preview {
    ContentView()
}
