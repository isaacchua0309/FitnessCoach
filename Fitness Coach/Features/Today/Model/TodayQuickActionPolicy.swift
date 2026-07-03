//
//  TodayQuickActionPolicy.swift
//  Fitness Coach
//
//  Forma — Which quick actions appear on Today and in what order.
//

import Foundation

struct TodayQuickActionsConfiguration: Equatable, Sendable {
    var showsScanMeal: Bool
}

enum TodayQuickActionPolicy {

    static func configuration(
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> TodayQuickActionsConfiguration {
        TodayQuickActionsConfiguration(showsScanMeal: isScanFoodAvailable)
    }

    static func isVisible(
        _ kind: TodayQuickActionKind,
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> Bool {
        switch kind {
        case .logMeal:
            return true
        case .scanFood:
            return isScanFoodAvailable
        case .addWater, .logWeight, .logWorkout:
            return false
        }
    }
}
