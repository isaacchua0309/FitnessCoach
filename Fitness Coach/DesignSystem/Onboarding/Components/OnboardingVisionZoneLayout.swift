//
//  OnboardingVisionZoneLayout.swift
//  Fitness Coach
//
//  Forma — Proportional vertical zoning for filled marketing screens.
//

import SwiftUI

enum OnboardingVisionZone: Equatable, Hashable {
    case headline
    case hero
    case narrative
    case benefits
    case footer
}

enum OnboardingVisionLayoutProfile: Equatable {
    case regular
    case compact

    static func resolve(
        verticalSizeClass: UserInterfaceSizeClass?,
        contentHeight: CGFloat
    ) -> Self {
        if verticalSizeClass == .compact {
            return .compact
        }
        if contentHeight > 0, contentHeight < OnboardingVisionLayoutMetrics.compactHeightThreshold {
            return .compact
        }
        return .regular
    }

    var illustrationScale: CGFloat {
        switch self {
        case .regular: 1
        case .compact: 0.82
        }
    }
}

enum OnboardingVisionZoneWeights {
    /// Almost There: coach hero + copy + transformation card.
    static let almostThere: [OnboardingVisionZone: CGFloat] = [
        .hero: 0.36,
        .narrative: 0.22,
        .benefits: 0.30,
        .footer: 0.08
    ]

    /// Forma Proof: headline + target ring + supporting + benefit grid.
    static let formaProof: [OnboardingVisionZone: CGFloat] = [
        .headline: 0.11,
        .hero: 0.34,
        .narrative: 0.14,
        .benefits: 0.30,
        .footer: 0.07
    ]

    /// Plan blueprint: title + canvas + goal card + premium row + factor grid.
    static let planBlueprint: [OnboardingVisionZone: CGFloat] = [
        .headline: 0.09,
        .hero: 0.26,
        .narrative: 0.17,
        .benefits: 0.13,
        .footer: 0.32
    ]

    /// Landscape / short viewport — hero compresses, benefits expand.
    static let almostThereCompact: [OnboardingVisionZone: CGFloat] = [
        .hero: 0.28,
        .narrative: 0.18,
        .benefits: 0.42,
        .footer: 0.06
    ]

    static let formaProofCompact: [OnboardingVisionZone: CGFloat] = [
        .headline: 0.09,
        .hero: 0.26,
        .narrative: 0.11,
        .benefits: 0.44,
        .footer: 0.06
    ]

    static let planBlueprintCompact: [OnboardingVisionZone: CGFloat] = [
        .headline: 0.08,
        .hero: 0.20,
        .narrative: 0.14,
        .benefits: 0.10,
        .footer: 0.40
    ]

    static func weights(
        for screen: OnboardingVisionScreen,
        profile: OnboardingVisionLayoutProfile
    ) -> [OnboardingVisionZone: CGFloat] {
        switch (screen, profile) {
        case (.almostThere, .regular): almostThere
        case (.almostThere, .compact): almostThereCompact
        case (.formaProof, .regular): formaProof
        case (.formaProof, .compact): formaProofCompact
        case (.planBlueprint, .regular): planBlueprint
        case (.planBlueprint, .compact): planBlueprintCompact
        }
    }

    static func normalizedFillRatio(_ weights: [OnboardingVisionZone: CGFloat]) -> CGFloat {
        weights.values.reduce(0, +)
    }
}

enum OnboardingVisionScreen: Equatable {
    case almostThere
    case formaProof
    case planBlueprint
}

enum OnboardingVisionLayoutMetrics {
    /// Content heights below this use the compact zone profile (iPhone landscape, SE).
    static let compactHeightThreshold: CGFloat = 400

    /// Target vertical fill for marketing zones (normalized weights should land here).
    static let targetFillRange: ClosedRange<CGFloat> = 0.90...0.98

    static let progressHeaderEstimatedHeight: CGFloat = 28
    static let footerEstimatedHeight: CGFloat = 64
    static let safeAreaTopEstimate: CGFloat = 47
    static let safeAreaBottomEstimate: CGFloat = 34

    static func estimatedContentHeight(
        viewportHeight: CGFloat,
        progressHeaderHeight: CGFloat = progressHeaderEstimatedHeight,
        footerHeight: CGFloat = footerEstimatedHeight,
        safeAreaTop: CGFloat = safeAreaTopEstimate,
        safeAreaBottom: CGFloat = safeAreaBottomEstimate
    ) -> CGFloat {
        max(
            0,
            viewportHeight
                - safeAreaTop
                - safeAreaBottom
                - progressHeaderHeight
                - footerHeight
        )
    }

    static func zoneHeight(
        contentHeight: CGFloat,
        weight: CGFloat,
        totalWeight: CGFloat,
        dynamicTypeScale: CGFloat = 1
    ) -> CGFloat {
        guard contentHeight > 0, totalWeight > 0 else { return 0 }
        return contentHeight * (weight / totalWeight) * dynamicTypeScale
    }
}

private struct OnboardingContentHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct OnboardingVisionZoneWeightsKey: EnvironmentKey {
    static let defaultValue: [OnboardingVisionZone: CGFloat] = OnboardingVisionZoneWeights.almostThere
}

private struct OnboardingVisionLayoutProfileKey: EnvironmentKey {
    static let defaultValue: OnboardingVisionLayoutProfile = .regular
}

private struct OnboardingVisionZoneHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var onboardingContentHeight: CGFloat {
        get { self[OnboardingContentHeightKey.self] }
        set { self[OnboardingContentHeightKey.self] = newValue }
    }

    var onboardingVisionZoneWeights: [OnboardingVisionZone: CGFloat] {
        get { self[OnboardingVisionZoneWeightsKey.self] }
        set { self[OnboardingVisionZoneWeightsKey.self] = newValue }
    }

    var onboardingVisionLayoutProfile: OnboardingVisionLayoutProfile {
        get { self[OnboardingVisionLayoutProfileKey.self] }
        set { self[OnboardingVisionLayoutProfileKey.self] = newValue }
    }

    var onboardingVisionZoneHeight: CGFloat {
        get { self[OnboardingVisionZoneHeightKey.self] }
        set { self[OnboardingVisionZoneHeightKey.self] = newValue }
    }
}

struct OnboardingVisionZoneLayout: ViewModifier {
    @Environment(\.onboardingContentHeight) private var contentHeight
    @Environment(\.onboardingVisionZoneWeights) private var weights
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let zone: OnboardingVisionZone

    func body(content: Content) -> some View {
        let height = resolvedHeight
        content
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: zoneAlignment)
            .clipped()
            .environment(\.onboardingVisionZoneHeight, height)
    }

    private var resolvedHeight: CGFloat {
        guard contentHeight > 0, let weight = weights[zone] else { return 0 }
        let total = weights.values.reduce(0, +)
        let typeScale = dynamicTypeSize.isAccessibilitySize
            ? OnboardingVisual.accessibilityZoneScale
            : 1
        return OnboardingVisionLayoutMetrics.zoneHeight(
            contentHeight: contentHeight,
            weight: weight,
            totalWeight: total,
            dynamicTypeScale: typeScale
        )
    }

    private var zoneAlignment: Alignment {
        switch zone {
        case .headline:
            return .top
        case .hero, .narrative, .benefits:
            return .center
        case .footer:
            return .bottom
        }
    }
}

extension View {
    func onboardingVisionZone(_ zone: OnboardingVisionZone) -> some View {
        modifier(OnboardingVisionZoneLayout(zone: zone))
    }

    func onboardingVisionZoneWeights(_ weights: [OnboardingVisionZone: CGFloat]) -> some View {
        environment(\.onboardingVisionZoneWeights, weights)
    }

    func onboardingVisionLayoutProfile(_ profile: OnboardingVisionLayoutProfile) -> some View {
        environment(\.onboardingVisionLayoutProfile, profile)
    }

    func onboardingVisionScreen(_ screen: OnboardingVisionScreen) -> some View {
        modifier(OnboardingVisionScreenModifier(screen: screen))
    }
}

private struct OnboardingVisionScreenModifier: ViewModifier {
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile

    let screen: OnboardingVisionScreen

    func body(content: Content) -> some View {
        content.environment(
            \.onboardingVisionZoneWeights,
            OnboardingVisionZoneWeights.weights(for: screen, profile: layoutProfile)
        )
    }
}

#if DEBUG
private struct ZoneLayoutPreview: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(
                [
                    OnboardingVisionZone.hero,
                    .narrative,
                    .benefits,
                    .footer
                ],
                id: \.self
            ) { zone in
                RoundedRectangle(cornerRadius: 8)
                    .fill(OnboardingTheme.accent.opacity(0.12))
                    .overlay {
                        Text(String(describing: zone))
                            .font(.caption)
                    }
                    .onboardingVisionZone(zone)
            }
        }
        .environment(\.onboardingContentHeight, 500)
        .padding()
    }
}

#Preview {
    ZoneLayoutPreview()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
