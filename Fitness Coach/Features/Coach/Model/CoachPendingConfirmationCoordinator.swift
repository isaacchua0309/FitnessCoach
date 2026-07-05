//
//  CoachPendingConfirmationCoordinator.swift
//  Fitness Coach
//
//  Forma — Pending confirmation state, bar actions, typed confirm/reject, and food edit orchestration.
//

import Foundation

@MainActor
protocol CoachPendingConfirmationDelegate: AnyObject {
    var coachPendingConfirmationUI: CoachPendingConfirmationUIState { get }
    func coachPendingConfirmationApplyUI(_ state: CoachPendingConfirmationUIState)
    var lastTimelineAttribution: CoachTimelineEventSourceAttribution { get }

    func coachPendingConfirmationAppendAssistantMessage(
        _ text: String,
        sourceAttribution: CoachTimelineEventSourceAttribution
    )
    func notifyPhotoFlowDraftEdited(userMessageID: UUID, mealDraft: FoodLogDraft)
    func logAnalytics(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties)
}

@MainActor
final class CoachPendingConfirmationCoordinator {

    private weak var delegate: CoachPendingConfirmationDelegate?
    private let mutationExecutor: CoachMutationExecutor
    private let timelineRecorder: any CoachTimelineRecording
    private let foodCorrectionMemoryStore: (any FoodCorrectionMemoryStoring)?

    private var userEditedPendingBeforeConfirm = false
    private var pendingFoodBaselineDraft: FoodLogDraft?
    private var nutritionEstimateLogPending = false
    private var recordedTimelinePendingConfirmationKeys = Set<String>()
    private var pendingConfirmationTimelineKey: UUID?

    init(
        mutationExecutor: CoachMutationExecutor,
        timelineRecorder: any CoachTimelineRecording,
        foodCorrectionMemoryStore: (any FoodCorrectionMemoryStoring)?
    ) {
        self.mutationExecutor = mutationExecutor
        self.timelineRecorder = timelineRecorder
        self.foodCorrectionMemoryStore = foodCorrectionMemoryStore
    }

    func configure(delegate: CoachPendingConfirmationDelegate) {
        self.delegate = delegate
    }

    var currentPendingConfirmation: CoachPendingConfirmation? {
        delegate?.coachPendingConfirmationUI.pendingConfirmation
    }

    func handleTextInput(_ text: String) async -> CoachActionResult? {
        guard let confirmation = delegate?.coachPendingConfirmationUI.pendingConfirmation else { return nil }

        let normalized = CommandParserUtilities.normalized(text)
        if CoachPendingConfirmationPresenter.confirmWords.contains(normalized) {
            beginConfirmingPendingUI()
            defer { endConfirmingPendingUI() }
        }

        guard let result = await CoachPendingConfirmationPresenter.handleTextInput(
            text,
            pendingConfirmation: confirmation,
            executor: mutationExecutor,
            timelineContext: mutationTimelineContext(for: confirmation)
        ) else {
            return nil
        }

        if result.message == CoachResponseBuilder.pendingRejected {
            recordPendingRejected(confirmation: confirmation, userInputMethod: "typed")
        } else if CoachPendingConfirmationPresenter.confirmWords.contains(normalized) {
            recordPendingConfirmed(
                confirmation: confirmation,
                userInputMethod: "typed",
                entryId: mutationExecutor.lastAffectedEntryId
            )
        }

        if result.pendingConfirmation == nil {
            clearPendingConfirmation()
        }
        return result
    }

    func confirmFromBar() async {
        guard let confirmation = delegate?.coachPendingConfirmationUI.pendingConfirmation else { return }
        guard delegate?.coachPendingConfirmationUI.isConfirmingPending == false else { return }
        beginConfirmingPendingUI()
        defer { endConfirmingPendingUI() }

        let response = await mutationExecutor.executePendingConfirmation(
            confirmation,
            timelineContext: mutationTimelineContext(for: confirmation)
        )
        recordPendingConfirmed(
            confirmation: confirmation,
            userInputMethod: "bar",
            entryId: mutationExecutor.lastAffectedEntryId
        )
        if nutritionEstimateLogPending {
            delegate?.logAnalytics(.nutritionEstimateLogConfirmed, properties: CoachAnalyticsProperties())
            nutritionEstimateLogPending = false
        }
        clearPendingConfirmation()
        if !response.isEmpty {
            delegate?.coachPendingConfirmationAppendAssistantMessage(response, sourceAttribution: .localParser)
        }
    }

    func rejectFromBar() {
        guard let confirmation = delegate?.coachPendingConfirmationUI.pendingConfirmation else { return }
        recordPendingRejected(confirmation: confirmation, userInputMethod: "bar")
        if nutritionEstimateLogPending {
            delegate?.logAnalytics(.nutritionEstimateLogCancelled, properties: CoachAnalyticsProperties())
            nutritionEstimateLogPending = false
        }
        clearPendingConfirmation()
        delegate?.coachPendingConfirmationAppendAssistantMessage(
            CoachResponseBuilder.pendingRejected,
            sourceAttribution: .localParser
        )
    }

    func beginNutritionEstimateLogPending() {
        nutritionEstimateLogPending = true
        delegate?.logAnalytics(.nutritionEstimateLogStarted, properties: CoachAnalyticsProperties())
    }

    func openFoodEditSheet() {
        guard let next = CoachModelStateReducer.openFoodEditSheetUI(pendingConfirmationUI) else { return }
        applyPendingConfirmationUI(next)
    }

    func dismissFoodEditSheet() {
        applyPendingConfirmationUI(
            CoachModelStateReducer.dismissFoodEditSheetUI(pendingConfirmationUI)
        )
    }

    func saveFoodEdit(_ formState: FoodLogEditFormState) {
        let ui = pendingConfirmationUI
        guard case .food(var draft) = ui.pendingConfirmation else {
            applyPendingConfirmationUI(
                CoachModelStateReducer.saveFoodEditFailedUI(
                    ui,
                    message: "I could not prepare that estimate for editing."
                )
            )
            return
        }

        do {
            let baseline = pendingFoodBaselineDraft ?? draft.primaryMealDraft
            let updated = try formState.makeMealDraft(original: draft.primaryMealDraft)
            draft.mealDraft = updated
            applyPendingConfirmationUI(
                CoachModelStateReducer.saveFoodEditSucceededUI(ui, draft: draft)
            )
            userEditedPendingBeforeConfirm = true
            Task {
                await FoodCorrectionMemoryRecorder.recordIfNeeded(
                    before: baseline,
                    after: updated,
                    source: draft.relatedPhotoUserMessageID == nil ? .pendingEditSheet : .photoRecommission,
                    store: foodCorrectionMemoryStore
                )
            }
            if let userMessageID = draft.relatedPhotoUserMessageID {
                delegate?.notifyPhotoFlowDraftEdited(userMessageID: userMessageID, mealDraft: updated)
            }
        } catch let error as FoodEntryFormError {
            applyPendingConfirmationUI(
                CoachModelStateReducer.saveFoodEditFailedUI(
                    ui,
                    message: error.localizedDescription
                )
            )
        } catch {
            applyPendingConfirmationUI(
                CoachModelStateReducer.saveFoodEditFailedUI(
                    ui,
                    message: CoachResponseBuilder.aiFoodSaveFailed
                )
            )
        }
    }

    @discardableResult
    func setPendingConfirmation(_ confirmation: CoachPendingConfirmation) -> CoachPendingConfirmation {
        applyPendingConfirmationUI(
            CoachModelStateReducer.setPendingConfirmationUI(
                pendingConfirmationUI,
                confirmation: confirmation
            )
        )
        pendingConfirmationTimelineKey = UUID()
        switch confirmation {
        case .food(let draft):
            pendingFoodBaselineDraft = draft.primaryMealDraft
        default:
            pendingFoodBaselineDraft = nil
        }
        CoachAccuracyObservabilityLogger.logPendingConfirmationCreated(kind: confirmation.kindLabel)
        recordPendingCreatedIfNeeded(confirmation)
        return confirmation
    }

    func applyPendingConfirmation(from result: CoachActionResult) {
        if let confirmation = result.pendingConfirmation {
            setPendingConfirmation(confirmation)
        }
    }

    func clearPendingConfirmation() {
        applyPendingConfirmationUI(
            CoachModelStateReducer.clearPendingConfirmationUI(pendingConfirmationUI)
        )
        pendingConfirmationTimelineKey = nil
        userEditedPendingBeforeConfirm = false
        pendingFoodBaselineDraft = nil
    }

    func clearPendingConfirmationIfLinked(to userMessageID: UUID) {
        guard case .food(let draft) = pendingConfirmationUI.pendingConfirmation,
              draft.relatedPhotoUserMessageID == userMessageID else {
            return
        }
        clearPendingConfirmation()
    }

    func clearPhotoLinkedPendingConfirmation() {
        guard case .food(let draft) = pendingConfirmationUI.pendingConfirmation,
              draft.relatedPhotoUserMessageID != nil else {
            return
        }
        clearPendingConfirmation()
    }

    func priorFoodDraftForSupersede(userMessageID: UUID) -> AIFoodConfirmationDraft? {
        guard case .food(let draft) = pendingConfirmationUI.pendingConfirmation,
              draft.relatedPhotoUserMessageID == userMessageID else {
            return nil
        }
        return draft
    }

    func pendingConfirmationEstimateId() -> UUID? {
        pendingConfirmationUI.pendingConfirmation?.foodDraft?.id
    }

    func mutationTimelineContext(
        for confirmation: CoachPendingConfirmation
    ) -> CoachMutationTimelineContext {
        var context = CoachMutationTimelineContext(
            sourceAttribution: delegate?.lastTimelineAttribution ?? .localParser,
            userEditedBeforeConfirm: userEditedPendingBeforeConfirm
        )
        switch confirmation {
        case .food(let draft):
            context.pendingConfirmationId = draft.id
            context.relatedPhotoSessionId = draft.imageAnalysisSessionID
            if let sourceAttribution = draft.sourceAttribution {
                context.sourceAttribution = sourceAttribution
            }
        case .edit(let action, _, _), .delete(let action, _, _):
            context.linkedEntryId = action.linkedEntryId
            context.relatedTimelineEventId = action.linkedTimelineEventId
        case .water, .weight, .undo:
            break
        }
        return context
    }

    // MARK: Timeline

    private var pendingConfirmationUI: CoachPendingConfirmationUIState {
        delegate?.coachPendingConfirmationUI ?? .empty
    }

    private func applyPendingConfirmationUI(_ state: CoachPendingConfirmationUIState) {
        delegate?.coachPendingConfirmationApplyUI(state)
    }

    private func beginConfirmingPendingUI() {
        applyPendingConfirmationUI(
            CoachModelStateReducer.beginConfirmingPendingUI(pendingConfirmationUI)
        )
    }

    private func endConfirmingPendingUI() {
        applyPendingConfirmationUI(
            CoachModelStateReducer.endConfirmingPendingUI(pendingConfirmationUI)
        )
    }

    private func recordPendingCreatedIfNeeded(_ confirmation: CoachPendingConfirmation) {
        let key = pendingConfirmationDedupeKey(for: confirmation)
        guard recordedTimelinePendingConfirmationKeys.insert(key).inserted else { return }

        let payload = CoachModelTimelineSupport.confirmationPayload(from: confirmation)
        timelineRecorder.recordPendingConfirmationCreated(
            payload: payload,
            sourceAttribution: delegate?.lastTimelineAttribution ?? .localParser,
            occurredAt: Date()
        )
    }

    private func pendingConfirmationDedupeKey(for confirmation: CoachPendingConfirmation) -> String {
        switch confirmation {
        case .food(let draft):
            return "food:\(draft.id.uuidString)"
        case .water(let draft, _):
            if let pendingConfirmationTimelineKey {
                return "water:\(pendingConfirmationTimelineKey.uuidString):\(draft.amountMl)"
            }
            return "water:\(draft.amountMl)"
        case .weight(let draft, _):
            if let pendingConfirmationTimelineKey {
                return "weight:\(pendingConfirmationTimelineKey.uuidString):\(draft.weightKg)"
            }
            return "weight:\(draft.weightKg)"
        case .edit(let action, let originalText, _):
            return "edit:\(originalText):\(action.type.rawValue)"
        case .delete(let action, let originalText, _):
            return "delete:\(originalText):\(action.type.rawValue)"
        case .undo(let action, let originalText, _):
            return "undo:\(originalText):\(action.type.rawValue)"
        }
    }

    private func recordPendingConfirmed(
        confirmation: CoachPendingConfirmation,
        userInputMethod: String,
        entryId: UUID? = nil
    ) {
        let payload = CoachModelTimelineSupport.confirmationPayload(
            from: confirmation,
            userInputMethod: userInputMethod
        )
        let resolvedEntryId: UUID? = {
            if let entryId { return entryId }
            switch confirmation {
            case .edit(let action, _, _):
                return action.linkedEntryId
            case .delete(let action, _, _):
                return action.linkedEntryId
            default:
                return nil
            }
        }()
        timelineRecorder.recordPendingConfirmationConfirmed(
            payload: payload,
            entryId: resolvedEntryId,
            occurredAt: Date()
        )
    }

    private func recordPendingRejected(
        confirmation: CoachPendingConfirmation,
        userInputMethod: String
    ) {
        let payload = CoachModelTimelineSupport.confirmationPayload(
            from: confirmation,
            userInputMethod: userInputMethod
        )
        timelineRecorder.recordPendingConfirmationRejected(
            payload: payload,
            occurredAt: Date()
        )
        if case .food(let draft) = confirmation {
            timelineRecorder.recordFoodRejected(
                payload: CoachModelTimelineSupport.foodEstimatePayload(from: draft),
                messageId: draft.relatedPhotoUserMessageID,
                photoSessionId: draft.imageAnalysisSessionID,
                relatedEventIds: [draft.id],
                occurredAt: Date()
            )
        }
    }
}
