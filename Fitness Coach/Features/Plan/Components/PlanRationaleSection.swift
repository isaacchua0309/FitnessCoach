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
            PlanSectionLabel(title: "Why this plan?")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(rationale.summary)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let sustainabilityNote = rationale.sustainabilityNote {
                        Text(sustainabilityNote)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if rationale.calculationDetails != nil {
                        Button {
                            showsCalculationDetailsSheet = true
                        } label: {
                            Label("View calculation details", systemImage: "function")
                                .font(FormaTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(FormaTokens.Color.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, FormaTokens.Spacing.xs)
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
}

#Preview {
    PlanRationaleSection(
        rationale: PlanRationaleCopyBuilder.build(for: ProfilePreviewData.profile)
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
