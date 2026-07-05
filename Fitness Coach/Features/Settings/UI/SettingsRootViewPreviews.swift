//
//  SettingsRootViewPreviews.swift
//  Fitness Coach
//
//  Forma — Settings hub previews for production and debug states.
//

import SwiftUI

#if DEBUG
enum SettingsRootViewPreviews {

    static func host(
        integrationState: TrainingIntegrationState = .connected,
        isDebugOrInternalBuild: Bool = false,
        palette: AppThemePalette = .oceanBlue,
        unitSystem: UnitSystem = .metric,
        accountDeletionCoordinator: AccountDeletionCoordinator? = nil
    ) -> some View {
        let formState = configuredFormState(unitSystem: unitSystem)
        let themeDefaults = UserDefaults(suiteName: "SettingsRootPreview.\(palette.rawValue)")!
        let themeStore = ThemeStore(userDefaults: themeDefaults)
        themeStore.setPalette(palette)
        let resolvedCoordinator =
            accountDeletionCoordinator ?? previewAccountDeletionCoordinator()

        return SettingsRootView(
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
        .environment(\.accountDeletionCoordinator, resolvedCoordinator)
        .formaThemePreview(appearance: .dark, palette: palette)
    }

    static func previewAccountDeletionCoordinator() -> AccountDeletionCoordinator {
        try! AppContainer(inMemory: true).accountDeletionCoordinator
    }

    private static func configuredFormState(unitSystem: UnitSystem) -> PlanFormState {
        var formState = PlanPreviewData.formState
        formState.unitSystem = unitSystem
        return formState
    }
}

#Preview("Settings — Missing Deletion Coordinator") {
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
    .environmentObject(ThemeStore(userDefaults: UserDefaults(suiteName: "SettingsRootPreview.missing-coordinator")!))
    .formaThemePreview(appearance: .dark, palette: .oceanBlue)
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
