//
//  MainTabThemePreviewScreens.swift
//  Fitness Coach
//
//  Forma — Palette previews for main app tabs and settings.
//

import SwiftUI

#if DEBUG
enum MainTabThemePreviewScreens {

    @ViewBuilder
    static func today(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        let container = try! AppContainer(inMemory: true)
        ScrollView {
            TodayReadOnlyView(
                state: TodayPreviewData.state,
                actionCoordinator: container.makeTodayActionCoordinator(),
                onOpenCoach: { _ in },
                onOpenJourney: {},
                onOpenPlan: {}
            )
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func plan(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PlanLayout.sectionSpacing) {
                PlanMissionControlHeroSection(
                    state: PlanPreviewData.state.missionControl.mission
                )
                PlanTodayMissionSection(
                    state: PlanPreviewData.state.missionControl.todayMission,
                    onGoToToday: {}
                )
                PlanThisWeekSection(state: PlanPreviewData.state.missionControl.week)
                PlanConfidenceSection(state: PlanPreviewData.state.missionControl.confidence)
            }
            .padding(.horizontal, PlanLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.lg)
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func journey(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            JourneyDashboardContent(state: JourneyPreviewData.dashboard(.strongMomentum))
        }
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func coach(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
            .environmentObject(AppRefreshCenter())
            .environmentObject(AuthManager())
            .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func settings(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        SettingsRootView(
            formState: .constant(PlanPreviewData.formState),
            errorMessage: nil,
            onSaveUnits: { _ in },
            onDismiss: {}
        )
        .environmentObject(AuthManager())
        .environmentObject(
            TrainingInsightsStore(
                integration: StubTrainingIntegrationProvider(refreshResult: .connected)
            )
        )
        .environmentObject(ThemeStore(userDefaults: UserDefaults(suiteName: "MainTabSettingsPreview.\(palette.rawValue)")!))
        .formaThemePreview(appearance: appearance, palette: palette)
    }
}

#Preview("Today — Ocean Blue") {
    MainTabThemePreviewScreens.today()
}

#Preview("Today — Blossom Pink") {
    MainTabThemePreviewScreens.today(palette: .blossomPink)
}

#Preview("Today — Emerald Green") {
    MainTabThemePreviewScreens.today(palette: .emeraldGreen)
}

#Preview("Today — Sunset Orange") {
    MainTabThemePreviewScreens.today(palette: .sunsetOrange)
}

#Preview("Plan — Ocean Blue") {
    MainTabThemePreviewScreens.plan()
}

#Preview("Plan — Blossom Pink") {
    MainTabThemePreviewScreens.plan(palette: .blossomPink)
}

#Preview("Plan — Emerald Green") {
    MainTabThemePreviewScreens.plan(palette: .emeraldGreen)
}

#Preview("Plan — Sunset Orange") {
    MainTabThemePreviewScreens.plan(palette: .sunsetOrange)
}

#Preview("Journey — Ocean Blue") {
    MainTabThemePreviewScreens.journey()
}

#Preview("Journey — Blossom Pink") {
    MainTabThemePreviewScreens.journey(palette: .blossomPink)
}

#Preview("Journey — Emerald Green") {
    MainTabThemePreviewScreens.journey(palette: .emeraldGreen)
}

#Preview("Journey — Sunset Orange") {
    MainTabThemePreviewScreens.journey(palette: .sunsetOrange)
}

#Preview("Coach — Ocean Blue") {
    MainTabThemePreviewScreens.coach()
}

#Preview("Coach — Blossom Pink") {
    MainTabThemePreviewScreens.coach(palette: .blossomPink)
}

#Preview("Coach — Emerald Green") {
    MainTabThemePreviewScreens.coach(palette: .emeraldGreen)
}

#Preview("Coach — Sunset Orange") {
    MainTabThemePreviewScreens.coach(palette: .sunsetOrange)
}

#Preview("Settings — Ocean Blue") {
    MainTabThemePreviewScreens.settings()
}

#Preview("Settings — Blossom Pink") {
    MainTabThemePreviewScreens.settings(palette: .blossomPink)
}

#Preview("Settings — Emerald Green") {
    MainTabThemePreviewScreens.settings(palette: .emeraldGreen)
}

#Preview("Settings — Sunset Orange") {
    MainTabThemePreviewScreens.settings(palette: .sunsetOrange)
}
#endif
