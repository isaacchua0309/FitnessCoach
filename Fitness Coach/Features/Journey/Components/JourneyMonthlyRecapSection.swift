//
//  JourneyMonthlyRecapSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMonthlyRecapSection: View {
    let state: JourneyMonthlyRecapState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: state.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if state.showsTeaser {
                        teaserContent
                    } else {
                        ForEach(Array(state.rows.enumerated()), id: \.element.id) { index, row in
                            metricRow(row, isOverall: row.id == "overall")
                            if index < state.rows.count - 1 {
                                FormaPlanRowDivider()
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private var teaserContent: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            if let title = state.teaserTitle {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHidden(true)
            }

            if let detail = state.teaserDetail {
                Text(detail)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ row: JourneyMonthlyRecapMetricRow, isOverall: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text("\(row.title):")
                .font(
                    FormaTokens.Typography.sectionSubtitle.weight(
                        isOverall ? .semibold : .medium
                    )
                )
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(row.value)
                .font(
                    FormaTokens.Typography.sectionSubtitle.weight(
                        isOverall ? .semibold : .regular
                    )
                )
                .foregroundStyle(
                    isOverall
                        ? FormaTokens.Color.textPrimary
                        : FormaTokens.Color.textSecondary
                )
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Monthly recap") {
    ScrollView {
        JourneyMonthlyRecapSection(state: JourneyPreviewData.monthlyRecapActive)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Monthly recap teaser") {
    ScrollView {
        JourneyMonthlyRecapSection(state: JourneyPreviewData.sparseData.monthlyRecap)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
