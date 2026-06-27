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
}

// MARK: - Scroll inset

extension View {
    /// Reserves scroll clearance above the floating main tab bar.
    /// Apply to tab-root `ScrollView`s; pair with `FormaMainTabLayout.scrollContentBottomPadding`
    /// on the scroll content.
    func formaMainTabScrollInsets() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: FormaMainTabLayout.scrollBottomInset)
        }
    }
}
