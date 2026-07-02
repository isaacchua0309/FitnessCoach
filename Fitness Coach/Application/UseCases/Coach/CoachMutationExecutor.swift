//
//  CoachMutationExecutor.swift
//  Fitness Coach
//
//  Canonical Coach mutation execution — food, water, weight, undo, edit, delete, status.
//

import Foundation

@MainActor
final class CoachMutationExecutor {

    private let actionCenter: FitnessActionCenter
    private let dailyLogReader: any DailyLogReading
    private let healthActivityQuery: HealthActivityQueryService
    private let localNutritionEstimator: LocalNutritionEstimator
    private let mutationHistory: CoachMutationHistory

    init(
        actionCenter: FitnessActionCenter,
        dailyLogReader: any DailyLogReading,
        healthActivityQuery: HealthActivityQueryService,
        localNutritionEstimator: LocalNutritionEstimator,
        mutationHistory: CoachMutationHistory
    ) {
        self.actionCenter = actionCenter
        self.dailyLogReader = dailyLogReader
        self.healthActivityQuery = healthActivityQuery
        self.localNutritionEstimator = localNutritionEstimator
        self.mutationHistory = mutationHistory
    }

    func hasWorkoutToday() async -> Bool {
        (try? await healthActivityQuery.dailyTrainingActivity().hasWorkout) ?? false
    }

    func execute(_ command: ParsedCommand) async -> String {
        switch command.intent {
        case .logWater(let draft):
            return executeLogWater(draft)
        case .logWeight(let draft):
            return executeLogWeight(draft)
        case .logFood(let draft):
            return executeLogFood(draft)
        case .undo(let target):
            return executeUndo(target)
        case .status:
            return executeStatus()
        case .dailyReview:
            return await executeDailyReview()
        case .logSteps:
            return CoachResponseBuilder.stepsPlaceholder
        case .unsupported:
            return CoachResponseBuilder.unsupportedResponse
        case .needsAI:
            return CoachResponseBuilder.needsAIResponse
        }
    }

    func executePendingConfirmation(_ confirmation: CoachPendingConfirmation) async -> String {
        switch confirmation {
        case .food(let draft):
            return executeLogFood(draft.primaryMealDraft)
        case .water(let draft, _):
            return executeLogWater(draft)
        case .weight(let draft, _):
            return executeLogWeight(draft)
        case .edit(let action, _, _):
            return executeEditAction(action)
        case .delete(let action, _, _):
            return executeDeleteAction(action)
        case .undo(let action, _, _):
            return executeUndoAction(action)
        }
    }

    func executeLogWater(_ draft: WaterDraft) -> String {
        do {
            let entry = try actionCenter.logWater(draft, date: Date())
            let log = try? dailyLogReader.getLog(for: Date())
            mutationHistory.record(
                entryId: entry.id,
                type: .water,
                summary: "\(entry.amountMl)ml water"
            )
            return CoachResponseBuilder.water(loggedMl: entry.amountMl, log: log)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not save that water entry. Please try again."
        }
    }

    func executeLogWeight(_ draft: WeightDraft) -> String {
        do {
            let entry = try actionCenter.logDailyWeight(draft, date: Date())
            mutationHistory.record(
                entryId: entry.id,
                type: .weight,
                summary: "\(entry.weightKg)kg weight"
            )
            return CoachResponseBuilder.weight(entry.weightKg)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not log that weight. Please try again."
        }
    }

    func executeLogFood(_ meal: FoodLogDraft) -> String {
        do {
            let entry = try actionCenter.logFood(meal, date: Date())
            let log = try? dailyLogReader.getLog(for: Date())
            mutationHistory.record(entryId: entry.id, type: .food, summary: entry.name)
            return CoachResponseBuilder.food(entry, log: log)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch ServiceError.missingUserProfile {
            return "I could not log that food entry. Please check that your profile is set up."
        } catch {
            return "I could not log that food entry. Please check the calories and macro values."
        }
    }

    func executeLogFood(_ draft: FoodDraft) -> String {
        executeLogFood(FoodLogDraftMapper.fromLegacyDraft(draft))
    }

    func executeEditAction(_ action: AICommandAction) -> String {
        if let foodDraft = action.foodDraft {
            return applyFoodEdit(from: foodDraft, selector: action.targetEntrySelector)
        }
        return "I couldn't find which entry to edit. Try being more specific."
    }

    func executeDeleteAction(_ action: AICommandAction) -> String {
        if let mealType = action.foodDraft?.mealType {
            return deleteFood(mealType: mealType)
        }

        let selector = (action.targetEntrySelector ?? "").lowercased()
        for mealType in MealType.allCases where selector.contains(mealType.rawValue.lowercased()) {
            return deleteFood(mealType: mealType)
        }

        return "I couldn't find which entry to delete. Try naming the meal type."
    }

    func executeUndoAction(_ action: AICommandAction) -> String {
        let selector = (action.targetEntrySelector ?? "").lowercased()
        if selector.contains("food") {
            return executeUndo(.food)
        }
        if selector.contains("water") {
            return executeUndo(.water)
        }
        if selector.contains("workout") {
            return TrainingIntegrationCopy.coachWorkoutMutationUnavailable
        }
        return executeUndo(.last)
    }

    func executeUndo(_ target: UndoTarget) -> String {
        switch target {
        case .food:
            do {
                let entry = try actionCenter.undoLastFoodEntry(date: Date())
                return CoachResponseBuilder.undoFood(entry)
            } catch {
                return "I could not undo your last food entry. Please try again."
            }
        case .water:
            do {
                let entry = try actionCenter.undoLastWaterEntry(date: Date())
                return CoachResponseBuilder.undoWater(entry)
            } catch {
                return "I could not undo your last water entry. Please try again."
            }
        case .last:
            return executeUndoLastMutation()
        case .workout:
            return TrainingIntegrationCopy.coachWorkoutMutationUnavailable
        case .weight:
            return "Weight undo is not available yet. Log the corrected weight instead."
        }
    }

    private func executeUndoLastMutation() -> String {
        guard let record = mutationHistory.latest() else {
            return CoachResponseBuilder.undoLastPlaceholder
        }

        do {
            switch record.entryType {
            case .food:
                try actionCenter.deleteFoodEntry(id: record.entryId)
            case .water:
                try actionCenter.deleteWaterEntry(id: record.entryId)
            case .workout:
                return TrainingIntegrationCopy.coachWorkoutMutationUnavailable
            case .weight:
                return "Weight undo is not available yet. Log the corrected weight instead."
            }
            mutationHistory.remove(id: record.id)
            return "Undid \(record.summary)."
        } catch {
            return "I could not undo that last action. Please try again."
        }
    }

    private func deleteFood(mealType: MealType) -> String {
        do {
            let entries = try actionCenter.getFoodEntries(for: Date())
                .filter { $0.mealType == mealType }

            guard !entries.isEmpty else {
                return "I did not find a \(mealType.rawValue) entry for today."
            }

            guard entries.count == 1, let entry = entries.first else {
                return "I found \(entries.count) \(mealType.rawValue) entries. Which one should I delete?"
            }

            try actionCenter.deleteFoodEntry(id: entry.id)
            return CoachResponseBuilder.deleteFood(entry)
        } catch {
            return "I could not delete that food entry. Please try again."
        }
    }

    private func applyFoodEdit(from draft: FoodDraft, selector: String?) -> String {
        do {
            let entries = try actionCenter.getFoodEntries(for: Date())
            guard let entry = entries.last else {
                return "There is no food entry to edit today."
            }

            let update = FoodEntryUpdate(
                mealType: draft.mealType,
                name: draft.name.isEmpty ? nil : draft.name,
                quantity: draft.quantity,
                unit: draft.unit,
                calories: draft.calories,
                protein: draft.protein,
                carbs: draft.carbs,
                fat: draft.fat,
                fiber: draft.fiber,
                sodium: draft.sodium,
                source: .corrected,
                confidence: draft.confidence,
                imageUrl: draft.imageUrl,
                notes: draft.notes ?? selector
            )
            let updated = try actionCenter.editFoodEntry(id: entry.id, update: update)
            mutationHistory.record(entryId: updated.id, type: .food, summary: "edit \(updated.name)")
            return CoachResponseBuilder.editFood(updated)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not edit that food entry. Please try again."
        }
    }

    private func executeStatus() -> String {
        do {
            let log = try dailyLogReader.getTodayLog()
            return CoachResponseBuilder.status(log)
        } catch ServiceError.missingUserProfile {
            return "I could not load your status. Please check that your profile is set up."
        } catch {
            return "I could not load your status. Please try again."
        }
    }

    private func executeDailyReview() async -> String {
        do {
            let review = try await actionCenter.generateDailyReview(for: Date())
            return CoachResponseBuilder.dailyReview(review)
        } catch ServiceError.missingUserProfile {
            return "I could not generate your daily review yet. Please start a day and make sure your profile is set up."
        } catch ServiceError.dailyLogNotFound {
            return "There is no daily log for today yet. Open Today to load your dashboard."
        } catch {
            return "I could not generate your daily review yet. Please try again."
        }
    }
}
