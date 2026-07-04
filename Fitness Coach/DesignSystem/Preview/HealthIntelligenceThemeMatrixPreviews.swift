//
//  HealthIntelligenceThemeMatrixPreviews.swift
//  Fitness Coach
//
//  Forma — Palette and accessibility matrix for Phase 11–15 Health Intelligence UI.
//

import SwiftUI

#if DEBUG
enum HealthIntelligenceThemeMatrixPreviews {

    static func todaySection(
        palette: AppThemePalette,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            TodayHealthIntelligenceSection(
                state: TodayHealthIntelligencePreviewData.workoutDay,
                onNextBestAction: { _ in }
            )
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func journeySection(
        palette: AppThemePalette,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            JourneyHealthIntelligenceSection(
                state: JourneyHealthIntelligencePreviewData.strongWeek,
                onWeeklyReviewSelected: { _ in }
            )
            .padding(.horizontal, JourneyLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func planSection(
        palette: AppThemePalette,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            PlanHealthIntelligenceSection(
                state: PlanHealthIntelligencePresentationPreviewData.strongFit
            )
            .padding(.horizontal, PlanLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }
}

#Preview("HI Today — Emerald Green Dark") {
    HealthIntelligenceThemeMatrixPreviews.todaySection(palette: .emeraldGreen, appearance: .dark)
}

#Preview("HI Today — Sunset Orange Light") {
    HealthIntelligenceThemeMatrixPreviews.todaySection(palette: .sunsetOrange, appearance: .light)
}

#Preview("HI Journey — Blossom Pink Dark") {
    HealthIntelligenceThemeMatrixPreviews.journeySection(palette: .blossomPink, appearance: .dark)
}

#Preview("HI Plan — Ocean Blue Light") {
    HealthIntelligenceThemeMatrixPreviews.planSection(palette: .oceanBlue, appearance: .light)
}

#Preview("HI Today — Accessibility Large Text") {
    HealthIntelligenceThemeMatrixPreviews.todaySection(palette: .oceanBlue, appearance: .dark)
        .dynamicTypeSize(.accessibility2)
}

#Preview("HI Journey — Accessibility Large Text") {
    HealthIntelligenceThemeMatrixPreviews.journeySection(palette: .oceanBlue, appearance: .dark)
        .dynamicTypeSize(.accessibility2)
}

#Preview("HI Plan — Accessibility Large Text") {
    HealthIntelligenceThemeMatrixPreviews.planSection(palette: .oceanBlue, appearance: .dark)
        .dynamicTypeSize(.accessibility2)
}
#endif
