//
//  NoExistingProfileFoundView.swift
//  Fitness Coach
//
//  Forma — Post-sign-in interstitial when auth succeeded but no saved plan exists.
//

import SwiftUI

struct NoExistingProfileFoundView: View {

    let analyticsLogger: any PublicEntryAnalyticsLogging
    let onStartOnboarding: () -> Void
    let onUseAnotherAccount: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var didLogView = false

    private let copy = FormaProductCopy.PublicEntry.NoExistingPlan.self

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FormaTokens.Spacing.md) {
                brandMark
                titleBlock
                primaryCTA
                secondaryCTA
                supportingCopy
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

    // MARK: - Sections

    private var brandMark: some View {
        NoExistingProfileFoundBrandMark(palette: palette)
            .frame(maxWidth: .infinity)
            .padding(.bottom, FormaTokens.Spacing.sm)
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(copy.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.84)
                .lineLimit(3)
                .accessibilityAddTraits(.isHeader)

            Text(copy.subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.88)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.subtitle)")
    }

    private var primaryCTA: some View {
        Button(action: handleStartOnboardingTapped) {
            Text(copy.startOnboardingCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(palette.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(palette.accent)
        }
        .padding(.top, FormaTokens.Spacing.sm)
        .accessibilityHint("Begin building your Forma plan")
    }

    private var secondaryCTA: some View {
        Button(action: handleUseAnotherAccountTapped) {
            Text(copy.useAnotherAccountCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Sign out and choose a different account")
    }

    private var supportingCopy: some View {
        Text(copy.supportingCopy)
            .font(FormaTokens.Typography.caption)
            .foregroundStyle(palette.textTertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, FormaTokens.Spacing.xs)
    }

    // MARK: - Actions

    private func handleStartOnboardingTapped() {
        analyticsLogger.log(
            .noExistingProfileStartOnboardingTapped,
            properties: PublicEntryAnalyticsProperties()
        )
        onStartOnboarding()
    }

    private func handleUseAnotherAccountTapped() {
        analyticsLogger.log(
            .noExistingProfileUseAnotherAccountTapped,
            properties: PublicEntryAnalyticsProperties()
        )
        onUseAnotherAccount()
    }

    private func logViewedIfNeeded() {
        guard !didLogView else { return }
        didLogView = true
        analyticsLogger.log(.noExistingProfileViewed, properties: PublicEntryAnalyticsProperties())
    }
}

// MARK: - Chrome

private struct NoExistingProfileFoundBrandMark: View {
    let palette: PublicWelcomeTheme.Palette

    @ScaledMetric(relativeTo: .largeTitle) private var markDiameter: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.accentSoft)
                .frame(width: markDiameter * 1.18, height: markDiameter * 1.18)

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: markDiameter * 0.38, weight: .semibold))
                .foregroundStyle(palette.accent)
        }
    }
}

#Preview {
    NoExistingProfileFoundView(
        analyticsLogger: OSLogPublicEntryAnalyticsLogger(),
        onStartOnboarding: {},
        onUseAnotherAccount: {}
    )
}
