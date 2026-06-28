//
//  JourneyWeeklySnapshotSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWeeklySnapshotSection: View {
    let snapshot: JourneyWeeklySnapshot

    private var rows: [JourneyWeeklySnapshotRow] {
        JourneyWeeklySnapshotCopyBuilder.rows(for: snapshot)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.sectionThisWeek)

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
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
