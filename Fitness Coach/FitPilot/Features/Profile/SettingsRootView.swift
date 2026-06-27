//
//  SettingsRootView.swift
//  Fitness Coach
//
//  FitPilot — Consumer settings hub (grouped list, modal Done).
//

import SwiftUI

struct SettingsRootView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var insightsStore: TrainingInsightsStore

    @Binding var formState: ProfileFormState
    let errorMessage: String?
    let onSaveUnits: (ProfileFormState) async -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                accountSection
                preferencesSection
                notificationsSection
                integrationsSection
                privacySection

                #if DEBUG
                developerSection
                #endif

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(FormaTokens.Typography.sectionSubtitle)
                            .foregroundStyle(FormaTokens.Color.warning)
                            .fitPilotSettingsRowChrome()
                    }
                }
            }
            .fitPilotDarkGroupedList()
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
            .fitPilotScrollBottomInset()
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
            .fitPilotSettingsRowChrome()
        } header: {
            FitPilotSettingsSectionHeader(title: "Account")
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
            .fitPilotSettingsRowChrome()

            FitPilotComingSoonRow(title: "AI preferences")
                .fitPilotSettingsRowChrome(isEnabled: false)
        } header: {
            FitPilotSettingsSectionHeader(title: "Preferences")
        }
    }

    private var notificationsSection: some View {
        Section {
            FitPilotComingSoonRow(title: "Daily reminders")
                .fitPilotSettingsRowChrome(isEnabled: false)
            FitPilotComingSoonRow(title: "Coach check-ins")
                .fitPilotSettingsRowChrome(isEnabled: false)
        } header: {
            FitPilotSettingsSectionHeader(title: "Notifications")
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
                .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
            }
            .fitPilotSettingsRowChrome()
        } header: {
            FitPilotSettingsSectionHeader(title: "Integrations")
        } footer: {
            Text(TrainingIntegrationCopy.healthIntegrationFooter)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary)
        }
        .task {
            await insightsStore.refresh()
        }
    }

    private var privacySection: some View {
        Section {
            FitPilotComingSoonRow(title: "Data export")
                .fitPilotSettingsRowChrome(isEnabled: false)
            FitPilotComingSoonRow(title: "Delete data")
                .fitPilotSettingsRowChrome(isEnabled: false)
        } header: {
            FitPilotSettingsSectionHeader(title: "Privacy")
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
            .fitPilotSettingsRowChrome()

            NavigationLink {
                PipelineDiagnosticsView()
            } label: {
                settingsRowLabel("Pipeline traces")
            }
            .fitPilotSettingsRowChrome()
        } header: {
            FitPilotSettingsSectionHeader(title: "Developer")
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
            .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .leading)
    }
}

#Preview {
    SettingsRootView(
        formState: .constant(ProfilePreviewData.formState),
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
}
