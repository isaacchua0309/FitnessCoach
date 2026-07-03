//
//  TodayQuickActionPolicy.swift
//  Fitness Coach
//
//  Forma — Which quick actions appear on Today and in what order.
//

import Foundation

struct TodayQuickActionsConfiguration: Equatable, Sendable {
    var showsScanMeal: Bool
    var waterPresetAmountsMl: [Int]
}

enum TodayQuickActionPolicy {

    static func configuration(
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> TodayQuickActionsConfiguration {
        TodayQuickActionsConfiguration(
            showsScanMeal: isScanFoodAvailable,
            waterPresetAmountsMl: TodayActionCoordinator.defaultWaterPresetAmountsMl
        )
    }

    static func isVisible(
        _ kind: TodayQuickActionKind,
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> Bool {
        switch kind {
        case .logMeal, .addWater:
            return true
        case .scanFood:
            return isScanFoodAvailable
        case .logWeight, .logWorkout:
            return false
        }
    }
}
