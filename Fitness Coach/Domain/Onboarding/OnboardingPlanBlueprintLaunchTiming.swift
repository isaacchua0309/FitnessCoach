//
//  OnboardingPlanBlueprintLaunchTiming.swift
//  Fitness Coach
//
//  Forma — Shared launch-ready timing for blueprint screen animations.
//

import Foundation

enum OnboardingPlanBlueprintLaunchTiming {
    /// Delay after appear before launch-ready loops begin (matches entrance tail).
    static let readyDelay: TimeInterval = 0.32
    /// Breathing pulse for goal card, canvas, progress, and CTA glow.
    static let pulseDuration: TimeInterval = 1.35
}
