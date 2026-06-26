//
//  SettingsRootView.swift
//  Fitness Coach
//
//  FitPilot — Consumer settings hub (grouped list, modal Done).
//

import SwiftUI

struct SettingsRootView: View {

    @Environment(\.dismiss) private var dismiss

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
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.warning)
                            .listRowBackground(OnboardingTheme.card)
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
            .listRowInsets(settingsRowInsets)
            .listRowBackground(OnboardingTheme.card)
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
            .listRowInsets(settingsRowInsets)
            .listRowBackground(OnboardingTheme.card)

            FitPilotComingSoonRow(title: "AI preferences")
                .listRowInsets(settingsRowInsets)
                .listRowBackground(OnboardingTheme.card.opacity(0.65))
        } header: {
            FitPilotSettingsSectionHeader(title: "Preferences")
        }
    }

    private var notificationsSection: some View {
        Section {
            FitPilotComingSoonRow(title: "Daily reminders")
                .listRowInsets(settingsRowInsets)
                .listRowBackground(OnboardingTheme.card.opacity(0.65))
            FitPilotComingSoonRow(title: "Coach check-ins")
                .listRowInsets(settingsRowInsets)
                .listRowBackground(OnboardingTheme.card.opacity(0.65))
        } header: {
            FitPilotSettingsSectionHeader(title: "Notifications")
        }
    }

    private var integrationsSection: some View {
        Section {
            FitPilotComingSoonRow(title: "HealthKit")
                .listRowInsets(settingsRowInsets)
                .listRowBackground(OnboardingTheme.card.opacity(0.65))
        } header: {
            FitPilotSettingsSectionHeader(title: "Integrations")
        }
    }

    private var privacySection: some View {
        Section {
            FitPilotComingSoonRow(title: "Data export")
                .listRowInsets(settingsRowInsets)
                .listRowBackground(OnboardingTheme.card.opacity(0.65))
            FitPilotComingSoonRow(title: "Delete data")
                .listRowInsets(settingsRowInsets)
                .listRowBackground(OnboardingTheme.card.opacity(0.65))
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
            .listRowInsets(settingsRowInsets)
            .listRowBackground(OnboardingTheme.card)
        } header: {
            FitPilotSettingsSectionHeader(title: "Developer")
        } footer: {
            Text("Debug builds only.")
                .foregroundStyle(OnboardingTheme.tertiaryText)
        }
    }
    #endif

    // MARK: - Row chrome

    private var settingsRowInsets: EdgeInsets {
        EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    }

    private func settingsRowLabel(_ title: String) -> some View {
        Text(title)
            .font(.body)
            .foregroundStyle(OnboardingTheme.primaryText)
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
}
