//
//  JourneyMilestonesSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMilestonesSection: View {
    let milestones: [JourneyMilestone]

    private var nextMilestone: JourneyMilestone? {
        ProgressFormatter.nextMilestone(from: milestones)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            JourneySectionLabel(title: "Milestones")

            if milestones.isEmpty {
                Text(FormaProductCopy.Journey.milestonesNeedGoal)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            } else {
                if let nextMilestone {
                    Text(FormaProductCopy.Journey.nextStop(
                        ProgressFormatter.journeyKg(nextMilestone.weightKg)
                    ))
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                }

                FitPilotPlanCard {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                                HStack(spacing: 0) {
                                    milestoneNode(milestone, index: index)
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

    private func milestoneNode(_ milestone: JourneyMilestone, index: Int) -> some View {
        let isNext = milestone.id == nextMilestone?.id
        let role = roleLabel(for: milestone, index: index, isNext: isNext)

        return VStack(spacing: 6) {
            if let role {
                Text(role)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(
                        milestone.status == .current || isNext
                            ? FormaTokens.Color.accent
                            : FormaTokens.Color.textTertiary
                    )
            }

            Circle()
                .fill(fillColor(for: milestone.status, isNext: isNext))
                .frame(width: nodeSize(for: milestone.status, isNext: isNext), height: nodeSize(for: milestone.status, isNext: isNext))
                .overlay {
                    if milestone.status == .current || isNext {
                        Circle()
                            .strokeBorder(FormaTokens.Color.accent.opacity(0.45), lineWidth: 2)
                            .frame(width: nodeSize(for: milestone.status, isNext: isNext) + 6)
                    }
                }

            Text(ProgressFormatter.journeyKg(milestone.weightKg))
                .font(
                    milestone.status == .current || isNext
                        ? FormaTokens.Typography.sectionSubtitle.weight(.semibold)
                        : FormaTokens.Typography.caption
                )
                .foregroundStyle(
                    milestone.status == .upcoming && !isNext
                        ? FormaTokens.Color.textTertiary
                        : FormaTokens.Color.textPrimary
                )
        }
        .frame(minWidth: 64)
    }

    private func roleLabel(for milestone: JourneyMilestone, index: Int, isNext: Bool) -> String? {
        if milestone.status == .current { return FormaProductCopy.Journey.milestoneCurrent }
        if isNext { return FormaProductCopy.Journey.milestoneNext }
        if index == milestones.count - 1 { return FormaProductCopy.Journey.milestoneGoal }
        return nil
    }

    private func nodeSize(for status: JourneyMilestoneStatus, isNext: Bool) -> CGFloat {
        status == .current || isNext ? 14 : 10
    }

    private func connector(from: JourneyMilestone, to: JourneyMilestone) -> some View {
        Rectangle()
            .fill(from.status == .completed ? FormaTokens.Color.borderStrong : FormaTokens.Color.border)
            .frame(width: 28, height: 2)
            .padding(.bottom, 22)
    }

    private func fillColor(for status: JourneyMilestoneStatus, isNext: Bool) -> Color {
        switch status {
        case .completed: return FormaTokens.Color.textSecondary
        case .current: return FormaTokens.Color.accent
        case .upcoming: return isNext ? FormaTokens.Color.accent.opacity(0.55) : FormaTokens.Color.surfaceSubtle
        }
    }
}
