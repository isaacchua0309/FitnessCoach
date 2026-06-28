//
//  PlanCalculationDetailsSheet.swift
//  Fitness Coach
//
//  Forma — Full calculation breakdown sheet for Plan trust.
//

import SwiftUI

struct PlanCalculationDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let details: PlanCalculationDetailsState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                    ForEach(details.sections) { section in
                        sectionCard(section)
                    }

                    Text(details.disclaimer)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, PlanLayout.horizontalPadding)
                .padding(.vertical, FormaTokens.Spacing.md)
            }
            .background(FormaTokens.Color.canvas)
            .navigationTitle("Calculation details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionCard(_ section: PlanCalculationDetailsSection) -> some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: section.title)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    ForEach(section.rows) { row in
                        detailRow(row)
                    }
                }
            }
        }
    }

    private func detailRow(_ row: PlanCalculationDetailsRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(row.value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let footnote = row.footnote {
                Text(footnote)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    PlanCalculationDetailsSheet(
        details: PlanCalculationDetailsBuilder.build(
            profile: ProfilePreviewData.profile,
            result: try! PlanCalculationBridge.planResult(from: ProfilePreviewData.profile)
        )
    )
}
