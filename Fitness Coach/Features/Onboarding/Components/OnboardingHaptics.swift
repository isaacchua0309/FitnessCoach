//
//  OnboardingHaptics.swift
//  Fitness Coach
//
//  Forma — Lightweight haptic feedback during onboarding input.
//

import UIKit

enum OnboardingHaptics {

    static func selectionChanged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
