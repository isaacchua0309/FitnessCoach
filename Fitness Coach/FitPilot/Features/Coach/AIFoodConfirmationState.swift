//
//  AIFoodConfirmationState.swift
//  Fitness Coach
//
//  FitPilot AI — State for pending AI food confirmation in Coach.
//

import Foundation

enum AIFoodConfirmationState: Equatable {
    case none
    case pending(AIFoodConfirmationDraft)
    case saving(AIFoodConfirmationDraft)
    case error(AIFoodConfirmationDraft, String)

    var pendingDraft: AIFoodConfirmationDraft? {
        switch self {
        case .none:
            return nil
        case .pending(let draft), .saving(let draft), .error(let draft, _):
            return draft
        }
    }
}
