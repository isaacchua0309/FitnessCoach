//
//  ThemeSettingsHaptics.swift
//  Fitness Coach
//
//  Forma — Lightweight haptic feedback for theme settings interactions.
//

import UIKit

enum ThemeSettingsHaptics {

    static func selectionChanged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
