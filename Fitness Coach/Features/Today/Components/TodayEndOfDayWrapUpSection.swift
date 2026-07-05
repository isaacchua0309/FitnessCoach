//
//  TodayEndOfDayWrapUpSection.swift
//  Fitness Coach
//
//  Forma — Evening wrap-up card for Today.
//

import SwiftUI

struct TodayEndOfDayWrapUpSection: View {
    let wrapUp: TodayEndOfDayState
    let onOpenJourney: () -> Void
    var onViewed: (() -> Void)?

    @Environment(\.theme) private var theme

    var body: some View {
        if wrapUp.isVisible {
            VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
                TodaySectionLabel(title: wrapUp.sectionTitle)

                FormaPlanCard {
                    VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                        if let noLogsMessage = wrapUp.noLogsMessage {
                            Text(noLogsMessage)
                                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if let overallMessage = wrapUp.overallMessage {
                            Text(overallMessage)
                                .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !wrapUp.rows.isEmpty {
                            VStack(spacing: FormaTokens.Spacing.xs) {
                                ForEach(Array(wrapUp.rows.enumerated()), id: \.offset) { _, row in
                                    wrapUpRow(row)
                                }
                            }
                            .padding(.top, FormaTokens.Spacing.xs)
                        }

                        FormaQuickActionChip(
                            title: wrapUp.journeyActionTitle,
                            action: onOpenJourney,
                            accessibilityHint: wrapUp.journeyActionHint
                        )
                        .padding(.top, FormaTokens.Spacing.xs)
                    }
                    .padding(.vertical, FormaTokens.Spacing.xs)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(wrapUp.accessibilityLabel)
            .onAppear {
                onViewed?()
            }
        }
    }

    private func wrapUpRow(_ row: TodayEndOfDayRowState) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
            Text(row.label)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 72, alignment: .leading)

            Text(row.valueText)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(valueColor(for: row.status))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
    }

    private func valueColor(for status: TodayEndOfDayRowStatus) -> Color {
        switch status {
        case .complete:
            return theme.accent
        case .partial:
            return theme.primaryText
        case .notLogged:
            return theme.tertiaryText
        case .overTarget:
            return theme.destructive.opacity(0.9)
        }
    }
}

#Preview("Partial evening") {
    TodayEndOfDayWrapUpSection(
        wrapUp: TodayEndOfDayState(
            isVisible: true,
            sectionTitle: FormaProductCopy.Today.EndOfDay.sectionTitle,
            overallMessage: FormaProductCopy.Today.EndOfDay.overallGoodStart,
            noLogsMessage: nil,
            rows: [
                TodayEndOfDayRowState(
                    label: FormaProductCopy.Today.EndOfDay.rowCalories,
                    valueText: "710 / 1,800 kcal",
                    status: .partial
                ),
                TodayEndOfDayRowState(
                    label: FormaProductCopy.Today.EndOfDay.rowProtein,
                    valueText: "79 / 170g",
                    status: .partial
                )
            ],
            journeyActionTitle: FormaProductCopy.Today.EndOfDay.seeJourneyAction,
            journeyActionHint: FormaProductCopy.Today.EndOfDay.seeJourneyHint,
            accessibilityLabel: "Today's Wrap-Up"
        ),
        onOpenJourney: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
