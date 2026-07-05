//
//  PlanEditDiscardConfirmationPolicy.swift
//  Fitness Coach
//
//  Forma — Cancel / discard confirmation routing for the Adjust Plan wizard.
//

import Foundation

enum PlanEditDiscardConfirmationPolicy {

    enum CancelRequestAction: Equatable {
        case dismissImmediately
        case presentConfirmation
    }

    static func cancelRequestAction(hasUnsavedChanges: Bool) -> CancelRequestAction {
        hasUnsavedChanges ? .presentConfirmation : .dismissImmediately
    }
}

struct PlanEditDiscardConfirmationState: Equatable {

    private(set) var isShowingConfirmation = false

    @discardableResult
    mutating func handleCancelRequest(hasUnsavedChanges: Bool) -> PlanEditDiscardConfirmationPolicy.CancelRequestAction {
        let action = PlanEditDiscardConfirmationPolicy.cancelRequestAction(
            hasUnsavedChanges: hasUnsavedChanges
        )
        if action == .presentConfirmation {
            isShowingConfirmation = true
        }
        return action
    }

    mutating func keepEditing() {
        isShowingConfirmation = false
    }

    mutating func dismissConfirmation() {
        isShowingConfirmation = false
    }
}
