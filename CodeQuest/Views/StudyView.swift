//
//  StudyView.swift
//  CodeQuest
//
//  Created by coco leong on 27/08/2025.
//

import SwiftUI

// MARK: - 主視圖 (包含：錯題重溫 + 總複習)
struct StudyView: View {
    @ObservedObject private var dataService = GameDataService.shared
    @StateObject private var viewModel = GameViewModel() // 用於取得 allQuestions
    
    let onStartReview: ([QuizQuestion]) -> Void
    let onBack: () -> Void
    @State private var selectedReviewType = 0
    @State private var showClearAlert = false
    
    var body: some View {
        ZStack {
            // 背景固定用 stage 背景
            Image("stage-background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // 模式切換
                Picker("複習模式", selection: $selectedReviewType) {
                    Text("錯題重溫").tag(0)
                    Text("總複習").tag(1)
                }
                .pickerStyle(.segmented)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // 不同的子畫面
                if selectedReviewType == 0 {
                    WrongQuestionsReviewView(
                        allQuestions: viewModel.allQuestions,
                        onStartReview: onStartReview
                    )
                } else {
                    AllQuestionsReviewView(
                        allQuestions: viewModel.allQuestions,
                        onStartReview: onStartReview
                    )
                }
                Spacer()
            }
            .padding(.top, 20)
            
            // --- 上方返回 + 清除 ---
            VStack {
                HStack {
                    // 返回按鈕
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
                    .padding(.top, -30)
                    .padding(.horizontal, 80)
                    
                    Spacer()
                    
                    // 垃圾桶按鈕（只有錯題重溫時顯示）
                    if selectedReviewType == 0, !dataService.wrongQuestionIDs.isEmpty {
                        Button {
                            showClearAlert = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .shadow(radius: 5)
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 2)
                                    .padding(4)
                                Image(systemName: "trash")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(.red.opacity(0.9))
                            }
                            .frame(width: 44, height: 44)
                        }
                        .padding(.top, -30)
                        .padding(.horizontal, 80)
                        
                        .alert("確定要清除所有錯題嗎？", isPresented: $showClearAlert) {
                            Button("取消", role: .cancel) {}
                            Button("清除", role: .destructive) {
                                GameDataService.shared.clearWrongQuestions()
                            }
                        } message: {
                            Text("此操作無法復原，錯題紀錄將會消失。")
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - 錯題重溫視圖
struct WrongQuestionsReviewView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let allQuestions: [QuizQuestion]
    let onStartReview: ([QuizQuestion]) -> Void
    
    @State private var chapterPercentages: [Int: Double] = [1: 1.0, 2: 1.0, 3: 1.0, 4: 1.0, 5: 1.0]
    
    var body: some View {
        VStack(spacing: 15) {
            Text("錯題重溫")
                .font(.custom("CEF Fonts CJK Mono", size: 32))
                .bold()
                .foregroundColor(.white)
            
            ForEach(1...5, id: \.self) { chapter in
                let wrongQuestionsInChapter = getWrongQuestions(for: chapter)
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
            
            // 建立關卡按鈕
            Button("建立錯題重溫關卡") {
                var reviewQuestions: [QuizQuestion] = []
                for (chapter, percentage) in chapterPercentages {
                    let wrongQuestions = getWrongQuestions(for: chapter)
                    let countToTake = Int(Double(wrongQuestions.count) * percentage)
                    reviewQuestions.append(contentsOf: wrongQuestions.shuffled().prefix(countToTake))
                }
                if !reviewQuestions.isEmpty {
                    onStartReview(reviewQuestions.shuffled())
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.custom("CEF Fonts CJK Mono", size: 20))
            .padding()
        }
        .padding()
    }
    
    private func getWrongQuestions(for chapter: Int) -> [QuizQuestion] {
        let chapterSize = 21
        let startStage = (chapter - 1) * chapterSize + 1
        let endStage = chapter * chapterSize
        return allQuestions.filter { question in
            dataService.wrongQuestionIDs.contains(question.questionID) &&
            question.stages.contains { $0 >= startStage && $0 <= endStage }
        }
    }
}

// MARK: - 總複習視圖
struct AllQuestionsReviewView: View {
    @ObservedObject private var dataService = GameDataService.shared
    let allQuestions: [QuizQuestion]
    let onStartReview: ([QuizQuestion]) -> Void
    
    @State private var chapterPercentages: [Int: Double] = [1: 0.2, 2: 0.2, 3: 0.2, 4: 0.2, 5: 0.2]

    var body: some View {
        VStack(spacing: 15) {
            Text("總複習")
                .font(.custom("CEF Fonts CJK Mono", size: 32))
                .bold()
                .foregroundColor(.white)
            
            ForEach(1...5, id: \.self) { chapter in
                let questionsInChapter = getQuestions(for: chapter)
                if dataService.isChapterUnlocked(chapter) {
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
            
            Button("建立總複習關卡") {
                var reviewQuestions: [QuizQuestion] = []
                for (chapter, percentage) in chapterPercentages {
                    if dataService.isChapterUnlocked(chapter) {
                        let questions = getQuestions(for: chapter)
                        let countToTake = Int(Double(questions.count) * percentage)
                        reviewQuestions.append(contentsOf: questions.shuffled().prefix(countToTake))
                    }
                }
                if !reviewQuestions.isEmpty {
                    onStartReview(reviewQuestions.shuffled())
                }
            }
            .buttonStyle(.borderedProminent)
            .font(.custom("CEF Fonts CJK Mono", size: 20))
            .padding()
        }
        .padding()
    }
    
    private func getQuestions(for chapter: Int) -> [QuizQuestion] {
        let chapterSize = 21
        let startStage = (chapter - 1) * chapterSize + 1
        let endStage = chapter * chapterSize
        return allQuestions.filter { q in
            q.stages.contains { $0 >= startStage && $0 <= endStage }
        }
    }
}

// MARK: - 可重用的 UI 元件 (進度條)
struct ReviewChapterRow: View {
    let title: String
    let totalCount: Int
    @Binding var percentage: Double
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("\(title): 共 \(totalCount) 題")
                    .padding(.horizontal,50)
                Spacer()
                Text("題目比例: \(Int(percentage * 100))%")
                .padding(.horizontal,50)
            }
            .font(.custom("CEF Fonts CJK Mono", size: 14)) // 縮小一點
            
            Slider(value: $percentage, in: 0...1, step: 0.01)
                .scaleEffect(x: 0.9, y: 0.8, anchor: .center) // ← 縮小
                .padding(.horizontal, 10)
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
