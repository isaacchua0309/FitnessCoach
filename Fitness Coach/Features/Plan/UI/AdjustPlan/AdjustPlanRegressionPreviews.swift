//
//  AdjustPlanRegressionPreviews.swift
//  Fitness Coach
//
//  Forma — Xcode previews for Adjust Plan UI regression scenarios.
//

import SwiftUI

#if DEBUG

#Preview("Adjust Plan — Small iPhone") {
    adjustPlanRegressionPreview(.smallPhoneWidth)
}

#Preview("Adjust Plan — Selected Lose Fat") {
    adjustPlanRegressionPreview(.selectedLoseFat)
}

#Preview("Adjust Plan — Selected Maintain") {
    adjustPlanRegressionPreview(.selectedMaintain)
}

#Preview("Adjust Plan — Selected Build Muscle") {
    adjustPlanRegressionPreview(.selectedBuildMuscle)
}

#Preview("Adjust Plan — Large Dynamic Type") {
    adjustPlanRegressionPreview(.largeDynamicType)
}

#Preview("Adjust Plan — Theme Ocean Blue") {
    adjustPlanRegressionPreview(.themeOceanBlue)
}

#Preview("Adjust Plan — Theme Blossom Pink") {
    adjustPlanRegressionPreview(.themeBlossomPink)
}

#Preview("Adjust Plan — Long Localized Text") {
    adjustPlanRegressionPreview(.longLocalizedText)
}

@MainActor
private func adjustPlanRegressionPreview(_ scenario: AdjustPlanRegressionScenario) -> some View {
    NavigationStack {
        AdjustPlanGoalStepRegressionHost(scenario: scenario)
    }
    .frame(
        width: scenario.contentWidth,
        height: scenario.contentHeight
    )
    .formaThemePreview(appearance: scenario.appearance, palette: scenario.palette)
}

#endif
