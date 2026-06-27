//
//  OnboardingLandingStepView.swift
//  Fitness Coach
//
//  Forma — V2 app entry (step 0) before sign-in or onboarding questions.
//

import SwiftUI

struct OnboardingLandingStepView: View {
    let onGetStarted: () -> Void
    var onExistingAccount: (() -> Void)?

    var body: some View {
        ZStack {
            OnboardingLandingBackground()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: FormaTokens.Spacing.xl) {
                        Spacer(minLength: FormaTokens.Spacing.lg)

                        OnboardingLandingBrandMoment()

                        OnboardingLandingHero()

                        OnboardingLandingBenefitCluster()
                            .padding(.top, FormaTokens.Spacing.xs)

                        Spacer(minLength: FormaTokens.Spacing.md)
                    }
                    .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)

                OnboardingLandingActionStack(
                    onGetStarted: onGetStarted,
                    onExistingAccount: onExistingAccount
                )
                .padding(.top, FormaTokens.Spacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Background

private struct OnboardingLandingBackground: View {
    var body: some View {
        ZStack {
            OnboardingTheme.background

            RadialGradient(
                colors: [
                    OnboardingTheme.accent.opacity(0.14),
                    OnboardingTheme.accent.opacity(0.04),
                    .clear
                ],
                center: UnitPoint(x: 0.5, y: 0.08),
                startRadius: 6,
                endRadius: 340
            )

            LinearGradient(
                colors: [
                    OnboardingTheme.accent.opacity(0.04),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Brand moment

private struct OnboardingLandingBrandMoment: View {
    @ScaledMetric(relativeTo: .title2) private var glowDiameter: CGFloat = 88

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            OnboardingTheme.accent.opacity(0.30),
                            OnboardingTheme.accent.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowDiameter * 0.5
                    )
                )
                .frame(width: glowDiameter, height: glowDiameter)
                .blur(radius: 8)

            FormaBrandMark(size: .small, accessibilityMode: .decorative)
                .shadow(color: OnboardingTheme.accent.opacity(0.22), radius: 12, y: 2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Hero

private struct OnboardingLandingHero: View {
    private let copy = FormaProductCopy.Onboarding.V2.Landing.self

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(copy.title)
                .font(FormaTokens.Typography.screenTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.subtitle)")
    }
}

// MARK: - Benefits

private struct OnboardingLandingBenefitCluster: View {
    private let benefits = FormaProductCopy.Onboarding.V2.Landing.benefits

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(benefits, id: \.title) { benefit in
                OnboardingLandingBenefitRow(icon: benefit.icon, title: benefit.title)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.sm + 2)
        .frame(maxWidth: 360, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                        .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingLandingBenefitRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: 26, height: 26)

                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Actions

private struct OnboardingLandingActionStack: View {
    let onGetStarted: () -> Void
    var onExistingAccount: (() -> Void)?

    @ScaledMetric(relativeTo: .body) private var primaryButtonHeight: CGFloat = 52

    private let copy = FormaProductCopy.Onboarding.V2.Landing.self

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Button(action: onGetStarted) {
                Text(copy.cta)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(primaryButtonHeight, FormaTokens.Layout.minTouchTarget))
                    .background(OnboardingTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
                    .shadow(color: OnboardingTheme.accent.opacity(0.28), radius: 10, y: 3)
                    .contentShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copy.cta)
            .accessibilityHint("Start building your plan")

            if let onExistingAccount {
                Button(action: onExistingAccount) {
                    Text(copy.existingAccountAction)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copy.existingAccountAction)
                .accessibilityHint(copy.existingAccountAccessibilityHint)
            }
        }
        .padding(.bottom, FormaTokens.Spacing.sm)
    }
}

#Preview {
    OnboardingLandingStepView(onGetStarted: {}, onExistingAccount: {})
        .padding(.horizontal, OnboardingTheme.pagePadding)
        .background(OnboardingTheme.background)
        .preferredColorScheme(.dark)
}
