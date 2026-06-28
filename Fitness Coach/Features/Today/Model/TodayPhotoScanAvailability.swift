//
//  TodayPhotoScanAvailability.swift
//  Fitness Coach
//
//  Forma — Gate for Today Scan Food until Coach photo analysis is end-to-end.
//

import Foundation

enum TodayPhotoScanAvailability {

    /// True when a meal photo can be analyzed and logged without a broken Coach handoff.
    /// Today hides Scan Food until image bytes reach the AI photo pipeline.
    static var isPipelineReady: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FORMA_TODAY_SCAN_FOOD_ENABLED"] == "1"
        #else
        return false
        #endif
    }
}
