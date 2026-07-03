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
        PlanEditCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                Text(copy.summaryTitle)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaPlanTokens.Color.planPrimaryText)

                VStack(spacing: FormaTokens.Spacing.sm) {
                    metricRow(label: copy.heightLabel, value: state.heightDisplay)
                    metricRow(label: copy.weightLabel, value: state.weightDisplay)

                    if let bodyContextLine = state.bodyContextLine {
                        metricRow(label: copy.bodyContextLabel, value: bodyContextLine)
                    }

                    if let maintenancePreviewLine = state.maintenancePreviewLine {
                        metricRow(label: copy.maintenanceLabel, value: maintenancePreviewLine)
                    }
                }

                Text(state.coachingLine)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private func metricRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaPlanTokens.Color.planMutedText)
            Spacer(minLength: FormaTokens.Spacing.sm)
            Text(value)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaPlanTokens.Color.planSecondaryText)
                .multilineTextAlignment(.trailing)
        }
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
        PlanEditCard(compact: true) {
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
                maintenancePreviewLine: "≈ 2,400 kcal/day estimated maintenance",
                coachingLine: FormaProductCopy.PlanEditBodyBaseline.coachingLine,
                isComplete: true
            )
        )
        PlanBodyBaselineProjectionCard(
            state: PlanBodyBaselineProjectionState(
                maintenanceLine: "At this baseline, Forma estimates your maintenance at 2,400 kcal/day.",
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
