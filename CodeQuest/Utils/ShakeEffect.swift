// MARK: - Utils/ShakeEffect.swift

import SwiftUI

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat // SwiftUI 要求動畫資料必須是 Animatable

    func effectValue(size: CGSize) -> ProjectionTransform {
        // animatableData 是從 0 到 1 的值，代表動畫進度
        // 我們用 sin 函數來產生左右擺動的效果
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }

    // 這個建構函式是為了讓 View Modifier 更容易使用
    init(attempts: Int) {
        animatableData = CGFloat(attempts)
    }
}
