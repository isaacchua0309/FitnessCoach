//
//  HealthIntelligenceCardLayout.swift
//  Fitness Coach
//
//  Forma — Shared layout, opacity, and loading tokens for Health Intelligence cards.
//

import SwiftUI

enum HealthIntelligenceCardLayout {
    /// Matches Today Activity / Plan item vertical inset for card content.
    static let cardInnerVerticalPadding = FormaTokens.Spacing.sm

    /// Soft badge/chip fill derived from semantic or theme foreground colors.
    static let badgeBackgroundOpacity: Double = 0.14
    static let chipBackgroundOpacity: Double = 0.72
    static let chipBorderOpacity: Double = 0.35
}

struct HealthIntelligenceLoadingContainer<Content: View>: View {
    var isLoading: Bool
    @ViewBuilder var content: Content

    var body: some View {
        content
            .redacted(reason: isLoading ? .placeholder : [])
            .allowsHitTesting(!isLoading)
            .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension View {
    func healthIntelligenceCardInnerPadding() -> some View {
        padding(.vertical, HealthIntelligenceCardLayout.cardInnerVerticalPadding)
    }

    func healthIntelligenceMultilineText() -> some View {
        fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }
}
