//
//  CoachModel+CoordinatorDelegates.swift
//  Fitness Coach
//
//  Forma — Coordinator delegate bridges for published Coach surface state.
//

import Foundation

// MARK: - Launch chrome

extension CoachModel: CoachLaunchChromeDelegate {

    var launchChrome: CoachLaunchChromeState {
        CoachLaunchChromeState(
            activeLaunchPresentation: activeLaunchPresentation,
            composerPlaceholderOverride: composerPlaceholderOverride,
            requestsComposerFocus: requestsComposerFocus,
            requestsCameraPresentation: requestsCameraPresentation
        )
    }
}

// MARK: - Pending confirmation

extension CoachModel: CoachPendingConfirmationDelegate {

    var coachPendingConfirmationUI: CoachPendingConfirmationUIState {
        CoachPendingConfirmationUIState(
            pendingConfirmation: pendingConfirmation,
            isConfirmingPending: isConfirmingPending,
            foodEditErrorMessage: foodEditErrorMessage,
            isShowingFoodEditSheet: isShowingFoodEditSheet
        )
    }

    func coachPendingConfirmationApplyUI(_ state: CoachPendingConfirmationUIState) {
        applyPendingConfirmationUI(state)
    }

    func coachPendingConfirmationAppendAssistantMessage(
        _ text: String,
        sourceAttribution: CoachTimelineEventSourceAttribution
    ) {
        _ = messagePersistenceCoordinator.appendAssistantMessage(
            text,
            sourceAttribution: sourceAttribution
        )
    }

    func notifyPhotoFlowDraftEdited(userMessageID: UUID, mealDraft: FoodLogDraft) {
        photoFlowCoordinator.handlePendingFoodDraftEdited(
            userMessageID: userMessageID,
            mealDraft: mealDraft
        )
    }

    func logAnalytics(_ event: CoachAnalyticsEvent, properties: CoachAnalyticsProperties) {
        logCoachAnalytics(event, properties: properties)
    }
}

// MARK: - Message persistence

extension CoachModel: CoachMessagePersistenceDelegate {

    var transcriptMessages: [ChatMessage] {
        get { messages }
        set { setTranscriptMessages(newValue) }
    }

    func persistenceDidAppendStructuredMessage(_ content: CoachStructuredMessageContent) {
        logNutritionCardShown(content)
    }
}
