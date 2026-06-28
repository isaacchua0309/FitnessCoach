//
//  PublicWelcomeView.swift
//  Fitness Coach
//
//  Forma — Logged-out public welcome screen (not an onboarding step).
//

import SwiftUI

struct PublicWelcomeView: View {

    let analyticsLogger: any PublicEntryAnalyticsLogging
    let onCreateMyPlan: () -> Void
    let onSignIn: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var didLogView = false

    private let copy = FormaProductCopy.PublicEntry.Welcome.self

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(colorScheme: colorScheme)
    }

    private var isCompactHeight: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        ScrollView {
            VStack(spacing: contentSpacing) {
                brandMark
                titleBlock
                benefitChips
                primaryCTA
                secondarySignIn
            }
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .padding(.top, topPadding)
            .padding(.bottom, FormaTokens.Spacing.lg)
            .frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .background(PublicWelcomeBackground(palette: palette))
        .onAppear(perform: logWelcomeViewedIfNeeded)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Sections

    private var brandMark: some View {
        PublicWelcomeBrandMark(palette: palette)
            .frame(maxWidth: .infinity)
            .padding(.bottom, isCompactHeight ? 0 : FormaTokens.Spacing.xs)
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            Text(copy.title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.84)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)

            Text(copy.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.88)

            Text(copy.supportingCopy)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.headline) \(copy.supportingCopy)")
    }

    private var benefitChips: some View {
        VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
            ForEach(copy.benefits, id: \.title) { benefit in
                PublicWelcomeBenefitChip(
                    icon: benefit.icon,
                    title: benefit.title,
                    palette: palette
                )
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.sm + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                .fill(palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: FormaTokens.Radius.card, style: .continuous)
                        .stroke(palette.surfaceBorder, lineWidth: 1)
                }
                .shadow(
                    color: colorScheme == .dark ? .clear : Color.black.opacity(0.04),
                    radius: 12,
                    y: 4
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(copy.benefitsAccessibilityLabel)
    }

    private var primaryCTA: some View {
        Button(action: handleCreateMyPlanTapped) {
            Text(copy.createMyPlanCTA)
                .font(FormaTokens.Typography.body.weight(.semibold))
                .foregroundStyle(palette.accentForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                .fill(palette.accent)
        }
        .accessibilityLabel(copy.createMyPlanCTA)
        .accessibilityHint(copy.createPlanAccessibilityHint)
    }

    private var secondarySignIn: some View {
        VStack(spacing: FormaTokens.Spacing.xs) {
            Text(copy.existingAccountPrompt)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)

            Button(action: handleSignInTapped) {
                Text(copy.signInCTA)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
            .buttonStyle(.plain)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            .accessibilityLabel(copy.signInAccessibilityLabel)
            .accessibilityHint(copy.signInAccessibilityHint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, FormaTokens.Spacing.xs)
    }

    // MARK: - Layout

    private var contentSpacing: CGFloat {
        isCompactHeight ? FormaTokens.Spacing.md : FormaTokens.Spacing.lg
    }

    private var topPadding: CGFloat {
        isCompactHeight ? FormaTokens.Spacing.md : FormaTokens.Spacing.xl
    }

    // MARK: - Analytics

    private func logWelcomeViewedIfNeeded() {
        guard !didLogView else { return }
        didLogView = true
        analyticsLogger.log(.welcomeViewed, properties: PublicEntryAnalyticsProperties())
    }

    private func handleCreateMyPlanTapped() {
        analyticsLogger.log(.welcomeCreatePlanTapped, properties: PublicEntryAnalyticsProperties())
        onCreateMyPlan()
    }

    private func handleSignInTapped() {
        analyticsLogger.log(.welcomeSignInTapped, properties: PublicEntryAnalyticsProperties())
        onSignIn()
    }
}

// MARK: - Chrome

private struct PublicWelcomeBackground: View {
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        ZStack {
            palette.canvas

            RadialGradient(
                colors: [
                    palette.canvasGlow,
                    palette.canvasGlow.opacity(0.35),
                    .clear
                ],
                center: .top,
                startRadius: 8,
                endRadius: 420
            )

            LinearGradient(
                colors: [
                    palette.accentSoft.opacity(0.55),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
        }
        .ignoresSafeArea()
    }
}

private struct PublicWelcomeBrandMark: View {
    let palette: PublicWelcomeTheme.Palette

    @ScaledMetric(relativeTo: .largeTitle) private var markDiameter: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .fill(palette.accentSoft)
                .frame(width: markDiameter * 1.22, height: markDiameter * 1.22)

            Image("FormaAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: markDiameter, height: markDiameter)
                .clipShape(RoundedRectangle(cornerRadius: markDiameter * 0.22, style: .continuous))
                .shadow(color: palette.accent.opacity(0.18), radius: 14, y: 4)
        }
    }
}

private struct PublicWelcomeBenefitChip: View {
    let icon: String
    let title: String
    let palette: PublicWelcomeTheme.Palette

    var body: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(palette.chipIconBackground)
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
            .accessibilityHidden(true)

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, FormaTokens.Spacing.xs)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Capsule(style: .continuous)
                .fill(palette.chipBackground)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(palette.surfaceBorder.opacity(0.85), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

// MARK: - Previews

#Preview("Light — Default") {
    PublicWelcomeView(
        analyticsLogger: NoOpPublicEntryAnalyticsLogger(),
        onCreateMyPlan: {},
        onSignIn: {}
    )
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    PublicWelcomeView(
        analyticsLogger: NoOpPublicEntryAnalyticsLogger(),
        onCreateMyPlan: {},
        onSignIn: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("iPhone SE") {
    PublicWelcomeView(
        analyticsLogger: NoOpPublicEntryAnalyticsLogger(),
        onCreateMyPlan: {},
        onSignIn: {}
    )
    .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
    .preferredColorScheme(.light)
}

#Preview("Large Dynamic Type") {
    PublicWelcomeView(
        analyticsLogger: NoOpPublicEntryAnalyticsLogger(),
        onCreateMyPlan: {},
        onSignIn: {}
    )
    .dynamicTypeSize(.accessibility3)
    .preferredColorScheme(.light)
}
