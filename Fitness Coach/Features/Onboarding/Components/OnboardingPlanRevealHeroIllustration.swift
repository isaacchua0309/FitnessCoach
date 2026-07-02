//
//  OnboardingPlanRevealHeroIllustration.swift
//  Fitness Coach
//
//  Forma — Direction-aware hero illustration with onboarding glow language.
//

import SwiftUI

struct OnboardingPlanRevealHeroIllustration: View {
    enum Style: Equatable {
        case destination(PlanGoalDirection)
        case successHandoff
    }

    let style: Style

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingPlanRevealLayoutProfile) private var layoutProfile
    @Environment(\.onboardingPlanRevealIsCompactHeight) private var isCompactHeight
    @Environment(\.onboardingPlanRevealVisibleStages) private var visibleStages
    @State private var pulse = false
    @State private var waveExpansion: CGFloat = 0.92
    @State private var didStartAmbientMotion = false

    @ScaledMetric(relativeTo: .title3) private var baseHaloDiameter: CGFloat = 72
    @ScaledMetric(relativeTo: .title3) private var baseRingDiameter: CGFloat = 58

    private var haloDiameter: CGFloat {
        let compactScale: CGFloat = isCompactHeight ? 0.82 : 1
        return baseHaloDiameter * layoutProfile.illustrationScale * compactScale
    }

    private var ringDiameter: CGFloat {
        let compactScale: CGFloat = isCompactHeight ? 0.82 : 1
        return baseRingDiameter * layoutProfile.illustrationScale * compactScale
    }

    private let ringLineWidth: CGFloat = 2.5

    var body: some View {
        ZStack {
            signalWaves
            haloGlow
            progressRing
            centerContent
        }
        .frame(width: haloDiameter, height: haloDiameter)
        .accessibilityHidden(true)
        .onChange(of: visibleStages) { _, stages in
            guard stages.contains(.heroIllustration) else { return }
            scheduleAmbientMotionIfNeeded()
        }
        .onAppear {
            if visibleStages.contains(.heroIllustration) {
                scheduleAmbientMotionIfNeeded()
            }
        }
    }

    // MARK: - Atmosphere

    private var signalWaves: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(
                        OnboardingTheme.accent.opacity(0.14 - Double(index) * 0.04),
                        lineWidth: 1.5
                    )
                    .frame(
                        width: haloDiameter * (waveExpansion + CGFloat(index) * 0.1),
                        height: haloDiameter * (waveExpansion + CGFloat(index) * 0.1)
                    )
                    .opacity(pulse && !reduceMotion ? 0.9 - Double(index) * 0.25 : 0.55)
            }
        }
        .opacity(style == .successHandoff ? 0.85 : 1)
    }

    private var haloGlow: some View {
        Circle()
            .fill(OnboardingGradients.heroGlow(centerOpacity: 0.28, midOpacity: 0.1))
            .frame(width: haloDiameter * 0.92, height: haloDiameter * 0.92)
            .scaleEffect(pulse && !reduceMotion ? 1.04 : 1)
            .animation(reduceMotion ? nil : OnboardingMotion.pulseEase, value: pulse)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(OnboardingTheme.progressTrack.opacity(0.45), lineWidth: ringLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            if style == .successHandoff {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(
                        OnboardingTheme.progress,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .trim(from: 0, to: 0.82)
                    .stroke(
                        OnboardingTheme.progress,
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-118))
                    .shadow(color: OnboardingTheme.primary.opacity(0.3), radius: 6, y: 2)
            }
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch style {
        case .successHandoff:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: ringDiameter * 0.42, weight: .semibold))
                .foregroundStyle(OnboardingTheme.primary)
                .symbolRenderingMode(.hierarchical)
        case let .destination(direction):
            destinationGlyph(direction)
                .font(.system(size: ringDiameter * 0.34, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent.opacity(0.92))
                .scaleEffect(pulse && !reduceMotion ? 1.03 : 1)
                .animation(reduceMotion ? nil : OnboardingMotion.pulseEase, value: pulse)
        }
    }

    @ViewBuilder
    private func destinationGlyph(_ direction: PlanGoalDirection) -> some View {
        switch direction {
        case .cut:
            Image(systemName: "flag.fill")
        case .maintain:
            Image(systemName: "scope")
        case .gain:
            Image(systemName: "arrow.up.forward.circle.fill")
        }
    }

    private func scheduleAmbientMotionIfNeeded() {
        guard !reduceMotion, !didStartAmbientMotion else { return }
        didStartAmbientMotion = true

        Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(OnboardingPlanRevealTiming.ambientMotionDelay * 1_000_000_000)
            )
            guard !Task.isCancelled else { return }
            startAmbientMotion()
        }
    }

    private func startAmbientMotion() {
        guard !reduceMotion else { return }
        pulse = true
        withAnimation(OnboardingMotion.pulseEase) {
            waveExpansion = 1.06
        }
    }
}

#if DEBUG
#Preview("Destinations") {
    HStack(spacing: 16) {
        OnboardingPlanRevealHeroIllustration(style: .destination(.cut))
        OnboardingPlanRevealHeroIllustration(style: .destination(.maintain))
        OnboardingPlanRevealHeroIllustration(style: .destination(.gain))
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Success handoff") {
    OnboardingPlanRevealHeroIllustration(style: .successHandoff)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
