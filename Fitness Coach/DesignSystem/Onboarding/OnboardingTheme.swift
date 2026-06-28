//
//  OnboardingTheme.swift
//  Fitness Coach
//
//  FitPilot AI — Shared visual language for first-run onboarding.
//

import SwiftUI

/// Onboarding semantic colors resolved from the active Forma theme.
///
/// Values read through `FormaTokens.Color` on each access so palette and appearance
/// changes from `ThemeStore` propagate without restarting onboarding.
enum OnboardingTheme {
    @MainActor
    private static var colors: FormaThemeColors { FormaThemeAccess.currentColors }

    @MainActor
    static var background: Color { colors.canvas }
    @MainActor
    static var card: Color { colors.surface }
    @MainActor
    static var cardElevated: Color { colors.surfaceElevated }
    @MainActor
    static var surfaceSubtle: Color { colors.surfaceSubtle }
    @MainActor
    static var border: Color { colors.border }
    @MainActor
    static var selectedBorder: Color { colors.borderSelected }
    @MainActor
    static var primaryText: Color { colors.textPrimary }
    @MainActor
    static var secondaryText: Color { colors.textSecondary }
    @MainActor
    static var tertiaryText: Color { colors.textTertiary }
    @MainActor
    static var legalText: Color { colors.textLegal }
    @MainActor
    static var accent: Color { colors.accent }
    @MainActor
    static var accentMuted: Color { colors.accentMuted }
    @MainActor
    static var ctaBackground: Color { colors.ctaBackground }
    @MainActor
    static var ctaText: Color { colors.ctaText }
    @MainActor
    static var progress: Color { colors.progress }
    @MainActor
    static var progressTrack: Color { colors.progressTrack }
    @MainActor
    static var chartPrimary: Color { colors.chartPrimary }
    @MainActor
    static var chartSecondary: Color { colors.chartSecondary }
    @MainActor
    static var warning: Color { colors.warning }
    @MainActor
    static var success: Color { colors.success }
    @MainActor
    static var destructive: Color { colors.destructive }

    static let cornerRadius = FormaTokens.Radius.card
    static let compactCornerRadius = FormaTokens.Radius.compact
    static let pagePadding = FormaTokens.Spacing.pageHorizontal
    static let sectionSpacing = FormaTokens.Spacing.sectionSpacing
    static let fieldSpacing = FormaTokens.Spacing.sm

    @MainActor
    static func cardBackground(selected: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(selected ? accentMuted : card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(selected ? selectedBorder : border, lineWidth: selected ? 1.4 : 1)
            )
    }
}

enum OnboardingLayout {
    static let compactSectionSpacing: CGFloat = 12
    static let compactFieldSpacing: CGFloat = 8
    static let compactCardPadding: CGFloat = 12
    static let compactFieldVerticalPadding: CGFloat = 10
    static let compactFieldHorizontalPadding: CGFloat = 12
    static let compactLabelGap: CGFloat = 6
    static let scrollBottomPadding: CGFloat = 16
    /// Legacy fallback when footer height is not measured yet.
    static let scrollBottomPaddingWithFooter: CGFloat = 88
    static let progressHeaderTop: CGFloat = 8
    static let progressBarSpacing: CGFloat = 10
    static let progressTitleSpacing: CGFloat = 6
    static let progressSegmentHeight: CGFloat = 4
    static let selectionRowMinHeight: CGFloat = 48
    static let footerVerticalPadding: CGFloat = 6
    static let footerInnerSpacing: CGFloat = 6
    static let measurementWheelHeight: CGFloat = 220
    /// Tall enough for readable wheel rows on the birthday fixed-viewport step.
    static let birthdayWheelHeight: CGFloat = 200
    static let birthdaySectionSpacing: CGFloat = 16
    static let birthdayWheelVerticalPadding: CGFloat = 12
    static let heroRulerHeight: CGFloat = 156
    static let heroRulerTickSpacing: CGFloat = 16
}

struct OnboardingSectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FormaTokens.Typography.sectionTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func onboardingCard(selected: Bool = false) -> some View {
        padding(FormaTokens.Spacing.cardPadding)
            .background(OnboardingTheme.cardBackground(selected: selected))
    }

    func onboardingCompactCard(selected: Bool = false) -> some View {
        padding(OnboardingLayout.compactCardPadding)
            .background(OnboardingTheme.cardBackground(selected: selected))
    }
}
