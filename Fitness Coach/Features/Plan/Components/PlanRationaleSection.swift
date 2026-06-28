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
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    if rationale.usesHighlightLayout, let highlights = rationale.highlights {
                        highlightsContent(highlights)
                    } else {
                        paragraphContent
                    }

                    if let sustainabilityNote = rationale.sustainabilityNote {
                        Text(sustainabilityNote)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, rationale.usesHighlightLayout ? FormaTokens.Spacing.xs : 0)
                    }

                    if rationale.calculationDetails != nil {
                        calculationDetailsButton
                    }
                }
            }
        }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(highlight.label), \(highlight.value)")
    }

    private var calculationDetailsButton: some View {
        Button {
            showsCalculationDetailsSheet = true
        } label: {
            Label(
                FormaProductCopy.PlanRationale.viewCalculationDetails,
                systemImage: "function"
            )
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.accent)
        }
        .buttonStyle(.plain)
        .padding(.top, FormaTokens.Spacing.xs)
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
