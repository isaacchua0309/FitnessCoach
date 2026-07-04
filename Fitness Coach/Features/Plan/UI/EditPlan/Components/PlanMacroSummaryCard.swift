//
//  PlanMacroSummaryCard.swift
//  Fitness Coach
//
//  Forma — Title + metric rows card for Edit Plan summaries.
//

import SwiftUI

struct PlanMetricRow: View {
    enum ValueWeight {
        case medium
        case semibold
    }

    let label: String
    let value: String
    var valueWeight: ValueWeight = .semibold

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer(minLength: FormaTokens.Spacing.sm)
            Text(value)
                .font(valueFont)
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var valueFont: Font {
        switch valueWeight {
        case .medium:
            return FormaTokens.Typography.caption.weight(.medium)
        case .semibold:
            return FormaTokens.Typography.caption.weight(.semibold)
        }
    }
}

struct PlanMacroSummaryCard: View {
    let model: PlanMacroSummaryCardDisplayModel

    var body: some View {
        PlanProjectionCard(compact: model.compact) {
            VStack(alignment: .leading, spacing: model.compact ? FormaTokens.Spacing.sm : FormaTokens.Spacing.md) {
                if let title = model.title {
                    Text(title)
                        .font(titleFont)
                        .foregroundStyle(titleColor)
                }

                VStack(spacing: FormaTokens.Spacing.sm) {
                    ForEach(model.rows) { row in
                        PlanMetricRow(label: row.label, value: row.value)
                    }
                }

                if let footerText = model.footerText {
                    Text(footerText)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var titleFont: Font {
        model.compact
            ? FormaTokens.Typography.caption.weight(.semibold)
            : FormaTokens.Typography.sectionSubtitle.weight(.semibold)
    }

    private var titleColor: Color {
        model.compact
            ? FormaPlanTokens.Color.planMutedText
            : FormaPlanTokens.Color.planPrimaryText
    }

}

#if DEBUG
#Preview {
    PlanMacroSummaryCard(
        model: PlanMacroSummaryCardDisplayModel(
            title: "Your plan",
            rows: [
                PlanMetricRowDisplayModel(label: "Goal", value: "Lose fat"),
                PlanMetricRowDisplayModel(label: "Current", value: "80 kg"),
                PlanMetricRowDisplayModel(label: "Target", value: "70 kg")
            ],
            footerText: "Targets update as you refine your inputs."
        )
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
