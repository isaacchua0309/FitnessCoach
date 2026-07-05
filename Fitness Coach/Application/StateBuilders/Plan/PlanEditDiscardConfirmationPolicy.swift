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
