//
//  OnboardingPlanBlueprintBasisCard.swift
//  Fitness Coach
//
//  Forma — Profile mirror for plan blueprint milestone.
//

import SwiftUI

struct OnboardingPlanBlueprintProfileMirrorCard: View {
    let title: String
    let signals: [OnboardingPlanBlueprintProfileSignal]

    var body: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
            Text(title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
                .textCase(.uppercase)
                .tracking(0.4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: FormaTokens.Spacing.sm) {
                ForEach(signals) { signal in
                    signalRow(signal)
                }
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(title). \(signals.map { "\($0.supporting): \($0.headline)" }.joined(separator: ", "))"
        )
    }

    private func signalRow(_ signal: OnboardingPlanBlueprintProfileSignal) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(FormaTokens.Color.accentMuted)
                    .frame(width: 32, height: 32)

                Image(systemName: signal.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent.opacity(0.92))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(signal.headline)
                    .font(FormaTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(signal.supporting)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(OnboardingTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(signal.supporting): \(signal.headline)")
    }
}

#if DEBUG
#Preview {
    OnboardingPlanBlueprintProfileMirrorCard(
        title: FormaProductCopy.Onboarding.Flow.Summary.ProfileMirror.title,
        signals: OnboardingPlanBlueprintBuilder.build(from: OnboardingPreviewData.formState).profileSignals
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
