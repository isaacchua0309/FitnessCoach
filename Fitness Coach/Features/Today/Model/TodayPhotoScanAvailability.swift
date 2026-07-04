//
//  TodayPhotoScanAvailability.swift
//  Fitness Coach
//
//  Forma — Gate for Today Scan Food until Coach photo analysis is end-to-end.
//

import Foundation

enum TodayPhotoScanAvailability {

    /// True when meal photos reach the AI photo pipeline with image bytes attached.
    static var isPipelineReady: Bool {
        FormaAbTest.Today.scanFoodEnabled && FormaAbTest.Coach.mealPhotoPipelineReady
    }
}
