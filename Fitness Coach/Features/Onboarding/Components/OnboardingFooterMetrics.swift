//
//  OnboardingFooterMetrics.swift
//  Fitness Coach
//
//  Forma — Measured footer height and scroll inset helpers for onboarding.
//

import SwiftUI

enum OnboardingFooterHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension OnboardingLayout {
    /// Breathing room below scroll content. Footer clearance is handled by `safeAreaInset`.
    static let scrollContentBreathingRoom: CGFloat = 12

    static func scrollContentBottomInset(keyboardHeight: CGFloat) -> CGFloat {
        scrollContentBreathingRoom + max(0, keyboardHeight)
    }
}

extension View {
    func onboardingMeasureFooterHeight() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OnboardingFooterHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        }
    }
}
