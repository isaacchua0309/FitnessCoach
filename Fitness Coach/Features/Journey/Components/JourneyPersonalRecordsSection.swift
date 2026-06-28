//
//  JourneyPersonalRecordsSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyPersonalRecordsSection: View {
    let state: JourneyPersonalRecordsState

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.PersonalRecords.sectionTitle)

            if !state.isUnlocked {
                FitPilotPlanCard {
                    Text(state.lockedMessage ?? FormaProductCopy.Journey.PersonalRecords.lockedBody)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if state.displayRecords.isEmpty {
                FitPilotPlanCard {
                    Text(FormaProductCopy.Journey.PersonalRecords.lockedBody)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                FitPilotPlanCard {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: FormaTokens.Spacing.sm) {
                            ForEach(state.displayRecords) { record in
                                recordCard(record)
                            }
                        }
                        .padding(.vertical, FormaTokens.Spacing.xs)
                    }
                }
            }
        }
    }

    private func recordCard(_ record: JourneyPersonalRecord) -> some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            Image(systemName: "trophy.fill")
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.success)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(record.title)
                .font(FormaTokens.Typography.caption.weight(.medium))
                .foregroundStyle(FormaTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(record.value)
                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = record.subtitle {
                Text(subtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(
                        record.isEarlyRecord
                            ? FormaTokens.Color.textTertiary
                            : FormaTokens.Color.textSecondary
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let period = record.periodLabel {
                Text(period)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 148, alignment: .leading)
        .padding(FormaTokens.Spacing.sm)
        .background(FormaTokens.Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: record))
    }

    private func accessibilityLabel(for record: JourneyPersonalRecord) -> String {
        var parts = [record.title, record.value]
        if let subtitle = record.subtitle {
            parts.append(subtitle)
        }
        if let period = record.periodLabel {
            parts.append(period)
        }
        return parts.joined(separator: ", ")
    }
}

#if DEBUG
#Preview("Personal records") {
    ScrollView {
        JourneyPersonalRecordsSection(state: ProgressPreviewData.state.personalRecords)
            .padding()
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
