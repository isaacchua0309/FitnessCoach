//
//  OnboardingIllustrationContainer.swift
//  Fitness Coach
//
//  Forma — Hero illustration wrapper for onboarding marketing screens.
//

import SwiftUI

struct OnboardingIllustrationContainer: View {
    let style: OnboardingIllustrationStyle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingVisionLayoutProfile) private var layoutProfile
    @State private var pulse = false
    @State private var waveExpansion: CGFloat = 0.92
    @State private var drawnProgress: Double = 0
    @State private var orbitRotation: Double = 0

    @ScaledMetric(relativeTo: .largeTitle) private var coachRingDiameter = OnboardingVisual.coachRingDiameter
    @ScaledMetric(relativeTo: .largeTitle) private var coachHaloDiameter = OnboardingVisual.coachHaloDiameter
    @ScaledMetric(relativeTo: .largeTitle) private var targetRingDiameter = OnboardingVisual.targetRingDiameter
    @ScaledMetric(relativeTo: .largeTitle) private var targetHaloDiameter = OnboardingVisual.targetHaloDiameter

    var body: some View {
        illustrationPlate {
            GeometryReader { geometry in
                Group {
                    switch style {
                    case .coachWaiting:
                        coachWaitingIllustration
                    case let .targetRing(intentLabel, weightLabel, pathStyle, ringProgress):
                        targetRingIllustration(
                            intentLabel: intentLabel,
                            weightLabel: weightLabel,
                            pathStyle: pathStyle,
                            ringProgress: ringProgress
                        )
                    }
                }
                .scaleEffect(illustrationScale(in: geometry.size))
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear { startAnimations() }
    }

    private func illustrationScale(in size: CGSize) -> CGFloat {
        let reference = max(coachHaloDiameter, targetHaloDiameter)
        guard reference > 0 else { return 1 }
        let fitScale = min(size.width, size.height) / reference
        return min(1, fitScale) * layoutProfile.illustrationScale
    }

    private func illustrationPlate<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: OnboardingVisual.illustrationPlateCornerRadius,
                    style: .continuous
                )
                .fill(OnboardingGradients.illustrationPlate)
                .overlay(
                    RoundedRectangle(
                        cornerRadius: OnboardingVisual.illustrationPlateCornerRadius,
                        style: .continuous
                    )
                    .stroke(OnboardingTheme.accent.opacity(0.12), lineWidth: 1)
                )
            )
    }

    // MARK: - Coach waiting

    private var coachWaitingIllustration: some View {
        ZStack {
            coachSignalWaves
            coachOrbitDots
            coachHaloGlow
            coachWaitingRing
            ringTickMarks(diameter: coachRingDiameter, lineWidth: OnboardingVisual.coachRingLineWidth)
            FormaBrandMark(size: .large, accessibilityMode: .branded)
                .scaleEffect(pulse && !reduceMotion ? 1.04 : 1)
                .animation(reduceMotion ? nil : OnboardingMotion.pulseEase, value: pulse)
        }
        .frame(width: coachHaloDiameter, height: coachHaloDiameter)
        .accessibilityHidden(true)
    }

    private var coachOrbitDots: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .offset(y: -(coachHaloDiameter * 0.46))
                    .rotationEffect(.degrees(Double(index) * 120 + orbitRotation))
            }
        }
        .opacity(reduceMotion ? 0 : 1)
    }

    private var coachSignalWaves: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.12 - Double(index) * 0.03), lineWidth: 1.5)
                    .frame(
                        width: coachHaloDiameter * (waveExpansion + CGFloat(index) * 0.08),
                        height: coachHaloDiameter * (waveExpansion + CGFloat(index) * 0.08)
                    )
                    .opacity(pulse && !reduceMotion ? 0.95 - Double(index) * 0.2 : 0.5)
            }
        }
    }

    private var coachHaloGlow: some View {
        Circle()
            .fill(OnboardingGradients.heroGlow(centerOpacity: 0.32, midOpacity: 0.12))
            .frame(width: coachHaloDiameter * 0.92, height: coachHaloDiameter * 0.92)
            .scaleEffect(pulse && !reduceMotion ? 1.05 : 1)
            .animation(reduceMotion ? nil : OnboardingMotion.pulseEase, value: pulse)
    }

    private var coachWaitingRing: some View {
        ZStack {
            Circle()
                .stroke(OnboardingTheme.progressTrack.opacity(0.45), lineWidth: OnboardingVisual.coachRingLineWidth)
                .frame(width: coachRingDiameter, height: coachRingDiameter)

            Circle()
                .trim(from: 0, to: 0.86)
                .stroke(
                    OnboardingTheme.accent,
                    style: StrokeStyle(lineWidth: OnboardingVisual.coachRingLineWidth, lineCap: .round)
                )
                .frame(width: coachRingDiameter, height: coachRingDiameter)
                .rotationEffect(.degrees(-118))
                .shadow(color: OnboardingTheme.accent.opacity(0.35), radius: OnboardingVisual.ringShadowRadius, y: 2)
        }
    }

    // MARK: - Target ring

    private func targetRingIllustration(
        intentLabel: String,
        weightLabel: String,
        pathStyle: OnboardingFormaProofPathStyle,
        ringProgress: Double
    ) -> some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(intentLabel)
                .font(OnboardingMarketingTypography.goalIntent)
                .foregroundStyle(OnboardingTheme.accent)
                .textCase(.uppercase)
                .tracking(1.2)
                .accessibilityHidden(true)

            ZStack {
                targetHaloGlow
                targetRing(pathStyle: pathStyle, ringProgress: ringProgress)
                ringTickMarks(diameter: targetRingDiameter, lineWidth: OnboardingVisual.targetRingLineWidth)
                OnboardingMetricHighlight(
                    value: weightLabel,
                    showsStabilityBand: pathStyle == .maintain
                )
            }
            .frame(width: targetHaloDiameter * 0.92, height: targetHaloDiameter * 0.92)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(intentLabel), \(weightLabel)")
        .accessibilityAddTraits(.isHeader)
    }

    private var targetHaloGlow: some View {
        Circle()
            .fill(OnboardingGradients.heroGlow(centerOpacity: 0.3, midOpacity: 0.1))
            .frame(width: targetHaloDiameter * 0.9, height: targetHaloDiameter * 0.9)
            .scaleEffect(pulse && !reduceMotion ? 1.04 : 1)
            .animation(reduceMotion ? nil : OnboardingMotion.pulseEase, value: pulse)
    }

    private func targetRing(
        pathStyle: OnboardingFormaProofPathStyle,
        ringProgress: Double
    ) -> some View {
        let clamped = min(max(ringProgress, 0), 1)
        return ZStack {
            Circle()
                .stroke(OnboardingTheme.progressTrack.opacity(0.5), lineWidth: OnboardingVisual.targetRingLineWidth)
                .frame(width: targetRingDiameter, height: targetRingDiameter)

            Circle()
                .trim(from: 0, to: drawnProgress)
                .stroke(
                    OnboardingTheme.accent,
                    style: StrokeStyle(lineWidth: OnboardingVisual.targetRingLineWidth, lineCap: .round)
                )
                .frame(width: targetRingDiameter, height: targetRingDiameter)
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: OnboardingTheme.accent.opacity(0.3),
                    radius: OnboardingVisual.ringShadowRadius,
                    y: 3
                )

            if pathStyle == .maintain {
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.2), lineWidth: 1.5)
                    .frame(width: targetRingDiameter * 0.72, height: targetRingDiameter * 0.72)

                stabilityBandRing
            }
        }
        .onAppear {
            if reduceMotion {
                drawnProgress = clamped
            } else {
                withAnimation(OnboardingMotion.ringDrawEase.delay(0.12)) {
                    drawnProgress = clamped
                }
            }
        }
        .onChange(of: ringProgress) { _, newValue in
            let next = min(max(newValue, 0), 1)
            withAnimation(reduceMotion ? nil : OnboardingMotion.ringDrawEase) {
                drawnProgress = next
            }
        }
    }

    private var stabilityBandRing: some View {
        Capsule()
            .stroke(OnboardingTheme.accent.opacity(0.28), lineWidth: 1)
            .frame(width: targetRingDiameter * 0.5, height: targetRingDiameter * 0.18)
            .accessibilityHidden(true)
    }

    private func ringTickMarks(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            ForEach(0..<OnboardingVisual.ringTickCount, id: \.self) { index in
                Capsule()
                    .fill(OnboardingTheme.accent.opacity(index % 3 == 0 ? 0.35 : 0.16))
                    .frame(width: index % 3 == 0 ? 3 : 2, height: index % 3 == 0 ? 8 : 5)
                    .offset(y: -(diameter * 0.5 + lineWidth))
                    .rotationEffect(.degrees(Double(index) / Double(OnboardingVisual.ringTickCount) * 360))
            }
        }
        .accessibilityHidden(true)
    }

    private func startAnimations() {
        guard !reduceMotion else { return }
        pulse = true
        withAnimation(OnboardingMotion.orbitRotation) {
            orbitRotation = 360
        }
        if case .coachWaiting = style {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                waveExpansion = 1.1
            }
        }
    }
}

#if DEBUG
#Preview("Coach") {
    OnboardingIllustrationContainer(style: .coachWaiting)
        .frame(height: 280)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Maintain ring") {
    OnboardingIllustrationContainer(
        style: .targetRing(
            intentLabel: "Maintain",
            weightLabel: "70 kg",
            pathStyle: .maintain,
            ringProgress: 1
        )
    )
    .frame(height: 300)
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
