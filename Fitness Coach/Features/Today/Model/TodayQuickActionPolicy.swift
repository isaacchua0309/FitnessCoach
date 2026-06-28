//
//  TodayQuickActionPolicy.swift
//  Fitness Coach
//
//  Forma — Which quick actions appear in the Today FAB menu.
//

import Foundation

enum TodayQuickActionPolicy {

    static func menuItems(isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady) -> [TodayQuickActionMenuItem] {
        var items: [TodayQuickActionMenuItem] = []

        if isScanFoodAvailable {
            items.append(
                TodayQuickActionMenuItem(kind: .scanFood, isEnabled: true, disabledReason: nil)
            )
        }

        items.append(contentsOf: [
            TodayQuickActionMenuItem(kind: .manualEntry, isEnabled: true, disabledReason: nil),
            TodayQuickActionMenuItem(kind: .addWater, isEnabled: true, disabledReason: nil),
            TodayQuickActionMenuItem(kind: .logWeight, isEnabled: true, disabledReason: nil),
            TodayQuickActionMenuItem(kind: .askCoach, isEnabled: true, disabledReason: nil)
        ])

        return items
    }

    static func isVisible(_ kind: TodayQuickActionKind, isScanFoodAvailable: Bool = TodayPhotoScanAvailability.isPipelineReady) -> Bool {
        menuItems(isScanFoodAvailable: isScanFoodAvailable).contains { $0.kind == kind && $0.isEnabled }
    }
}
