//
//  JourneyMilestonesSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMilestonesSection: View {
    let milestones: [JourneyMilestone]

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Milestones")

            if milestones.isEmpty {
                Text("Set a goal in Plan to see your weight roadmap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                            HStack(spacing: 0) {
                                milestoneNode(milestone)
                                if index < milestones.count - 1 {
                                    connector(from: milestone, to: milestones[index + 1])
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func milestoneNode(_ milestone: JourneyMilestone) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(fillColor(for: milestone.status))
                .frame(width: milestone.status == .current ? 14 : 10, height: milestone.status == .current ? 14 : 10)
                .overlay {
                    if milestone.status == .current {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.35), lineWidth: 2)
                            .frame(width: 20, height: 20)
                    }
                }

            Text(formatKg(milestone.weightKg))
                .font(milestone.status == .current ? .subheadline.weight(.semibold) : .caption)
                .foregroundStyle(milestone.status == .upcoming ? .tertiary : .primary)
        }
        .frame(minWidth: 56)
    }

    private func connector(from: JourneyMilestone, to: JourneyMilestone) -> some View {
        Rectangle()
            .fill(from.status == .completed ? Color.primary.opacity(0.35) : Color.secondary.opacity(0.2))
            .frame(width: 28, height: 2)
            .padding(.bottom, 22)
    }

    private func fillColor(for status: JourneyMilestoneStatus) -> Color {
        switch status {
        case .completed: return Color.primary.opacity(0.7)
        case .current: return Color.primary
        case .upcoming: return Color.secondary.opacity(0.25)
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
