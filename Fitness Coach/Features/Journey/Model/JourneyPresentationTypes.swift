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
    case projected(
        title: String,
        detail: String,
        etaLabel: String?,
        confidenceLabel: String?,
        remainingLabel: String?
    )
}

struct JourneyGoalProjectionState: Equatable {
    var sectionTitle: String
    var status: JourneyGoalProjectionStatus

    var isVisible: Bool {
        switch status {
        case .hidden:
            return false
        case .insufficientData, .projected:
            return true
        }
    }
}

// MARK: - Milestones

struct JourneyMilestoneState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var unlocked: [JourneyMilestone]
    var upcoming: [JourneyMilestone]
    var next: JourneyMilestone?
    var nextProgressFraction: Double?
    var items: [JourneyMilestone]
    var emptyMessage: String?

    var milestonesState: JourneyMilestonesState {
        JourneyMilestonesState(
            unlocked: unlocked,
            upcoming: upcoming,
            next: next,
            nextProgressFraction: nextProgressFraction,
            items: items
        )
    }

    static func fromMilestones(_ milestones: JourneyMilestonesState) -> JourneyMilestoneState {
        let hasProgress = !milestones.unlocked.isEmpty
            || milestones.items.contains { $0.status == .completed }
            || (milestones.nextProgressFraction ?? 0) > 0

        return JourneyMilestoneState(
            isVisible: hasProgress,
            sectionTitle: FormaProductCopy.Journey.Milestones.sectionTitle,
            unlocked: milestones.unlocked,
            upcoming: milestones.upcoming,
            next: milestones.next,
            nextProgressFraction: milestones.nextProgressFraction,
            items: milestones.items,
            emptyMessage: milestones.items.isEmpty
                ? FormaProductCopy.Journey.Milestones.emptyBody
                : nil
        )
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

struct JourneyInsightState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var isUnlocked: Bool
    var lockedMessage: String?
    var strongestTitle: String
    var strongestDetail: String?
    var focusTitle: String
    var focusDetail: String?
    var suggestionTitle: String
    var suggestion: String
    var suggestionCTA: JourneyCTA?

    static func fromHabitInsights(_ insights: JourneyHabitInsightsState) -> JourneyInsightState {
        let copy = FormaProductCopy.Journey.HabitInsights.self
        guard insights.isUnlocked else {
            return JourneyInsightState(
                isVisible: true,
                sectionTitle: copy.sectionTitle,
                isUnlocked: false,
                lockedMessage: insights.lockedMessage ?? copy.lockedBody,
                strongestTitle: "",
                strongestDetail: nil,
                focusTitle: "",
                focusDetail: nil,
                suggestionTitle: "",
                suggestion: "",
                suggestionCTA: nil
            )
        }

        let strongestDetail = [
            insights.strongestHabitLabel,
            insights.strongestQualitative
        ]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " — ")

        let focusDetail = insights.weakestHabitLabel.isEmpty
            ? nil
            : "\(insights.weakestHabitLabel) · \(insights.weakestScorePercent)%"

        return JourneyInsightState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            isUnlocked: true,
            lockedMessage: nil,
            strongestTitle: copy.strongestTitle,
            strongestDetail: strongestDetail.isEmpty ? nil : strongestDetail,
            focusTitle: copy.nextFocusTitle,
            focusDetail: focusDetail,
            suggestionTitle: copy.suggestionTitle,
            suggestion: insights.suggestedNextAction,
            suggestionCTA: insights.suggestionCTA
        )
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

struct JourneyWeeklyHabitState: Equatable {
    var isVisible: Bool
    var sectionTitle: String
    var weekSummary: String
    var rows: [JourneyWeeklyHabitRow]
    var consistencyHeadline: String?
    var consistencyDetail: String?
    var weekOverWeekDetail: String?
    var training: JourneyWeeklyTrainingStatus
    var emptyMessage: String?
    var weeklyReviewState: JourneyWeeklyReviewState

    static func fromWeeklyReview(_ review: JourneyWeeklyReviewState) -> JourneyWeeklyHabitState {
        let copy = FormaProductCopy.Journey.WeeklyReview.self
        let isEmpty = review.foodLoggedDays == 0
            && review.proteinGoalDays == 0
            && review.waterGoalDays == 0
            && review.trainingDays == 0

        return JourneyWeeklyHabitState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            weekSummary: review.weekSummaryCopy,
            rows: review.rows.map {
                JourneyWeeklyHabitRow(
                    id: $0.id,
                    icon: $0.icon,
                    title: $0.title,
                    value: $0.value,
                    detail: $0.detail,
                    winScore: $0.winScore
                )
            },
            consistencyHeadline: review.consistencyHeadline,
            consistencyDetail: review.consistencyDetail,
            weekOverWeekDetail: review.weekOverWeekDetail,
            training: review.training,
            emptyMessage: isEmpty ? copy.noFoodLogsSummary : nil,
            weeklyReviewState: review
        )
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
