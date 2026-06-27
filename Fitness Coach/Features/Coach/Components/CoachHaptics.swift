//
//  CoachHaptics.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight haptic feedback for Coach interactions.
//

import UIKit

enum CoachHaptics {
    static func toolbarTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func send() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func attachmentToggle() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
