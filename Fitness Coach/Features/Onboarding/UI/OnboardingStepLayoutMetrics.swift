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

    static func resolve(
        viewportHeight: CGFloat,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> Self {
        if viewportHeight < 700 { return .compact }
        if dynamicTypeSize.isAccessibilitySize, viewportHeight < 820 { return .compact }
        return .regular
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

    func allowsScrollableContent(
        step: OnboardingStep,
        dynamicTypeSize: DynamicTypeSize
    ) -> Bool {
        guard step == .appleHealth else { return false }
        if dynamicTypeSize.isAccessibilitySize { return true }
        if self == .compact { return true }
        return false
    }
}

enum OnboardingStepLayoutMetrics {

    /// Estimated height for progress bar + title + subtitle block.
    static func progressChromeHeight(
        step: OnboardingStep,
        profile: OnboardingStepLayoutProfile,
        showsSubtitle: Bool,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> CGFloat {
        let segmentBar: CGFloat = OnboardingLayout.progressSegmentHeight
        let titleBlock = estimatedTitleBlockHeight(
            showsSubtitle: showsSubtitle,
            dynamicTypeSize: dynamicTypeSize
        )
        let spacing = OnboardingLayout.progressBarSpacing + OnboardingLayout.progressTitleSpacing
        return profile.progressTopPadding + segmentBar + spacing + titleBlock
    }

    private static func estimatedTitleBlockHeight(
        showsSubtitle: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return showsSubtitle ? 128 : 76
        }
        if dynamicTypeSize >= .xxLarge {
            return showsSubtitle ? 68 : 40
        }
        return showsSubtitle ? 56 : 34
    }

    /// Height available to step-specific content below the shared chrome.
    static func contentAreaHeight(
        viewportHeight: CGFloat,
        step: OnboardingStep,
        profile: OnboardingStepLayoutProfile,
        showsSubtitle: Bool = true,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> CGFloat {
        let chrome = progressChromeHeight(
            step: step,
            profile: profile,
            showsSubtitle: showsSubtitle,
            dynamicTypeSize: dynamicTypeSize
        )
        return max(0, viewportHeight - chrome - profile.chromeBottomSpacing)
    }

    static func introProofFooterStackHeight(
        profile: OnboardingStepLayoutProfile,
        dynamicTypeSize: DynamicTypeSize
    ) -> CGFloat {
        let base: CGFloat = profile == .compact ? 78 : 92
        if dynamicTypeSize.isAccessibilitySize {
            return base + 36
        }
        if dynamicTypeSize >= .xxLarge {
            return base + 12
        }
        return base
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
        let minimum: CGFloat = {
            if dynamicTypeSize.isAccessibilitySize { return 150 }
            if dynamicTypeSize >= .xxLarge { return 170 }
            return 190
        }()
        return max(minimum, min(available, cap))
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
