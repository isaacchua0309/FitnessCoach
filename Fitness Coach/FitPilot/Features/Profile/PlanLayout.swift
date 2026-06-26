//
//  PlanLayout.swift
//  Fitness Coach
//
//  FitPilot AI — Shared spacing for the Plan strategy screen.
//

import SwiftUI

enum PlanLayout {
    static let sectionSpacing = FitPilotScreenStyle.sectionSpacing
    static let itemSpacing: CGFloat = 10
    static let horizontalPadding = FitPilotScreenStyle.horizontalPadding
}

struct PlanSectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}
