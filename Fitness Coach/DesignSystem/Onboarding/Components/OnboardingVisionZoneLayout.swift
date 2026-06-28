//
//  OnboardingVisionZoneLayout.swift
//  Fitness Coach
//
//  Forma — Proportional vertical zoning for filled marketing screens.
//

import SwiftUI

enum OnboardingVisionZone: Equatable {
    case headline
    case hero
    case narrative
    case benefits
    case footer
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
}

private struct OnboardingContentHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct OnboardingVisionZoneWeightsKey: EnvironmentKey {
    static let defaultValue: [OnboardingVisionZone: CGFloat] = OnboardingVisionZoneWeights.almostThere
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
}

struct OnboardingVisionZoneLayout: ViewModifier {
    @Environment(\.onboardingContentHeight) private var contentHeight
    @Environment(\.onboardingVisionZoneWeights) private var weights
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let zone: OnboardingVisionZone

    func body(content: Content) -> some View {
        content
            .frame(
                maxWidth: .infinity,
                minHeight: resolvedMinHeight,
                maxHeight: zone == .benefits ? resolvedMinHeight : nil,
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
        case .hero, .headline, .narrative:
            return .center
        case .benefits:
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
