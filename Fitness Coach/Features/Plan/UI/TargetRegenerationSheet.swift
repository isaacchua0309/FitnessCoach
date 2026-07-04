//
//  TargetRegenerationSheet.swift
//  Fitness Coach
//
//  FitPilot AI — Preview regenerated targets before applying.
//

import SwiftUI

struct TargetRegenerationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: CalorieTargetResult
    let onApply: () async -> Void
    let onCancel: () -> Void

    @State private var isApplying = false

    private let copy = FormaProductCopy.PlanTargetRegeneration.self

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.lg) {
                    if let warning = PlanEditWarningCopyMapper.userFacingWarning(
                        warningCode: preview.warning,
                        isAggressive: preview.isAggressive
                    ) {
                        PlanWarningCard(
                            model: PlanWarningCardDisplayModel(
                                title: warning.title,
                                body: warning.body
                            )
                        )
                    }

                    PlanMacroSummaryCard(
                        model: PlanMacroSummaryCardDisplayModel(
                            title: copy.estimatesTitle,
                            rows: estimateRows
                        )
                    )

                    PlanMacroSummaryCard(
                        model: PlanMacroSummaryCardDisplayModel(
                            title: copy.targetsTitle,
                            rows: targetRows
                        )
                    )
                }
                .padding(FormaTokens.Spacing.pageHorizontal)
            }
            .background(FormaPlanTokens.Color.planBackground)
            .navigationTitle(copy.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .tint(FormaPlanTokens.Color.planAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copy.cancel) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        apply()
                    } label: {
                        if isApplying {
                            SwiftUI.ProgressView()
                        } else {
                            Text(copy.apply)
                        }
                    }
                    .disabled(isApplying)
                }
            }
            .planEditSupportsDynamicType()
        }
    }

    private var estimateRows: [PlanMetricRowDisplayModel] {
        [
            PlanMetricRowDisplayModel(id: "bmr", label: copy.bmrLabel, value: PlanFormatter.kcal(preview.estimatedBMR)),
            PlanMetricRowDisplayModel(id: "tdee", label: copy.tdeeLabel, value: PlanFormatter.kcal(preview.estimatedTDEE)),
            PlanMetricRowDisplayModel(
                id: "deficit",
                label: copy.dailyDeficitLabel,
                value: PlanFormatter.kcal(preview.estimatedDailyDeficit)
            )
        ]
    }

    private var targetRows: [PlanMetricRowDisplayModel] {
        var rows = [
            PlanMetricRowDisplayModel(
                id: "calories",
                label: copy.caloriesLabel,
                value: PlanFormatter.kcal(preview.targets.calorieTarget)
            ),
            PlanMetricRowDisplayModel(
                id: "protein",
                label: copy.proteinLabel,
                value: PlanFormatter.grams(preview.targets.proteinTarget)
            ),
            PlanMetricRowDisplayModel(
                id: "carbs",
                label: copy.carbsLabel,
                value: PlanFormatter.grams(preview.targets.carbTarget)
            ),
            PlanMetricRowDisplayModel(
                id: "fat",
                label: copy.fatLabel,
                value: PlanFormatter.grams(preview.targets.fatTarget)
            ),
            PlanMetricRowDisplayModel(
                id: "water",
                label: copy.waterLabel,
                value: PlanFormatter.ml(preview.targets.waterTargetMl)
            ),
            PlanMetricRowDisplayModel(
                id: "aggressiveness",
                label: copy.aggressivenessLabel,
                value: PlanFormatter.aggressiveness(preview.targets.aggressiveness)
            )
        ]

        if let weeklyLoss = PlanFormatter.weeklyLoss(preview.targets.expectedWeeklyWeightLossKg) {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "weeklyLoss",
                    label: copy.expectedWeeklyLossLabel,
                    value: weeklyLoss
                )
            )
        }

        return rows
    }

    private func apply() {
        guard !isApplying else { return }
        isApplying = true
        Task {
            await onApply()
            isApplying = false
            dismiss()
        }
    }
}

#Preview {
    TargetRegenerationSheet(
        preview: PlanPreviewData.generatedPreview,
        onApply: {},
        onCancel: {}
    )
    .formaThemePreview()
}
