//
//  OnboardingGeneratingPlanHeroView.swift
//  Fitness Coach
//
//  Forma — Branded hero visual for the plan-generation moment.
//

import SwiftUI

struct OnboardingGeneratingPlanHeroView: View {
    enum Style: Equatable {
        case generating
        case success
        case failure
    }

    let style: Style
    let progress: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var orbitRotation: Double = 0

    @ScaledMetric(relativeTo: .largeTitle) private var ringDiameter: CGFloat = 112
    @ScaledMetric(relativeTo: .largeTitle) private var orbitDiameter: CGFloat = 132

    private let ringLineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            if style == .generating, !reduceMotion {
                orbitDots
            }

            glow

            progressRing

            centerMark
        }
        .frame(width: orbitDiameter, height: orbitDiameter)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                orbitRotation = 360
            }
        }
    }

    private var glow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        OnboardingTheme.accent.opacity(style == .failure ? 0.08 : 0.22),
                        OnboardingTheme.accent.opacity(0.04),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: ringDiameter * 0.55
                )
            )
            .frame(width: ringDiameter * 1.12, height: ringDiameter * 1.12)
            .scaleEffect(pulse && style == .generating && !reduceMotion ? 1.05 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                value: pulse
            )
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(OnboardingTheme.progressTrack.opacity(0.55), lineWidth: ringLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: clampedProgress)
        }
    }

    private var centerMark: some View {
        ZStack {
            switch style {
            case .generating:
                FormaBrandMark(size: .medium)
                    .scaleEffect(pulse && !reduceMotion ? 1.02 : 1)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                        value: pulse
                    )
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .symbolRenderingMode(.hierarchical)
                    .transition(.scale.combined(with: .opacity))
            case .failure:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.warning)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var orbitDots: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.55))
                    .frame(width: 6, height: 6)
                    .offset(y: -(orbitDiameter * 0.46))
                    .rotationEffect(.degrees(Double(index) * 120 + orbitRotation))
            }
        }
    }

    private var ringColor: Color {
        switch style {
        case .generating:
            return OnboardingTheme.accent
        case .success:
            return OnboardingTheme.accent
        case .failure:
            return OnboardingTheme.warning
        }
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}

#if DEBUG
#Preview("Generating") {
    OnboardingGeneratingPlanHeroView(style: .generating, progress: 0.45)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Success") {
    OnboardingGeneratingPlanHeroView(style: .success, progress: 1)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Failure") {
    OnboardingGeneratingPlanHeroView(style: .failure, progress: 0)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
