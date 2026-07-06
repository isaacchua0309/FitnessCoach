//
//  TodayRecoverySection.swift
//  Fitness Coach
//
//  Forma — Recovery / training readiness section on Today.
//

import SwiftUI

struct TodayRecoverySection: View {
    let state: TodayRecoveryCardState
    var isLoading: Bool = false
    var staleDataLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            if let staleDataLabel {
                staleDataBanner(label: staleDataLabel)
            }

            if TodayRecoverySectionFormatting.isCompact(state) {
                compactRecoveryCard
            } else {
                TodayRecoveryCard(state: state, isLoading: isLoading)
            }
        }
        .accessibilityIdentifier("today-recovery-section")
        .formaThemeReactive()
    }

    private var compactRecoveryCard: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            SectionLabel(title: FormaProductCopy.Today.Recovery.sectionTitle)

            MainTabCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                    Text(TodayRecoverySectionFormatting.compactTitle(for: state))
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(TodayRecoverySectionFormatting.compactBody(for: state))
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, FormaTokens.Spacing.sm)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(TodayRecoverySectionFormatting.compactAccessibilityLabel(for: state))
            .accessibilityIdentifier("today-recovery-compact-card")
        }
    }

    @ViewBuilder
    private func staleDataBanner(label: String) -> some View {
        HStack(spacing: FormaTokens.Spacing.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(FormaTokens.Typography.caption2)
                .foregroundStyle(FormaTokens.Color.textTertiary)
                .accessibilityHidden(true)

            Text(label)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

#Preview("Compact recovery") {
    TodayRecoverySection(state: TodayHealthIntelligencePreviewData.noHealthData.recoveryCard)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}

#Preview("Full recovery") {
    TodayRecoverySection(state: TodayHealthIntelligencePreviewData.readyDay.recoveryCard)
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
