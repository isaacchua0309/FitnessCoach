//
//  CoachLaunchIntent.swift
//  Fitness Coach
//
//  Forma — One-shot launch routing into Coach without duplicating Coach state.
//

import Foundation

enum CoachLaunchIntent: Equatable, Sendable {
    /// Standard Coach tab — no launch-specific starter chrome.
    case normal
    /// Meal logging via photo, text, or voice.
    case logMeal(mealType: MealType?)
    /// Photo meal analysis (Today Scan Food and similar entry points).
    case analyzePhotoMeal
    /// Hydration logging via Coach command pipeline.
    case logWater(amountMl: Int = 500)
    /// Legacy text prefill for Journey / review / protein / weight prompts.
    case prefill(String)
}
