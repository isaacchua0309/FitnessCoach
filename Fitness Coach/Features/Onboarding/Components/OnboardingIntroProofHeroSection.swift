//
//  OnboardingIntroProofHeroSection.swift
//  Fitness Coach
//
//  Forma — Hero comparison section for the intro proof onboarding step.
//

import SwiftUI

struct OnboardingIntroProofHeroSection: View {
    let model: OnboardingWeightTrajectoryComparisonModel
    var chartReveal: CGFloat = 1
    var showsSupportingContent: Bool = true

    @Environment(\.onboardingStepContentHeight) private var contentHeight
    @Environment(\.onboardingStepLayoutProfile) private var layoutProfile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: layoutProfile.sectionSpacing) {
            heroCard
                .frame(height: heroCardHeight)

            if showsSupportingContent {
                insightPill
                supportingMicrocopy
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Hero card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            legendRow

            OnboardingWeightTrajectoryHeroChart(
                model: model,
                revealProgress: chartReveal
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(model.disclaimer)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onboardingUnifiedStepCard()
        .shadow(color: OnboardingTheme.border.opacity(0.08), radius: 12, y: 4)
    }

    private var legendRow: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            TrajectoryLegendChip(
                label: model.formaLabel,
                color: OnboardingTheme.chartPrimary,
                style: .solid
            )
            TrajectoryLegendChip(
                label: model.traditionalLabel,
                color: OnboardingTheme.chartSecondary,
                style: .dashed
            )
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(model.formaLabel), \(FormaProductCopy.Onboarding.Flow.Proof.TrajectoryComparison.formaDescription). "
                + "\(model.traditionalLabel), "
                + FormaProductCopy.Onboarding.Flow.Proof.TrajectoryComparison.traditionalDescription
        )
    }

    // MARK: - Supporting content

    private var insightPill: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            Image(systemName: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .accessibilityHidden(true)

            Text(model.insightPill)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(OnboardingTheme.accentMuted)
        )
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(OnboardingTheme.accent.opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.insightPill)
    }

    private var supportingMicrocopy: some View {
        Text(model.supportingCopy)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(OnboardingTheme.secondaryText)
            .lineLimit(3)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(model.supportingCopy)
    }

    // MARK: - Layout

    private var heroCardHeight: CGFloat {
        OnboardingStepLayoutMetrics.introProofHeroCardHeight(
            contentHeight: contentHeight,
            profile: layoutProfile,
            dynamicTypeSize: dynamicTypeSize
        )
    }
}

// MARK: - Legend chip

private struct TrajectoryLegendChip: View {
    enum Style {
        case solid
        case dashed
    }

    let label: String
    let color: Color
    let style: Style

    var body: some View {
        HStack(spacing: 6) {
            lineSwatch
            Text(label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(OnboardingTheme.surfaceSubtle)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(OnboardingTheme.border.opacity(0.45), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var lineSwatch: some View {
        switch style {
        case .solid:
            Capsule()
                .fill(color)
                .frame(width: 18, height: 3)
        case .dashed:
            HStack(spacing: 2) {
                Capsule().fill(color).frame(width: 6, height: 3)
                Capsule().fill(color).frame(width: 4, height: 3)
                Capsule().fill(color).frame(width: 6, height: 3)
            }
        }
    }
}

#if DEBUG
#Preview("Intro Proof Hero") {
    OnboardingIntroProofHeroSection(
        model: .introProofDefault,
        chartReveal: 1
    )
    .padding(.horizontal, OnboardingTheme.pagePadding)
    .environment(\.onboardingStepContentHeight, 460)
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
