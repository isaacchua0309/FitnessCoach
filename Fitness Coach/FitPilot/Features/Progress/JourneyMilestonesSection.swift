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
                Text(FormaProductCopy.Journey.milestonesNeedGoal)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            } else {
                FitPilotPlanCard {
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
    }

    private func milestoneNode(_ milestone: JourneyMilestone) -> some View {
        VStack(spacing: 8) {
            Circle()
                .fill(fillColor(for: milestone.status))
                .frame(width: milestone.status == .current ? 14 : 10, height: milestone.status == .current ? 14 : 10)
                .overlay {
                    if milestone.status == .current {
                        Circle()
                            .strokeBorder(FormaTokens.Color.accent.opacity(0.45), lineWidth: 2)
                            .frame(width: 20, height: 20)
                    }
                }

            Text(formatKg(milestone.weightKg))
                .font(milestone.status == .current ? FormaTokens.Typography.sectionSubtitle.weight(.semibold) : FormaTokens.Typography.caption)
                .foregroundStyle(milestone.status == .upcoming ? FormaTokens.Color.textTertiary : FormaTokens.Color.textPrimary)
        }
        .frame(minWidth: 56)
    }

    private func connector(from: JourneyMilestone, to: JourneyMilestone) -> some View {
        Rectangle()
            .fill(from.status == .completed ? FormaTokens.Color.borderStrong : FormaTokens.Color.border)
            .frame(width: 28, height: 2)
            .padding(.bottom, 22)
    }

    private func fillColor(for status: JourneyMilestoneStatus) -> Color {
        switch status {
        case .completed: return FormaTokens.Color.textSecondary
        case .current: return FormaTokens.Color.accent
        case .upcoming: return FormaTokens.Color.surfaceSubtle
        }
    }

    private func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
