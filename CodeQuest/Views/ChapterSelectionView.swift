import SwiftUI
import CoreGraphics


struct AlphaShape: Shape {
    let cgImage: CGImage
    var yOffset: CGFloat = -0.1
    var debug: Bool = false

    // ✅ 1. 定義快取的「鑰匙」(Key)
    // 我們需要一個獨一無二的標識來區分不同的圖片和 yOffset
    private struct CacheKey: Hashable {
        let imageIdentifier: ObjectIdentifier
        let yOffset: CGFloat
    }

    // ✅ 2. 建立一個靜態快取字典
    // `static` 意味著這個快取屬於 AlphaShape 這個類型本身，而不是單一實例。
    // 所有的 AlphaShape 實例都會共用這一個快取。
    private static var pathCache: [CacheKey: Path] = [:]

    func path(in rect: CGRect) -> Path {
        // ✅ 3. 為當前的圖片和 yOffset 產生一個獨一無二的鑰匙
        let key = CacheKey(imageIdentifier: ObjectIdentifier(cgImage), yOffset: yOffset)

        // ✅ 4. 檢查快取中是否已經有計算好的 Path
        if let cachedPath = Self.pathCache[key] {
            // 如果有，直接回傳快取結果，並根據當前大小進行縮放。超快！
            return cachedPath.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
        }
        
        // --- 如果快取中沒有，才執行下面的昂貴計算 ---
        var calculatedPath = Path()
        let width = cgImage.width
        let height = cgImage.height
        guard let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return calculatedPath }

        for y in stride(from: 0, to: height, by: 1) {
            for x in stride(from: 0, to: width, by: 1) {
                let pixelIndex = (y * width + x) * 4
                let alpha = ptr[pixelIndex + 3]
                if alpha > 0 {
                    let px = CGFloat(x) / CGFloat(width)
                    var py = CGFloat(y) / CGFloat(height)
                    py = min(max(py + yOffset, 0), 1)

                    // 注意：我們儲存的是標準化 (normalized, 0-1) 的座標
                    let rectCell = CGRect(x: px, y: py, width: 1/CGFloat(width), height: 1/CGFloat(height))
                    calculatedPath.addRect(rectCell)
                }
            }
        }
        
        // ✅ 5. 將這次辛苦計算的結果存入快取，供下次使用
        Self.pathCache[key] = calculatedPath
        
        // ✅ 6. 回傳這次計算結果，並根據當前大小進行縮放
        return calculatedPath.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
    }
}
// MARK: - 模擬按下效果
struct AlwaysPressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(0.6) // 👈 永遠模擬 pressed 狀態
    }
}

// MARK: - 教學引導（小手指 + 提示文字）
struct HandGuideView: View {
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "hand.point.up.left.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
                .offset(x: animate ? -5 : 5, y: animate ? -5 : 5)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
                .onAppear { animate = true }
                .allowsHitTesting(false)

            LocalizedText(key: "guide_tap_to_start")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.yellow)
                .shadow(color: .black.opacity(0.7), radius: 3, x: 1, y: 1)
                .allowsHitTesting(false)
        }
        
    }
}

// MARK: - 單一章節 Mask
struct ChapterMaskView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let chapterNumber: Int
    let onChapterSelect: (Int) -> Void
    var showDebugBorder: Bool = false
    var yOffset: CGFloat = 0   // 👈 接收外部調整
    @State private var isPulsing = false

    var body: some View {
        let isUnlocked = dataService.isChapterUnlocked(chapterNumber)
        let isNew = chapterNumber == dataService.highestUnlockedChapter
        
        if let uiImage = UIImage(named: "selecting-\(chapterNumber)"),
           let cgImage = uiImage.cgImage {

            Button {
                onChapterSelect(chapterNumber)
            } label: {
                Image("selecting-\(chapterNumber)")
                    .resizable().scaledToFit()
                    .overlay(
                        ZStack {
                            if !isUnlocked {
                                Color.black.opacity(0.785)
                            } else if isNew {
                                Color.yellow.opacity(isPulsing ? 0.8 : 0.2).blur(radius: 15)
                                Color.white.opacity(isPulsing ? 0.7 : 0.1).blur(radius: 5)
                            } else {
                                Color.black.opacity(0.001)
                            }
                        }
                        .mask(Image("selecting-\(chapterNumber)").resizable().scaledToFit())
                    )
            }
            .disabled(!isUnlocked)
            .contentShape(AlphaShape(cgImage: cgImage, yOffset: yOffset))
            .buttonStyle(
                (isUnlocked && !isNew) ? AlwaysPressedStyle() : .init()
            )
            
            // Debug: 顯示 AlphaShape 範圍
            .overlay {
                if showDebugBorder {
                    AlphaShape(cgImage: cgImage, yOffset: yOffset, debug: true)
                        .stroke(Color.red.opacity(0.5), lineWidth: 0.5)
                }
            }
            
            // This handles changes to 'isNew' AFTER the view has appeared
            .onChange(of: isNew) { newValue in
                if newValue {
                    // Start pulsing animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                } else {
                    // Stop pulsing animation
                    withAnimation { isPulsing = false }
                }
            }
            // This handles the 'initial' case when the view first appears
            .onAppear {
                // We check the initial state of 'isNew' here
                if isNew {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                            isPulsing = true
                        }
                    }
                }
            }
        }
    }
}
// MARK: - 統一座標系的地圖畫布 (已修正)
struct MapView: View {
    // ❗️❗️❗️ 關鍵：定義你的地圖原圖尺寸
    // ❗️不再是內部常數，而是從外部傳入
    let mapImageName: String
    let nativeImageSize: CGSize

    // 接收來自外部的設定
    let chapterConfigs: [(chapter: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)]
    let onChapterSelect: (Int) -> Void
    var showDebugBorder: Bool = false
    var debugYOffset: CGFloat = 0

    var body: some View {
        // 使用一個 ZStack 作為固定大小的「畫布」
        ZStack {
            // 底層：背景地圖
            Image(mapImageName)
                .resizable()

            // 上層：根據絕對像素座標放置章節
            ForEach(chapterConfigs, id: \.chapter) { config in
                ChapterMaskView(
                    chapterNumber: config.chapter,
                    onChapterSelect: onChapterSelect,
                    showDebugBorder: showDebugBorder,
                    yOffset: debugYOffset
                )
                // 1. First, give the view its size.
                .frame(width: config.w, height: config.h)
                
                // ✅ THE FIX: We move the measurement modifier to be BEFORE .position()
                // 2. NOW, measure its frame while it's still a small, distinct view.
                .if(config.chapter == 1) { view in
                    view.modifier(TutorialHighlightModifier(step: 1))
                }
                
                // 3. LAST, position the view (which has now been measured) onto the larger map canvas.
                .position(x: config.x, y: config.y)
            }
        }
        // ✨ 關鍵修正 1: 只保留 frame，建立一個固定原始尺寸的畫布
        // 這就是我們的絕對座標系統的基礎
        .frame(width: nativeImageSize.width, height: nativeImageSize.height)
        // ✨ .aspectRatio 已被移除，縮放工作交給父視圖處理
    }
}

// MARK: - 主畫面 (已修正)
struct ChapterSelectionView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.horizontalSizeClass) var sizeClass
    let onChapterSelect: (Int) -> Void
    let onSelectReviewTab: () -> Void
    
    @State private var selectedTabIndex: Int = 0
    @State private var showGuide: Bool = false
    var showDebugBorder: Bool = false
    // ✅ 新增：用一個 @State 變數來儲存第一章的 frame 位置
    @State private var chapter1Frame: CGRect? = nil
    // Debug: 動態調整 yOffset
    @State private var debugYOffset: CGFloat = 0
    // ✨ NEW: 用於實現彩蛋功能的狀態變數
    @State private var mapTapCount = 0
    @State private var showSecretKeyAlert = false
    @State private var secretKeyInput = ""
    // ✅ 步驟 1: 新增一個 State 來控制語言選擇視窗的顯示
    @State private var showLanguageSelector = false
    // 1. 定義 iPhone 的資源設定
    let iphoneChapterConfigs: [(chapter: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        // (章節, 中心點x, 中心點y, 寬度, 高度) - 請使用你的實際座標
        (1, 395.5, 459, 557, 370),
        (2, 298.5, 563.5, 289, 271),
        (3, 412, 611.5, 208, 167),
        (4, 150.5, 808, 241, 296),
        (5, 337.5, 934.5, 583, 675)
    ]
    let iphoneMapImageName = "selecting3" // iPhone 專用地圖檔名
    let iphoneNativeImageSize = CGSize(width: 710, height: 1536)
    
    // 2. 定義 iPad/通用 的資源設定
    let generalChapterConfigs: [(chapter: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = [
        // (章節, 中心點x, 中心點y, 寬度, 高度) - 請使用你的實際座標
        (1, 552.5, 459, 557, 370),
        (2, 457, 564, 292, 272),
        (3, 569, 612, 208, 168),
        (4, 309, 808, 244, 296),
        (5, 495, 935, 584, 676)
    ]
    let generalMapImageName = "selecting" // 原始地圖檔名
    let generalNativeImageSize = CGSize(width: 1024, height: 1536) // 原始地圖尺寸
    
    // 3. 執行期的變數，用來決定當前要用哪一套設定
    @State private var currentConfigs: [(chapter: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat)] = []
    @State private var currentMapImageName: String = ""
    @State private var currentNativeImageSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            // --- 地圖層 (使用新的縮放邏輯) ---
            if !currentMapImageName.isEmpty {
                
                // ✨ 關鍵修正 2: 使用 GeometryReader 獲取螢幕實際可用空間
                GeometryReader { geometry in
                    let nativeSize = currentNativeImageSize
                    let screenSize = geometry.size
                    
                    // ✨ 計算要「填滿」螢幕所需的縮放比例 (ContentMode.fill)
                    let widthScale = screenSize.width / nativeSize.width
                    let heightScale = screenSize.height / nativeSize.height
                    let scale = max(widthScale, heightScale)
                    
                    MapView(
                        mapImageName: currentMapImageName,
                        nativeImageSize: currentNativeImageSize,
                        chapterConfigs: currentConfigs,
                        onChapterSelect: { chapter in
                            onChapterSelect(chapter)
                            dismissGuideIfNeeded()
                        },
                        showDebugBorder: showDebugBorder,
                        debugYOffset: debugYOffset
                    )
                    .scaleEffect(scale)
                    // ✨ 關鍵修正：告訴 SwiftUI，縮放後的視圖其「佈局框架」也應該更新
                    // 這會讓「點擊熱區」與「視覺外觀」保持同步
                    .frame(
                        width: nativeSize.width * scale,
                        height: nativeSize.height * scale
                    )
                }
                // ✨ 將 .ignoresSafeArea() 移到容器 GeometryReader 上
                .ignoresSafeArea()
            }
            
            // --- 標題和語言切換按鈕 ---
            VStack {
                // ✅ Base layer: An HStack that spans the full width to center the title
                HStack {
                    Spacer()
                    Text("𝑴 𝑨 𝑷")
                        .font(.custom("CEF Fonts CJK Mono", size: 50))
                        .foregroundColor(.black)
                        .onTapGesture {
                            mapTapCount += 1
                            if mapTapCount >= 5 {
                                showSecretKeyAlert = true
                                mapTapCount = 0
                            }
                        }
                    Spacer()
                }
                
                // ✅ Overlay layer: Place the button on top, aligned to the right
                .overlay(alignment: .trailing) {
                    Button(action: {
                        showLanguageSelector = true
                    }) {
                        Image(systemName: "globe.americas.fill") // A more detailed globe
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.blue.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.4))
                                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.5), lineWidth: 0.7)
                            )
                        
                    }
                    .padding(.trailing, 15) // Give the button some space from the edge
                }
                .padding(.top, (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.safeAreaInsets.top ?? 0)
                
                Spacer()
            }
            .offset(y: sizeClass == .regular ? 30 : -45)
        }
    
        
        .background(Color.black.ignoresSafeArea())
        // ✅ FIX 2: We use a stable .overlay for the guide view.
        // This prevents the guide itself from affecting the main content's layout.
        .overlay(
            ZStack { // Use a ZStack inside the overlay for positioning
                if showGuide, let frame = chapter1Frame {
                    
                    // The actual HandGuideView
                    HandGuideView()
                        .position(x: frame.midX + 70, y: frame.minY + 120)
                }
            }
            .ignoresSafeArea() // The overlay should ignore safe areas to use global coordinates
        )
        // ✅ FIX 1: We check if the value has changed before updating the state.
        .onPreferenceChange(TutorialHighlightKey.self) { value in
            let newFrame = value[1]
            // Only update the state if the new frame is different from the current one.
            // This is the key to breaking the infinite loop.
            if newFrame != self.chapter1Frame {
                DispatchQueue.main.async {
                    self.chapter1Frame = newFrame
                }
            }
        }
        .onAppear {
            // 4. ✨ 核心邏輯：在 View 出現時，判斷裝置類型並設定資源
            if UIDevice.current.userInterfaceIdiom == .phone {
                currentConfigs = iphoneChapterConfigs
                currentMapImageName = iphoneMapImageName
                currentNativeImageSize = iphoneNativeImageSize
            } else {
                // 如果是 iPad 或其他裝置
                currentConfigs = generalChapterConfigs
                currentMapImageName = generalMapImageName
                currentNativeImageSize = generalNativeImageSize
            }
            if dataService.highestUnlockedChapter == 1 {
                 // 稍微延遲以確保 PreferenceKey 有時間傳遞
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showGuide = true
                }
            }
        }
        // ✅ 步驟 3: 加上彈出視窗的 Modifier
        .confirmationDialog("select_language_title".localized(), isPresented: $showLanguageSelector, titleVisibility: .visible) {
            // ✅ 步驟 4: 動態產生語言選項
            // 假設你的 LanguageManager 有一個 `availableLanguages` 的屬性
            // 例如: [("en", "English"), ("zh-Hant", "繁體中文")]
            ForEach(languageManager.availableLanguages, id: \.code) { lang in
                Button(lang.name) {
                    languageManager.changeLanguage(to: lang.code)
                }
            }
        }
        // ✅ 修改 Alert 的內容
        .alert("secret_alert_title".localized(), isPresented: $showSecretKeyAlert) {
            TextField("secret_alert_placeholder".localized(), text: $secretKeyInput)
                .autocapitalization(.none)
            
            Button("secret_alert_button_cancel".localized(), role: .cancel) {
                mapTapCount = 0
                secretKeyInput = ""
            }
            
            Button("secret_alert_button_confirm".localized()) {
                let input = secretKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if input == "cocoyyds" {
                    dataService.unlockAllStages()
                } else if input == "coco324" {
                    dataService.resetAllData()
                }
                
                mapTapCount = 0
                secretKeyInput = ""
            }
            
        } message: {
            Text("secret_alert_message".localized())
        }
        .navigationBarHidden(true)
    }
    
    private func dismissGuideIfNeeded() {
        if showGuide {
            withAnimation { showGuide = false }
        }
    }
}

// MARK: - 底部按鈕
struct BottomTabButton: View {
    let iconName: String
    let title: String
    let tag: Int
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(isEnabled ? (isSelected ? .yellow : .white) : .gray)
                    .frame(width: 28, height: 28)
                Text(title) // Text 會自動處理本地化字串
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isEnabled ? (isSelected ? .yellow : .white) : .gray)
            }
            .padding(.horizontal, 20)
        }
        .disabled(!isEnabled)
    }
}
// MARK: - 預覽
struct ChapterSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ChapterSelectionView(
            onChapterSelect: { chapter in
                print("Selected chapter: \(chapter)")
            },
            onSelectReviewTab: {
                print("Review Tab Selected")
            },
            showDebugBorder: true // 👈 開啟 Debug Mode
        )
        .previewDisplayName("章節地圖 Debug")
        .environmentObject(LanguageManager.shared)
    }
        
}
