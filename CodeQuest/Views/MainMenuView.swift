import SwiftUI

struct MainMenuView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var showingDetailForStage: Int? = nil

    // --- ✨ 過場動畫狀態 ---
    @State private var showTransitionOverlay = false
    @State private var overlayOpacity: Double = 1.0
    @State private var textOpacity: Double = 0.0   // 文字透明度
    @State private var pendingStage: Int? = nil

    // --- ✨ 新手教學狀態 ---
    @State private var showTutorial = false
    @State private var tutorialStep = 0
    @State private var arrowOffset: CGFloat = -80

    @State private var dimBackground = true
    @State private var tutorialTextAtBottom = false

    // --- ✨ 新增：過關祝賀 ---
    @State private var showCongrats = false
    // ✨ NEW: 新增導覽書的顯示狀態
    @State private var showSummary = false
    @State private var showGuidebook = false
    
    // MainMenuView 需要知道它是第幾章
    let chapterNumber: Int

    let onStageSelect: (Int) -> Void
    let onBack: () -> Void
    
    // 👇 新增：傳出過場狀態給 GameNavigationView
    @Binding var isOverlayActive: Bool
    
    
    private var stagesForThisChapter: Range<Int> {
        let totalBefore = dataService.chapterStageCounts.prefix(chapterNumber - 1).reduce(0, +)
        let chapterSize = dataService.stagesInChapter(chapterNumber)
        let startStage = totalBefore + 1
        let endStage = totalBefore + chapterSize
        return startStage..<(endStage + 1)
    }

    var body: some View {
        ZStack {
            // --- 背景 ---
            Image("stage-background\(chapterNumber)")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            // --- 主內容 ---
            VStack(spacing: 50) {
                Text("第 \(chapterNumber) 章")
                    .font(.custom("CEF Fonts CJK Mono", size: 40))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5, y: 5)

                GeometryReader { geo in
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .center) {
                                Capsule()
                                    .fill(Color.black.opacity(0.25))
                                    .frame(height: 25)
                                    .padding(.horizontal, geo.size.width * -0.01)   // ✅ 改比例

                                HStack(spacing: geo.size.width * 0.08) {         // ✅ 改比例
                                    ForEach(stagesForThisChapter, id: \.self) { stage in
                                        StageIconView(
                                            stageNumber: stage,
                                            chapterNumber: chapterNumber,
                                            isUnlocked: dataService.isStageUnlocked(stage),
                                            isNew: stage == dataService.highestUnlockedStage,
                                            result: dataService.getResult(for: stage),
                                            action: {
                                                self.showingDetailForStage = stage
                                                if showTutorial && tutorialStep == 1 {
                                                    tutorialStep = 2
                                                }
                                            }
                                        )
                                        .id(stage)
                                    }
                                }
                                .padding(.horizontal, geo.size.width * 0.15)      // ✅ 改比例
                            }
                            .padding(.vertical, 40)
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring()) {
                                    proxy.scrollTo(dataService.highestUnlockedStage, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(height: 180)  // ✅ 固定高度避免 GeometryReader 撐開

                Spacer()
            }
            .padding(.top, 60)
            
            
            // --- 返回按鈕 ---
            GeometryReader { geo in
                VStack {
                    HStack {
                        Button(action: onBack) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .shadow(radius: 5)
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                                    .padding(4)
                                Image(systemName: "arrow.backward")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .frame(width: 44, height: 44)
                        }
                        .padding(.leading, geo.size.width * 0.15)   // ✅ 自動適應 iPhone/iPad
                        .padding(.vertical, geo.size.height * 0.06)
                        
                        // ✨ NEW: 導覽書按鈕
                        Button(action: {
                            showGuidebook = true
                        }) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .padding(.horizontal, geo.size.width * 0.5)
                        // ✨ NEW: 重點整理按鈕
                    Button(action: { showSummary = true }) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.yellow)
                        }
                    .padding(.horizontal, geo.size.width * -0.7)
                    }
                    Spacer()

                    
                }
            }
            .edgesIgnoringSafeArea(.all)
    
            
            // --- 關卡細節彈窗 ---
            if let stage = showingDetailForStage {
                StageDetailView(
                    stageNumber: stage,
                    chapterNumber: chapterNumber,
                    result: dataService.getResult(for: stage),
                    onStart: {
                        if showTutorial {
                            tutorialStep = 3
                        }
                        self.showingDetailForStage = nil
                        pendingStage = stage
                        showTransitionOverlay = true
                        overlayOpacity = 0.0
                        textOpacity = 0.0
                        
                        withAnimation(.easeIn(duration: 1)) {
                            overlayOpacity = 1.0
                        }
                        withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
                            textOpacity = 1.0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            if let stage = pendingStage {
                                onStageSelect(stage)
                            }
                            withAnimation(.easeOut(duration: 1.0)) {
                                overlayOpacity = 0
                                textOpacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                showTransitionOverlay = false
                                pendingStage = nil
                                if showTutorial && tutorialStep == 3 {
                                    showTutorial = false
                                }
                            }
                        }
                    },
                    onCancel: {
                        self.showingDetailForStage = nil
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // --- ✨ 黑幕過場層 ---
            if showTransitionOverlay {
                Color.black
                    .opacity(overlayOpacity)
                    .edgesIgnoringSafeArea(.all)
                
                if let stage = pendingStage {
                    let (chapter, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stage)
                    let isBossStage = stageInChapter == GameDataService.shared.stagesInChapter(chapter)
                    
                    Text(isBossStage
                         ? "-第 \(chapter) 章-\n\n\n  最終關"
                         : "-第 \(chapter) 章-\n\n\n  第\(stageInChapter)關")
                    .font(.custom("CEF Fonts CJK Mono", size: 30))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(textOpacity)
                }
            }

        
            // --- 教學引導 Overlay ---
            if showTutorial {
                Color.black.opacity(dimBackground ? 0.5 : 0.0)
                    .edgesIgnoringSafeArea(.all)
                    .animation(.easeInOut(duration: 1.0), value: dimBackground)
                    .allowsHitTesting(false)

                GeometryReader { geo in
                    VStack {
                        Spacer()
                        
                        switch tutorialStep {
                        case 0:
                            // ✅ 新增 HStack 並加入 Spacer 來置中文字盒子
                            HStack {
                                Spacer()
                                tutorialTextBox(
                                    "🎉 歡迎來到《滿分上路》！\n一起闖關練習，向筆試滿分邁進吧！",
                                    buttonTitle: "下一步"
                                ) {
                                    tutorialStep = 1
                                }
                                .frame(maxWidth: 500) // 💡 建議加上最大寬度，避免在大螢幕上文字太寬
                                Spacer()
                            }
                            
                        
                        case 1:
                            HStack { // 使用 HStack 來控制水平位置
                                Spacer() // ✅ 在文字盒子前加入 Spacer，將它推向右邊
                                tutorialTextBox("點擊畫面上的『第 1 關』圖示\n開始第一個挑戰吧！")
                                    .offset(y: tutorialTextAtBottom ? geo.size.height/2 - 80 : 0)
                                    .animation(.easeInOut(duration: 1.0), value: tutorialTextAtBottom)
                                Spacer()
                                // 可以再加一個 Spacer，讓它和前面的 Spacer 平均分配空間
                            }
                            .frame(width: geo.size.width) // 確保 HStack 填滿整個畫面的寬度
                        
                            if tutorialTextAtBottom {
                                Image(systemName: "arrow.down")
                                    .resizable()
                                    .frame(width: 30, height: 50)
                                    .foregroundColor(.white)
                                    .offset(x: -geo.size.width * 0.3,
                                            y: -geo.size.height * 0.35)
                            }
                            
                        case 2:
                            HStack { // ✅ 使用 HStack 來控制水平位置
                                Spacer() // ✅ 在文字盒子前加入 Spacer，將它推向右邊
                                tutorialTextBox("這裡會顯示關卡紀錄\n點『開始挑戰』就能進入遊戲。")
                                    .offset(y: tutorialTextAtBottom ? geo.size.height/2 - 80 : 0)
                                    .animation(.easeInOut(duration: 1.0), value: tutorialTextAtBottom)
                                Spacer() // 可以再加一個 Spacer，讓它和前面的 Spacer 平均分配空間
                            }
                            .frame(width: geo.size.width) // 確保 HStack 填滿整個畫面的寬度
                        
                            if tutorialTextAtBottom {
                                Image(systemName: "arrow.down")
                                    .resizable()
                                    .frame(width: 30, height: 50)
                                    .foregroundColor(.white)
                                    .offset(x: geo.size.width * 0.1
                                            )
                            }
                        
                        default:
                            EmptyView()
                        }
                        
                        Spacer()
                    }
                
                }
                    .transition(.opacity)
                .onChange(of: tutorialStep) { newValue in
                    if newValue == 1 || newValue == 2 {
                        dimBackground = true
                        tutorialTextAtBottom = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                dimBackground = false
                                tutorialTextAtBottom = true
                            }
                        }
                    }
                }
            }
            // --- ✨ 祝賀畫面 Overlay ---
            if showCongrats {
                Color.black.opacity(0.6)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    if dataService.highestUnlockedStage == 2 {
                        // 🎉 第一關
                        Text("🎉 恭喜完成第 1 關！")
                            .font(.custom("CEF Fonts CJK Mono", size: 26))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("👏 繼續加油，挑戰更多關卡吧！")
                            .font(.custom("CEF Fonts CJK Mono", size: 20))
                            .foregroundColor(.yellow)

                    } else {
                        let (chapter, _) = dataService.chapterAndStageInChapter(for: dataService.highestUnlockedStage - 1)
                        let totalChapters = dataService.chapterStageCounts.count

                        if chapter == totalChapters {
                            // 🎉 最終章特別祝賀
                            Text("🏆 恭喜通過最終章！")
                                .font(.custom("CEF Fonts CJK Mono", size: 26))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("🎉 你已經完成所有挑戰，太厲害了！")
                                .font(.custom("CEF Fonts CJK Mono", size: 20))
                                .foregroundColor(.yellow)

                        } else {
                            // 🎉 一般章節
                            Text("🎉 恭喜完成第 \(chapter) 章！")
                                .font(.custom("CEF Fonts CJK Mono", size: 26))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("👏 繼續加油，挑戰下一章吧！")
                                .font(.custom("CEF Fonts CJK Mono", size: 20))
                                .foregroundColor(.yellow)
                        }
                    }

                    Button(action: { showCongrats = false }) {
                        Text("繼續前進 🚀")
                            .padding()
                            .frame(maxWidth: 200)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.7)))
                .padding()
                .transition(.scale.combined(with: .opacity))
            }
            if showSummary {
                SummaryView(
                    chapterNumber: chapterNumber,
                    onClose: { showSummary = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // ✨ NEW: 導覽書畫面 Overlay
            if showGuidebook {
                GuidebookView(
                    chapterNumber: chapterNumber,
                    onClose: { showGuidebook = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
        }
        .animation(.spring(), value: showingDetailForStage)
        .animation(.default, value: showGuidebook)
        .animation(.default, value: showSummary) // 為 Overlay 加上動畫
        .onAppear {
            if dataService.highestUnlockedStage <= 1 {
                showTutorial = true
            }

            // ✅ 恭喜完成第 1 關（只顯示一次）
            if dataService.highestUnlockedStage == 2 {
                let shownFirst = UserDefaults.standard.bool(forKey: "shownFirstStageCongrats")
                if !shownFirst {
                    showCongrats = true
                    UserDefaults.standard.set(true, forKey: "shownFirstStageCongrats")
                }
            }

            // ✅ 恭喜完成某章最終關（只顯示一次）
            let justUnlocked = dataService.highestUnlockedStage
            let (chapter, stageInChapter) = dataService.chapterAndStageInChapter(for: justUnlocked - 1)

            if stageInChapter == dataService.stagesInChapter(chapter) {
                var shownChapters = UserDefaults.standard.array(forKey: "shownCongratsChapters") as? [Int] ?? []
                if !shownChapters.contains(chapter) {
                    showCongrats = true
                    shownChapters.append(chapter)
                    UserDefaults.standard.set(shownChapters, forKey: "shownCongratsChapters")
                }
            }
        }
        .onChange(of: showTransitionOverlay) { newValue in
            isOverlayActive = newValue
        }
        
    }

    // --- ✨ 教學文字盒子元件 ---
    @ViewBuilder
    private func tutorialTextBox(_ text: String, buttonTitle: String? = nil, action: (() -> Void)? = nil) -> some View {
        VStack(spacing: 16) {
            Text(text)
                .font(.custom("CEF Fonts CJK Mono", size: 17))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            if let buttonTitle = buttonTitle, let action = action {
                Button(buttonTitle, action: action)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                
            }
        }
        .padding()
    }
}
// MARK: - ✨ NEW: 重點整理資料模型 (懶人包內容)
struct SummaryContent: Identifiable {
    let id = UUID()
    let chapterNumber: Int
    let title: String
    let sections: [SummarySection]
}

struct SummarySection: Identifiable {
    let id = UUID()
    let heading: String
    let icon: String
    let items: [String]
}

// 存放所有懶人包內容的資料來源
struct SummaryDataProvider {
    static let summaries: [SummaryContent] = [
        // 第 2 章
        // MARK: 🔧 MODIFIED: 第二章 - 整合您的最新小筆記
        SummaryContent(chapterNumber: 2, title: "第二章 重點整理", sections: [
            SummarySection(heading: "基本行車及轉彎規則", icon: "arrow.triangle.swap", items: [
                "**上落客/貨**: 應在道路 **左方** 進行 (左上右落)",
                "**單行線轉彎**: **轉左靠左，轉右靠右**",
                "**雙行線轉彎**: **轉左靠左，中線轉右**"
            ]),
            SummarySection(heading: "路權優先順序 (讓先權)", icon: "list.number", items: [
                "**第1步: 看標誌** -> 有 **讓先(▽)符號** 的車輛 **最後行**",
                "**第2步: 看動作** -> **左轉車** 擁有優先權",
                "**第3步: 看位置** -> 讓 **左方車輛** 先行",
                "**判斷流程 (綜合)**: 在無燈號路口，按 **B(左轉車) -> C(有讓先符號) -> A(無車路口)** 的逆時針方向判斷"
            ]),
            SummarySection(heading: "禁止事項提醒", icon: "xmark.octagon.fill", items: [
                "**交匯處**: **不得** 停車、泊車、爬頭(超車)、掉頭、倒後",
                "**黃虛線**: **可以** 上落客(停車)，但 **不能** 泊車",
                "**黃實線**: **不得** 停車及泊車"
            ])
        ]),
        
        // 第 3 章
        SummaryContent(chapterNumber: 3, title: "第三章 重點整理", sections: [
            SummarySection(heading: "常見監禁/停牌時間", icon: "calendar", items: [
                "一年至三年",
                "兩個月至六個月",
                "累犯 題目金額乘2"
            ]),
            SummarySection(heading: "特定行為罰款", icon: "dollarsign.circle", items: [
                "選擇中題目只有300 600 900 1500 3000中其中一個 優先選擇",
                "燈號違規: $600",
                "橋上違規: $900",
                "無牌駕駛: $5,000 至 $25,000"
            ])
        ]),
        
        // MARK: 🔧 MODIFIED: 第四章終極整合版筆記
        SummaryContent(chapterNumber: 4, title: "第四章 重點整理", sections: [
            SummarySection(heading: "罰款金額核心法則", icon: "key.fill", items: [
                "筆試中，**固定金額罰款只有 $300, $600, $900, $1500, $3000 這五種**。",
                "看到其他固定金額 (如$400, $500, $1000) 的選項基本可以**直接排除**！"
            ]),
            SummarySection(heading: "五大罰款金額關鍵字全覽", icon: "list.bullet.rectangle.portrait.fill", items: [
                "**$300 (輕微違規)**: 超載、開門、起步、死火(冇打燈)、單車載人、行人路推車、行人路行車、違規響按、突然減速、違規進入特定車道、牌照文件問題。",
                "**$600 (中度違規)**: 裝卸貨物、不靠左停泊、頭盔、P牌、電單車違規(離手/並排/拖帶)、使用電話、影響環境(排煙/噪音)、未被超越時加速、不便他人超車。",
                "**$900 (影響交通流程)**: 運載方式不當、倒車、轉彎、不靠左行駛、阻塞時不讓對頭車、在左方超車。",
                "**$1500 (危險燈光)**: **遠光燈**使用不當。",
                "**$3000 (嚴重違規)**: 運載超重 **超過20%**、運載危險品不符規定、安裝 **雷達干擾儀器**。"
            ]),
            SummarySection(heading: "快速記憶技巧 (口訣)", icon: "brain.head.profile", items: [
                "選項同時有 3000 和其他四位數 -> 選 **$3000**",
                "選項同時有 50, 600 -> 選 **$600**",
                "選項最大是 1000 -> 選 **$600**",
                "選項有 200, 400, 600, 900 -> 選 **$900**"
            ]),
            SummarySection(heading: "罰款組合 (範圍題)", icon: "arrow.up.arrow.down.circle", items: [
                "**優先選擇**: $600 - $2,500",
                "**優先選擇**: $2,000 - $10,000",
                "**優先選擇**: $4,000 - $20,000",
                "看到 **累犯** -> **$1,200 - $5,000**",
                "引橋不讓 -> **$1,000 - $5,000**",
                "注意 **前面 x 5 = 後面** 的規律 (如 $6000 - $30000)"
            ]),
            SummarySection(heading: "嚴重違規行為 (徒刑/重罰)", icon: "shield.lefthalf.filled.slash", items: [
                "撞車後不顧而去: 最高 **3年** 徒刑",
                "無牌駕駛: **6個月** 監禁 & **$10,000 - $50,000**",
                "慣常酗酒/受藥物影響: **1-3年** 徒刑"
            ])
        ])
    ]


    
    // 根據章節號碼查找對應的懶人包
    static func getSummary(for chapter: Int) -> SummaryContent? {
        return summaries.first { $0.chapterNumber == chapter }
    }
}


// MARK: - ✨ NEW: 重點整理彈出視窗 (SummaryView)
struct SummaryView: View {
    let chapterNumber: Int
    let onClose: () -> Void
    
    @State private var summary: SummaryContent?
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            
            VStack(spacing: 0) {
                // 標題列
                HStack {
                    Text(summary?.title ?? "重點整理")
                        .font(.custom("CEF Fonts CJK Mono", size: 22))
                        .bold()
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                .padding()
                // 🔧 MODIFIED: 使用可適應的系統灰色作為標題背景
                .background(Color(UIColor.tertiarySystemBackground))
                
                Divider()
                
                // 內容
                if let summary = summary {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(summary.sections) { section in
                                SummarySectionView(section: section)
                            }
                        }
                        .padding()
                    }
                } else {
                    // 如果沒有內容，顯示提示
                    Spacer()
                    Text("本章節暫無重點整理")
                        .font(.custom("CEF Fonts CJK Mono", size: 18))
                        .foregroundColor(.gray)
                    Spacer()
                }
            }
            .frame(maxWidth: 350, maxHeight: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal)
            .padding(.vertical, 40)
        }
        .onAppear {
            self.summary = SummaryDataProvider.getSummary(for: chapterNumber)
        }
    }
}

// MARK: - ✨ NEW: 重點整理的區塊 (SummarySectionView)
struct SummarySectionView: View {
    let section: SummarySection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 區塊標題
            Label(section.heading, systemImage: section.icon)
                .font(.custom("CEF Fonts CJK Mono", size: 20))
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            // 項目列表
            VStack(alignment: .leading, spacing: 8) {
                ForEach(section.items, id: \.self) { item in
                    Label {
                        // 使用 AttributedString 來處理 **粗體** 標記
                        Text(markdownToAttributedString(item))
                    } icon: {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.green)
                    }
                    .font(.custom("CEF Fonts CJK Mono", size: 17))
                }
            }
            .padding(.leading, 10) // 列表內容縮排
        }
    }
    
    // 將 Markdown 的 **粗體** 轉換為 AttributedString
    private func markdownToAttributedString(_ string: String) -> AttributedString {
        do {
            return try AttributedString(markdown: string)
        } catch {
            return AttributedString(string)
        }
    }
}


// MARK: - 導覽書主畫面 (GuidebookView)
struct GuidebookView: View {
    let chapterNumber: Int
    let onClose: () -> Void
    
    @State private var allQuestions: [QuizQuestion] = []
    @State private var zoomedImageName: String? = nil
    @State private var searchText = ""
    
    private var filteredQuestions: [QuizQuestion] {
        if searchText.isEmpty {
            return allQuestions
        } else {
            return allQuestions.filter {
                $0.questionText.localizedCaseInsensitiveContains(searchText) ||
                $0.correctAnswer.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        // 1. 用一個 ZStack 包住所有東西，來放置背景和卡片
        ZStack {
            // 半透明背景，點擊可關閉
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            // 導覽書主體 (NavigationStack)
            NavigationStack {
                ZStack {
                    // 卡片的背景色
                    Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredQuestions) { question in
                                    GuidebookRowView(
                                        question: question,
                                        chapterNumber: self.chapterNumber,
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
                    .navigationTitle("第 \(chapterNumber) 章 導覽書")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // 放大圖片的 Overlay
                    if let imageName = zoomedImageName {
                        ZoomedImageView(
                            imageName: imageName,
                            zoomedImageName: $zoomedImageName
                        )
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜尋問題或答案")
            .onAppear(perform: loadQuestions)
            // 👇 2. 把圓角、陰影、邊距修飾符，加在 NavigationStack 的外面
            .cornerRadius(20)
            .shadow(radius: 15)
            // MARK: 在這裡調整整個導覽書的大小
            .padding(.horizontal, 75) // 👈 調整【寬度】，數字越小越寬
            .padding(.vertical, 35)   // 👈 調整【高度】，數字越小越高
        }
    }
    
    private func loadQuestions() {
        let allChapterQuestions = GameDataService.shared.allQuestions.filter { $0.level == chapterNumber }
        self.allQuestions = allChapterQuestions.sorted { $0.questionID < $1.questionID }
    }
}

// MARK: - 導覽書的區塊 (GuidebookRowView)
struct GuidebookRowView: View {
    let question: QuizQuestion
    let chapterNumber: Int
    let onImageTap: (String) -> Void
    
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // 根據章節編號決定要顯示哪種排版
            if chapterNumber <= 2 {
                imageBasedLayout // 樣式 1: 有圖模式
            } else {
                textBasedLayout // 樣式 2: 純文字模式
            }
            Divider()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
    
    // --- 樣式 1: 有圖模式 (第 1-2 章)，已升級為可展開 ---
    private var imageBasedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            // --- 可點擊的標頭區域 ---
            HStack(spacing: 15) {
                // 左側圖片
                if let imageName = question.imageName, !imageName.isEmpty {
                    Image(imageName)
                        .resizable().scaledToFit().frame(width: 100, height: 75)
                        .background(Color.black).cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .onTapGesture { onImageTap(imageName) }
                } else {
                    placeholderView
                }
                
                // 中間的問題與答案
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.questionText)
                        .font(.custom("CEF Fonts CJK Mono", size: 15))
                        .foregroundColor(.secondary)
                    
                    Text(question.correctAnswer)
                        .font(.custom("CEF Fonts CJK Mono", size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 右側的箭頭圖示
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            
            // --- 可展開的選項區域 ---
            if isExpanded {
                optionsView
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    // --- 樣式 2: 純文字模式 ---
    private var textBasedLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 15) {
                // 左側的題號圖示
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemBlue).opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "number")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                // 中間的題目與答案
                VStack(alignment: .leading, spacing: 4) {
                    Text(question.questionText)
                        .font(.custom("CEF Fonts CJK Mono", size: 15))
                        .foregroundColor(.secondary)
                    
                    Text(question.correctAnswer)
                        .font(.custom("CEF Fonts CJK Mono", size: 18))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 右側的箭頭圖示
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }
            
            // --- 可展開的選項區域 ---
            if isExpanded {
                optionsView
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }
    
    // --- 可重用的選項列表子視圖 ---
    @ViewBuilder
    private var optionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(question.options.filter { !$0.isEmpty }, id: \.self) { option in
                HStack(spacing: 12) {
                    if option == question.correctAnswer {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.headline)
                    }
                    
                    Text(option)
                        .font(.custom("CEF Fonts CJK Mono", size: 16))
                        .fontWeight(option == question.correctAnswer ? .bold : .regular)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.systemGray5))
        )
    }

    // --- 共用的圖片佔位符 ---
    private var placeholderView: some View {
        ZStack {
             RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemGray5))
             Image(systemName: "photo.on.rectangle")
                .font(.largeTitle)
                .foregroundColor(Color(UIColor.systemGray2))
        }
        .frame(width: 100, height: 75)
    }
}

// ✨ NEW: 負責顯示放大圖片的全新 View
struct ZoomedImageView: View {
    let imageName: String
    @Binding var zoomedImageName: String? // 使用 Binding 來關閉自己

    var body: some View {
        ZStack {
            // 半透明黑色背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    closeView()
                }
            
            // 圖片本身
            Image(imageName)
                .resizable()
                .scaledToFit()
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.5), radius: 20)
                .padding(70) // 讓圖片與螢幕邊緣保持距離

            // 右上角的關閉按鈕
            VStack {
                HStack {
                    Spacer()
                    Button(action: closeView) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(60)
                }
                Spacer()
            }
            .padding()
        }
        // 為整個放大畫面的出現/消失加上過場動畫
        .transition(.scale.combined(with: .opacity))
        // 使用 .id 確保每次圖片名稱變化時，動畫都能正確執行
        .id(imageName)
    }
    
    private func closeView() {
        withAnimation(.spring()) {
            zoomedImageName = nil
        }
    }
}


// ✨ StageIconView
struct StageIconView: View {
    let stageNumber: Int          // 全域編號 (1..N)
    let chapterNumber: Int        // 目前頁面章節
    let isUnlocked: Bool
    let isNew: Bool
    let result: StageResult?
    let action: () -> Void

    // 章內相對編號
    private var relativeStage: Int {
        let (_, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stageNumber)
        return stageInChapter
    }


    var isReviewStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        let reviewCount = max(1, chapterSize / 6)
        let interval = chapterSize / (reviewCount + 1)
        let reviewStages = Set((1...reviewCount).map { $0 * interval })
        return reviewStages.contains(relativeStage) && relativeStage < chapterSize
    }

    var isBossStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        return relativeStage == chapterSize
    }


    var iconColor: Color {
        if !isUnlocked {
            return Color.gray.opacity(0.6)
        } else if isBossStage {
            return Color.red
        } else if isReviewStage {
            return Color(red: 70/255, green: 175/255, blue: 255/255)
        } else {
            return Color(red: 255/255, green: 180/255, blue: 0)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(iconColor)
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 4))

                        if isUnlocked {
                            if let res = result {
                                Text(res.evaluation)
                                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                            } else {
                                if isBossStage {
                                    Image(systemName: "crown.fill")
                                        .resizable()
                                        .renderingMode(.template)
                                        .foregroundColor(.white)
                                        .scaledToFit()
                                        .frame(width: 35, height: 35)
                                } else {
                                    Image("image_8b7251")
                                        .resizable().renderingMode(.template)
                                        .foregroundColor(.white)
                                        .frame(width: 35, height: 35)
                                }
                            }
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundColor(.black.opacity(0.5))
                        }
                    }

                    if isNew && isUnlocked {
                        Text("NEW")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 8, y: -8)
                    }
                }

                Text(isBossStage
                     ? "最終關"
                     : "第\(relativeStage)關")
                    .font(.custom("CEF Fonts CJK Mono", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .disabled(!isUnlocked)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 8)
        .scaleEffect(isUnlocked ? 1.0 : 0.95)
        .animation(.spring(), value: isUnlocked)
    }
}


// ✨ StageDetailView
struct StageDetailView: View {
    let stageNumber: Int
    let chapterNumber: Int
    let result: StageResult?
    let onStart: () -> Void
    let onCancel: () -> Void

    private var relativeStage: Int {
        let (_, stageInChapter) = GameDataService.shared.chapterAndStageInChapter(for: stageNumber)
        return stageInChapter
    }

    var isReviewStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        let reviewCount = max(1, chapterSize / 6)
        let interval = chapterSize / (reviewCount + 1)
        let reviewStages = Set((1...reviewCount).map { $0 * interval })
        return reviewStages.contains(relativeStage) && relativeStage < chapterSize
    }

    var isBossStage: Bool {
        let chapterSize = GameDataService.shared.stagesInChapter(chapterNumber)
        return relativeStage == chapterSize
    }

    private let textColor = Color(red: 85/255, green: 65/255, blue: 50/255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).edgesIgnoringSafeArea(.all).onTapGesture(perform: onCancel)

            VStack(spacing: 15) {
                Text(isBossStage ? "最終關" : "第 \(relativeStage) 關")
                    .font(.custom("CEF Fonts CJK Mono", size: 30))
                    .bold()
                    .foregroundColor(textColor)

                Divider()

                if let res = result {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("👑 最高紀錄").font(.custom("CEF Fonts CJK Mono", size: 20)).bold()
                        Text("評價: \(res.evaluation)")
                        Text("最高連對: \(res.maxCombo)")
                        Text("答對題數: \(res.correctlyAnswered) / \(res.totalQuestions)")
                    }
                    .font(.custom("CEF Fonts CJK Mono", size: 18))
                    .foregroundColor(textColor)
                } else {
                    Text("尚未挑戰")
                        .font(.custom("CEF Fonts CJK Mono", size: 22))
                        .foregroundColor(.gray)
                        .padding(.vertical, 30)
                }

                Divider()

                HStack(spacing: 15) {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.custom("CEF Fonts CJK Mono", size: 16))
                            .bold().padding().frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.3)).cornerRadius(10)
                    }

                    Button(action: onStart) {
                        Text("開始挑戰")
                            .font(.custom("CEF Fonts CJK Mono", size: 16))
                            .bold().padding().frame(maxWidth: .infinity)
                            .background(Color.blue).cornerRadius(10)
                    }
                }
                .foregroundColor(.white)
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(red: 240/255, green: 230/255, blue: 210/255))
                    .shadow(radius: 10)
            )
        }
    }
}

// ✨ 預覽
struct InteractiveMenuPreview: View {
    @ObservedObject private var dataService = GameDataService.shared
    @State private var isOverlayActive = false   // 👈 新增
    
    var body: some View {
        MainMenuView(
            chapterNumber: 5,
            onStageSelect: { stageNumber in
                print("Preview: Stage \(stageNumber) was selected.")
            },
            onBack: {
                print("Preview: Back button was tapped.")
            },
            isOverlayActive: $isOverlayActive    // 👈 傳入
        )
        .overlay(alignment: .bottom) {
            HStack {
                Button(action: { dataService.resetProgress() }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .foregroundColor(.white).padding()
                        .background(Color.black.opacity(0.5)).clipShape(Circle())
                }
                Spacer()
                Button(action: { dataService.unlockAllStages() }) {
                    Image(systemName: "chevron.right.2")
                        .foregroundColor(.white.opacity(0.8)).padding()
                        .background(Color.black.opacity(0.5)).clipShape(Circle())
                }
            }
            .font(.largeTitle)
            .padding()
        }
        .onAppear {
            dataService.objectWillChange.send()
        }
    }
}


#Preview("預設互動模式") {
    InteractiveMenuPreview()
}
