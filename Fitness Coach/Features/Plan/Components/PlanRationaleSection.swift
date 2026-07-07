//
//  PlanRationaleSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanRationaleSection: View {
    let explanation: PlanExplanationState
    var onCalculationDetailsOpened: (() -> Void)? = nil

    @State private var showsCalculationDetailsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.headerToCardSpacing) {
            FormaSectionLabel(title: explanation.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm + 2) {
                    energySummaryBlock

                    Text("\"\(explanation.guidanceCopy)\"")
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, FormaTokens.Spacing.xs)
                        .accessibilityHidden(true)

                    if explanation.showsCalculationAction {
                        calculationDetailsButton
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(explanation.accessibilitySummary)
        }
        .sheet(isPresented: $showsCalculationDetailsSheet) {
            if let details = explanation.calculationDetails {
                PlanCalculationDetailsSheet(details: details)
            }
        }
    }

    private var energySummaryBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(explanation.energyLines.enumerated()), id: \.element.id) { index, line in
                if index > 0 {
                    FormaPlanRowDivider()
                }
                FormaPlanDisplayRow(label: line.label, value: line.value)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
    }

    private var calculationDetailsButton: some View {
        Button {
            onCalculationDetailsOpened?()
            showsCalculationDetailsSheet = true
        } label: {
            Text(explanation.seeCalculationTitle)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Theme.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .padding(.top, FormaTokens.Spacing.xs)
        .accessibilityLabel(explanation.seeCalculationTitle)
        .accessibilityHint(FormaProductCopy.PlanMissionControl.seeCalculationAccessibilityHint)
    }
}

#Preview {
    PlanRationaleSection(
        explanation: PlanMissionControlFixtures.loseDashboard.explanation
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
