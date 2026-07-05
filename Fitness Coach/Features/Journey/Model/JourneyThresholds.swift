//
//  JourneyThresholds.swift
//  Fitness Coach
//
//  Forma — Named Journey unlock and ritual thresholds (single source of truth).
//

import Foundation

/// Shared numeric gates for Journey presentation, unlocks, and next-best-action selection.
enum JourneyThresholds {

    // MARK: Weekly review ritual

    /// Minimum distinct days with meal calories logged to unlock the weekly review ritual.
    static let requiredMealLoggingDays = WeeklyProgressConfidencePolicy.minimumFoodLoggedDays

    /// Minimum calendar days in the review window before maintenance / weekly review unlock.
    static let requiredCalendarSpanDays = WeeklyProgressConfidencePolicy.minimumCalendarSpanDays

    /// Minimum weigh-ins in the canonical review window for weight-trend unlock.
    static let requiredWeighIns = WeeklyProgressConfidencePolicy.minimumWeightEntries

    /// Minimum recovery days with usable signals before recovery baseline unlock.
    static let requiredRecoveryDays = 5

    /// Minimum days with average step data before steps are shown in weekly stats.
    static let requiredStepDays = 3

    // MARK: Journey maturity

    /// Logging streak days that qualify as “meaningful” journey data for section unlock.
    static let meaningfulCheckInStreakDays = 2

    /// Check-in streak days shown as a Chapter 1 progress milestone.
    static let chapterCheckInStreakDays = 3

    /// Chapter XP awarded per chapter advancement (must match `JourneyChapterBuilder`).
    static let chapterXPPerLevel = 200

    // MARK: Story timeline

    /// Maximum story events shown on the Journey dashboard.
    static let maxDisplayedStoryEvents = 12
}
