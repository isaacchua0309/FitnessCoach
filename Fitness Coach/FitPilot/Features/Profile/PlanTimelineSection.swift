//
//  PlanTimelineSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanTimelineSection: View {
    let timeline: PlanTimelineState

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Plan timeline")

            FitPilotPlanCard {
                if timeline.phases.isEmpty {
                    Text("Phases will appear as your strategy evolves.")
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(timeline.phases.enumerated()), id: \.element.id) { index, phase in
                            HStack(spacing: FormaTokens.Spacing.sm) {
                                phaseNode(phase)

                                Text(phase.name)
                                    .font(phase.status == .current ? FormaTokens.Typography.sectionSubtitle.weight(.semibold) : FormaTokens.Typography.sectionSubtitle)
                                    .foregroundStyle(phaseForeground(for: phase.status))

                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: FitPilotScreenStyle.rowMinHeight)

                            if index < timeline.phases.count - 1 {
                                connector(isActive: phase.status == .current || phase.status == .past)
                                    .padding(.leading, 5)
                            }
                        }
                    }
                }
            }
        }
    }

    private func phaseForeground(for status: PlanPhaseStatus) -> Color {
        switch status {
        case .upcoming:
            return FormaTokens.Color.textTertiary
        case .current, .past:
            return FormaTokens.Color.textPrimary
        }
    }

    private func phaseNode(_ phase: PlanPhase) -> some View {
        Circle()
            .fill(nodeColor(for: phase.status))
            .frame(width: phase.status == .current ? 12 : 8, height: phase.status == .current ? 12 : 8)
            .overlay {
                if phase.status == .current {
                    Circle()
                        .strokeBorder(FormaTokens.Color.borderStrong, lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 18, height: 18)
    }

    private func connector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? FormaTokens.Color.border : FormaTokens.Color.border.opacity(0.45))
            .frame(width: 2, height: 16)
            .padding(.leading, 8)
    }

    private func nodeColor(for status: PlanPhaseStatus) -> Color {
        switch status {
        case .current:
            return FormaTokens.Color.textPrimary
        case .past:
            return FormaTokens.Color.textSecondary
        case .upcoming:
            return FormaTokens.Color.textTertiary
        }
    }
}
