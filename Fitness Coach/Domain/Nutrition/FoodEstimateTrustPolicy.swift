//
//  FoodEstimateTrustPolicy.swift
//  Fitness Coach
//
//  FitPilot AI — Trust gates for Coach food estimate confirmation.
//

import Foundation

struct FoodEstimateTrustGateResult: Equatable, Sendable {
    var canConfirm: Bool
    var blockedReason: String?
    var sanityFailed: Bool
    var requiresEditBeforeConfirm: Bool
}

enum FoodEstimateTrustPolicy {

    static let editBeforeLoggingMessage =
        "This estimate needs a portion review. Tap Edit to adjust before logging."

    /// Blocks one-tap confirm when sanity failed unless the user edited the pending draft.
    static func confirmGate(
        sanityResult: NutritionSanityResult,
        userEditedBeforeConfirm: Bool
    ) -> FoodEstimateTrustGateResult {
        let sanityFailed = !sanityResult.isAcceptable
        let requiresEdit = sanityFailed && !userEditedBeforeConfirm
        return FoodEstimateTrustGateResult(
            canConfirm: !requiresEdit,
            blockedReason: requiresEdit ? editBeforeLoggingMessage : nil,
            sanityFailed: sanityFailed,
            requiresEditBeforeConfirm: requiresEdit
        )
    }

    static func confirmGate(
        sanityWarning: String?,
        userEditedBeforeConfirm: Bool
    ) -> FoodEstimateTrustGateResult {
        let sanityFailed = sanityWarning != nil
        let requiresEdit = sanityFailed && !userEditedBeforeConfirm
        return FoodEstimateTrustGateResult(
            canConfirm: !requiresEdit,
            blockedReason: requiresEdit ? editBeforeLoggingMessage : nil,
            sanityFailed: sanityFailed,
            requiresEditBeforeConfirm: requiresEdit
        )
    }
}
