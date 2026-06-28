//
//  PlanRationaleSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanRationaleSection: View {
    let rationale: PlanRationaleState

    @State private var showsCalculationDetailsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.PlanRationale.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    if rationale.usesVisualFlowLayout, let flowSteps = rationale.flowSteps {
                        visualFlowContent(flowSteps)

                        if let basedOnItems = rationale.basedOnItems {
                            basedOnBlock(basedOnItems)
                        }
                    } else if rationale.usesHighlightLayout, let highlights = rationale.highlights {
                        highlightsContent(highlights)
                    } else {
                        paragraphContent
                    }

                    if let sustainabilityNote = rationale.sustainabilityNote {
                        Text(sustainabilityNote)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, FormaTokens.Spacing.xs)
                    }

                    if rationale.calculationDetails != nil {
                        calculationDetailsButton
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rationale.accessibilitySummary)
        .sheet(isPresented: $showsCalculationDetailsSheet) {
            if let details = rationale.calculationDetails {
                PlanCalculationDetailsSheet(details: details)
            }
        }
    }

    private var paragraphContent: some View {
        Text(rationale.summary)
            .font(FormaTokens.Typography.sectionSubtitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    private func visualFlowContent(_ steps: [PlanRationaleFlowStep]) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                if index > 0 {
                    flowArrow
                }
                flowStep(step)
            }
        }
        .accessibilityHidden(true)
    }

    private func flowStep(_ step: PlanRationaleFlowStep) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step.label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(step.value)
                .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var flowArrow: some View {
        Text("↓")
            .font(FormaTokens.Typography.sectionTitle.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    private func basedOnBlock(_ items: [PlanRationaleBasedOnItem]) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(FormaProductCopy.PlanRationale.basedOnHeading)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .padding(.top, FormaTokens.Spacing.sm)

            ForEach(items) { item in
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
                    Text("•")
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textTertiary)

                    Text(item.label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)

                    Spacer(minLength: FormaTokens.Spacing.xs)

                    Text(item.value)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.medium))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func highlightsContent(_ highlights: [PlanRationaleHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                highlightRow(highlight)

                if index < highlights.count - 1 {
                    FitPilotPlanRowDivider()
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func highlightRow(_ highlight: PlanRationaleHighlight) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(highlight.label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(highlight.value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private var calculationDetailsButton: some View {
        Button {
            showsCalculationDetailsSheet = true
        } label: {
            Text(rationale.seeCalculationTitle)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
        }
        .buttonStyle(.plain)
        .padding(.top, FormaTokens.Spacing.xs)
        .accessibilityLabel(rationale.seeCalculationTitle)
    }
}

#Preview {
    PlanRationaleSection(
        rationale: PlanRationaleCopyBuilder.build(for: ProfilePreviewData.profile)
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
