//
//  WorkoutEntryFormState.swift
//  Fitness Coach
//
//  FitPilot AI — Local form state for adding an MVP workout.
//
//  This is UI input state only. Conversion produces WorkoutDraft for
//  WorkoutLogService; it never persists directly.
//

import Foundation

struct WorkoutEntryFormState: Equatable {
    var name: String = ""
    var durationMinutesText: String = ""
    var notes: String = ""
    var exerciseSets: [ExerciseSetDraftRowState] = [ExerciseSetDraftRowState(setNumberText: "1")]

    func makeDraft() throws -> WorkoutDraft {
        let duration = try parseOptionalPositiveInt(
            durationMinutesText,
            fieldName: "Duration"
        )
        let drafts = try exerciseSets
            .filter { !$0.isIgnorableEmptyRow }
            .map { try $0.makeDraft() }
        guard !drafts.isEmpty else {
            throw TrainingFormError.invalid("Add at least one exercise set.")
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        return WorkoutDraft(
            name: trimmedName.isEmpty ? "Workout" : trimmedName,
            durationMinutes: duration,
            estimatedCaloriesBurned: nil,
            intensity: nil,
            recoveryDemand: nil,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            exerciseSets: drafts
        )
    }

    private func parseOptionalPositiveInt(_ text: String, fieldName: String) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value > 0 else {
            throw TrainingFormError.invalid("\(fieldName) must be a positive whole number.")
        }
        return value
    }
}

struct ExerciseSetDraftRowState: Identifiable, Equatable {
    var id = UUID()
    var exerciseName: String = ""
    var setNumberText: String = ""
    var repsText: String = ""
    var weightKgText: String = ""
    var rpeText: String = ""

    var isIgnorableEmptyRow: Bool {
        exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && repsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && weightKgText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && rpeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeDraft() throws -> ExerciseSetDraft {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw TrainingFormError.invalid("Exercise name is required.")
        }
        guard let setNumber = Int(setNumberText), setNumber > 0 else {
            throw TrainingFormError.invalid("Set number must be positive.")
        }
        guard let reps = Int(repsText), reps > 0 else {
            throw TrainingFormError.invalid("Reps must be positive.")
        }

        let weightKg = try parseOptionalPositiveDouble(weightKgText, fieldName: "Weight")
        let rpe = try parseOptionalRPE(rpeText)

        return ExerciseSetDraft(
            exerciseName: trimmedName,
            setNumber: setNumber,
            reps: reps,
            weightKg: weightKg,
            rpe: rpe
        )
    }

    private func parseOptionalPositiveDouble(_ text: String, fieldName: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), value > 0 else {
            throw TrainingFormError.invalid("\(fieldName) must be positive.")
        }
        return value
    }

    private func parseOptionalRPE(_ text: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Double(trimmed), (1...10).contains(value) else {
            throw TrainingFormError.invalid("RPE must be between 1 and 10.")
        }
        return value
    }
}

enum TrainingFormError: Error, Equatable {
    case invalid(String)

    var message: String {
        switch self {
        case .invalid(let message):
            return message
        }
    }
}
