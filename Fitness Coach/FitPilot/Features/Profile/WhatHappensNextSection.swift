//
//  WhatHappensNextSection.swift
//  Fitness Coach
//
//  Forma — Explains the current strategy phase and what likely comes next.
//

import SwiftUI

struct WhatHappensNextSection: View {
    let state: WhatHappensNextState

    @State private var isRoadmapExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "What happens next")

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    progressionBlock(
                        label: "Current phase",
                        title: state.currentPhaseName,
                        detail: state.currentPhaseGoal
                    )

                    FitPilotPlanRowDivider()

                    progressionBlock(
                        label: "Next checkpoint",
                        title: nil,
                        detail: state.nextCheckpoint
                    )

                    FitPilotPlanRowDivider()

                    progressionBlock(
                        label: "Next phase",
                        title: state.nextPhaseName,
                        detail: state.nextPhaseGoal
                    )

                    if let roadmap = state.roadmapSummary {
                        FitPilotPlanRowDivider()

                        DisclosureGroup(isExpanded: $isRoadmapExpanded) {
                            Text(roadmap)
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaTokens.Color.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        } label: {
                            Text("Possible roadmap")
                                .font(FormaTokens.Typography.caption)
                                .foregroundStyle(FormaTokens.Color.textSecondary)
                        }
                        .tint(FormaTokens.Color.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func progressionBlock(label: String, title: String?, detail: String) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)

            if let title {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)
            }

            Text(detail)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(title == nil ? FormaTokens.Color.textPrimary : FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    WhatHappensNextSection(state: ProfilePreviewData.state.whatHappensNext)
        .padding()
        .background(FormaTokens.Color.canvas)
        .preferredColorScheme(.dark)
}
