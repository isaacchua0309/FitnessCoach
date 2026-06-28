//
//  OnboardingPlanRevealDestinationIllustration.swift
//  Fitness Coach
//
//  Forma — Direction-aware destination graphic for plan reveal.
//

import SwiftUI

struct OnboardingPlanRevealDestinationIllustration: View {
    let direction: PlanGoalDirection

    @ScaledMetric(relativeTo: .title3) private var width: CGFloat = 64
    @ScaledMetric(relativeTo: .title3) private var height: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OnboardingTheme.accent.opacity(0.22),
                            OnboardingTheme.accent.opacity(0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: width * 0.55
                    )
                )
                .frame(width: width, height: width)

            illustration
                .foregroundStyle(OnboardingTheme.accent.opacity(0.9))
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var illustration: some View {
        switch direction {
        case .cut:
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: width * 0.42, weight: .semibold))
                    .offset(x: -width * 0.08, y: -height * 0.06)
                Image(systemName: "flag.fill")
                    .font(.system(size: width * 0.22, weight: .bold))
                    .offset(x: width * 0.12, y: -height * 0.22)
            }
        case .maintain:
            ZStack {
                Image(systemName: "scope")
                    .font(.system(size: width * 0.44, weight: .semibold))
                Circle()
                    .stroke(OnboardingTheme.accent.opacity(0.35), lineWidth: 1.5)
                    .frame(width: width * 0.52, height: width * 0.52)
            }
        case .gain:
            ZStack(alignment: .bottom) {
                Image(systemName: "stairs")
                    .font(.system(size: width * 0.44, weight: .semibold))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: width * 0.18, weight: .bold))
                    .offset(x: width * 0.18, y: -height * 0.34)
            }
        }
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 24) {
        OnboardingPlanRevealDestinationIllustration(direction: .cut)
        OnboardingPlanRevealDestinationIllustration(direction: .maintain)
        OnboardingPlanRevealDestinationIllustration(direction: .gain)
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
