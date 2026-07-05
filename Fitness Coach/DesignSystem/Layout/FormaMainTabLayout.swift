//
//  FormaMainTabLayout.swift
//  Fitness Coach
//
//  Forma — Shared scroll clearance for main-tab root screens (Today, Coach, Journey, Plan).
//

import SwiftUI

enum FormaMainTabLayout {
    /// Padding below the last scroll content block before the tab-bar inset zone.
    static let scrollContentBottomPadding = FormaTokens.Layout.mainTabScrollContentPadding
    /// Reserved scroll height above the floating tab bar (`safeAreaInset`).
    static let scrollBottomInset = FormaTokens.Layout.mainTabScrollBottomInset

    /// Extra clearance when Dynamic Type is enlarged so content stays above the tab bar.
    static func scrollBottomInset(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let base = scrollBottomInset
        if dynamicTypeSize >= .accessibility3 {
            return base + FormaTokens.Spacing.md
        }
        if dynamicTypeSize >= .accessibility1 {
            return base + FormaTokens.Spacing.xs
        }
        return base
    }
}

// MARK: - Scroll inset

private struct FormaMainTabScrollInsetModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: FormaMainTabLayout.scrollBottomInset(dynamicTypeSize: dynamicTypeSize))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Reserves scroll clearance above the floating main tab bar.
    /// Apply to tab-root `ScrollView`s; pair with `FormaMainTabLayout.scrollContentBottomPadding`
    /// on the scroll content.
    func formaMainTabScrollInsets() -> some View {
        modifier(FormaMainTabScrollInsetModifier())
    }
}
