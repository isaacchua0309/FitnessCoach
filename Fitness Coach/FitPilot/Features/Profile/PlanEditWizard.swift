//
//  PlanEditWizard.swift
//  Fitness Coach
//
//  FitPilot AI — Guided plan editing wizard.
//

import SwiftUI

struct PlanEditWizard: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var formState: ProfileFormState
    let errorMessage: String?
    let onSave: (ProfileFormState) async -> Void
    let onCancel: () -> Void
    let onRegenerate: (ProfileFormState) async -> Void

    @State private var step = 0
    @State private var goalType: PlanGoalType = .loseFat
    @State private var isSaving = false
    @State private var showAdvanced = false

    private let stepTitles = ["Goal", "Goal weight", "Training", "Lifestyle"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal)
                    .padding(.top, 8)

                Form {
                    switch step {
                    case 0:
                        goalStep
                    case 1:
                        goalWeightStep
                    case 2:
                        trainingStep
                    case 3:
                        lifestyleStep
                    default:
                        EmptyView()
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step < stepTitles.count - 1 {
                        Button("Next") { advance() }
                    } else {
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
            .onAppear {
                goalType = PlanStateBuilder.goalType(for: formState.asProfileSnapshot())
            }
        }
    }

    // MARK: Steps

    private var goalStep: some View {
        Section {
            Picker("Goal", selection: $goalType) {
                ForEach(PlanGoalType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.inline)
            .onChange(of: goalType) { _, newValue in
                applyGoalType(newValue)
            }

            Picker("Pace", selection: $formState.aggressiveness) {
                ForEach(CalorieAggressiveness.allCases, id: \.self) { level in
                    Text(ProfileFormatter.aggressiveness(level)).tag(level)
                }
            }
        } footer: {
            Text("Coach will compute calorie and macro targets from your goal and lifestyle.")
        }
    }

    private var goalWeightStep: some View {
        Section {
            TextField("Goal weight (kg)", text: $formState.goalWeightKgText)
                .keyboardType(.decimalPad)
        } header: {
            Text("Goal weight")
        } footer: {
            Text("Your baseline weight (\(formState.currentWeightKgText) kg) is used for calculations. Update it in Advanced Settings if needed.")
        }
    }

    private var trainingStep: some View {
        Section {
            TextField("Strength sessions per week", text: $formState.trainingFrequencyPerWeekText)
                .keyboardType(.numberPad)
        } header: {
            Text("Training frequency")
        } footer: {
            Text("How many structured strength workouts you plan each week.")
        }
    }

    private var lifestyleStep: some View {
        Group {
            Section {
                Picker("Activity level", selection: $formState.activityLevel) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Text(ProfileFormatter.activityLevel(level)).tag(level)
                    }
                }

                TextField("Average steps per day", text: $formState.averageStepsText)
                    .keyboardType(.numberPad)
            } header: {
                Text("Lifestyle")
            }

            FoodPreferencesView(dietPreference: $formState.dietPreference)

            Section {
                DisclosureGroup("Advanced Settings", isExpanded: $showAdvanced) {
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
                    TextField("Baseline weight (kg)", text: $formState.currentWeightKgText)
                        .keyboardType(.decimalPad)
                    TextField("Body fat % (optional)", text: $formState.estimatedBodyFatPercentageText)
                        .keyboardType(.decimalPad)

                    MacroTargetSettingsView(
                        calorieTargetText: $formState.calorieTargetText,
                        proteinTargetText: $formState.proteinTargetText,
                        carbTargetText: $formState.carbTargetText,
                        fatTargetText: $formState.fatTargetText,
                        expectedWeeklyWeightLossKgText: $formState.expectedWeeklyWeightLossKgText,
                        aggressiveness: $formState.aggressiveness,
                        onRegenerate: {
                            Task { await onRegenerate(formState) }
                        }
                    )

                    WaterTargetSettingsView(waterTargetMlText: $formState.waterTargetMlText)
                    UnitSettingsView(unitSystem: $formState.unitSystem)
                }
            }
        }
    }

    // MARK: Chrome

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(stepTitles.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.primary : Color.secondary.opacity(0.2))
                    .frame(height: 3)
            }
        }
    }

    // MARK: Actions

    private func advance() {
        withAnimation(.easeInOut(duration: 0.2)) {
            step = min(step + 1, stepTitles.count - 1)
        }
    }

    private func applyGoalType(_ type: PlanGoalType) {
        guard let current = Double(formState.currentWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        let goal: Double
        switch type {
        case .loseFat:
            goal = max(current - 5, current * 0.9)
        case .maintain:
            goal = current
        case .gainMuscle:
            goal = current + 3
        }

        formState.goalWeightKgText = formatDouble(goal)
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onSave(formState)
            isSaving = false
        }
    }

    private func formatDouble(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"
    }
}

// MARK: Form snapshot for goal type inference

private extension ProfileFormState {
    func asProfileSnapshot() -> UserProfile {
        let now = Date()
        return UserProfile(
            id: UUID(),
            name: name.isEmpty ? nil : name,
            age: Int(ageText) ?? 24,
            sex: sex,
            heightCm: Double(heightCmText) ?? 170,
            currentWeightKg: Double(currentWeightKgText) ?? 70,
            goalWeightKg: Double(goalWeightKgText) ?? 65,
            estimatedBodyFatPercentage: Double(estimatedBodyFatPercentageText),
            activityLevel: activityLevel,
            trainingFrequencyPerWeek: Int(trainingFrequencyPerWeekText) ?? 3,
            averageSteps: Int(averageStepsText) ?? 5000,
            dietPreference: dietPreference.isEmpty ? nil : dietPreference,
            unitSystem: unitSystem,
            targets: UserTargets(
                calorieTarget: Int(calorieTargetText) ?? 2000,
                proteinTarget: Double(proteinTargetText) ?? 140,
                carbTarget: Double(carbTargetText) ?? 200,
                fatTarget: Double(fatTargetText) ?? 56,
                waterTargetMl: Int(waterTargetMlText) ?? 2450,
                expectedWeeklyWeightLossKg: Double(expectedWeeklyWeightLossKgText),
                aggressiveness: aggressiveness
            ),
            createdAt: now,
            updatedAt: now
        )
    }
}

#Preview {
    PlanEditWizard(
        formState: .constant(ProfilePreviewData.formState),
        errorMessage: nil,
        onSave: { _ in },
        onCancel: {},
        onRegenerate: { _ in }
    )
}
