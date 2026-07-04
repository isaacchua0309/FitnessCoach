//
//  PlanBodyBaselineSummaryCard.swift
//  Fitness Coach
//
//  Forma — Body baseline summary for Edit Plan height & weight step.
//

import SwiftUI

struct PlanBodyBaselineSummaryCard: View {
    let state: PlanBodyBaselineSummaryState

    private let copy = FormaProductCopy.PlanEditBodyBaseline.self

    var body: some View {
        PlanMacroSummaryCard(model: summaryModel)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary)
    }

    private var summaryModel: PlanMacroSummaryCardDisplayModel {
        var rows: [PlanMetricRowDisplayModel] = [
            PlanMetricRowDisplayModel(id: "height", label: copy.heightLabel, value: state.heightDisplay),
            PlanMetricRowDisplayModel(id: "weight", label: copy.weightLabel, value: state.weightDisplay)
        ]

        if let bodyContextLine = state.bodyContextLine {
            rows.append(
                PlanMetricRowDisplayModel(id: "context", label: copy.bodyContextLabel, value: bodyContextLine)
            )
        }

        if let maintenancePreviewLine = state.maintenancePreviewLine {
            rows.append(
                PlanMetricRowDisplayModel(
                    id: "maintenance",
                    label: copy.maintenanceLabel,
                    value: maintenancePreviewLine
                )
            )
        }

        return PlanMacroSummaryCardDisplayModel(
            title: copy.summaryTitle,
            rows: rows,
            footerText: state.coachingLine
        )
    }

    private var accessibilitySummary: String {
        var parts = [
            copy.summaryTitle,
            "\(copy.heightLabel), \(state.heightDisplay)",
            "\(copy.weightLabel), \(state.weightDisplay)"
        ]
        if let bodyContextLine = state.bodyContextLine {
            parts.append(bodyContextLine)
        }
        if let maintenancePreviewLine = state.maintenancePreviewLine {
            parts.append("\(copy.maintenanceLabel), \(maintenancePreviewLine)")
        }
        parts.append(state.coachingLine)
        return parts.joined(separator: ". ")
    }
}

struct PlanBodyBaselineProjectionCard: View {
    let state: PlanBodyBaselineProjectionState

    private let copy = FormaProductCopy.PlanEditBodyBaseline.self

    var body: some View {
        PlanProjectionCard(compact: true) {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(copy.projectionTitle)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planMutedText)

                if let maintenanceLine = state.maintenanceLine {
                    Text(maintenanceLine)
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.numericText())
                } else {
                    Text(copy.maintenancePlaceholder)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(state.adjustmentLine)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("Body Baseline Cards") {
    VStack(spacing: 12) {
        PlanBodyBaselineSummaryCard(
            state: PlanBodyBaselineSummaryState(
                heightDisplay: "175 cm",
                weightDisplay: "80 kg",
                bodyContextLine: "Based on 175 cm and 80 kg.",
                maintenancePreviewLine: FormaProductCopy.PlanEditBodyBaseline.maintenancePreviewValue("2,400 kcal/day"),
                coachingLine: FormaProductCopy.PlanEditBodyBaseline.coachingLine,
                isComplete: true
            )
        )
        PlanBodyBaselineProjectionCard(
            state: PlanBodyBaselineProjectionState(
                maintenanceLine: FormaProductCopy.PlanEditBodyBaseline.maintenanceAtBaseline("2,400 kcal/day"),
                adjustmentLine: FormaProductCopy.PlanEditBodyBaseline.targetAdjustedFromBaseline,
                isPlaceholder: false
            )
        )
    }
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
