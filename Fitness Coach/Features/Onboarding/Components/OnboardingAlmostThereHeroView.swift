//
//  OnboardingAlmostThereHeroView.swift
//  Fitness Coach
//
//  Forma — Large coach-waiting hero for the almost-there milestone.
//

import SwiftUI

struct OnboardingAlmostThereHeroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var waveExpansion: CGFloat = 0.92

    @ScaledMetric(relativeTo: .largeTitle) private var ringDiameter: CGFloat = 152
    @ScaledMetric(relativeTo: .largeTitle) private var haloDiameter: CGFloat = 176

    private let ringLineWidth: CGFloat = 3.5

    var body: some View {
        ZStack {
            signalWaves

            haloGlow

            waitingRing

            FormaBrandMark(size: .large, accessibilityMode: .branded)
                .scaleEffect(pulse && !reduceMotion ? 1.03 : 1)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 2.1).repeatForever(autoreverses: true),
                    value: pulse
                )
        }
        .frame(width: haloDiameter, height: haloDiameter)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                waveExpansion = 1.08
            }
        }
    }

    private var signalWaves: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.14 - Double(index) * 0.04), lineWidth: 1.5)
                    .frame(
                        width: haloDiameter * (waveExpansion + CGFloat(index) * 0.1),
                        height: haloDiameter * (waveExpansion + CGFloat(index) * 0.1)
                    )
                    .opacity(pulse && !reduceMotion ? 0.9 - Double(index) * 0.25 : 0.55)
            }
        }
    }

    private var haloGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        OnboardingTheme.accent.opacity(0.28),
                        OnboardingTheme.accent.opacity(0.1),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: ringDiameter * 0.62
                )
            )
            .frame(width: haloDiameter, height: haloDiameter)
            .scaleEffect(pulse && !reduceMotion ? 1.04 : 1)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2.1).repeatForever(autoreverses: true),
                value: pulse
            )
    }

    private var waitingRing: some View {
        ZStack {
            Circle()
                .stroke(OnboardingTheme.progressTrack.opacity(0.45), lineWidth: ringLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(
                    OnboardingTheme.accent,
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .rotationEffect(.degrees(-118))
                .shadow(color: OnboardingTheme.accent.opacity(0.35), radius: 8, y: 2)
        }
    }
}

#if DEBUG
#Preview {
    OnboardingAlmostThereHeroView()
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}
#endif
