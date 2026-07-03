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

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planWarning)
                Text(model.body)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
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
