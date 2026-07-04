//
//  CoachMutationExecutor.swift
//  Fitness Coach
//
//  Canonical Coach mutation execution — food, water, weight, undo, edit, delete, status.
//  All account nutrition/review writes go through FitnessActionCenter.
//  See Docs/Architecture/SourceOfTruthMap.md §3.
//

import Foundation

@MainActor
final class CoachMutationExecutor {

    private let actionCenter: FitnessActionCenter
    private let dailyLogReader: any DailyLogReading
    private let healthActivityQuery: HealthActivityQueryService
    private let mutationHistory: CoachMutationHistory
    private let timelineRecorder: any CoachTimelineRecording
    private let timelineStore: (any CoachTimelineStoring)?

    private var completedPendingConfirmationIDs = Set<UUID>()
    private var recordedFoodLogEntryIDs = Set<UUID>()
    private(set) var lastAffectedEntryId: UUID?

    init(
        actionCenter: FitnessActionCenter,
        dailyLogReader: any DailyLogReading,
        healthActivityQuery: HealthActivityQueryService,
        mutationHistory: CoachMutationHistory,
        timelineRecorder: (any CoachTimelineRecording)? = nil,
        timelineStore: (any CoachTimelineStoring)? = nil
    ) {
        self.actionCenter = actionCenter
        self.dailyLogReader = dailyLogReader
        self.healthActivityQuery = healthActivityQuery
        self.mutationHistory = mutationHistory
        self.timelineRecorder = timelineRecorder ?? NoOpCoachTimelineRecorder()
        self.timelineStore = timelineStore
    }

    func hasWorkoutToday() async -> Bool {
        (await healthActivityQuery.dailyTrainingActivity().hasWorkout)
    }

    func execute(
        _ command: ParsedCommand,
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        contextHints: CoachResponseContextHints? = nil
    ) async -> String {
        switch command.intent {
        case .logWater(let draft):
            return executeLogWater(draft)
        case .logWeight(let draft):
            return executeLogWeight(draft)
        case .logFood(let draft):
            return executeLogFood(FoodLogDraftMapper.fromLegacyDraft(draft))
        case .undo(let target):
            return executeUndo(target)
        case .status:
            return await executeStatus(
                healthIntelligence: healthIntelligence,
                contextHints: contextHints
            )
        case .dailyReview:
            return await executeDailyReview(contextHints: contextHints)
        case .logSteps:
            return CoachResponseBuilder.stepsPlaceholder
        case .unsupported:
            return CoachResponseBuilder.unsupportedResponse
        case .needsAI:
            return CoachResponseBuilder.needsAIResponse
        }
    }

    func executePendingConfirmation(
        _ confirmation: CoachPendingConfirmation,
        timelineContext: CoachMutationTimelineContext = CoachMutationTimelineContext()
    ) async -> String {
        if let pendingId = timelineContext.pendingConfirmationId,
           completedPendingConfirmationIDs.contains(pendingId) {
            logMutationOutcome(kind: confirmation.kindLabel, success: true)
            return alreadyLoggedResponse(for: confirmation)
        }

        let response: String
        switch confirmation {
        case .food(let draft):
            response = executeLogFood(
                draft.primaryMealDraft,
                timelineContext: timelineContext
            )
        case .water(let draft, _):
            response = executeLogWater(draft)
        case .weight(let draft, _):
            response = executeLogWeight(draft)
        case .edit(let action, _, _):
            response = await executeEditAction(action)
        case .delete(let action, _, _):
            response = await executeDeleteAction(action)
        case .undo(let action, _, _):
            response = executeUndoAction(action)
        }

        if let pendingId = timelineContext.pendingConfirmationId,
           isSuccessfulMutationResponse(response, for: confirmation) {
            completedPendingConfirmationIDs.insert(pendingId)
        }

        logMutationOutcome(
            kind: confirmation.kindLabel,
            success: isSuccessfulMutationResponse(response, for: confirmation)
        )

        return response
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
            timelineRecorder.recordWaterLogged(entry: entry, occurredAt: entry.createdAt)
            return CoachResponseBuilder.water(loggedMl: entry.amountMl, log: log)
        } catch ServiceError.invalidInput(let message) {
            timelineRecordMutationFailure(message: message, category: "invalid_input")
            return message
        } catch {
            timelineRecordMutationFailure(message: error.localizedDescription, category: "water_log")
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
            timelineRecorder.recordWeightLogged(entry: entry, occurredAt: entry.createdAt)
            return CoachResponseBuilder.weight(entry.weightKg)
        } catch ServiceError.invalidInput(let message) {
            timelineRecordMutationFailure(message: message, category: "invalid_input")
            return message
        } catch {
            timelineRecordMutationFailure(message: error.localizedDescription, category: "weight_log")
            return "I could not log that weight. Please try again."
        }
    }

    func executeLogFood(_ meal: FoodLogDraft) -> String {
        executeLogFood(meal, timelineContext: CoachMutationTimelineContext())
    }

    func executeLogFood(
        _ meal: FoodLogDraft,
        timelineContext: CoachMutationTimelineContext
    ) -> String {
        if let pendingId = timelineContext.pendingConfirmationId,
           completedPendingConfirmationIDs.contains(pendingId) {
            return alreadyLoggedResponse(for: .food(
                AIFoodConfirmationDraft(
                    id: pendingId,
                    originalText: meal.displayName,
                    assistantMessage: nil,
                    mealDraft: meal,
                    confidence: .medium,
                    requiresConfirmation: false
                )
            ))
        }

        do {
            let entry = try actionCenter.logFood(meal, date: Date())
            lastAffectedEntryId = entry.id
            let log = try? dailyLogReader.getLog(for: Date())
            mutationHistory.record(entryId: entry.id, type: .food, summary: entry.name)
            timelineRecordFoodLoggedIfNeeded(
                entry: entry,
                sourceAttribution: timelineContext.sourceAttribution,
                userEditedBeforeConfirm: timelineContext.userEditedBeforeConfirm,
                linkedPhotoSessionId: timelineContext.relatedPhotoSessionId
            )
            if let pendingId = timelineContext.pendingConfirmationId {
                completedPendingConfirmationIDs.insert(pendingId)
            }
            CoachTodaySyncDebugLogger.coachMealSaved(
                entryId: entry.id,
                name: entry.name,
                calories: entry.calories,
                protein: entry.protein,
                mealType: entry.mealType?.rawValue ?? MealType.unknown.rawValue,
                refreshToken: actionCenter.dataRefreshToken
            )
            return CoachResponseBuilder.food(
                entry,
                log: log,
                fromPhotoAnalysis: timelineContext.sourceAttribution == .mealImage
                    || entry.source == .aiPhotoEstimate
            )
        } catch ServiceError.invalidInput(let message) {
            timelineRecordMutationFailure(message: message, category: "invalid_input")
            return message
        } catch ServiceError.missingUserProfile {
            timelineRecordMutationFailure(
                message: "Missing user profile for food log.",
                category: "missing_profile"
            )
            return "I could not log that food entry. Please check that your profile is set up."
        } catch {
            timelineRecordMutationFailure(message: error.localizedDescription, category: "food_log")
            return "I could not log that food entry. Please check the calories and macro values."
        }
    }

    func executeLogFood(_ draft: FoodDraft) -> String {
        executeLogFood(FoodLogDraftMapper.fromLegacyDraft(draft))
    }

    func executeEditAction(_ action: AICommandAction) async -> String {
        if let foodDraft = action.foodDraft {
            return await applyFoodEdit(
                from: foodDraft,
                linkedEntryId: action.linkedEntryId
            )
        }
        return CoachResponseBuilder.entryReferenceClarification()
    }

    func executeDeleteAction(_ action: AICommandAction) async -> String {
        if let linkedEntryId = action.linkedEntryId {
            return await deleteFood(entryId: linkedEntryId)
        }

        return CoachResponseBuilder.entryReferenceClarification()
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
                if let entry {
                    timelineRecorder.recordUndoPerformed(
                        entryType: "food",
                        undoneEntryId: entry.id,
                        summary: entry.name,
                        occurredAt: Date()
                    )
                }
                return CoachResponseBuilder.undoFood(entry)
            } catch {
                timelineRecordMutationFailure(message: error.localizedDescription, category: "undo_food")
                return "I could not undo your last food entry. Please try again."
            }
        case .water:
            do {
                let entry = try actionCenter.undoLastWaterEntry(date: Date())
                if let entry {
                    timelineRecorder.recordUndoPerformed(
                        entryType: "water",
                        undoneEntryId: entry.id,
                        summary: "\(entry.amountMl) ml",
                        occurredAt: Date()
                    )
                }
                return CoachResponseBuilder.undoWater(entry)
            } catch {
                timelineRecordMutationFailure(message: error.localizedDescription, category: "undo_water")
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
                timelineRecorder.recordUndoPerformed(
                    entryType: "food",
                    undoneEntryId: record.entryId,
                    summary: record.summary,
                    occurredAt: Date()
                )
            case .water:
                try actionCenter.deleteWaterEntry(id: record.entryId)
                timelineRecorder.recordUndoPerformed(
                    entryType: "water",
                    undoneEntryId: record.entryId,
                    summary: record.summary,
                    occurredAt: Date()
                )
            case .workout:
                return TrainingIntegrationCopy.coachWorkoutMutationUnavailable
            case .weight:
                return "Weight undo is not available yet. Log the corrected weight instead."
            }
            mutationHistory.remove(id: record.id)
            return "Undid \(record.summary)."
        } catch {
            timelineRecordMutationFailure(message: error.localizedDescription, category: "undo_last")
            return "I could not undo that last action. Please try again."
        }
    }

    private func deleteFood(entryId: UUID) async -> String {
        do {
            let entries = try actionCenter.getFoodEntries(for: Date())
            guard let entry = entries.first(where: { $0.id == entryId }) else {
                return CoachResponseBuilder.entryReferenceDeletedOrMissing
            }

            let supersededEventId = await CoachMutationTimelineLookup.latestFoodMutationEventId(
                forEntryId: entry.id,
                store: timelineStore
            )
            try actionCenter.deleteFoodEntry(id: entry.id)
            lastAffectedEntryId = entry.id
            timelineRecorder.recordFoodDeleted(
                entry: entry,
                supersedesEventId: supersededEventId,
                occurredAt: Date()
            )
            return CoachResponseBuilder.deleteFood(entry)
        } catch {
            timelineRecordMutationFailure(message: error.localizedDescription, category: "food_delete")
            return "I could not delete that food entry. Please try again."
        }
    }

    private func applyFoodEdit(
        from draft: FoodDraft,
        linkedEntryId: UUID?
    ) async -> String {
        do {
            let entries = try actionCenter.getFoodEntries(for: Date())
            guard let linkedEntryId else {
                return CoachResponseBuilder.entryReferenceClarification()
            }

            guard let entry = entries.first(where: { $0.id == linkedEntryId }) else {
                return CoachResponseBuilder.entryReferenceDeletedOrMissing
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
                notes: draft.notes
            )
            let supersededEventId = await CoachMutationTimelineLookup.latestFoodMutationEventId(
                forEntryId: entry.id,
                store: timelineStore
            )
            let updated = try actionCenter.editFoodEntry(id: entry.id, update: update)
            lastAffectedEntryId = updated.id
            mutationHistory.record(entryId: updated.id, type: .food, summary: "edit \(updated.name)")
            timelineRecorder.recordFoodEdited(
                entry: updated,
                supersedesEventId: supersededEventId,
                occurredAt: updated.updatedAt
            )
            return CoachResponseBuilder.editFood(updated)
        } catch ServiceError.invalidInput(let message) {
            timelineRecordMutationFailure(message: message, category: "invalid_input")
            return message
        } catch {
            timelineRecordMutationFailure(message: error.localizedDescription, category: "food_edit")
            return "I could not edit that food entry. Please try again."
        }
    }

    private func executeStatus(
        healthIntelligence: CoachHealthIntelligenceContext? = nil,
        contextHints: CoachResponseContextHints? = nil
    ) async -> String {
        do {
            let log = try dailyLogReader.getTodayLog()
            var hints = contextHints ?? CoachResponseContextHints()
            let training: DailyTrainingActivity?
            if hints.missingData?.workoutsUnavailable == true
                || hints.missingData?.workoutPermissionDeniedOrUnavailable == true {
                training = nil
            } else {
                training = await healthActivityQuery.dailyTrainingActivity(on: log.date)
            }

            if hints.recentMeals.isEmpty {
                let foodEntries = (try? actionCenter.getFoodEntries(for: log.date)) ?? []
                hints.recentMeals = foodEntries.map { CoachRecentMealContext.from(entry: $0) }
            }

            if hints.steps == nil,
               hints.missingData?.stepsUnavailable != true,
               hints.missingData?.stepsMissing != true {
                hints.steps = try? await healthActivityQuery.stepsToday(on: log.date)
            }
            if hints.steps == nil {
                hints.steps = log.steps
            }

            if hints.timelineEvents.isEmpty, let timelineStore {
                let localDate = CoachContextMeta.make(generatedAt: log.date).localDate
                if let events = try? await timelineStore.events(forLocalDate: localDate) {
                    hints.timelineEvents = events.map { event in
                        CoachTimelineContextEvent.from(
                            event: event,
                            summary: CoachTimelineEventSummaryBuilder.summary(for: event)
                        )
                    }
                }
            }

            if hints.healthIntelligence == nil {
                hints.healthIntelligence = healthIntelligence
            }

            return CoachResponseBuilder.status(
                log,
                healthIntelligence: healthIntelligence ?? hints.healthIntelligence,
                contextHints: hints,
                training: training
            )
        } catch ServiceError.missingUserProfile {
            return "I could not load your status. Please check that your profile is set up."
        } catch {
            return "I could not load your status. Please try again."
        }
    }

    private func executeDailyReview(contextHints: CoachResponseContextHints? = nil) async -> String {
        do {
            let review = try await actionCenter.generateDailyReview(for: Date())
            return CoachResponseBuilder.dailyReview(review, contextHints: contextHints)
        } catch ServiceError.missingUserProfile {
            return "I could not generate your daily review yet. Please start a day and make sure your profile is set up."
        } catch ServiceError.dailyLogNotFound {
            return "There is no daily log for today yet. Open Today to load your dashboard."
        } catch {
            return "I could not generate your daily review yet. Please try again."
        }
    }

    // MARK: Timeline helpers

    private func timelineRecordFoodLoggedIfNeeded(
        entry: FoodEntry,
        sourceAttribution: CoachTimelineEventSourceAttribution,
        userEditedBeforeConfirm: Bool,
        linkedPhotoSessionId: UUID?
    ) {
        guard recordedFoodLogEntryIDs.insert(entry.id).inserted else { return }
        timelineRecorder.recordFoodLogged(
            entry: entry,
            sourceAttribution: sourceAttribution,
            userEditedBeforeConfirm: userEditedBeforeConfirm,
            linkedPhotoSessionId: linkedPhotoSessionId,
            occurredAt: entry.createdAt
        )
    }

    private func logMutationOutcome(
        kind: String,
        success: Bool,
        backendErrorCategory: String? = nil
    ) {
        CoachAccuracyObservabilityLogger.logMutation(
            CoachMutationObservabilitySnapshot(
                mutationKind: kind,
                success: success,
                backendErrorCategory: backendErrorCategory
            )
        )
    }

    private func timelineRecordMutationFailure(message: String, category: String) {
        timelineRecorder.recordBackendError(
            category: category,
            userMessage: message,
            isRetryable: false,
            httpStatus: nil,
            occurredAt: Date()
        )
    }

    private func alreadyLoggedResponse(for confirmation: CoachPendingConfirmation) -> String {
        switch confirmation {
        case .food:
            return "That meal is already logged."
        case .water(let draft, _):
            return CoachResponseBuilder.water(loggedMl: draft.amountMl, log: try? dailyLogReader.getLog(for: Date()))
        case .weight(let draft, _):
            return CoachResponseBuilder.weight(draft.weightKg)
        case .edit, .delete, .undo:
            return "That change is already applied."
        }
    }

    private func isSuccessfulMutationResponse(
        _ response: String,
        for confirmation: CoachPendingConfirmation
    ) -> Bool {
        switch confirmation {
        case .food:
            return !response.contains("could not log")
        case .water:
            return !response.contains("could not save")
        case .weight:
            return !response.contains("could not log")
        case .edit:
            return !response.contains("could not edit") && !response.contains("no food entry")
        case .delete:
            return !response.contains("could not delete") && !response.contains("did not find")
        case .undo:
            return !response.contains("could not undo") && !response.contains("not available")
        }
    }
}
