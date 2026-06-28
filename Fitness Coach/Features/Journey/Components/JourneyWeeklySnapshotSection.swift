//
//  JourneyWeeklySnapshotSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklySnapshotSection: View {
    let review: JourneyWeeklyReviewState

    private var rows: [JourneyWeeklySnapshotRow] {
        JourneyWeeklySnapshotCopyBuilder.rows(for: review)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.sectionThisWeek)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(review.weekSummaryCopy)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index == 0 {
                            FitPilotPlanRowDivider()
                        }
                        FormaMetricRow(
                            label: row.label,
                            value: row.detail,
                            style: .snapshot
                        )
                        if index < rows.count - 1 {
                            FitPilotPlanRowDivider()
                        }
                    }
                }
            }
        }
    }
}
