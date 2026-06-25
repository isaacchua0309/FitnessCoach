//
//  OnboardingWarningBanner.swift
//  Fitness Coach
//
//  FitPilot AI — Inline validation or plan warning banner.
//

import SwiftUI

struct OnboardingWarningBanner: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .foregroundStyle(OnboardingTheme.warning)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .fill(OnboardingTheme.warning.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                .stroke(OnboardingTheme.warning.opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
