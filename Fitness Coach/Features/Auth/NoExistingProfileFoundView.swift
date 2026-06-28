//
//  NoExistingProfileFoundView.swift
//  Fitness Coach
//
//  Forma — Post-sign-in interstitial when auth succeeded but no saved plan exists.
//

import SwiftUI

struct NoExistingProfileFoundView: View {

    let analyticsLogger: any PublicEntryAnalyticsLogging
    var analyticsProperties: PublicEntryAnalyticsProperties = PublicEntryAnalyticsProperties()
    let onStartOnboarding: () -> Void
    let onUseAnotherAccount: () -> Void

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    @State private var didLogView = false

    private let copy = FormaProductCopy.PublicEntry.NoExistingPlan.self

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FormaTokens.Spacing.md) {
                PublicEntryBrandMark(style: .planSearch, palette: palette)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, FormaTokens.Spacing.sm)
                    .accessibilityHidden(true)

                PublicEntryTitleBlock(
                    title: copy.title,
                    subtitle: copy.subtitle,
                    palette: palette,
                    titleLineLimit: 3
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(copy.title). \(copy.subtitle)")

                PublicEntryPrimaryButton(
                    title: copy.startOnboardingCTA,
                    palette: palette,
                    action: handleStartOnboardingTapped,
                    accessibilityHint: copy.startOnboardingAccessibilityHint
                )
                .padding(.top, FormaTokens.Spacing.sm)

                PublicEntrySecondaryLink(
                    title: copy.useAnotherAccountCTA,
                    palette: palette,
                    action: handleUseAnotherAccountTapped,
                    font: FormaTokens.Typography.body.weight(.semibold),
                    accessibilityHint: copy.useAnotherAccountAccessibilityHint
                )

                Text(copy.supportingCopy)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(palette.textTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, FormaTokens.Spacing.xs)
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, FormaTokens.Spacing.xl)
            .padding(.bottom, FormaTokens.Spacing.lg)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(PublicEntryScreenBackground(palette: palette))
        .onAppear(perform: logViewedIfNeeded)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Actions

    private func handleStartOnboardingTapped() {
        analyticsLogger.log(
            .noExistingProfileStartOnboardingTapped,
            properties: analyticsProperties
        )
        onStartOnboarding()
    }

    private func handleUseAnotherAccountTapped() {
        analyticsLogger.log(
            .noExistingProfileUseAnotherAccountTapped,
            properties: analyticsProperties
        )
        onUseAnotherAccount()
    }

    private func logViewedIfNeeded() {
        guard !didLogView else { return }
        didLogView = true
        analyticsLogger.log(.noExistingProfileViewed, properties: analyticsProperties)
    }
}
