//
//  SettingsRootViewPreviews.swift
//  Fitness Coach
//
//  Forma — Settings hub previews for production and debug states.
//

import SwiftUI

#if DEBUG
enum SettingsRootViewPreviews {

    @ViewBuilder
    static func host(
        integrationState: TrainingIntegrationState = .connected,
        isDebugOrInternalBuild: Bool = false,
        palette: AppThemePalette = .oceanBlue,
        unitSystem: UnitSystem = .metric
    ) -> some View {
        var formState = PlanPreviewData.formState
        formState.unitSystem = unitSystem

        let themeDefaults = UserDefaults(suiteName: "SettingsRootPreview.\(palette.rawValue)")!
        let themeStore = ThemeStore(userDefaults: themeDefaults)
        themeStore.setPalette(palette)

        SettingsRootView(
            formState: .constant(formState),
            errorMessage: nil,
            onSaveUnits: { _ in },
            onDismiss: {},
            isDebugOrInternalBuild: isDebugOrInternalBuild
        )
        .environmentObject(AuthManager())
        .environmentObject(
            TrainingInsightsStore(
                integration: StubTrainingIntegrationProvider(refreshResult: integrationState)
            )
        )
        .environmentObject(themeStore)
        .formaThemePreview(appearance: .dark, palette: palette)
    }
}

#Preview("Settings — Production User") {
    SettingsRootViewPreviews.host()
}

#Preview("Settings — Debug Build User") {
    SettingsRootViewPreviews.host(isDebugOrInternalBuild: true)
}

#Preview("Settings — Apple Health Connected") {
    SettingsRootViewPreviews.host(integrationState: .connected)
}

#Preview("Settings — Apple Health Disconnected") {
    SettingsRootViewPreviews.host(integrationState: .notConnected)
}
#endif
