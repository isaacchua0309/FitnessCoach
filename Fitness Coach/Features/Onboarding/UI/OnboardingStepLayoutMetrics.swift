//
//  OnboardingStepLayoutMetrics.swift
//  Fitness Coach
//
//  Forma — Adaptive layout metrics for unified onboarding step shells.
//

import SwiftUI

enum OnboardingStepLayoutProfile: Equatable {
    case regular
    case compact

    static func resolve(viewportHeight: CGFloat) -> Self {
        viewportHeight < 700 ? .compact : .regular
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .regular: OnboardingLayout.compactSectionSpacing
        case .compact: 8
        }
    }

    var progressTopPadding: CGFloat {
        OnboardingLayout.progressHeaderTop
    }

    var chromeBottomSpacing: CGFloat {
        switch self {
        case .regular: FormaTokens.Spacing.sm
        case .compact: FormaTokens.Spacing.xs
        }
    }
}

enum OnboardingStepLayoutMetrics {

    /// Estimated height for progress bar + title + subtitle block.
    static func progressChromeHeight(
        step: OnboardingStep,
        profile: OnboardingStepLayoutProfile,
        showsSubtitle: Bool
    ) -> CGFloat {
        let segmentBar: CGFloat = OnboardingLayout.progressSegmentHeight
        let titleBlock: CGFloat = showsSubtitle ? 56 : 34
        let spacing = OnboardingLayout.progressBarSpacing + OnboardingLayout.progressTitleSpacing
        return profile.progressTopPadding + segmentBar + spacing + titleBlock
    }

    /// Height available to step-specific content below the shared chrome.
    static func contentAreaHeight(
        viewportHeight: CGFloat,
        step: OnboardingStep,
        profile: OnboardingStepLayoutProfile,
        showsSubtitle: Bool = true
    ) -> CGFloat {
        let chrome = progressChromeHeight(
            step: step,
            profile: profile,
            showsSubtitle: showsSubtitle
        )
        return max(0, viewportHeight - chrome - profile.chromeBottomSpacing)
    }

    static func introProofFooterStackHeight(
        profile: OnboardingStepLayoutProfile,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let base: CGFloat = profile == .compact ? 78 : 92
        guard dynamicTypeSize.isAccessibilitySize else { return base }
        return base + 36
    }

    /// Hero card height fills most of the step content area below shared chrome.
    static func introProofHeroCardHeight(
        contentHeight: CGFloat,
        profile: OnboardingStepLayoutProfile,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let footerStack = introProofFooterStackHeight(
            profile: profile,
            dynamicTypeSize: dynamicTypeSize
        )
        let spacing = profile.sectionSpacing * 2
        let available = max(0, contentHeight - footerStack - spacing)
        let cap: CGFloat = profile == .compact ? 320 : 380
        return max(190, min(available, cap))
    }

    static func introProofChartHeight(
        contentHeight: CGFloat,
        profile: OnboardingStepLayoutProfile
    ) -> CGFloat {
        introProofHeroCardHeight(
            contentHeight: contentHeight,
            profile: profile,
            dynamicTypeSize: .large
        )
    }

    static func appleHealthSectionSpacing(profile: OnboardingStepLayoutProfile) -> CGFloat {
        profile == .compact ? 8 : OnboardingLayout.compactSectionSpacing
    }
}

// MARK: - Environment

private struct OnboardingStepContentHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 480
}

private struct OnboardingStepLayoutProfileKey: EnvironmentKey {
    static let defaultValue: OnboardingStepLayoutProfile = .regular
}

extension EnvironmentValues {
    var onboardingStepContentHeight: CGFloat {
        get { self[OnboardingStepContentHeightKey.self] }
        set { self[OnboardingStepContentHeightKey.self] = newValue }
    }

    var onboardingStepLayoutProfile: OnboardingStepLayoutProfile {
        get { self[OnboardingStepLayoutProfileKey.self] }
        set { self[OnboardingStepLayoutProfileKey.self] = newValue }
    }
}
