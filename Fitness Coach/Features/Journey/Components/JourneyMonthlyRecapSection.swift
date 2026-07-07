//
//  JourneyMonthlyRecapSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMonthlyRecapSection: View {
    let state: JourneyMonthlyRecapState
    var hidesWorkoutMetrics: Bool = false

    private var visibleRows: [JourneyMonthlyRecapMetricRow] {
        guard hidesWorkoutMetrics else { return state.rows }
        return state.rows.filter { $0.id != "workouts" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.headerToCardSpacing) {
            SectionLabel(title: state.sectionTitle)

            JourneyCard(elevation: .standard) {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if state.showsTeaser {
                        teaserContent
                    } else {
                        ForEach(Array(visibleRows.enumerated()), id: \.element.id) { index, row in
                            metricRow(row, isOverall: row.id == "overall")
                            if index < visibleRows.count - 1 {
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
        VStack(alignment: .leading, spacing: JourneyLayout.compactSpacing) {
            if let title = state.teaserTitle {
                Text(title)
                    .font(JourneyTypography.cardHeadline)
                    .foregroundStyle(FormaTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHidden(true)
            }

            if let detail = state.teaserDetail {
                Text(detail)
                    .font(JourneyTypography.cardSupporting)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricRow(_ row: JourneyMonthlyRecapMetricRow, isOverall: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(row.title)
                .font(isOverall ? JourneyTypography.cardHeadline : JourneyTypography.metricLabel)
                .foregroundStyle(FormaTokens.Color.textPrimary)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Text(row.value)
                .font(isOverall ? JourneyTypography.metricValue : JourneyTypography.cardSupporting.weight(.medium))
                .foregroundStyle(
                    isOverall
                        ? FormaTokens.Theme.primary
                        : FormaTokens.Color.textSecondary
                )
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, JourneyLayout.compactSpacing)
        .padding(.horizontal, isOverall ? FormaTokens.Spacing.xs : 0)
        .background {
            if isOverall {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .fill(FormaTokens.Theme.softBackground.opacity(0.55))
            }
        }
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
