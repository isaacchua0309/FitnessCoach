//
//  JourneyLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Journey transformation screen.
//

import SwiftUI

enum JourneyLayout {
    static let sectionSpacing = FormaTokens.Spacing.lg
    static let itemSpacing = FormaTokens.Spacing.sm
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal

    /// Extra scroll clearance above the tab bar: shared tab-bar inset plus breathing room.
    static let scrollBottomInset =
        FitPilotScreenStyle.scrollBottomInset + FormaTokens.Layout.bottomBarClearance

    /// Padding below the last Journey section before the scroll bottom inset.
    static let scrollBottomContentPadding =
        FormaTokens.Layout.bottomBarClearance + FormaTokens.Spacing.xs
}

struct JourneySectionLabel: View {
    let title: String

    var body: some View {
        FormaSectionLabel(title: title)
    }
}

// MARK: - Scroll inset

extension View {
    /// Journey scroll clearance above the tab bar (composes shared layout tokens).
    func journeyScrollBottomInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: JourneyLayout.scrollBottomInset)
        }
    }
}
