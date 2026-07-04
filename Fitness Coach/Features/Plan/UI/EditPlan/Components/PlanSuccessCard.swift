//
//  PlanSuccessCard.swift
//  Fitness Coach
//
//  Forma — Success / up-to-date status card for Edit Plan.
//

import SwiftUI

struct PlanSuccessCard: View {
    let model: PlanSuccessCardDisplayModel

    var body: some View {
        switch model.variant {
        case .statusBanner(let isUpToDate):
            statusBanner(headline: model.headline, isUpToDate: isUpToDate)
        }
    }

    private func statusBanner(headline: String, isUpToDate: Bool) -> some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            Image(systemName: isUpToDate ? "checkmark.circle.fill" : "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(
                    isUpToDate
                        ? FormaPlanTokens.Color.planSuccess
                        : FormaPlanTokens.Color.planAccent
                )
                .accessibilityHidden(true)

            Text(headline)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(
                    isUpToDate
                        ? FormaPlanTokens.Color.planUpToDateBackground
                        : FormaPlanTokens.Color.planSelectedCardBackground
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .stroke(
                    isUpToDate
                        ? FormaPlanTokens.Color.planSuccessBorder
                        : FormaPlanTokens.Color.planAccentBorder,
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(headline)
    }
}

#if DEBUG
#Preview("Up to date") {
    PlanSuccessCard(
        model: PlanSuccessCardDisplayModel(
            headline: "Your plan is up to date.",
            variant: .statusBanner(isUpToDate: true)
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
