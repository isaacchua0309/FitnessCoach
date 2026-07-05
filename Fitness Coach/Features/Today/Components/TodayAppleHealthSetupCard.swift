//
//  TodayAppleHealthSetupCard.swift
//  Fitness Coach
//
//  Forma — Bottom improvement prompt for Apple Health on Today.
//

import SwiftUI

struct TodayAppleHealthSetupCard: View {
    let actionTitle: String
    let onAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.AppleHealthSetup.sectionTitle)

            FormaPlanCard {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    Text(FormaProductCopy.Today.AppleHealthSetup.body)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(actionTitle, action: onAction)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
                        .accessibilityLabel(actionTitle)
                        .accessibilityHint(FormaProductCopy.Today.AppleHealthSetup.body)
                }
                .padding(.vertical, FormaTokens.Spacing.sm)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today-apple-health-setup-card")
    }
}

#Preview("Connect Apple Health") {
    TodayAppleHealthSetupCard(
        actionTitle: FormaProductCopy.Today.AppleHealthSetup.connectAction,
        onAction: {}
    )
    .padding(.horizontal, TodayLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
