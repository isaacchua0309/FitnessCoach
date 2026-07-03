//
//  JourneyPresentationTypes.swift
//  Fitness Coach
//
//  Forma — Presentation section models for the Journey dashboard.
//

import Foundation

// MARK: - Shared habit taxonomy

enum JourneyHabitKind: Equatable, Sendable, CaseIterable {
    case foodLogging
    case protein
    case water
    case calorieAdherence
    case training
    case weightLogging
    case weekendLogging
}

// MARK: - Momentum

struct JourneyMomentumState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var headline: String
    var detail: String?
    var streakDays: Int
    var emptyMessage: String?

    static let hidden = JourneyMomentumState(
        isVisible: false,
        sectionTitle: FormaProductCopy.Journey.Momentum.sectionTitle,
        headline: "",
        detail: nil,
        streakDays: 0,
        emptyMessage: nil
    )
}

// MARK: - Transformation hero

struct JourneyTransformationState: Equatable {
    var isVisible: Bool
    var variant: JourneyHeroBuilder.Variant
    var title: String
    var primaryMessage: String
    var body: String
    var nextActionTitle: String?
    var nextActionCTA: JourneyCTA?
    var showsProgressBar: Bool
    var progressBarFill: Double
    var progressLabel: String
    var progressBarAccessibilityValue: String
    var showsWeightAnchors: Bool
    var weightAnchorsCopy: String?
    var accessibilitySummary: String
    var emptyMessage: String?
}

// MARK: - Goal projection

enum JourneyGoalProjectionStatus: Equatable, Sendable {
    case hidden
    case insufficientData(title: String, detail: String)
    case towardGoal(title: String, detail: String)
    case flatTrend(title: String, detail: String)
    case awayFromGoal(title: String, detail: String)
    case goalReached(title: String, detail: String)
}

struct JourneyGoalProjectionState: Equatable {
    var sectionTitle: String
    var status: JourneyGoalProjectionStatus
    var accessibilitySummary: String

    var isVisible: Bool {
        switch status {
        case .hidden:
            return false
        case .insufficientData, .towardGoal, .flatTrend, .awayFromGoal, .goalReached:
            return true
        }
    }

    var title: String {
        switch status {
        case .hidden:
            return ""
        case .insufficientData(let title, _),
             .towardGoal(let title, _),
             .flatTrend(let title, _),
             .awayFromGoal(let title, _),
             .goalReached(let title, _):
            return title
        }
    }

    var detail: String {
        switch status {
        case .hidden:
            return ""
        case .insufficientData(_, let detail),
             .towardGoal(_, let detail),
             .flatTrend(_, let detail),
             .awayFromGoal(_, let detail),
             .goalReached(_, let detail):
            return detail
        }
    }
}

// MARK: - Milestones

struct JourneyMilestoneState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var header: String
    var icon: String
    var title: String
    var progressText: String
    var progressFraction: Double
    var rewardCopy: String
    var accessibilitySummary: String
    var unlockedCount: Int
    var completedMilestoneIDs: [String]
    var legacyMilestones: JourneyMilestonesState

    var milestonesState: JourneyMilestonesState {
        legacyMilestones
    }
}

// MARK: - Story timeline

struct JourneyStoryEvent: Identifiable, Equatable {
    var id: String
    var date: Date
    var dayLabel: String
    var title: String
    var subtitle: String?
    var icon: String
    var isMajorEvent: Bool
    var eventType: JourneyTimelineEventType

    var timelineEvent: JourneyTimelineEvent {
        JourneyTimelineEvent(
            id: id,
            date: date,
            type: eventType,
            title: title,
            subtitle: subtitle,
            icon: icon,
            isMajorEvent: isMajorEvent
        )
    }

    static func fromTimelineEvent(
        _ event: JourneyTimelineEvent,
        calendar: Calendar
    ) -> JourneyStoryEvent {
        JourneyStoryEvent(
            id: event.id,
            date: event.date,
            dayLabel: JourneyFormatter.timelineDayLabel(event.date, calendar: calendar),
            title: event.title,
            subtitle: event.subtitle,
            icon: event.icon,
            isMajorEvent: event.isMajorEvent,
            eventType: event.type
        )
    }
}

// MARK: - Insights

/// Internal builder output retained for deterministic habit scoring.
struct JourneyHabitInsightsState: Equatable {
    var isUnlocked: Bool
    var lockedMessage: String?

    var strongestHabitLabel: String
    var strongestScorePercent: Int
    var strongestQualitative: String?

    var weakestHabitLabel: String
    var weakestHabitKind: JourneyHabitKind?
    var weakestScorePercent: Int
    var weakestScorePrefix: String?

    var suggestedNextAction: String
    var suggestionCTA: JourneyCTA?

    static let locked = JourneyHabitInsightsState(
        isUnlocked: false,
        lockedMessage: FormaProductCopy.Journey.HabitInsights.lockedBody,
        strongestHabitLabel: "",
        strongestScorePercent: 0,
        strongestQualitative: nil,
        weakestHabitLabel: "",
        weakestHabitKind: nil,
        weakestScorePercent: 0,
        weakestScorePrefix: nil,
        suggestedNextAction: "",
        suggestionCTA: nil
    )
}

enum JourneyPersonalizedInsightType: String, Equatable, Sendable {
    case proteinConsistency
    case waterConsistency
    case calorieOpportunity
    case workoutConsistency
    case weightTrend
    case bestHabit
    case biggestOpportunity
}

struct JourneyPersonalizedInsight: Identifiable, Equatable {
    var id: String
    var type: JourneyPersonalizedInsightType
    var title: String
    var detail: String
}

struct JourneyInsightState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var showsLearningState: Bool
    var learningTitle: String?
    var learningDetail: String?
    var insights: [JourneyPersonalizedInsight]
    var accessibilitySummary: String

    var isUnlocked: Bool {
        !showsLearningState && !insights.isEmpty
    }

    var lockedMessage: String? {
        showsLearningState ? learningDetail : nil
    }

    var strongestTitle: String {
        insights.first?.title ?? ""
    }

    var strongestDetail: String? {
        insights.first?.detail
    }

    var focusTitle: String {
        insights.count > 1 ? insights[1].title : ""
    }

    var focusDetail: String? {
        insights.count > 1 ? insights[1].detail : nil
    }

    var suggestionTitle: String {
        insights.count > 2 ? insights[2].title : ""
    }

    var suggestion: String {
        insights.count > 2 ? insights[2].detail : ""
    }

    var suggestionCTA: JourneyCTA? {
        nil
    }
}

// MARK: - Weekly habits

struct JourneyWeeklyHabitRow: Equatable, Identifiable {
    var id: String
    var icon: String
    var title: String
    var value: String
    var detail: String?
    var winScore: Double
}

struct JourneyWeeklyHabitRowState: Equatable, Identifiable {
    var id: String
    var title: String
    var weeklyCountLabel: String
    var streakLabel: String?
    var supportiveCopy: String?
    var dayCells: [Bool]
    var showsDayProgress: Bool = true
}

struct JourneyWeeklyHabitState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var showsHabitRows: Bool
    var emptyMessage: String?
    var habits: [JourneyWeeklyHabitRowState]
    var training: JourneyWeeklyTrainingStatus
    var accessibilitySummary: String
    var weeklyReviewState: JourneyWeeklyReviewState

    var rows: [JourneyWeeklyHabitRow] {
        weeklyReviewState.rows.map {
            JourneyWeeklyHabitRow(
                id: $0.id,
                icon: $0.icon,
                title: $0.title,
                value: $0.value,
                detail: $0.detail,
                winScore: $0.winScore
            )
        }
    }

    var weekSummary: String {
        weeklyReviewState.weekSummaryCopy
    }

    var consistencyHeadline: String? {
        weeklyReviewState.consistencyHeadline
    }

    var consistencyDetail: String? {
        weeklyReviewState.consistencyDetail
    }

    var weekOverWeekDetail: String? {
        weeklyReviewState.weekOverWeekDetail
    }
}

// MARK: - Monthly recap

struct JourneyMonthlyRecapMetricRow: Identifiable, Equatable {
    var id: String
    var title: String
    var value: String
}

struct JourneyMonthlyRecapState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var isComplete: Bool
    var buildingMessage: String?
    var monthWeightDeltaKg: Double?
    var calorieAdherencePercent: Double?
    var proteinAdherencePercent: Double?
    var waterAdherencePercent: Double?
    var trainingSessions: Int?
    var showsTrainingRow: Bool
    var loggedDays: Int
    var bestHabitCopy: String?
    var summaryCopy: String
    var rows: [JourneyMonthlyRecapMetricRow]
}

// MARK: - Chapter / XP

struct JourneyChapterState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var levelLabel: String
    var levelTitle: String
    var xpProgressLabel: String
    var progressPercent: Double
    var totalXP: Int
    var explanation: String
    var emptyMessage: String?

    static func fromLevel(_ level: JourneyLevelState) -> JourneyChapterState {
        let copy = FormaProductCopy.Journey.Level.self
        return JourneyChapterState(
            isVisible: level.hasData,
            sectionTitle: copy.sectionTitle,
            levelLabel: copy.levelLabel(level.currentLevel),
            levelTitle: level.levelTitle,
            xpProgressLabel: copy.xpProgress(
                current: level.currentXP,
                required: level.xpRequiredForNextLevel
            ),
            progressPercent: level.progressPercent,
            totalXP: level.totalXP,
            explanation: level.xpEarnedExplanation,
            emptyMessage: level.hasData ? nil : copy.emptyBody
        )
    }
}

/// Internal builder output for XP progression.
struct JourneyLevelState: Equatable {
    var currentLevel: Int
    var levelTitle: String
    var currentXP: Int
    var xpRequiredForNextLevel: Int
    var totalXP: Int
    var progressPercent: Double
    var xpEarnedExplanation: String
    var hasData: Bool
}
