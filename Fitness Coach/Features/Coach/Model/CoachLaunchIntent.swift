//
//  CoachLaunchIntent.swift
//  Fitness Coach
//
//  Forma — Lightweight launch routing into Coach without duplicating Coach state.
//

import Foundation

enum CoachLaunchIntent: Equatable, Sendable {
    /// Opens Coach ready for photo, text, or voice meal logging.
    case logMeal(mealType: MealType?)
    /// Opens Coach with the scan-meal prefill (photo pipeline).
    case scanFood
    /// Generic text prefill for Journey, review, protein, water, etc.
    case prefill(String)
}
