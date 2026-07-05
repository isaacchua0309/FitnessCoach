//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    /// Breathing room between major story beats.
    static let sectionSpacing = FormaTokens.Spacing.xl
    static let itemSpacing = FormaTokens.Spacing.sm
    static let compactSpacing: CGFloat = 4
    static let horizontalPadding = FormaFeatureLayout.horizontalPadding

    /// Label-to-card gap inside a section.
    static let headerToCardSpacing = FormaTokens.Spacing.xs

    /// Tighter stack between momentum chip and transformation hero.
    static let heroStackSpacing = FormaTokens.Spacing.xs

    /// Extra breathing room after the flagship transformation hero.
    static let heroBottomSpacing = FormaTokens.Spacing.md

    // MARK: Card padding

    static let cardPaddingHorizontal = FormaTokens.Spacing.md
    static let heroCardPaddingVertical = FormaTokens.Spacing.md + 2
    static let featuredCardPaddingVertical = FormaTokens.Spacing.md
    static let standardCardPaddingVertical = FormaTokens.Spacing.sm + 2
    static let quietCardPaddingVertical = FormaTokens.Spacing.sm

    // MARK: Progress

    static let progressBarHeight: CGFloat = 6
    static let heroProgressBarHeight: CGFloat = 8

    // MARK: Tab bar clearance

    /// Gap between the last Journey card and the floating tab bar (24–32pt target).
    static let tabBarBreathingRoom = FormaTokens.Spacing.xl

    /// Reserved scroll height above the floating tab bar for Journey (`safeAreaInset`).
    static func scrollBottomInset(
        bottomSafeArea: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let base = FormaTokens.Layout.journeyScrollBottomInset(
            bottomSafeArea: bottomSafeArea,
            breathingRoom: tabBarBreathingRoom
        )
        if dynamicTypeSize >= .accessibility3 {
            return base + FormaTokens.Spacing.md
        }
        if dynamicTypeSize >= .accessibility1 {
            return base + FormaTokens.Spacing.xs
        }
        return base
    }

    /// Small padding below the last Journey section before the inset zone begins.
    static let scrollBottomContentPadding = FormaTokens.Spacing.sm
}

// MARK: - Journey scroll inset

private struct JourneyBottomSafeAreaKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct FormaJourneyScrollInsetModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var bottomSafeArea: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: JourneyBottomSafeAreaKey.self,
                            value: proxy.safeAreaInsets.bottom
                        )
                }
            }
            .onPreferenceChange(JourneyBottomSafeAreaKey.self) { bottomSafeArea = $0 }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(
                        height: JourneyLayout.scrollBottomInset(
                            bottomSafeArea: bottomSafeArea,
                            dynamicTypeSize: dynamicTypeSize
                        )
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    /// Reserves Journey-specific scroll clearance above the floating tab bar.
    /// Uses tab bar height + bottom safe area + breathing room; do not stack with
    /// `formaMainTabScrollInsets()`.
    func formaJourneyScrollInsets() -> some View {
        modifier(FormaJourneyScrollInsetModifier())
    }
}
