//
//  FormaMainTabLayout.swift
//  Fitness Coach
//
//  Forma — Shared layout metrics for main-tab root screens (Today, Coach, Journey, Plan).
//

import SwiftUI

enum FormaMainTabLayout {
    /// Horizontal inset for tab-root page content and headers.
    static let horizontalPadding = FormaFeatureLayout.horizontalPadding

    // MARK: Page shell

    /// Space below the status bar / safe-area top before the page title.
    static let headerTopPadding = FormaTokens.Spacing.md
    /// Space between the page header block and primary scroll content.
    static let headerBottomPadding = FormaTokens.Spacing.sm
    /// Tight gap between large title and subtitle.
    static let headerTitleSubtitleSpacing: CGFloat = 4
    /// Default vertical gap between dashboard sections inside the scaffold scroll area.
    static let sectionSpacing = FormaTokens.Spacing.xl
    /// Gap between a section label and the card below it.
    static let sectionLabelBottomSpacing = FormaTokens.Spacing.xs
    /// VStack spacing between `SectionLabel` and the content below it.
    /// SectionLabel already applies `sectionLabelBottomSpacing` beneath the label text.
    static let sectionContentSpacing = FormaTokens.Spacing.xs

    // MARK: Cards

    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 24
    static let cardCompactPadding: CGFloat = FormaTokens.Spacing.md

    // MARK: Tab bar clearance

    /// Visual height of the floating tab bar capsule (excluding the home-indicator safe area).
    ///
    /// The system `TabView` already reserves this in the tab content safe area.
    /// Do **not** re-apply this height via a root `safeAreaInset` on tab pages — that
    /// double-counts the tab bar and compresses content into the upper half of the screen.
    static let tabBarReservedHeight = FormaTokens.Layout.floatingTabBarHeight
    /// Comfortable gap between the last scroll item and the system tab-bar safe area.
    static let tabBarBreathingRoom = FormaTokens.Layout.floatingTabBarBreathingRoom
    /// Padding below the last scroll content block inside the scroll area.
    static let scrollContentBottomPadding = FormaTokens.Layout.mainTabScrollContentPadding

    /// Extra scroll-content padding so the last item is not flush against the tab-bar safe area.
    ///
    /// This is **content padding**, not a layout-reserving `safeAreaInset`. The system
    /// `TabView` owns tab-bar and home-indicator safe areas; only breathing room belongs here.
    static func bottomContentInset(
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> CGFloat {
        var inset = scrollContentBottomPadding + tabBarBreathingRoom
        if dynamicTypeSize >= .accessibility3 {
            inset += FormaTokens.Spacing.md
        } else if dynamicTypeSize >= .accessibility1 {
            inset += FormaTokens.Spacing.xs
        }
        return inset
    }

    /// Legacy alias for scroll-content bottom padding (breathing room only).
    static var scrollBottomInset: CGFloat {
        bottomContentInset()
    }

    /// Extra clearance when Dynamic Type is enlarged so content stays above the tab bar.
    static func scrollBottomInset(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        bottomContentInset(dynamicTypeSize: dynamicTypeSize)
    }
}

// MARK: - Scroll content breathing room

private struct FormaMainTabScrollInsetModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .safeAreaPadding(.bottom, FormaMainTabLayout.bottomContentInset(
                dynamicTypeSize: dynamicTypeSize
            ))
    }
}

extension View {
    /// Adds modest bottom breathing room above the system tab-bar safe area.
    /// Prefer `MainTabPageScaffold`, which applies this inside scroll content.
    ///
    /// Do not combine with a measured `safeAreaInsets.bottom` fed back into
    /// `safeAreaInset` — that creates a layout feedback loop.
    func formaMainTabScrollInsets() -> some View {
        modifier(FormaMainTabScrollInsetModifier())
    }
}
