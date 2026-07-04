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

enum TodayWaterQuickAddColors {
    static func foreground(isDisabled: Bool, isSelected: Bool) -> Color {
        if isDisabled { return FormaTokens.Color.textTertiary }
        if isSelected { return FormaTokens.Theme.textOnAccent }
        return FormaTokens.Theme.primary
    }

    static func background(isDisabled: Bool, isSelected: Bool) -> Color {
        if isDisabled { return FormaTokens.Color.surfaceSubtle }
        if isSelected { return FormaTokens.Theme.primary }
        return FormaTokens.Theme.softBackground
    }

    static func border(isDisabled: Bool, isSelected: Bool) -> Color {
        if isDisabled { return FormaTokens.Color.border.opacity(0.45) }
        if isSelected { return FormaTokens.Theme.primary.opacity(0.5) }
        return FormaTokens.Theme.borderTint.opacity(0.28)
    }

    static func borderWidth(isSelected: Bool) -> CGFloat {
        isSelected ? 1 : 0.5
    }
}
