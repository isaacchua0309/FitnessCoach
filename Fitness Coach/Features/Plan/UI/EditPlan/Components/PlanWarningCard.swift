//
//  PlanWarningCard.swift
//  Fitness Coach
//
//  Forma — Warning callout card for Edit Plan review.
//

import SwiftUI

struct PlanWarningCard: View {
    let model: PlanWarningCardDisplayModel

    var body: some View {
        HStack(alignment: .top, spacing: FormaTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planWarning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planWarning)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.body)
                    .font(FormaTokens.Typography.body)
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(FormaTokens.Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(FormaPlanTokens.Color.planWarningSoft)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .stroke(FormaPlanTokens.Color.planWarningBorder, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(FormaProductCopy.PlanEditAccessibility.warningPrefix). \(model.title). \(model.body)"
        )
    }
}

#if DEBUG
#Preview {
    PlanWarningCard(
        model: PlanWarningCardDisplayModel(
            title: "Aggressive pace",
            body: "This pace may be harder to sustain long term."
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
