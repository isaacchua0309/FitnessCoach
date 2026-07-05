//
//  PlanEditMotion.swift
//  Fitness Coach
//
//  Forma — Lightweight motion tokens for the Edit Plan wizard.
//

import SwiftUI

enum PlanEditMotion {

    static let stepTransition = Animation.easeInOut(duration: 0.28)
    static let stepTransitionDuration: TimeInterval = 0.28

    static let heroUpdate = Animation.easeInOut(duration: 0.24)
    static let selection = Animation.easeOut(duration: 0.22)
    static let progress = Animation.easeInOut(duration: 0.28)
    static let successReveal = Animation.easeOut(duration: 0.30)
    static let modalPresentation = Animation.easeOut(duration: 0.24)

    /// Subtle emphasis — small enough to avoid layout clipping.
    static let selectedScale: CGFloat = 1.012

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    static func withAnimationIfEnabled(
        _ animation: Animation,
        reduceMotion: Bool,
        _ body: () -> Void
    ) {
        if reduceMotion {
            body()
        } else {
            withAnimation(animation, body)
        }
    }

    static var stepContentTransition: AnyTransition {
        .opacity
    }
}
