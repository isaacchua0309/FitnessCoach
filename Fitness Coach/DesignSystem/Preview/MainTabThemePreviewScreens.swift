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
        palette: AppThemePalette = .default,
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
        palette: AppThemePalette = .default,
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
        palette: AppThemePalette = .default,
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
        palette: AppThemePalette = .default,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
            .environmentObject(AppRefreshCenter())
            .environmentObject(AuthManager())
            .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func settings(
        palette: AppThemePalette = .default,
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

#Preview("Today — Default") {
    MainTabThemePreviewScreens.today()
}

#Preview("Today — Pink") {
    MainTabThemePreviewScreens.today(palette: .pink)
}

#Preview("Today — Cool Blue") {
    MainTabThemePreviewScreens.today(palette: .coolBlue)
}

#Preview("Plan — Default") {
    MainTabThemePreviewScreens.plan()
}

#Preview("Plan — Pink") {
    MainTabThemePreviewScreens.plan(palette: .pink)
}

#Preview("Plan — Cool Blue") {
    MainTabThemePreviewScreens.plan(palette: .coolBlue)
}

#Preview("Journey — Default") {
    MainTabThemePreviewScreens.journey()
}

#Preview("Journey — Pink") {
    MainTabThemePreviewScreens.journey(palette: .pink)
}

#Preview("Journey — Cool Blue") {
    MainTabThemePreviewScreens.journey(palette: .coolBlue)
}

#Preview("Coach — Default") {
    MainTabThemePreviewScreens.coach()
}

#Preview("Coach — Pink") {
    MainTabThemePreviewScreens.coach(palette: .pink)
}

#Preview("Coach — Cool Blue") {
    MainTabThemePreviewScreens.coach(palette: .coolBlue)
}

#Preview("Settings — Default") {
    MainTabThemePreviewScreens.settings()
}

#Preview("Settings — Pink") {
    MainTabThemePreviewScreens.settings(palette: .pink)
}

#Preview("Settings — Cool Blue") {
    MainTabThemePreviewScreens.settings(palette: .coolBlue)
}
#endif
