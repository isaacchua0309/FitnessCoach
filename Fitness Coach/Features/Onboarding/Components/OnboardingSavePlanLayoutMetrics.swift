//
//  OnboardingSavePlanLayoutMetrics.swift
//  Fitness Coach
//
//  Forma — Adaptive density for the save-plan completion screen.
//

import SwiftUI

struct OnboardingSavePlanLayoutMetrics: Equatable {
    let isCompactHeight: Bool
    let isVeryCompactHeight: Bool
    let isCompactWidth: Bool
    let dynamicTypeSize: DynamicTypeSize

    init(
        size: CGSize,
        dynamicTypeSize: DynamicTypeSize
    ) {
        isCompactHeight = size.height < 760
        isVeryCompactHeight = size.height < 700
        isCompactWidth = size.width < 390
        self.dynamicTypeSize = dynamicTypeSize
    }

    var usesAccessibilityLayout: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var sectionSpacing: CGFloat {
        if isVeryCompactHeight || usesAccessibilityLayout { return 6 }
        if isCompactHeight { return 8 }
        return 10
    }

    var cardSpacing: CGFloat {
        if isVeryCompactHeight { return 6 }
        if isCompactHeight { return 8 }
        return 10
    }

    var cardPadding: CGFloat {
        if isVeryCompactHeight { return FormaTokens.Spacing.sm }
        if isCompactHeight { return FormaTokens.Spacing.sm + 2 }
        return OnboardingLayout.compactCardPadding
    }

    var heroTitleFont: Font {
        if usesAccessibilityLayout {
            return .system(.title3, design: .rounded).weight(.bold)
        }
        if isVeryCompactHeight {
            return .system(.title3, design: .rounded).weight(.bold)
        }
        if isCompactHeight {
            return .system(.title2, design: .rounded).weight(.bold)
        }
        return OnboardingMarketingTypography.screenHeadline
    }

    var heroSubtitleFont: Font {
        if isVeryCompactHeight || usesAccessibilityLayout {
            return FormaTokens.Typography.caption
        }
        if isCompactHeight {
            return FormaTokens.Typography.sectionSubtitle
        }
        return OnboardingMarketingTypography.supporting
    }

    var heroSubtitleLineLimit: Int {
        if isVeryCompactHeight || usesAccessibilityLayout { return 2 }
        return 3
    }

    var completionLabelFont: Font {
        .caption2.weight(.semibold)
    }

    var planGoalFont: Font {
        if usesAccessibilityLayout {
            return .system(.title3, design: .rounded).weight(.bold)
        }
        if isVeryCompactHeight {
            return .system(.title3, design: .rounded).weight(.bold)
        }
        if isCompactHeight {
            return .system(.title2, design: .rounded).weight(.bold)
        }
        return .system(.title, design: .rounded).weight(.bold)
    }

    var completionIconSize: CGFloat {
        if isVeryCompactHeight { return 28 }
        if isCompactHeight { return 32 }
        return 36
    }

    var benefitRowLimit: Int {
        if isVeryCompactHeight || usesAccessibilityLayout { return 3 }
        return 4
    }

    var footerSpacing: CGFloat {
        if isVeryCompactHeight { return FormaTokens.Spacing.xs }
        if isCompactHeight { return FormaTokens.Spacing.sm }
        return FormaTokens.Spacing.sm + 2
    }

    var toolbarBottomSpacing: CGFloat {
        isVeryCompactHeight ? 2 : FormaTokens.Spacing.xs
    }
}
