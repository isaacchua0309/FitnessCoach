//
//  MainTabThemePreviewScreens.swift
//  Fitness Coach
//
//  Forma — Palette previews for main app tabs and settings.
//

import SwiftUI

#if DEBUG
@MainActor
enum MainTabThemePreviewScreens {

    static func today(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        let container = try! AppContainer(inMemory: true)
        return ScrollView {
            TodayReadOnlyView(
                state: TodayPreviewData.state,
                actionCoordinator: container.makeTodayActionCoordinator(),
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
            PlanDashboardContent(state: PlanPreviewScreens.dashboard(.aggressiveCut))
                .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
                .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
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
                .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
                .padding(.bottom, FormaMainTabLayout.scrollContentBottomPadding)
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

    static func settings(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        let themeDefaults = UserDefaults(suiteName: "MainTabSettingsPreview.\(palette.rawValue)")!
        let themeStore = ThemeStore(userDefaults: themeDefaults)
        themeStore.setPalette(palette)

        return SettingsRootView(
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
        .environmentObject(themeStore)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func recoveryCard(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        TodayRecoveryCard(state: TodayHealthIntelligencePreviewData.workoutDay.recoveryCard)
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FormaTokens.Color.canvas)
            .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func nutritionCard(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        TodayNutritionProgressCard(
            macros: TodayPreviewData.state.macroHydration.macroSummary,
            water: TodayPreviewData.state.macroHydration.waterSummary,
            calorieSummary: TodayPreviewData.state.mission.calorieSummary
        )
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func nextActionCard(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        TodayNextBestActionCard(state: TodayHealthIntelligencePreviewData.workoutDay.nextBestAction)
            .padding(.horizontal, TodayLayout.horizontalPadding)
            .padding(.vertical, FormaTokens.Spacing.md)
            .background(FormaTokens.Color.canvas)
            .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func mainTabShell(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        let container = try! AppContainer(inMemory: true)
        return MainTabView(container: container)
            .environmentObject(container.authManager)
            .environmentObject(container.refreshCenter)
            .environmentObject(container.trainingInsightsStore)
            .environmentObject(container.trainingInsightsModel)
            .environmentObject(container.healthSyncStateStore)
            .environmentObject(container.healthSummarySyncConsentStore)
            .environmentObject(container.themeStore)
            .formaThemePreview(appearance: appearance, palette: palette)
    }

    static func coachComposer(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        LiveThemeComposerPreviewHost()
            .padding(.vertical, FormaTokens.Spacing.md)
            .background(FormaTokens.Color.canvas)
            .formaThemePreview(appearance: appearance, palette: palette)
    }
}

private struct LiveThemeComposerPreviewHost: View {
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        CoachComposer(
            text: $text,
            canPickAttachment: true,
            isFocused: $isFocused,
            isSending: false,
            onSend: {},
            onVoiceTap: {},
            onAttachmentSelect: { _ in },
            onRemoveAttachment: {},
            onRetryImageSelection: {}
        )
        .padding(.horizontal, FormaTokens.Spacing.md)
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

#Preview("Recovery card — Ocean Blue") {
    MainTabThemePreviewScreens.recoveryCard()
}

#Preview("Recovery card — Blossom Pink") {
    MainTabThemePreviewScreens.recoveryCard(palette: .blossomPink)
}

#Preview("Nutrition card — Ocean Blue") {
    MainTabThemePreviewScreens.nutritionCard()
}

#Preview("Nutrition card — Blossom Pink") {
    MainTabThemePreviewScreens.nutritionCard(palette: .blossomPink)
}

#Preview("Next action card — Ocean Blue") {
    MainTabThemePreviewScreens.nextActionCard()
}

#Preview("Next action card — Blossom Pink") {
    MainTabThemePreviewScreens.nextActionCard(palette: .blossomPink)
}

#Preview("Main tab bar — Ocean Blue") {
    MainTabThemePreviewScreens.mainTabShell()
}

#Preview("Main tab bar — Blossom Pink") {
    MainTabThemePreviewScreens.mainTabShell(palette: .blossomPink)
}

#Preview("Coach input — Ocean Blue") {
    MainTabThemePreviewScreens.coachComposer()
}

#Preview("Coach input — Blossom Pink") {
    MainTabThemePreviewScreens.coachComposer(palette: .blossomPink)
}
#endif
