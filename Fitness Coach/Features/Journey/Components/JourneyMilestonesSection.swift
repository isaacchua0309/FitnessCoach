//
//  JourneyMilestonesSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyMilestonesSection: View {
    let state: JourneyMilestonesState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.Milestones.sectionTitle)

            if state.items.isEmpty {
                FitPilotPlanCard {
                    Text(FormaProductCopy.Journey.Milestones.emptyBody)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                if let next = state.next {
                    nextMilestoneHeader(next)
                }

                FitPilotPlanCard {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FormaTokens.Spacing.sm) {
                            ForEach(state.items) { milestone in
                                milestoneCard(milestone, isNext: milestone.id == state.next?.id)
                            }
                        }
                        .padding(.vertical, FormaTokens.Spacing.xs)
                    }
                }
            }
        }
    }

    private func nextMilestoneHeader(_ milestone: JourneyMilestone) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Text(FormaProductCopy.Journey.Milestones.nextUp)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textTertiary)

            Text(milestone.title)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)

            if let progress = state.nextProgressFraction {
                SwiftUI.ProgressView(value: min(max(progress, 0), 1))
                    .tint(FormaTokens.Color.progress)
                    .accessibilityLabel(FormaProductCopy.Journey.Milestones.nextUp)
                    .accessibilityValue(
                        FormaProductCopy.Journey.Milestones.Accessibility.progressPercent(
                            Int((progress * 100).rounded())
                        )
                    )
                Text(FormaProductCopy.Journey.Milestones.progressLabel(
                    percent: Int((progress * 100).rounded())
                ))
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .accessibilityHidden(true)
            }
        }
    }

    private func milestoneCard(_ milestone: JourneyMilestone, isNext: Bool) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            HStack(spacing: FormaTokens.Spacing.xs) {
                Text(statusIcon(for: milestone.status))
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .accessibilityHidden(true)

                Text(milestone.title)
                    .font(FormaTokens.Typography.caption.weight(milestone.status == .completed ? .semibold : .medium))
                    .foregroundStyle(titleColor(for: milestone.status, isNext: isNext))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

            if milestone.status != .completed,
               let progress = milestone.progressFraction,
               isNext {
                SwiftUI.ProgressView(value: min(max(progress, 0), 1))
                    .tint(FormaTokens.Color.progress)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 148, alignment: .leading)
        .padding(FormaTokens.Spacing.sm)
        .background(cardBackground(for: milestone.status, isNext: isNext))
        .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous))
        .overlay {
            if isNext {
                RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                    .strokeBorder(FormaTokens.Color.accent.opacity(0.45), lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: milestone, isNext: isNext))
    }

    private func statusIcon(for status: JourneyMilestoneStatus) -> String {
        switch status {
        case .completed: return "✓"
        case .current: return "◎"
        case .upcoming: return "⬜"
        }
    }

    private func titleColor(for status: JourneyMilestoneStatus, isNext: Bool) -> Color {
        switch status {
        case .completed:
            return FormaTokens.Color.textPrimary
        case .current:
            return FormaTokens.Color.accent
        case .upcoming:
            return isNext ? FormaTokens.Color.textPrimary : FormaTokens.Color.textSecondary
        }
    }

    private func cardBackground(for status: JourneyMilestoneStatus, isNext: Bool) -> Color {
        switch status {
        case .completed:
            return FormaTokens.Color.success.opacity(0.12)
        case .current:
            return FormaTokens.Color.accentMuted
        case .upcoming:
            return isNext ? FormaTokens.Color.surfaceSubtle : FormaTokens.Color.canvas
        }
    }

    private func accessibilityLabel(for milestone: JourneyMilestone, isNext: Bool) -> String {
        let accessibility = FormaProductCopy.Journey.Milestones.Accessibility.self
        let status: String
        switch milestone.status {
        case .completed: status = accessibility.unlocked
        case .current: status = accessibility.nextUp
        case .upcoming: status = isNext ? accessibility.nextUp : accessibility.upcoming
        }
        if let progress = milestone.progressFraction, milestone.status != .completed {
            return "\(status). \(milestone.title). \(accessibility.progressPercent(Int((progress * 100).rounded())))."
        }
        return "\(status). \(milestone.title)."
    }
}

// MARK: - Previews

#Preview("New user") {
    JourneyMilestonesSection(state: ProgressPreviewData.milestonesNewUser)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Active progress") {
    JourneyMilestonesSection(state: ProgressPreviewData.milestonesActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Near goal") {
    JourneyMilestonesSection(state: ProgressPreviewData.milestonesNearGoal)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
