//
//  JourneyAchievementsSection.swift
//  Fitness Coach
//
//  Forma — Personal records surface (legacy filename retained until UI pass renames).
//

import SwiftUI

struct JourneyAchievementsSection: View {
    let records: JourneyPersonalRecordsState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: "Personal records")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    ForEach(records.records) { record in
                        recordRow(record)
                    }
                }
            }
        }
    }

    private func recordRow(_ record: JourneyPersonalRecord) -> some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Image(systemName: record.isActive ? "trophy.fill" : "trophy")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(
                    record.isActive
                        ? FormaTokens.Color.success
                        : FormaTokens.Color.textTertiary
                )
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(record.isActive ? .medium : .regular))
                    .foregroundStyle(
                        record.isActive
                            ? FormaTokens.Color.textPrimary
                            : FormaTokens.Color.textSecondary
                    )
                Text(record.value)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
    }
}

#if DEBUG
#Preview("Personal records") {
    ScrollView {
        JourneyAchievementsSection(records: ProgressPreviewData.state.personalRecords)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
#endif
