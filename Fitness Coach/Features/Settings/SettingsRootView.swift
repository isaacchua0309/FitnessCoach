//
//  SettingsRootView.swift
//  Fitness Coach
//
//  Forma — Consumer settings hub (grouped list, modal Done).
//

import SwiftUI

struct SettingsRootView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var insightsStore: TrainingInsightsStore

    @Binding var formState: PlanFormState
    let errorMessage: String?
    let onSaveUnits: (PlanFormState) async -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                integrationsSection

                #if DEBUG
                developerSection
                #endif

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.warning)
                            .formaSettingsRowChrome()
                    }
                }
            }
            .formaGroupedList()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(FormaTokens.Color.accent)
                }
            }
            .formaScrollBottomInset()
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section {
            NavigationLink {
                AccountSettingsView()
            } label: {
                settingsRowLabel("Account")
            }
            .formaSettingsRowChrome()
        } header: {
            FormaSettingsSectionHeader(title: "Account")
        }
    }

    private var preferencesSection: some View {
        Section {
            NavigationLink {
                UnitsSettingsScreen(
                    formState: $formState,
                    onSave: onSaveUnits
                )
            } label: {
                settingsRowLabel("Units")
            }
            .formaSettingsRowChrome()

            NavigationLink {
                PlanBodyDetailsSettingsView(formState: formState)
            } label: {
                settingsRowLabel(FormaProductCopy.PlanCalculation.bodyDetailsSettingsTitle)
            }
            .formaSettingsRowChrome()

            NavigationLink {
                ThemeSettingsView()
            } label: {
                settingsRowLabel(SettingsPreferencesCatalog.themeRowTitle)
            }
            .formaSettingsRowChrome()
        } header: {
            FormaSettingsSectionHeader(title: SettingsPreferencesCatalog.sectionTitle)
        }
    }

    private var integrationsSection: some View {
        Section {
            NavigationLink {
                AppleHealthIntegrationView(insightsStore: insightsStore)
            } label: {
                HStack(spacing: FormaTokens.Spacing.sm) {
                    Text("Apple Health")
                        .font(FormaTokens.Typography.body)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                    Spacer(minLength: FormaTokens.Spacing.xs)
                    Text(
                        TrainingIntegrationCopy.settingsStatusLabel(
                            for: insightsStore.integrationState
                        )
                    )
                    .font(FormaTokens.Typography.sectionSubtitle)
                    .foregroundStyle(FormaTokens.Color.textTertiary)
                }
                .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
            }
            .formaSettingsRowChrome()
        } header: {
            FormaSettingsSectionHeader(title: "Integrations")
        }
        .task {
            await insightsStore.refresh()
        }
    }

    #if DEBUG
    private var developerSection: some View {
        Section {
            NavigationLink {
                AuthDiagnosticsView()
            } label: {
                settingsRowLabel("Auth diagnostics")
            }
            .formaSettingsRowChrome()

            NavigationLink {
                PipelineDiagnosticsView()
            } label: {
                settingsRowLabel("Pipeline traces")
            }
            .formaSettingsRowChrome()
        } header: {
            FormaSettingsSectionHeader(title: "Developer")
        } footer: {
            Text("Debug builds only. Pipeline traces help troubleshoot Coach AI routing and backend calls.")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
    }
    #endif

    // MARK: - Row chrome

    private func settingsRowLabel(_ title: String) -> some View {
        Text(title)
            .font(FormaTokens.Typography.body)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
    }
}

#Preview {
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
    .environmentObject(ThemeStore(userDefaults: UserDefaults(suiteName: "SettingsRootPreview")!))
    .formaThemePreview()
}
