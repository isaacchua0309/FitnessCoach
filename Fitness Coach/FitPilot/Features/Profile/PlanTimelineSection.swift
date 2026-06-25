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

            if timeline.phases.isEmpty {
                Text("Phases will appear as your strategy evolves.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(timeline.phases.enumerated()), id: \.element.id) { index, phase in
                        HStack(spacing: 12) {
                            phaseNode(phase)

                            Text(phase.name)
                                .font(phase.status == .current ? .subheadline.weight(.semibold) : .subheadline)
                                .foregroundStyle(phase.status == .upcoming ? .tertiary : .primary)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)

                        if index < timeline.phases.count - 1 {
                            connector(isActive: phase.status == .current || phase.status == .past)
                                .padding(.leading, 5)
                        }
                    }
                }
            }
        }
    }

    private func phaseNode(_ phase: PlanPhase) -> some View {
        Circle()
            .fill(nodeColor(for: phase.status))
            .frame(width: phase.status == .current ? 12 : 8, height: phase.status == .current ? 12 : 8)
            .overlay {
                if phase.status == .current {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: 18, height: 18)
    }

    private func connector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? Color.primary.opacity(0.3) : Color.secondary.opacity(0.2))
            .frame(width: 2, height: 20)
            .padding(.leading, 8)
    }

    private func nodeColor(for status: PlanPhaseStatus) -> Color {
        switch status {
        case .current: return Color.primary
        case .past: return Color.primary.opacity(0.5)
        case .upcoming: return Color.secondary.opacity(0.25)
        }
    }
}
