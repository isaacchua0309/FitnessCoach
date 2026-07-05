//
//  CoachModelStateReducer.swift
//  Fitness Coach
//
//  Forma — Pure Coach surface-state transitions for processing, errors, launch chrome,
//  and pending-confirmation UI fields.
//

import Foundation

struct CoachTransientErrorState: Equatable {
    var title: String?
    var message: String?
    var showsAuthRetry: Bool

    static let cleared = CoachTransientErrorState(
        title: nil,
        message: nil,
        showsAuthRetry: false
    )
}

struct CoachLaunchChromeState: Equatable {
    var activeLaunchPresentation: CoachLaunchPresentation?
    var composerPlaceholderOverride: String?
    var requestsComposerFocus: Bool
    var requestsCameraPresentation: Bool

    static let initial = CoachLaunchChromeState(
        activeLaunchPresentation: nil,
        composerPlaceholderOverride: nil,
        requestsComposerFocus: false,
        requestsCameraPresentation: false
    )
}

struct CoachPendingConfirmationUIState: Equatable {
    var pendingConfirmation: CoachPendingConfirmation?
    var isConfirmingPending: Bool
    var foodEditErrorMessage: String?
    var isShowingFoodEditSheet: Bool

    static let empty = CoachPendingConfirmationUIState(
        pendingConfirmation: nil,
        isConfirmingPending: false,
        foodEditErrorMessage: nil,
        isShowingFoodEditSheet: false
    )
}

enum CoachModelStateReducer {

    // MARK: Processing phase

    static func isSending(processingPhase: CoachProcessingPhase) -> Bool {
        if case .idle = processingPhase { return false }
        return true
    }

    static func processingPhase(for operation: CoachProcessingOperation) -> CoachProcessingPhase {
        .active(operation)
    }

    static let idleProcessingPhase: CoachProcessingPhase = .idle

    // MARK: Transient errors

    static func sessionFailureError() -> CoachTransientErrorState {
        CoachTransientErrorState(
            title: AIServiceError.coachSessionFailureTitle,
            message: AIServiceError.coachSessionFailureMessage,
            showsAuthRetry: true
        )
    }

    static func clearedError() -> CoachTransientErrorState {
        .cleared
    }

    // MARK: Launch chrome

    static func consumeLaunchPresentation(_ state: CoachLaunchChromeState) -> CoachLaunchChromeState {
        var next = state
        next.activeLaunchPresentation = nil
        next.requestsComposerFocus = false
        return next
    }

    static func clearComposerLaunchChrome(_ state: CoachLaunchChromeState) -> CoachLaunchChromeState {
        var next = state
        next.composerPlaceholderOverride = nil
        return next
    }

    static func abandonLaunchSession(_ state: CoachLaunchChromeState) -> CoachLaunchChromeState {
        clearComposerLaunchChrome(
            consumeLaunchPresentation(state).settingCameraPresentation(false)
        )
    }

    static func applyLaunchPresentation(
        _ state: CoachLaunchChromeState,
        presentation: CoachLaunchPresentation,
        requestsCameraPresentation: Bool
    ) -> CoachLaunchChromeState {
        var next = state
        next.activeLaunchPresentation = presentation
        next.composerPlaceholderOverride = presentation.composerPlaceholder
        next.requestsComposerFocus = presentation.focusesComposer
        next.requestsCameraPresentation = requestsCameraPresentation
        return next
    }

    static func requestComposerFocus(_ state: CoachLaunchChromeState) -> CoachLaunchChromeState {
        var next = state
        next.requestsComposerFocus = true
        return next
    }

    static func consumeComposerFocusRequest(_ state: CoachLaunchChromeState) -> CoachLaunchChromeState {
        var next = state
        next.requestsComposerFocus = false
        return next
    }

    static func clearCameraPresentationRequest(_ state: CoachLaunchChromeState) -> CoachLaunchChromeState {
        state.settingCameraPresentation(false)
    }

    // MARK: Pending confirmation UI

    static func setPendingConfirmationUI(
        _ state: CoachPendingConfirmationUIState,
        confirmation: CoachPendingConfirmation
    ) -> CoachPendingConfirmationUIState {
        var next = state
        next.pendingConfirmation = confirmation
        next.foodEditErrorMessage = nil
        next.isShowingFoodEditSheet = false
        return next
    }

    static func clearPendingConfirmationUI(
        _ state: CoachPendingConfirmationUIState
    ) -> CoachPendingConfirmationUIState {
        .empty
    }

    static func beginConfirmingPendingUI(
        _ state: CoachPendingConfirmationUIState
    ) -> CoachPendingConfirmationUIState {
        var next = state
        next.isConfirmingPending = true
        return next
    }

    static func endConfirmingPendingUI(
        _ state: CoachPendingConfirmationUIState
    ) -> CoachPendingConfirmationUIState {
        var next = state
        next.isConfirmingPending = false
        return next
    }

    static func openFoodEditSheetUI(
        _ state: CoachPendingConfirmationUIState
    ) -> CoachPendingConfirmationUIState? {
        guard state.pendingConfirmation?.foodDraft != nil else { return nil }
        var next = state
        next.foodEditErrorMessage = nil
        next.isShowingFoodEditSheet = true
        return next
    }

    static func dismissFoodEditSheetUI(
        _ state: CoachPendingConfirmationUIState
    ) -> CoachPendingConfirmationUIState {
        var next = state
        next.isShowingFoodEditSheet = false
        return next
    }

    static func saveFoodEditSucceededUI(
        _ state: CoachPendingConfirmationUIState,
        draft: AIFoodConfirmationDraft
    ) -> CoachPendingConfirmationUIState {
        var next = state
        next.pendingConfirmation = .food(draft)
        next.foodEditErrorMessage = nil
        next.isShowingFoodEditSheet = false
        return next
    }

    static func saveFoodEditFailedUI(
        _ state: CoachPendingConfirmationUIState,
        message: String
    ) -> CoachPendingConfirmationUIState {
        var next = state
        next.foodEditErrorMessage = message
        return next
    }

    // MARK: Composer input sync

    static func inputState(
        _ inputState: CoachInputState,
        syncedToSending isSending: Bool
    ) -> CoachInputState {
        var next = inputState
        next.setSending(isSending)
        return next
    }
}

private extension CoachLaunchChromeState {
    func settingCameraPresentation(_ requestsCameraPresentation: Bool) -> CoachLaunchChromeState {
        var next = self
        next.requestsCameraPresentation = requestsCameraPresentation
        return next
    }
}
