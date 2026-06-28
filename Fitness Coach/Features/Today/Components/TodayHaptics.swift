//
//  TodayHaptics.swift
//  Fitness Coach
//
//  Forma — Lightweight haptic feedback after Today log actions.
//

import UIKit

enum TodayHaptics {

    static func saveSucceeded() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func deleteSucceeded() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
