//
//  OnboardingPlanRevealTiming.swift
//  Fitness Coach
//
//  Forma — Staged entrance timing for the plan reveal celebration.
//

import Foundation

enum OnboardingPlanRevealTiming {

    /// Matches generation → reveal screen transition (`stepTransitionAnimation`).
    static let fadeDuration: TimeInterval = OnboardingGeneratingPlanTiming.stepTransitionAnimation

    static let celebrationTitle: TimeInterval = 0
    static let achievementBadge: TimeInterval = 0.08
    static let heroIllustration: TimeInterval = 0.14
    static let goalCard: TimeInterval = 0.22
    static let goalSweepAfterGoalCard: TimeInterval = 0.10
    static let journey: TimeInterval = 0.36
    static let firstWeek: TimeInterval = 0.44
    static let nutrition: TimeInterval = 0.50
    static let coach: TimeInterval = 0.56
    static let ctaPulse: TimeInterval = 0.64

    static let sweepDuration: TimeInterval = 0.42
    static let ctaPulseDuration: TimeInterval = 0.30
    static let ambientMotionDelay: TimeInterval = 0.72

    static let springResponse: TimeInterval = 0.40
    static let springDamping: TimeInterval = 0.86

    // MARK: - Save plan continuation (plan reveal handoff)

    /// Plan artifact zones appear immediately; headline, coach note, then protect footer animate in.
    static let continuationCelebrationTitle: TimeInterval = 0
    static let continuationCoachMessage: TimeInterval = 0.14
    static let continuationProtectFooter: TimeInterval = 0.22
}
