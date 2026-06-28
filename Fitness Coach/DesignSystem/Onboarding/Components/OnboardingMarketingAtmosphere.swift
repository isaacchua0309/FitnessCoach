//
//  OnboardingMarketingAtmosphere.swift
//  Fitness Coach
//
//  Forma — Ambient background wash for onboarding marketing screens.
//

import SwiftUI

struct OnboardingMarketingAtmosphere: View {
    var style: OnboardingAtmosphereStyle = .milestone
    var layoutProfile: OnboardingVisionLayoutProfile = .regular

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            OnboardingTheme.background

            topAccentOrb
            bottomAccentOrb
            heroWash
            subtleGrid
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(OnboardingMotion.atmosphereDrift) {
                drift = true
            }
        }
    }

    private var orbScale: CGFloat {
        layoutProfile == .compact ? 0.72 : 1
    }

    private var topAccentOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        OnboardingTheme.accent.opacity(style.topOrbOpacity),
                        OnboardingTheme.accent.opacity(style.topOrbOpacity * 0.35),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: OnboardingVisual.atmosphereOrbRadius
                )
            )
            .frame(
                width: OnboardingVisual.atmosphereOrbRadius * 2 * orbScale,
                height: OnboardingVisual.atmosphereOrbRadius * 2 * orbScale
            )
            .blur(radius: OnboardingVisual.atmosphereBlur * orbScale)
            .offset(
                x: OnboardingVisual.atmosphereTopOrbOffset.x * orbScale + (drift ? 8 : 0),
                y: OnboardingVisual.atmosphereTopOrbOffset.y * orbScale + (drift ? -6 : 0)
            )
    }

    private var bottomAccentOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        OnboardingTheme.chartPrimary.opacity(style.bottomOrbOpacity),
                        OnboardingTheme.accent.opacity(style.bottomOrbOpacity * 0.4),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: OnboardingVisual.atmosphereOrbRadius * 0.82
                )
            )
            .frame(
                width: OnboardingVisual.atmosphereOrbRadius * 1.55 * orbScale,
                height: OnboardingVisual.atmosphereOrbRadius * 1.55 * orbScale
            )
            .blur(radius: (OnboardingVisual.atmosphereBlur + 6) * orbScale)
            .offset(
                x: OnboardingVisual.atmosphereBottomOrbOffset.x * orbScale + (drift ? -10 : 0),
                y: OnboardingVisual.atmosphereBottomOrbOffset.y * orbScale + (drift ? 12 : 0)
            )
    }

    private var heroWash: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [
                        OnboardingTheme.accent.opacity(style.heroWashOpacity),
                        OnboardingTheme.accent.opacity(0.02),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(
                width: OnboardingVisual.atmosphereHeroWashWidth * orbScale,
                height: OnboardingVisual.atmosphereHeroWashHeight * orbScale
            )
            .offset(y: OnboardingVisual.atmosphereHeroWashOffsetY * orbScale)
            .scaleEffect(drift && !reduceMotion ? 1.03 : 1)
            .animation(reduceMotion ? nil : OnboardingMotion.pulseEase, value: drift)
    }

    private var subtleGrid: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var path = Path()
            stride(from: 0, through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: 0, through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(
                path,
                with: .color(OnboardingTheme.border.opacity(0.045)),
                lineWidth: 0.5
            )
        }
        .opacity(0.55)
    }
}

enum OnboardingAtmosphereStyle {
    case milestone
    case futureVision

    var topOrbOpacity: Double {
        switch self {
        case .milestone: 0.16
        case .futureVision: 0.14
        }
    }

    var bottomOrbOpacity: Double {
        switch self {
        case .milestone: 0.1
        case .futureVision: 0.12
        }
    }

    var heroWashOpacity: Double {
        switch self {
        case .milestone: 0.09
        case .futureVision: 0.11
        }
    }
}

#if DEBUG
#Preview {
    OnboardingMarketingAtmosphere()
        .formaThemePreview()
}
#endif
