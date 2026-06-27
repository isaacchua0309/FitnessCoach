//
//  OnboardingTheme.swift
//  Fitness Coach
//
//  FitPilot AI — Shared visual language for first-run onboarding.
//

import SwiftUI

enum OnboardingTheme {
    static let background = FormaTokens.Color.canvas
    static let card = FormaTokens.Color.surface
    static let cardElevated = FormaTokens.Color.surfaceElevated
    static let border = FormaTokens.Color.border
    static let selectedBorder = FormaTokens.Color.borderSelected
    static let primaryText = FormaTokens.Color.textPrimary
    static let secondaryText = FormaTokens.Color.textSecondary
    static let tertiaryText = FormaTokens.Color.textTertiary
    static let legalText = FormaTokens.Color.textLegal
    static let accent = FormaTokens.Color.accent
    static let warning = FormaTokens.Color.warning
    static let cornerRadius = FormaTokens.Radius.card
    static let compactCornerRadius = FormaTokens.Radius.compact
    static let pagePadding = FormaTokens.Spacing.pageHorizontal
    static let sectionSpacing = FormaTokens.Spacing.sectionSpacing
    static let fieldSpacing = FormaTokens.Spacing.sm

    static func cardBackground(selected: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(selected ? FormaTokens.Color.accentMuted : card)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(selected ? selectedBorder : border, lineWidth: selected ? 1.4 : 1)
            )
    }
}

struct OnboardingSectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(FormaTokens.Typography.sectionTitle)
                .foregroundStyle(OnboardingTheme.primaryText)
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
}
