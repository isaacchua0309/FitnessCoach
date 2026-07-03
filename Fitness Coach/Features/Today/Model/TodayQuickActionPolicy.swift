//
//  TodayQuickActionPolicy.swift
//  Fitness Coach
//
//  Forma — Which quick actions appear on Today and in what order.
//

import Foundation

enum TodayQuickActionPolicy {

    static func menuItems(
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> [TodayQuickActionMenuItem] {
        [
            scanFoodItem(isAvailable: isScanFoodAvailable),
            TodayQuickActionMenuItem(kind: .logMeal, isEnabled: true, disabledReason: nil),
            TodayQuickActionMenuItem(
                kind: .manualEntry,
                isEnabled: true,
                disabledReason: nil,
                presentation: .secondary
            ),
            TodayQuickActionMenuItem(kind: .addWater, isEnabled: true, disabledReason: nil),
            TodayQuickActionMenuItem(kind: .logWeight, isEnabled: true, disabledReason: nil),
            TodayQuickActionMenuItem(kind: .logWorkout, isEnabled: true, disabledReason: nil)
        ]
    }

    static func isVisible(
        _ kind: TodayQuickActionKind,
        isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady
    ) -> Bool {
        menuItems(isScanFoodAvailable: isScanFoodAvailable).contains { $0.kind == kind }
    }

    private static func scanFoodItem(isAvailable: Bool) -> TodayQuickActionMenuItem {
        TodayQuickActionMenuItem(
            kind: .scanFood,
            isEnabled: isAvailable,
            disabledReason: isAvailable ? nil : FormaProductCopy.Today.QuickActions.scanFoodUnavailableNote
        )
    }
}
