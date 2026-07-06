//
//  MainTabResponsiveLayout.swift
//  Fitness Coach
//
//  Forma — Adaptive layout helpers for main-tab screens on narrow widths and Dynamic Type.
//

import SwiftUI

enum MainTabResponsiveLayout {
    /// Reference width for iPhone SE / small phones (points).
    static let compactPhoneWidth: CGFloat = 375

    /// Minimum readable scale factor for hero display values.
    static let heroMinimumScaleFloor: CGFloat = 0.75

    /// Minimum readable scale factor for header titles and pills.
    static let headerMinimumScaleFloor: CGFloat = 0.85

    /// Minimum chip width when building a two-column quick-action grid.
    static let quickActionGridMinimumItemWidth: CGFloat = 148

    /// Minimum width for water quick-add buttons in a flexible grid.
    static let waterQuickAddMinimumItemWidth: CGFloat = 72

    static func usesCompactPageTitle(for dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize >= .accessibility1
    }

    static func pageSubtitleLineLimit(for dynamicTypeSize: DynamicTypeSize) -> Int? {
        dynamicTypeSize >= .accessibility2 ? 5 : 4
    }

    static func heroLineLimit(
        for tier: MainTabHeroText.Tier,
        dynamicTypeSize: DynamicTypeSize
    ) -> Int {
        let base = tier.defaultLineLimit
        guard dynamicTypeSize >= .accessibility1 else { return base }
        switch tier {
        case .primary:
            return max(base, 2)
        case .goal, .metric:
            return max(base, 3)
        case .narrative:
            return max(base, 4)
        }
    }

    static func heroMinimumScaleFactor(for tier: MainTabHeroText.Tier) -> CGFloat {
        switch tier {
        case .primary, .goal:
            return heroMinimumScaleFloor
        case .metric:
            return 0.80
        case .narrative:
            return 0.78
        }
    }

    /// Two-column-friendly grid for quick actions (Coach chips, water presets).
    static func quickActionGridColumns(minimumItemWidth: CGFloat = quickActionGridMinimumItemWidth) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimumItemWidth, maximum: .infinity), spacing: FormaTokens.Spacing.sm)]
    }

    static func waterQuickAddGridColumns() -> [GridItem] {
        [
            GridItem(.flexible(minimum: waterQuickAddMinimumItemWidth), spacing: FormaTokens.Spacing.sm),
            GridItem(.flexible(minimum: waterQuickAddMinimumItemWidth), spacing: FormaTokens.Spacing.sm)
        ]
    }
}
