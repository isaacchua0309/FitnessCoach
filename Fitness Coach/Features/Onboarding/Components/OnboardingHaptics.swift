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

    static func planLaunch() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Primary footer CTA (Continue, Build My Plan, etc.).
    static func primaryActionTapped(launch: Bool = false) {
        if launch {
            planLaunch()
        } else {
            selectionChanged()
        }
    }

    /// Target-weight ruler crossed a whole 1.0 kg mark.
    static func rulerCrossedOneKgBoundary() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Target-weight ruler crossed a whole 5.0 kg mark.
    static func rulerCrossedFiveKgBoundary() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
