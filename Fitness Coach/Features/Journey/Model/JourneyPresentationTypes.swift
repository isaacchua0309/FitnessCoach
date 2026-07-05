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

// MARK: - Header

struct JourneyHeaderState: Equatable {
    var title: String
    var subtitle: String
    var accessibilitySummary: String
}

// MARK: - Monthly recap

enum JourneyMonthlyRecapGrade: String, Equatable, Sendable {
    case starting
    case building
    case consistent
    case strong
    case excellent
}

struct JourneyMonthlyRecapMetricRow: Identifiable, Equatable {
    var id: String
    var title: String
    var value: String
}

struct JourneyMonthlyRecapState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var showsTeaser: Bool
    var teaserTitle: String?
    var teaserDetail: String?
    var overallGrade: JourneyMonthlyRecapGrade?
    var overallGradeLabel: String?
    var loggedDays: Int
    var monthWeightDeltaKg: Double?
    var calorieAdherencePercent: Double?
    var proteinAdherencePercent: Double?
    var waterAdherencePercent: Double?
    var trainingSessions: Int?
    var bestStreakDays: Int?
    var rows: [JourneyMonthlyRecapMetricRow]
    var accessibilitySummary: String

    var isComplete: Bool {
        isVisible && !showsTeaser
    }

    var showsTrainingRow: Bool {
        trainingSessions != nil
    }
}

// MARK: - Chapter

struct JourneyChapterState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var chapterNumber: Int
    var chapterTitle: String
    var nextUnlockLabel: String?
    var progressPercent: Double
    var emptyMessage: String?
    var totalXP: Int
    var progressItems: [JourneyUnlockChecklistItem]
    var accessibilitySummary: String
}
