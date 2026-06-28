//
//  OnboardingFormaProofTargetRingView.swift
//  Fitness Coach
//
//  Forma — Large target ring hero for forma proof future-vision screen.
//

import SwiftUI

struct OnboardingFormaProofTargetRingView: View {
    let intentLabel: String
    let weightLabel: String
    let pathStyle: OnboardingFormaProofPathStyle
    let ringProgress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var drawnProgress: Double = 0

    @ScaledMetric(relativeTo: .largeTitle) private var ringDiameter: CGFloat = 168
    @ScaledMetric(relativeTo: .largeTitle) private var haloDiameter: CGFloat = 192

    private let ringLineWidth: CGFloat = 5

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            Text(intentLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .textCase(.uppercase)
                .tracking(1.2)
                .accessibilityHidden(true)

            ZStack {
                haloGlow

                targetRing

                centerContent
            }
            .frame(width: haloDiameter, height: haloDiameter)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(intentLabel), \(weightLabel)")
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            if reduceMotion {
                drawnProgress = clampedRingProgress
                return
            }
            pulse = true
            withAnimation(.easeOut(duration: 0.9).delay(0.12)) {
                drawnProgress = clampedRingProgress
            }
        }
    }

    private var centerContent: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(weightLabel)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())

            if pathStyle == .maintain {
                stabilityBand
                    .frame(width: ringDiameter * 0.42, height: 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
    }

    private var stabilityBand: some View {
        Capsule()
            .fill(OnboardingTheme.accent.opacity(0.45))
    }

    private var haloGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        OnboardingTheme.accent.opacity(0.26),
                        OnboardingTheme.accent.opacity(0.08),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: ringDiameter * 0.58
                )
            )
            .frame(width: haloDiameter, height: haloDiameter)
            .scaleEffect(pulse && !reduceMotion ? 1.03 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                value: pulse
            )
    }

    private var targetRing: some View {
        ZStack {
            Circle()
                .stroke(OnboardingTheme.progressTrack.opacity(0.5), lineWidth: ringLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            Circle()
                .trim(from: 0, to: drawnProgress)
                .stroke(
                    OnboardingTheme.accent,
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(ringRotation)
                .shadow(color: OnboardingTheme.accent.opacity(0.28), radius: 10, y: 3)

            if pathStyle == .maintain {
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.18), lineWidth: 1.5)
                    .frame(width: ringDiameter * 0.72, height: ringDiameter * 0.72)
            }
        }
    }

    private var ringRotation: Angle {
        switch pathStyle {
        case .loss:
            return .degrees(-90)
        case .gain:
            return .degrees(-90)
        case .maintain, .fallback:
            return .degrees(-90)
        }
    }

    private var clampedRingProgress: Double {
        min(max(ringProgress, 0), 1)
    }
}

#if DEBUG
#Preview("Maintain") {
    OnboardingFormaProofTargetRingView(
        intentLabel: "Maintain",
        weightLabel: "70 kg",
        pathStyle: .maintain,
        ringProgress: 1
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}

#Preview("Loss") {
    OnboardingFormaProofTargetRingView(
        intentLabel: "Lose",
        weightLabel: "66.5 kg",
        pathStyle: .loss,
        ringProgress: 0.78
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
