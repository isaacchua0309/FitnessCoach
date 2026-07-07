//
//  HealthIntelligencePresentationCopy.swift
//  Fitness Coach
//
//  Forma — Centralized copy accessors for Health Intelligence presentation.
//  Bridges to FormaProductCopy; does not duplicate product strings.
//

import Foundation

enum HealthIntelligencePresentationCopy {

    // MARK: - Shared (cross-surface identical)

    enum Shared {
        static var partialDataLabel: String { FormaProductCopy.HealthIntelligence.partialDataLabel }
        static var limitedEstimateLabel: String { FormaProductCopy.HealthIntelligence.limitedEstimateLabel }
        static var buildingLabel: String { FormaProductCopy.HealthIntelligence.buildingLabel }

        static func missingRecoverySignals(_ labels: [String]) -> String {
            FormaProductCopy.Today.HealthIntelligence.missingRecoverySignals(labels)
        }
    }

    // MARK: - Today

    enum Today {
        static var workoutComplete: String { FormaProductCopy.Today.HealthIntelligence.workoutComplete }
        static var limitedEstimate: String { FormaProductCopy.Today.HealthIntelligence.limitedEstimate }
        static var staleDataLabel: String { FormaProductCopy.Today.HealthIntelligence.staleDataLabel }
        static var syncFailedWithCacheLabel: String {
            FormaProductCopy.Today.HealthIntelligence.syncFailedWithCacheLabel
        }
        static var limitedRecoveryMissingSignals: String {
            FormaProductCopy.Today.HealthIntelligence.limitedRecoveryMissingSignals
        }
        static var limitedRecoveryUnavailable: String {
            FormaProductCopy.Today.HealthIntelligence.limitedRecoveryUnavailable
        }
        static var limitedRecoveryPartialSignals: String {
            FormaProductCopy.Today.HealthIntelligence.limitedRecoveryPartialSignals
        }
        static var unknownDailyMissionHeadline: String {
            FormaProductCopy.Today.HealthIntelligence.DailyMission.unknownHeadline
        }

        enum Recovery {
            static var readyExplanation: String {
                FormaProductCopy.Today.HealthIntelligence.Recovery.readyExplanation
            }
            static var moderateExplanation: String {
                FormaProductCopy.Today.HealthIntelligence.Recovery.moderateExplanation
            }
            static var lowExplanation: String {
                FormaProductCopy.Today.HealthIntelligence.Recovery.lowExplanation
            }
        }

        enum Workout {
            static var emptyTitle: String { FormaProductCopy.Today.HealthIntelligence.Workout.emptyTitle }
            static var emptyMessage: String { FormaProductCopy.Today.HealthIntelligence.Workout.emptyMessage }
        }

        enum AdaptiveNutrition {
            static var postWorkoutTitle: String {
                FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.postWorkoutTitle
            }
            static var defaultTitle: String {
                FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.defaultTitle
            }

            static func extraWater(_ ml: Int) -> String {
                FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.extraWater(ml)
            }

            static func proteinRemaining(_ grams: Int) -> String {
                FormaProductCopy.Today.HealthIntelligence.AdaptiveNutrition.proteinRemaining(grams)
            }
        }

        enum DailyMission {
            static func proteinRemaining(_ grams: Double) -> String {
                FormaProductCopy.Today.HealthIntelligence.DailyMission.proteinRemaining(grams)
            }

            static func waterRemaining(_ ml: Int) -> String {
                FormaProductCopy.Today.HealthIntelligence.DailyMission.waterRemaining(ml)
            }
        }
    }

    // MARK: - Journey

    enum Journey {
        static var limitedEstimate: String { FormaProductCopy.Journey.HealthIntelligence.limitedEstimate }
        static var staleDataLabel: String { FormaProductCopy.Journey.HealthIntelligence.staleDataLabel }
        static var syncFailedWithCacheLabel: String {
            FormaProductCopy.Journey.HealthIntelligence.syncFailedWithCacheLabel
        }
        static var connectedNoWorkoutsMessage: String {
            FormaProductCopy.Journey.HealthIntelligence.connectedNoWorkoutsMessage
        }
        static var healthDataSyncing: String { FormaProductCopy.Journey.Sync.healthDataSyncing }
        static var buildingFirstTrend: String { FormaProductCopy.Journey.EmptyState.buildingFirstTrend }
        static var weeklyConfidenceBuilding: String { FormaProductCopy.Journey.WeeklyConfidence.building }

        enum WorkoutHistory {
            static var emptyMessage: String {
                FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.emptyMessage
            }
        }

        enum Recovery {
            static var limitedMissingSignals: String {
                "Limited estimate because key recovery signals are missing."
            }
            static var unavailableSignals: String { "Not enough recovery signals yet." }
            static var partialSignals: String { "Limited estimate from partial recovery signals." }
        }
    }

    // MARK: - Plan

    enum Plan {
        static func insightKindLabel(for kind: HealthInsightKind) -> String {
            let copy = FormaProductCopy.PlanHealthIntelligencePresentation.self
            switch kind {
            case .workouts:
                return copy.signalAppleHealthWorkouts
            case .steps, .activeEnergy, .exerciseMinutes:
                return copy.signalStepHistory
            case .sleep:
                return copy.signalSleep
            case .restingHeartRate, .hrv:
                return copy.signalHeartMetrics
            case .weight:
                return copy.signalWeight
            case .recoveryBaseline, .remoteSync:
                return copy.dataQualitySectionTitle
            }
        }
    }

    // MARK: - Weekly review

    enum WeeklyReview {
        static var emptyTitle: String { FormaProductCopy.WeeklyReviewPresentation.emptyTitle }
        static var emptySummary: String { FormaProductCopy.WeeklyReviewPresentation.emptySummary }
        static var emptyAccessibilityLabel: String {
            FormaProductCopy.WeeklyReviewPresentation.emptyAccessibilityLabel
        }
        static var notEnoughDataSummary: String {
            FormaProductCopy.WeeklyReviewPresentation.notEnoughDataSummary
        }
    }

    // MARK: - UI state messages

    static func uiStateMessage(
        for kind: HealthIntelligenceUIStateKind,
        surface: HealthIntelligenceSurface,
        explicitErrorMessage: String? = nil
    ) -> HealthIntelligenceUIStateMessage {
        FormaProductCopy.HealthIntelligence.UIState.message(
            for: kind,
            surface: surface,
            explicitErrorMessage: explicitErrorMessage
        )
    }

    // MARK: - Stale labels (surface-specific)

    static func staleDataLabel(for surface: HealthIntelligenceSurface) -> String {
        switch surface {
        case .journey:
            return Journey.staleDataLabel
        case .today, .plan, .coach:
            return Today.staleDataLabel
        }
    }

    static func syncFailedWithCacheLabel(for surface: HealthIntelligenceSurface) -> String {
        switch surface {
        case .journey:
            return Journey.syncFailedWithCacheLabel
        case .today, .plan, .coach:
            return Today.syncFailedWithCacheLabel
        }
    }
}
