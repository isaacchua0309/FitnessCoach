//
//  OnboardingTheme.swift
//  Fitness Coach
//
//  FitPilot AI — Shared visual language for first-run onboarding.
//

import SwiftUI

enum OnboardingTheme {
    static let background = Color(red: 0.03, green: 0.05, blue: 0.08)
    static let card = Color.white.opacity(0.07)
    static let cardElevated = Color.white.opacity(0.1)
    static let border = Color.white.opacity(0.12)
    static let selectedBorder = Color.blue.opacity(0.72)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.68)
    static let tertiaryText = Color.white.opacity(0.48)
    /// Footer and legal copy — slightly higher contrast than `tertiaryText` for readability.
    static let legalText = Color.white.opacity(0.62)
    static let accent = Color.blue
    static let warning = Color.orange
    static let cornerRadius: CGFloat = 18
    static let compactCornerRadius: CGFloat = 14
    static let pagePadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 18
    static let fieldSpacing: CGFloat = 12

    static func cardBackground(selected: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(selected ? accent.opacity(0.16) : card)
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
                .font(.headline)
                .foregroundStyle(OnboardingTheme.primaryText)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func onboardingCard(selected: Bool = false) -> some View {
        padding(16)
            .background(OnboardingTheme.cardBackground(selected: selected))
    }
}
