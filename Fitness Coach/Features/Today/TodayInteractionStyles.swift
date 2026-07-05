//
//  TodayInteractionStyles.swift
//  Fitness Coach
//
//  Forma — Shared pressed/disabled interaction styles for Today logging surfaces.
//

import SwiftUI

// MARK: - Surface cards (Log Meal)

struct TodaySurfaceCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isEnabled, !reduceMotion else { return 1 }
        return isPressed ? 0.985 : 1
    }
}

// MARK: - Bordered rows (Scan Meal)

struct TodayBorderedRowPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard isEnabled, !reduceMotion else { return 1 }
        return isPressed ? 0.98 : 1
    }
}

// MARK: - Water quick-add presets

struct TodayWaterQuickAddButtonStyle: ButtonStyle {
    let isSelected: Bool
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(scale(isPressed: configuration.isPressed))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isSelected)
    }

    private func scale(isPressed: Bool) -> CGFloat {
        guard !reduceMotion else { return 1 }
        if isPressed { return 0.94 }
        if isSelected { return 0.97 }
        return 1
    }
}
