//
//  WeeklyProgressAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed Weekly Progress Loop v1 analytics events and safe property bag.
//  Privacy: no raw weight, calories, food names, review text, or full UID.
//

import Foundation

enum WeeklyProgressAnalyticsEvent: String, Sendable {
    case cardViewed = "weekly_progress_card_viewed"
    case reviewOpened = "weekly_review_opened"
    case reviewCompleted = "weekly_review_completed"
    case maintenanceEstimateShown = "maintenance_estimate_shown"
    case maintenanceEstimateInsufficientData = "maintenance_estimate_insufficient_data"
    case maintenanceConfidenceLow = "maintenance_confidence_low"
    case planRecommendationShown = "plan_recommendation_shown"
    case planRecommendationTapped = "plan_recommendation_tapped"
    case planEditStartedFromWeeklyReview = "plan_edit_started_from_weekly_review"
    case weightSpikeExplanationShown = "weight_spike_explanation_shown"
    case dailyReviewTeaserViewed = "daily_review_teaser_viewed"
    case dailyReviewOpenedFromToday = "daily_review_opened_from_today"
    case restorePending = "weekly_progress_restore_pending"
    case staleOrSyncing = "weekly_progress_stale_or_syncing"
}

enum WeeklyProgressAnalyticsSurface: String, Sendable {
    case journeyCard = "journey_card"
    case journeyDetail = "journey_detail"
    case planDashboard = "plan_dashboard"
    case todayTeaser = "today_teaser"
}

enum WeeklyProgressAnalyticsEntryPoint: String, Sendable {
    case journeyCard = "journey_card"
    case journeyDetail = "journey_detail"
    case planDashboard = "plan_dashboard"
    case todayTeaser = "today_teaser"
    case weeklyReview = "weekly_review"
    case journeyRecommendation = "journey_recommendation"
}

enum WeeklyProgressAnalyticsFoodLoggedDaysBucket: String, Sendable {
    case none
    case low = "1_2"
    case building = "3_4"
    case strong = "5_6"
    case full = "7"
}

enum WeeklyProgressAnalyticsWeightEntryCountBucket: String, Sendable {
    case zero = "0"
    case low = "1_2"
    case medium = "3_4"
    case high = "5_plus"
}

enum WeeklyProgressAnalyticsDataWindowDaysBucket: String, Sendable {
    case unknown
    case week = "7"
    case twoWeeks = "8_14"
    case threeWeeks = "15_27"
    case monthPlus = "28_plus"
}

struct WeeklyProgressAnalyticsProperties: Sendable {
    var confidenceLevel: String?
    var dataWindowDays: String?
    var foodLoggedDaysBucket: String?
    var weightEntryCountBucket: String?
    var recommendationKind: String?
    var hasMaintenanceEstimate: Bool?
    var hasWeightSpike: Bool?
    var entryPoint: String?
    var surface: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let confidenceLevel { parameters["confidence_level"] = confidenceLevel }
        if let dataWindowDays { parameters["data_window_days"] = dataWindowDays }
        if let foodLoggedDaysBucket { parameters["food_logged_days_bucket"] = foodLoggedDaysBucket }
        if let weightEntryCountBucket { parameters["weight_entry_count_bucket"] = weightEntryCountBucket }
        if let recommendationKind { parameters["recommendation_kind"] = recommendationKind }
        if let hasMaintenanceEstimate {
            parameters["has_maintenance_estimate"] = hasMaintenanceEstimate ? "true" : "false"
        }
        if let hasWeightSpike {
            parameters["has_weight_spike"] = hasWeightSpike ? "true" : "false"
        }
        if let entryPoint { parameters["entry_point"] = entryPoint }
        if let surface { parameters["surface"] = surface }
        return parameters
    }
}

protocol WeeklyProgressAnalyticsLogging: Sendable {
    func log(_ event: WeeklyProgressAnalyticsEvent, properties: WeeklyProgressAnalyticsProperties)
}

enum WeeklyProgressAnalyticsContextBuilder {

    static func properties(
        from summary: WeeklyProgressSummary,
        recommendationKind: WeeklyPlanRecommendationKind? = nil,
        surface: WeeklyProgressAnalyticsSurface? = nil,
        entryPoint: WeeklyProgressAnalyticsEntryPoint? = nil
    ) -> WeeklyProgressAnalyticsProperties {
        let maintenance = summary.maintenanceEstimate
        let sufficiency = maintenance.sufficiency
        let showsLearnedMaintenance = sufficiency.isEligibleForKcalMaintenanceDisplay
            && maintenance.estimatedMaintenanceKcal != nil

        return WeeklyProgressAnalyticsProperties(
            confidenceLevel: summary.confidence.rawValue,
            dataWindowDays: dataWindowDaysBucket(spanDays: sufficiency.calendarSpanDays).rawValue,
            foodLoggedDaysBucket: foodLoggedDaysBucket(foodLoggedDays: summary.foodLoggedDays).rawValue,
            weightEntryCountBucket: weightEntryCountBucket(
                weightEntryCount: sufficiency.weightEntryCount
            ).rawValue,
            recommendationKind: recommendationKind?.rawValue,
            hasMaintenanceEstimate: showsLearnedMaintenance,
            hasWeightSpike: summary.hasSuddenSpike,
            entryPoint: entryPoint?.rawValue,
            surface: surface?.rawValue
        )
    }

    static func properties(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        calendarSpanDays: Int,
        confidence: WeeklyProgressConfidenceLevel,
        hasWeightSpike: Bool = false,
        hasMaintenanceEstimate: Bool = false,
        recommendationKind: WeeklyPlanRecommendationKind? = nil,
        surface: WeeklyProgressAnalyticsSurface? = nil,
        entryPoint: WeeklyProgressAnalyticsEntryPoint? = nil
    ) -> WeeklyProgressAnalyticsProperties {
        WeeklyProgressAnalyticsProperties(
            confidenceLevel: confidence.rawValue,
            dataWindowDays: dataWindowDaysBucket(spanDays: calendarSpanDays).rawValue,
            foodLoggedDaysBucket: foodLoggedDaysBucket(foodLoggedDays: foodLoggedDays).rawValue,
            weightEntryCountBucket: weightEntryCountBucket(weightEntryCount: weightEntryCount).rawValue,
            recommendationKind: recommendationKind?.rawValue,
            hasMaintenanceEstimate: hasMaintenanceEstimate,
            hasWeightSpike: hasWeightSpike,
            entryPoint: entryPoint?.rawValue,
            surface: surface?.rawValue
        )
    }

    static func foodLoggedDaysBucket(foodLoggedDays: Int) -> WeeklyProgressAnalyticsFoodLoggedDaysBucket {
        switch max(foodLoggedDays, 0) {
        case 0:
            return .none
        case 1...2:
            return .low
        case 3...4:
            return .building
        case 5...6:
            return .strong
        default:
            return .full
        }
    }

    static func weightEntryCountBucket(
        weightEntryCount: Int
    ) -> WeeklyProgressAnalyticsWeightEntryCountBucket {
        switch max(weightEntryCount, 0) {
        case 0:
            return .zero
        case 1...2:
            return .low
        case 3...4:
            return .medium
        default:
            return .high
        }
    }

    static func dataWindowDaysBucket(spanDays: Int) -> WeeklyProgressAnalyticsDataWindowDaysBucket {
        switch max(spanDays, 0) {
        case 0:
            return .unknown
        case 1...7:
            return .week
        case 8...14:
            return .twoWeeks
        case 15...27:
            return .threeWeeks
        default:
            return .monthPlus
        }
    }

    static func isStaleOrSyncing(_ input: WeeklyProgressFreshnessInput?) -> Bool {
        guard let input else { return false }
        if input.isRestoringAccount { return true }
        if input.isCrossDeviceRefreshing { return true }
        if let pendingUploadCount = input.pendingUploadCount, pendingUploadCount > 0 {
            return true
        }
        return false
    }
}
