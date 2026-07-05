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

    // MARK: Cards

    static let cardCornerRadius: CGFloat = 24
    static let cardPadding: CGFloat = 24
    static let cardCompactPadding: CGFloat = FormaTokens.Spacing.md

    // MARK: Floating tab bar clearance

    /// Visual height of the floating tab bar capsule (excluding the home-indicator safe area).
    static let tabBarReservedHeight = FormaTokens.Layout.floatingTabBarHeight
    /// Comfortable gap between the last scroll item and the floating tab bar.
    static let tabBarBreathingRoom = FormaTokens.Layout.floatingTabBarBreathingRoom
    /// Fallback home-indicator height used before the first safe-area measurement (modern iPhone).
    static let defaultBottomSafeAreaFallback: CGFloat = 34
    /// Padding below the last scroll content block inside the scroll area.
    static let scrollContentBottomPadding = FormaTokens.Layout.mainTabScrollContentPadding

    /// Total bottom space scrollable main-tab content must reserve above the floating tab bar.
    ///
    /// Includes tab bar height, breathing room, and the device bottom safe area (home indicator).
    static func bottomContentInset(
        safeAreaBottom: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> CGFloat {
        var inset = tabBarReservedHeight + tabBarBreathingRoom + safeAreaBottom
        if dynamicTypeSize >= .accessibility3 {
            inset += FormaTokens.Spacing.md
        } else if dynamicTypeSize >= .accessibility1 {
            inset += FormaTokens.Spacing.xs
        }
        return inset
    }

    /// Legacy alias — minimum inset without measured safe area (pre-layout / tests).
    static var scrollBottomInset: CGFloat {
        bottomContentInset(safeAreaBottom: 0)
    }

    /// Extra clearance when Dynamic Type is enlarged so content stays above the tab bar.
    static func scrollBottomInset(dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        bottomContentInset(safeAreaBottom: 0, dynamicTypeSize: dynamicTypeSize)
    }
}

// MARK: - Safe area measurement

struct MainTabSafeAreaBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Tab bar clearance spacer

/// Clearance reserved beneath main-tab content so the floating tab bar never covers scroll items.
struct MainTabTabBarClearanceSpacer: View {
    var safeAreaBottom: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Color.clear
            .frame(height: FormaMainTabLayout.bottomContentInset(
                safeAreaBottom: safeAreaBottom,
                dynamicTypeSize: dynamicTypeSize
            ))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Scroll inset (legacy / previews outside scaffold)

private struct FormaMainTabScrollInsetModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var safeAreaBottom = FormaMainTabLayout.defaultBottomSafeAreaFallback

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: MainTabSafeAreaBottomPreferenceKey.self,
                            value: geometry.safeAreaInsets.bottom
                        )
                }
            }
            .onPreferenceChange(MainTabSafeAreaBottomPreferenceKey.self) { measured in
                let resolved = measured > 0 ? measured : FormaMainTabLayout.defaultBottomSafeAreaFallback
                if safeAreaBottom != resolved {
                    safeAreaBottom = resolved
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MainTabTabBarClearanceSpacer(safeAreaBottom: safeAreaBottom)
            }
    }
}

extension View {
    /// Reserves scroll clearance above the floating main tab bar.
    /// Prefer `MainTabPageScaffold`, which applies this globally.
    func formaMainTabScrollInsets() -> some View {
        modifier(FormaMainTabScrollInsetModifier())
    }
}
