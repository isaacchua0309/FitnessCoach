//
//  OnboardingPlanRevealLayout.swift
//  Fitness Coach
//
//  Forma — Adaptive fixed-viewport zoning for plan reveal.
//

import SwiftUI

enum OnboardingPlanRevealLayoutProfile: Equatable {
    case compact
    case regular
    case expansive

    static func resolve(
        contentHeight: CGFloat,
        contentWidth: CGFloat,
        dynamicTypeSize: DynamicTypeSize
    ) -> Self {
        if dynamicTypeSize.isAccessibilitySize {
            return .compact
        }
        if contentHeight < 520 || contentWidth < 360 {
            return .compact
        }
        if contentHeight > 680 {
            return .expansive
        }
        return .regular
    }

    var stacksActionCards: Bool {
        self == .compact
    }

    var usesExpandedGoalHero: Bool {
        self == .expansive
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .compact: FormaTokens.Spacing.sm
        case .regular: FormaTokens.Spacing.sm + 2
        case .expansive: FormaTokens.Spacing.md
        }
    }

    var illustrationScale: CGFloat {
        switch self {
        case .compact: 0.88
        case .regular: 1
        case .expansive: 1.18
        }
    }

    var heroHeadlineSize: CGFloat {
        switch self {
        case .compact: 32
        case .regular: 38
        case .expansive: 44
        }
    }

    var celebrationTitleFont: Font {
        switch self {
        case .compact:
            return .system(.title3, design: .rounded).weight(.bold)
        case .regular:
            return .system(.title2, design: .rounded).weight(.bold)
        case .expansive:
            return OnboardingMarketingTypography.screenHeadline
        }
    }

    var celebrationSubtitleFont: Font {
        switch self {
        case .compact:
            return FormaTokens.Typography.caption
        case .regular:
            return FormaTokens.Typography.sectionSubtitle
        case .expansive:
            return OnboardingMarketingTypography.supporting
        }
    }

    var zoneWeights: [OnboardingPlanRevealZone: CGFloat] {
        switch self {
        case .compact:
            return [
                .celebration: 0.13,
                .goalHero: 0.24,
                .journey: 0.17,
                .actionCards: 0.34,
                .coach: 0.12
            ]
        case .regular:
            return [
                .celebration: 0.12,
                .goalHero: 0.28,
                .journey: 0.16,
                .actionCards: 0.30,
                .coach: 0.14
            ]
        case .expansive:
            return [
                .celebration: 0.11,
                .goalHero: 0.32,
                .journey: 0.15,
                .actionCards: 0.28,
                .coach: 0.14
            ]
        }
    }

    /// Journey card drops on compact viewports so the protect CTA stays visible without scrolling.
    var savePlanShowsJourneyCard: Bool {
        self != .compact
    }

    var savePlanTrustRowLimit: Int {
        switch self {
        case .compact: 3
        case .regular: 4
        case .expansive: 5
        }
    }

    func savePlanUpperZoneWeights(showsJourney: Bool) -> [OnboardingPlanRevealZone: CGFloat] {
        if showsJourney {
            switch self {
            case .compact:
                return [
                    .celebration: 0.20,
                    .goalHero: 0.46,
                    .journey: 0.34,
                    .actionCards: 0,
                    .coach: 0
                ]
            case .regular:
                return [
                    .celebration: 0.18,
                    .goalHero: 0.50,
                    .journey: 0.32,
                    .actionCards: 0,
                    .coach: 0
                ]
            case .expansive:
                return [
                    .celebration: 0.16,
                    .goalHero: 0.52,
                    .journey: 0.32,
                    .actionCards: 0,
                    .coach: 0
                ]
            }
        }

        switch self {
        case .compact:
            return [
                .celebration: 0.24,
                .goalHero: 0.76,
                .journey: 0,
                .actionCards: 0,
                .coach: 0
            ]
        case .regular:
            return [
                .celebration: 0.20,
                .goalHero: 0.80,
                .journey: 0,
                .actionCards: 0,
                .coach: 0
            ]
        case .expansive:
            return [
                .celebration: 0.18,
                .goalHero: 0.82,
                .journey: 0,
                .actionCards: 0,
                .coach: 0
            ]
        }
    }
}

enum OnboardingPlanRevealZone: Hashable {
    case celebration
    case goalHero
    case journey
    case actionCards
    case coach
}

private struct OnboardingPlanRevealLayoutProfileKey: EnvironmentKey {
    static let defaultValue: OnboardingPlanRevealLayoutProfile = .regular
}

private struct OnboardingPlanRevealContentHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct OnboardingPlanRevealZoneWeightsKey: EnvironmentKey {
    static let defaultValue: [OnboardingPlanRevealZone: CGFloat] =
        OnboardingPlanRevealLayoutProfile.regular.zoneWeights
}

extension EnvironmentValues {
    var onboardingPlanRevealLayoutProfile: OnboardingPlanRevealLayoutProfile {
        get { self[OnboardingPlanRevealLayoutProfileKey.self] }
        set { self[OnboardingPlanRevealLayoutProfileKey.self] = newValue }
    }

    var onboardingPlanRevealContentHeight: CGFloat {
        get { self[OnboardingPlanRevealContentHeightKey.self] }
        set { self[OnboardingPlanRevealContentHeightKey.self] = newValue }
    }

    var onboardingPlanRevealZoneWeights: [OnboardingPlanRevealZone: CGFloat] {
        get { self[OnboardingPlanRevealZoneWeightsKey.self] }
        set { self[OnboardingPlanRevealZoneWeightsKey.self] = newValue }
    }
}

struct OnboardingPlanRevealZoneLayout: ViewModifier {
    @Environment(\.onboardingPlanRevealContentHeight) private var contentHeight
    @Environment(\.onboardingPlanRevealZoneWeights) private var weights
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let zone: OnboardingPlanRevealZone

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: .infinity,
                minHeight: resolvedMinHeight,
                maxHeight: zone == .actionCards ? resolvedMinHeight : nil,
                alignment: zoneAlignment
            )
    }

    private var resolvedMinHeight: CGFloat {
        guard contentHeight > 0, let weight = weights[zone] else { return 0 }
        let scale = dynamicTypeSize.isAccessibilitySize
            ? OnboardingVisual.accessibilityZoneScale
            : 1
        return max(0, contentHeight * weight * scale)
    }

    private var zoneAlignment: Alignment {
        switch zone {
        case .celebration, .goalHero, .journey, .actionCards:
            return .top
        case .coach:
            return .bottom
        }
    }
}

extension View {
    func onboardingPlanRevealZone(_ zone: OnboardingPlanRevealZone) -> some View {
        modifier(OnboardingPlanRevealZoneLayout(zone: zone))
    }

    func onboardingPlanRevealZoneWeights(_ weights: [OnboardingPlanRevealZone: CGFloat]) -> some View {
        environment(\.onboardingPlanRevealZoneWeights, weights)
    }
}
