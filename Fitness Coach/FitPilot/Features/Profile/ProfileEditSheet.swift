//
//  ProfileEditSheet.swift
//  Fitness Coach
//
//  FitPilot AI — Edit profile and settings form sheet.
//

import SwiftUI

struct ProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var formState: ProfileFormState
    let errorMessage: String?
    let onSave: (ProfileFormState) async -> Void
    let onCancel: () -> Void
    let onRegenerate: (ProfileFormState) async -> Void

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Details") {
                    TextField("Name", text: $formState.name)
                        .textInputAutocapitalization(.words)
                    TextField("Age", text: $formState.ageText)
                        .keyboardType(.numberPad)
                    Picker("Sex", selection: $formState.sex) {
                        ForEach(Sex.allCases, id: \.self) { sex in
                            Text(ProfileFormatter.sex(sex)).tag(sex)
                        }
                    }
                    TextField("Height (cm)", text: $formState.heightCmText)
                        .keyboardType(.decimalPad)
                    TextField("Body fat % (optional)", text: $formState.estimatedBodyFatPercentageText)
                        .keyboardType(.decimalPad)
                }

                GoalSettingsView(
                    currentWeightKgText: $formState.currentWeightKgText,
                    goalWeightKgText: $formState.goalWeightKgText,
                    aggressiveness: $formState.aggressiveness
                )

                ActivitySettingsView(
                    activityLevel: $formState.activityLevel,
                    trainingFrequencyPerWeekText: $formState.trainingFrequencyPerWeekText,
                    averageStepsText: $formState.averageStepsText
                )

                MacroTargetSettingsView(
                    calorieTargetText: $formState.calorieTargetText,
                    proteinTargetText: $formState.proteinTargetText,
                    carbTargetText: $formState.carbTargetText,
                    fatTargetText: $formState.fatTargetText,
                    expectedWeeklyWeightLossKgText: $formState.expectedWeeklyWeightLossKgText,
                    aggressiveness: $formState.aggressiveness,
                    onRegenerate: {
                        Task {
                            await onRegenerate(formState)
                        }
                    }
                )

                WaterTargetSettingsView(waterTargetMlText: $formState.waterTargetMlText)

                FoodPreferencesView(dietPreference: $formState.dietPreference)

                UnitSettingsView(unitSystem: $formState.unitSystem)

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Profile")
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
    ProfileEditSheet(
        formState: .constant(ProfilePreviewData.formState),
        errorMessage: nil,
        onSave: { _ in },
        onCancel: {},
        onRegenerate: { _ in }
    )
}
