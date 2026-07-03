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

    static func introProofChartHeight(
        contentHeight: CGFloat,
        profile: OnboardingStepLayoutProfile
    ) -> CGFloat {
        let legendAndTakeawayReserve: CGFloat = profile == .compact ? 72 : 84
        let available = max(0, contentHeight - legendAndTakeawayReserve - profile.sectionSpacing * 2)
        let ratio: CGFloat = profile == .compact ? 0.58 : 0.64
        let maxHeight: CGFloat = profile == .compact ? 260 : 320
        return max(150, min(available * ratio, maxHeight))
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
