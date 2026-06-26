//
//  ProfileSettingsSheet.swift
//  Fitness Coach
//
//  FitPilot AI — App preferences separated from the fitness plan.
//

import SwiftUI

struct ProfileSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var formState: ProfileFormState
    let errorMessage: String?
    let onSave: (ProfileFormState) async -> Void
    let onCancel: () -> Void

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        Text("Account")
                    }
                }

                Section("Notifications") {
                    settingsPlaceholderRow("Daily reminders", detail: "Coming soon")
                    settingsPlaceholderRow("Coach check-ins", detail: "Coming soon")
                }

                UnitSettingsView(unitSystem: $formState.unitSystem)

                Section("HealthKit") {
                    settingsPlaceholderRow("Sync workouts", detail: "Coming soon")
                    settingsPlaceholderRow("Sync weight", detail: "Coming soon")
                }

                Section("Privacy") {
                    settingsPlaceholderRow("Data export", detail: "Coming soon")
                    settingsPlaceholderRow("Delete data", detail: "Coming soon")
                }

                Section("AI preferences") {
                    settingsPlaceholderRow("Coach tone", detail: "Coming soon")
                    settingsPlaceholderRow("Adaptive adjustments", detail: "Coming soon")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            SwiftUI.ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func settingsPlaceholderRow(_ title: String, detail: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onSave(formState)
            isSaving = false
        }
    }
}

#Preview {
    ProfileSettingsSheet(
        formState: .constant(ProfilePreviewData.formState),
        errorMessage: nil,
        onSave: { _ in },
        onCancel: {}
    )
    .environmentObject(AuthManager())
}
