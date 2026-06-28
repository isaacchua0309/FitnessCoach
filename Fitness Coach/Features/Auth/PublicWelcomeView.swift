//
//  PublicWelcomeView.swift
//  Fitness Coach
//
//  Forma — Logged-out public welcome screen (not an onboarding step).
//

import SwiftUI

struct PublicWelcomeView: View {

    let analyticsLogger: any PublicEntryAnalyticsLogging
    var analyticsProperties: PublicEntryAnalyticsProperties = PublicEntryAnalyticsProperties()
    let onCreateMyPlan: () -> Void
    let onSignIn: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private let copy = FormaProductCopy.PublicEntry.Welcome.self

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    private var isCompactHeight: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView {
            VStack(spacing: contentSpacing) {
                PublicEntryBrandMark(style: .welcomeHero, palette: palette)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, isCompactHeight ? 0 : FormaTokens.Spacing.xs)
                    .accessibilityHidden(true)

                PublicEntryTitleBlock(
                    title: copy.title,
                    subtitle: copy.headline,
                    supportingCopy: copy.supportingCopy,
                    palette: palette
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(copy.title). \(copy.headline) \(copy.supportingCopy)")

                PublicEntryBenefitChipRow(
                    benefits: copy.benefits,
                    palette: palette,
                    accessibilityLabel: copy.benefitsAccessibilityLabel
                )

                PublicEntryPrimaryButton(
                    title: copy.createMyPlanCTA,
                    palette: palette,
                    action: handleCreateMyPlanTapped,
                    accessibilityHint: copy.createPlanAccessibilityHint
                )
                .accessibilityLabel(copy.createMyPlanCTA)

                VStack(spacing: FormaTokens.Spacing.xs) {
                    Text(copy.existingAccountPrompt)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(palette.textTertiary)
                        .multilineTextAlignment(.center)

                    PublicEntrySecondaryLink(
                        title: copy.signInCTA,
                        palette: palette,
                        action: handleSignInTapped,
                        accessibilityHint: copy.signInAccessibilityHint
                    )
                    .accessibilityLabel(copy.signInAccessibilityLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, FormaTokens.Spacing.xs)
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, topPadding)
            .padding(.bottom, FormaTokens.Spacing.lg)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(PublicEntryScreenBackground(palette: palette))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Layout

    private var contentSpacing: CGFloat {
        isCompactHeight ? FormaTokens.Spacing.md : FormaTokens.Spacing.lg
    }

    private var topPadding: CGFloat {
        isCompactHeight ? FormaTokens.Spacing.md : FormaTokens.Spacing.xl
    }

    // MARK: - Analytics

    private func handleCreateMyPlanTapped() {
        analyticsLogger.log(.welcomeCreatePlanTapped, properties: analyticsProperties)
        onCreateMyPlan()
    }

    private func handleSignInTapped() {
        analyticsLogger.log(.welcomeSignInTapped, properties: analyticsProperties)
        onSignIn()
    }
}
