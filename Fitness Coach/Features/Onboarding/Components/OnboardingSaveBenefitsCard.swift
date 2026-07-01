//
//  OnboardingSaveBenefitsCard.swift
//  Fitness Coach
//
//  Forma — What gets saved when the user signs in at onboarding completion.
//

import SwiftUI

struct OnboardingSaveBenefitsCard: View {
    let metrics: OnboardingSavePlanLayoutMetrics

    private let rows = FormaProductCopy.Onboarding.V2.SavePlan.signInTrustRows

    private var displayedRows: [FormaProductCopy.Onboarding.V2.SavePlan.SignInTrustRow] {
        Array(rows.prefix(metrics.benefitRowLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(displayedRows) { row in
                benefitRow(icon: row.icon, title: row.title)
            }
        }
        .padding(.horizontal, metrics.cardPadding)
        .padding(.vertical, metrics.isVeryCompactHeight ? FormaTokens.Spacing.xs : FormaTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(displayedRows.map(\.title).joined(separator: ". "))
    }

    private var rowSpacing: CGFloat {
        metrics.isVeryCompactHeight ? 5 : 6
    }

    private func benefitRow(icon: String, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(metrics.usesAccessibilityLayout ? 3 : 2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview {
    OnboardingSaveBenefitsCard(
        metrics: OnboardingSavePlanLayoutMetrics(
            size: CGSize(width: 390, height: 844),
            dynamicTypeSize: .large
        )
    )
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
#endif
