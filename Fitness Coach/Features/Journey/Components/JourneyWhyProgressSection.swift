//
//  JourneyWhyProgressSection.swift
//  Fitness Coach
//

import SwiftUI

struct JourneyWhyProgressSection: View {
    let state: JourneyProgressAttributionState

    private var isInsufficientData: Bool {
        state.confidence == .low
            && state.supportingReasons.isEmpty
            && state.primaryReasonTitle == FormaProductCopy.Journey.WhyProgress.insufficientTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyLayout.itemSpacing) {
            FormaSectionLabel(title: FormaProductCopy.Journey.ProgressAttribution.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(state.primaryReasonTitle)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(isInsufficientData ? .medium : .semibold))
                        .foregroundStyle(
                            isInsufficientData
                                ? FormaTokens.Color.textSecondary
                                : FormaTokens.Color.textPrimary
                        )
                        .fixedSize(horizontal: false, vertical: true)

                    Text(state.primaryReasonDetail)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !state.supportingReasons.isEmpty {
                        FormaPlanRowDivider()

                        VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                            ForEach(state.supportingReasons, id: \.self) { reason in
                                HStack(alignment: .top, spacing: FormaTokens.Spacing.xs) {
                                    Text("•")
                                        .font(FormaTokens.Typography.caption)
                                        .foregroundStyle(FormaTokens.Color.textTertiary)
                                    Text(reason)
                                        .font(FormaTokens.Typography.caption)
                                        .foregroundStyle(FormaTokens.Color.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        var parts = [state.primaryReasonTitle, state.primaryReasonDetail]
        parts.append(contentsOf: state.supportingReasons)
        return parts.joined(separator: ". ")
    }
}

// MARK: - Previews

#Preview("Active attribution") {
    JourneyWhyProgressSection(state: JourneyPreviewData.progressAttributionActive)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Plateau attribution") {
    JourneyWhyProgressSection(state: JourneyPreviewData.progressAttributionPlateau)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Insufficient data") {
    JourneyWhyProgressSection(state: .insufficientData)
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
