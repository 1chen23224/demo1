// MARK: - Utils/Color+Extension.swift

import SwiftUI

extension Color {
    // 背景色
    static let appBackground = Color("AppBackground")
    // 答題選項按鈕顏色
    static let optionButton = Color("OptionButton")
    // 正確答案的顏色
    static let correctGreen = Color("CorrectGreen")
    // 錯誤答案的顏色
    static let incorrectRed = Color("IncorrectRed")
    // 主要文字顏色
    static let primaryText = Color("PrimaryText")
    
    // 如果你沒有在 Assets.xcassets 中設定這些顏色，
    // SwiftUI 會使用下面的備用顏色。
    // 為了達到最佳效果，請在 Assets.xcassets 新增這些 Color Set。
    // 我先用程式碼定義，方便你直接運行。
    
    static let appBackgroundFallback = Color(red: 240/255, green: 247/255, blue: 255/255)
    static let optionButtonFallback = Color.white
    static let correctGreenFallback = Color(red: 116/255, green: 204/255, blue: 95/255)
    static let incorrectRedFallback = Color(red: 255/255, green: 105/255, blue: 97/255)
    static let primaryTextFallback = Color(red: 48/255, green: 65/255, blue: 89/255)
}
