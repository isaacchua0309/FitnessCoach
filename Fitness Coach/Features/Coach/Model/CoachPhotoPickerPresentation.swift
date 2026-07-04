//
//  CoachPhotoPickerPresentation.swift
//  Fitness Coach
//
//  Forma — Single source of truth for Coach photo picker presentation.
//

import Foundation

/// Coordinates the attachment source dialog and one active picker at a time.
struct CoachPhotoPickerPresentation: Equatable, Sendable {
    var activePicker: CoachPhotoPickerDestination = .none
    var pendingDestination: CoachPhotoPickerDestination = .none
    var isSourceDialogPresented: Bool = false

    static let idle = CoachPhotoPickerPresentation()

    var isPresentingPicker: Bool {
        activePicker.isPresentingPicker
    }

    var canPresentPicker: Bool {
        activePicker == .none
    }

    mutating func reset() {
        self = .idle
    }

    mutating func prepareSourceDialogPresentation() {
        pendingDestination = .none
        isSourceDialogPresented = true
    }

    mutating func queueDestination(_ destination: CoachPhotoPickerDestination) {
        guard destination != .none else { return }
        pendingDestination = destination
    }

    /// Call when the source dialog dismisses. Returns the destination to present, if any.
    mutating func consumePendingDestinationOnSourceDialogDismissed() -> CoachPhotoPickerDestination {
        isSourceDialogPresented = false
        guard canPresentPicker else {
            pendingDestination = .none
            return .none
        }
        let destination = pendingDestination
        pendingDestination = .none
        return destination
    }

    mutating func present(_ destination: CoachPhotoPickerDestination) -> Bool {
        guard destination != .none, canPresentPicker else { return false }
        activePicker = destination
        return true
    }

    mutating func dismissActivePicker() {
        activePicker = .none
    }

    mutating func dismissForBlockingSheet() {
        reset()
    }

    /// Returns `true` when the source dialog was opened. Ignores duplicate requests while a dialog or picker is active.
    mutating func requestSourceDialogPresentation() -> Bool {
        guard canPresentPicker, !isSourceDialogPresented, !isPresentingPicker else {
            return false
        }
        prepareSourceDialogPresentation()
        return true
    }

    mutating func selectAttachmentSource(_ destination: CoachPhotoPickerDestination) {
        queueDestination(destination)
    }

    /// Call when the source dialog binding becomes `false`. Returns the destination to present, if any.
    mutating func finishSourceDialogDismissal() -> CoachPhotoPickerDestination {
        consumePendingDestinationOnSourceDialogDismissed()
    }

    /// Opens the photo library picker directly, or queues it to present after the source dialog dismisses.
    mutating func requestPhotoLibraryPicker() -> CoachPhotoPickerDestination {
        guard canPresentPicker else { return .none }
        if isSourceDialogPresented {
            pendingDestination = .photoLibrary
            isSourceDialogPresented = false
            return .none
        }
        return present(.photoLibrary) ? .photoLibrary : .none
    }

    /// Returns `.camera` when presentation succeeds, `.none` when blocked.
    mutating func requestCameraPicker(isCameraAvailable: Bool) -> CoachPhotoPickerDestination {
        guard canPresentPicker, isCameraAvailable else { return .none }
        return present(.camera) ? .camera : .none
    }
}
