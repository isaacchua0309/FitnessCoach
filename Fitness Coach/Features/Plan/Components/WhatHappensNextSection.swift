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
            PlanSectionLabel(title: FormaProductCopy.WhatHappensNext.sectionTitle)

            FitPilotPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
                    progressionBlock(
                        label: FormaProductCopy.WhatHappensNext.currentPhase,
                        title: state.currentPhaseName,
                        detail: state.currentPhaseFocus
                    )

                    FitPilotPlanRowDivider()

                    progressionBlock(
                        label: FormaProductCopy.WhatHappensNext.nextCheckpoint,
                        title: nil,
                        detail: state.nextCheckpoint
                    )

                    FitPilotPlanRowDivider()

                    progressionBlock(
                        label: FormaProductCopy.WhatHappensNext.likelyNextStep,
                        title: state.likelyNextStepName,
                        detail: state.likelyNextStepDetail
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
                            Text(FormaProductCopy.WhatHappensNext.possibleRoadmap)
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
