//
//  UnifiedWeeklyReviewPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Canonical weekly progress presentation merging Journey habits,
//  WeeklyProgressSummary, and optional Health Intelligence weekly review.
//

import Foundation

// MARK: - Presentation state

struct UnifiedWeeklyReviewState: Equatable, Identifiable {
    let id: String
    let weekTitle: String
    let dateRangeText: String
    let headline: String
    let summary: String
    /// Short card title for the unified This Week section, e.g. "Getting started".
    let cardStateTitle: String
    /// Single-paragraph card body for the unified This Week section.
    let cardSummary: String
    let compactStats: [ThisWeekCompactStat]
    let confidenceLabel: String
    let confidenceAccessibilityLabel: String

    let maintenanceBlock: WeeklyMaintenanceBlockState?
    let planRecommendationBlock: WeeklyPlanRecommendationBlockState?
    let weightTrendBlock: WeeklyWeightTrendBlockState?
    let habitRows: [JourneyWeeklyHabitRowState]
    let healthInsights: [WeeklyHealthInsightState]
    let caveats: [String]

    let primaryCTA: WeeklyProgressCTA?
    let secondaryCTA: WeeklyProgressCTA?
    let isReady: Bool
    let isInsufficientData: Bool
    let insufficientDataSummary: String?
    let insufficientDataHeadline: String?
    let insufficientDataRequirement: String?
    let insufficientDataProgressLabel: String?
    let freshness: WeeklyProgressFreshnessState?
}

struct ThisWeekCompactStat: Equatable, Identifiable {
    let id: String
    let label: String
}

// MARK: - Sub-states

struct WeeklyMaintenanceBlockState: Equatable {
    let title: String
    let estimatedMaintenanceKcal: Int?
    let averageDailyCalories: Int?
    let trendDirectionLabel: String?
    let explanation: String
    let confidenceLabel: String
    let showsLearnedEstimate: Bool
    let accessibilityLabel: String
}

struct WeeklyPlanRecommendationBlockState: Equatable {
    let title: String
    let message: String
    let suggestedCalorieDelta: Int?
    let suggestedTargetKcal: Int?
    let confidenceLabel: String
    let recommendationKind: WeeklyPlanRecommendationKind?
    let reasons: [String]
    let safetyNotes: [String]
    let accessibilityLabel: String
}

struct WeeklyWeightTrendBlockState: Equatable {
    let title: String
    let startingWeightLabel: String?
    let endingWeightLabel: String?
    let changeLabel: String?
    let weeklyChangeLabel: String?
    let hasSuddenSpike: Bool
    let spikeTitle: String?
    let spikeShortBody: String?
    let spikeDetailBody: String?
    let spikeAccessibilityLabel: String?
    let isLimited: Bool
    let accessibilityLabel: String
}

enum WeeklyProgressCTAKind: Equatable {
    case keepLogging
    case holdSteady
    case reviewPlan
    case improveLoggingConsistency
    case logWeight
    case logFood
    case focusProtein
    case focusWater
    case connectAppleHealth
}

struct WeeklyProgressCTA: Equatable, Identifiable {
    let id: String
    let kind: WeeklyProgressCTAKind
    let title: String
    let subtitle: String?
    let accessibilityLabel: String
}

enum WeeklyHealthInsightKind: Equatable {
    case win
    case risk
    case focus
    case supplemental
}

struct WeeklyHealthInsightState: Equatable, Identifiable {
    let id: String
    let kind: WeeklyHealthInsightKind
    let title: String?
    let message: String
    let accessibilityLabel: String
}

// MARK: - Input

struct UnifiedWeeklyReviewInput: Equatable {
    var summary: WeeklyProgressSummary
    var weeklyHabit: JourneyWeeklyHabitState?
    var weeklyReview: JourneyWeeklyReviewState?
    var healthReviewCard: WeeklyReviewCardState?
    var healthReviewDetail: WeeklyReviewDetailState?
    var profile: UserProfile?
    var goalDirection: JourneyGoalDirection?
    var dailyReviewsThisWeekCount: Int
    var freshnessInput: WeeklyProgressFreshnessInput?
    var screenPresentation: JourneyScreenPresentationState?
    var calendar: Calendar

    init(
        summary: WeeklyProgressSummary,
        weeklyHabit: JourneyWeeklyHabitState? = nil,
        weeklyReview: JourneyWeeklyReviewState? = nil,
        healthReviewCard: WeeklyReviewCardState? = nil,
        healthReviewDetail: WeeklyReviewDetailState? = nil,
        profile: UserProfile? = nil,
        goalDirection: JourneyGoalDirection? = nil,
        dailyReviewsThisWeekCount: Int = 0,
        freshnessInput: WeeklyProgressFreshnessInput? = nil,
        screenPresentation: JourneyScreenPresentationState? = nil,
        calendar: Calendar = .current
    ) {
        self.summary = summary
        self.weeklyHabit = weeklyHabit
        self.weeklyReview = weeklyReview ?? weeklyHabit?.weeklyReviewState
        self.healthReviewCard = healthReviewCard
        self.healthReviewDetail = healthReviewDetail
        self.profile = profile
        self.goalDirection = goalDirection
        self.dailyReviewsThisWeekCount = dailyReviewsThisWeekCount
        self.freshnessInput = freshnessInput
        self.screenPresentation = screenPresentation
        self.calendar = calendar
    }
}

// MARK: - Builder

enum UnifiedWeeklyReviewPresentationBuilder {

    private static let unifiedWeekTitle = FormaProductCopy.Journey.WeeklyReview.sectionTitle

    // MARK: Public

    static func build(_ input: UnifiedWeeklyReviewInput) -> UnifiedWeeklyReviewState {
        let summary = input.summary
        let habitRows = habitRows(from: input)
        let healthInsights = healthInsights(from: input)
        let recommendation = planRecommendation(for: input)
        let maintenanceBlock = maintenanceBlock(from: summary)
        let weightTrendBlock = weightTrendBlock(from: summary)
        let planBlock = planRecommendationBlock(
            from: recommendation,
            summary: summary,
            profile: input.profile
        )
        let confidence = confidencePresentation(for: summary, screenPresentation: input.screenPresentation)
        let caveats = mergedCaveats(
            summary: summary,
            healthReviewDetail: input.healthReviewDetail
        )
        let ctas = ctas(
            summary: summary,
            recommendation: recommendation,
            weeklyReview: input.weeklyReview,
            screenPresentation: input.screenPresentation
        )
        let isInsufficientData = insufficientData(summary: summary)
        let isReady = ready(
            summary: summary,
            habitRows: habitRows,
            isInsufficientData: isInsufficientData
        )
        let freshness = WeeklyProgressFreshnessBuilder.build(
            input.freshnessInput,
            surface: input.screenPresentation == nil ? .generic : .journey
        )
        let weekRangeText = input.screenPresentation?.weekly.dateRangeText
            ?? JourneyFormatter.timelineDateRangeLabel(
                start: summary.startDate,
                end: summary.endDate,
                calendar: input.calendar
            )
        let emptyState = input.screenPresentation?.copy.emptyState
        let cardPresentation = thisWeekCardPresentation(
            input: input,
            isInsufficientData: isInsufficientData,
            isReady: isReady,
            healthInsights: healthInsights
        )

        return UnifiedWeeklyReviewState(
            id: summary.id,
            weekTitle: input.screenPresentation?.weekly.weekTitle ?? unifiedWeekTitle,
            dateRangeText: weekRangeText,
            headline: summary.headline,
            summary: summary.summary,
            cardStateTitle: cardPresentation.stateTitle,
            cardSummary: cardPresentation.summary,
            compactStats: cardPresentation.compactStats,
            confidenceLabel: confidence.label,
            confidenceAccessibilityLabel: confidence.accessibility,
            maintenanceBlock: maintenanceBlock,
            planRecommendationBlock: planBlock,
            weightTrendBlock: weightTrendBlock,
            habitRows: habitRows,
            healthInsights: healthInsights,
            caveats: caveats,
            primaryCTA: ctas.primary,
            secondaryCTA: ctas.secondary,
            isReady: isReady,
            isInsufficientData: isInsufficientData,
            insufficientDataSummary: emptyState?.requirement ?? input.screenPresentation?.copy.insufficientDataSummary,
            insufficientDataHeadline: emptyState?.headline,
            insufficientDataRequirement: emptyState?.requirement,
            insufficientDataProgressLabel: emptyState?.progressLabel,
            freshness: freshness
        )
    }

    static func build(
        dashboard: JourneyDashboardState,
        healthIntelligence: JourneyHealthIntelligenceSectionState? = nil,
        profile: UserProfile? = nil,
        freshnessInput: WeeklyProgressFreshnessInput? = nil,
        calendar: Calendar = .current
    ) -> UnifiedWeeklyReviewState {
        build(
            UnifiedWeeklyReviewInput(
                summary: dashboard.weeklyProgressSummary,
                weeklyHabit: dashboard.weeklyHabit,
                healthReviewCard: healthIntelligence?.weeklyReviewCard,
                healthReviewDetail: healthIntelligence?.weeklyReviewDetail,
                profile: profile,
                goalDirection: dashboard.baseline.goalDirection,
                dailyReviewsThisWeekCount: dashboard.dailyReviewsThisWeekCount,
                freshnessInput: freshnessInput,
                screenPresentation: dashboard.screenPresentation,
                calendar: calendar
            )
        )
    }

    static func buildDetail(
        dashboard: JourneyDashboardState,
        healthIntelligence: JourneyHealthIntelligenceSectionState? = nil,
        profile: UserProfile? = nil,
        freshnessInput: WeeklyProgressFreshnessInput? = nil,
        calendar: Calendar = .current
    ) -> WeeklyProgressDetailState {
        let input = UnifiedWeeklyReviewInput(
            summary: dashboard.weeklyProgressSummary,
            weeklyHabit: dashboard.weeklyHabit,
            healthReviewCard: healthIntelligence?.weeklyReviewCard,
            healthReviewDetail: healthIntelligence?.weeklyReviewDetail,
            profile: profile,
            goalDirection: dashboard.baseline.goalDirection,
            dailyReviewsThisWeekCount: dashboard.dailyReviewsThisWeekCount,
            freshnessInput: freshnessInput,
            screenPresentation: dashboard.screenPresentation,
            calendar: calendar
        )
        return buildDetail(input)
    }

    static func buildDetail(
        dashboard: JourneyDashboardState,
        healthIntelligence: JourneyHealthIntelligenceSectionState? = nil,
        profile: UserProfile? = nil,
        calendar: Calendar = .current
    ) -> WeeklyProgressDetailState {
        buildDetail(
            dashboard: dashboard,
            healthIntelligence: healthIntelligence,
            profile: profile,
            freshnessInput: nil,
            calendar: calendar
        )
    }

    static func build(
        dashboard: JourneyDashboardState,
        healthIntelligence: JourneyHealthIntelligenceSectionState? = nil,
        profile: UserProfile? = nil,
        calendar: Calendar = .current
    ) -> UnifiedWeeklyReviewState {
        build(
            dashboard: dashboard,
            healthIntelligence: healthIntelligence,
            profile: profile,
            freshnessInput: nil,
            calendar: calendar
        )
    }

    static func buildDetail(_ input: UnifiedWeeklyReviewInput) -> WeeklyProgressDetailState {
        let unified = build(input)
        let summary = input.summary
        let maintenance = summary.maintenanceEstimate

        return WeeklyProgressDetailState(
            summary: summary,
            unified: unified,
            verdictTitle: verdictTitle(
                for: summary.verdict,
                screenPresentation: input.screenPresentation
            ),
            primaryInsight: summary.primaryInsight,
            consistency: consistencySection(
                from: summary,
                dailyReviewsThisWeekCount: input.dailyReviewsThisWeekCount
            ),
            staticTDEEComparison: staticTDEEComparison(from: summary),
            nextWeekFocus: nextWeekFocus(
                unified: unified,
                healthReviewDetail: input.healthReviewDetail,
                summary: summary
            ),
            generatedAtLabel: FormaProductCopy.WeeklyReviewPresentation.generatedAtLabel(
                for: summary.generatedAt,
                calendar: input.calendar
            ),
            healthKitLimitedNotice: healthKitLimitedNotice(from: input.healthReviewDetail),
            uncertaintyTitle: uncertaintyTitle,
            freshness: unified.freshness,
            accessibilityLabel: detailAccessibilityLabel(
                unified: unified,
                summary: summary,
                generatedAtLabel: FormaProductCopy.WeeklyReviewPresentation.generatedAtLabel(
                    for: summary.generatedAt,
                    calendar: input.calendar
                )
            )
        )
    }

    // MARK: Detail assembly

    private static let uncertaintyTitle = "Why this may be uncertain"

    private static func verdictTitle(
        for verdict: WeeklyProgressVerdict,
        screenPresentation: JourneyScreenPresentationState? = nil
    ) -> String {
        switch verdict {
        case .notEnoughData:
            return screenPresentation?.copy.emptyState?.headline
                ?? FormaProductCopy.Journey.EmptyState.buildingFirstTrend
        case .onTrack:
            return "On track this week"
        case .likelyTooAggressive:
            return "Plan may be aggressive"
        case .likelyTooSlow:
            return "Progress looks slower than expected"
        case .noisyButLikelyOkay:
            return FormaProductCopy.WeightSpikeEducation.shortTitle
        case .needsConsistencyFirst:
            return "Consistency comes first"
        case .maintaining:
            return "Holding steady"
        case .unclear:
            return "Your week is still taking shape"
        }
    }

    private static func consistencySection(
        from summary: WeeklyProgressSummary,
        dailyReviewsThisWeekCount: Int = 0
    ) -> WeeklyProgressConsistencySectionState {
        let copy = FormaProductCopy.WeeklyReviewPresentation.self
        let total = max(summary.totalDays, JourneyLogMetrics.weekDayCount)

        return WeeklyProgressConsistencySectionState(
            foodLoggedLabel: summary.foodLoggedDays > 0
                ? copy.dayCountValue(summary.foodLoggedDays, total: total)
                : nil,
            averageCaloriesLabel: summary.averageDailyCalories.map {
                "Average intake: \($0) kcal / day"
            },
            proteinLabel: summary.proteinHitDays > 0
                ? "\(copy.proteinTitle): \(copy.dayCountValue(summary.proteinHitDays, total: total))"
                : nil,
            waterLabel: summary.waterTargetHitDays > 0
                ? "\(copy.waterTitle): \(copy.dayCountValue(summary.waterTargetHitDays, total: total))"
                : nil,
            calorieAdherenceLabel: summary.calorieTargetHitDays > 0
                ? "\(copy.caloriesTitle): \(copy.dayCountValue(summary.calorieTargetHitDays, total: total))"
                : nil,
            trainingLabel: summary.trainingDays.map { days in
                "\(FormaProductCopy.Journey.WeeklyReview.trainingTitle): \(FormaProductCopy.Journey.WeeklyReview.trainingDays(days))"
            },
            dailyReviewsLabel: dailyReviewsThisWeekCount > 0
                ? copy.dailyReviewsValue(dailyReviewsThisWeekCount, total: total)
                : nil
        )
    }

    private static func staticTDEEComparison(
        from summary: WeeklyProgressSummary
    ) -> WeeklyProgressTDEEComparisonState? {
        let maintenance = summary.maintenanceEstimate
        guard maintenance.sufficiency.isEligibleForKcalMaintenanceDisplay,
              let learned = maintenance.estimatedMaintenanceKcal,
              let staticTDEE = maintenance.staticTDEEKcal else {
            return nil
        }

        let comparisonCopy =
            "Your formula-based estimate is about \(staticTDEE) kcal per day. "
            + "Learned maintenance from this week's logging is about \(learned) kcal per day."

        return WeeklyProgressTDEEComparisonState(
            learnedMaintenanceKcal: learned,
            staticTDEEKcal: staticTDEE,
            comparisonCopy: comparisonCopy,
            accessibilityLabel: comparisonCopy
        )
    }

    private static func nextWeekFocus(
        unified: UnifiedWeeklyReviewState,
        healthReviewDetail: WeeklyReviewDetailState?,
        summary: WeeklyProgressSummary
    ) -> [WeeklyReviewFocusItemState] {
        var items: [WeeklyReviewFocusItemState] = []
        var seen = Set<String>()

        func appendFocus(id: String, message: String) {
            let key = message.lowercased()
            guard seen.insert(key).inserted else { return }
            items.append(
                WeeklyReviewFocusItemState(
                    id: id,
                    message: message,
                    accessibilityLabel: "\(FormaProductCopy.WeeklyReviewPresentation.focusHeader). \(message)"
                )
            )
        }

        if let healthReviewDetail {
            for item in healthReviewDetail.nextWeekFocus {
                appendFocus(id: "hi-\(item.id)", message: item.message)
            }
        }

        for insight in unified.healthInsights where insight.kind == .focus {
            appendFocus(id: "unified-\(insight.id)", message: insight.message)
        }

        if items.isEmpty {
            appendFocus(
                id: "next-action",
                message: "\(summary.nextActionTitle). \(summary.nextActionSubtitle)"
            )
        }

        return items
    }

    private static func healthKitLimitedNotice(
        from healthReviewDetail: WeeklyReviewDetailState?
    ) -> String? {
        guard let notice = healthReviewDetail?.missingDataNotice?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !notice.isEmpty else {
            return nil
        }

        return "Apple Health signals were limited this week. "
            + "This review still uses the meals and weight you logged in Forma. \(notice)"
    }

    private static func detailAccessibilityLabel(
        unified: UnifiedWeeklyReviewState,
        summary: WeeklyProgressSummary,
        generatedAtLabel: String
    ) -> String {
        var parts = [
            unified.weekTitle,
            unified.dateRangeText,
            unified.headline,
            unified.summary,
            unified.confidenceAccessibilityLabel,
            generatedAtLabel
        ]
        if let maintenance = unified.maintenanceBlock {
            parts.append(maintenance.accessibilityLabel)
        }
        if let plan = unified.planRecommendationBlock {
            parts.append(plan.accessibilityLabel)
        }
        if let weight = unified.weightTrendBlock {
            parts.append(weight.accessibilityLabel)
        }
        if let primary = unified.primaryCTA {
            parts.append(primary.accessibilityLabel)
        }
        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }

    // MARK: Readiness

    private static func insufficientData(summary: WeeklyProgressSummary) -> Bool {
        summary.verdict == .notEnoughData || summary.confidence == .unavailable
    }

    private static func ready(
        summary: WeeklyProgressSummary,
        habitRows: [JourneyWeeklyHabitRowState],
        isInsufficientData: Bool
    ) -> Bool {
        if !isInsufficientData {
            return true
        }
        return summary.foodLoggedDays > 0 || !habitRows.isEmpty
    }

    // MARK: Habit rows

    private static func habitRows(from input: UnifiedWeeklyReviewInput) -> [JourneyWeeklyHabitRowState] {
        if let habits = input.weeklyHabit?.habits, input.weeklyHabit?.showsHabitRows == true {
            return habits
        }
        return []
    }

    // MARK: Maintenance

    private static func maintenanceBlock(
        from summary: WeeklyProgressSummary
    ) -> WeeklyMaintenanceBlockState? {
        let estimate = summary.maintenanceEstimate
        let sufficiency = estimate.sufficiency
        let showsLearnedEstimate = sufficiency.isEligibleForKcalMaintenanceDisplay
            && estimate.estimatedMaintenanceKcal != nil

        guard showsLearnedEstimate
            || estimate.trendDirection != .unclear
            || !estimate.explanation.isEmpty else {
            return nil
        }

        let title = showsLearnedEstimate
            ? "Learned maintenance"
            : "Maintenance estimate building"

        let explanation: String
        if showsLearnedEstimate, let maintenance = estimate.estimatedMaintenanceKcal {
            explanation = "Based on your intake and weight trend, learned maintenance is about \(maintenance) kcal per day."
        } else {
            explanation = estimate.explanation
        }

        let accessibility: String
        if let maintenance = estimate.estimatedMaintenanceKcal, showsLearnedEstimate {
            accessibility = "\(title). About \(maintenance) kilocalories per day. \(explanation)"
        } else {
            accessibility = "\(title). \(explanation)"
        }

        return WeeklyMaintenanceBlockState(
            title: title,
            estimatedMaintenanceKcal: showsLearnedEstimate ? estimate.estimatedMaintenanceKcal : nil,
            averageDailyCalories: estimate.averageDailyCalories,
            trendDirectionLabel: trendDirectionLabel(for: estimate.trendDirection),
            explanation: explanation,
            confidenceLabel: shortConfidenceLabel(for: estimate.confidence),
            showsLearnedEstimate: showsLearnedEstimate,
            accessibilityLabel: accessibility
        )
    }

    // MARK: Plan recommendation

    private static func planRecommendation(
        for input: UnifiedWeeklyReviewInput
    ) -> WeeklyPlanRecommendation? {
        let summary = input.summary
        guard WeeklyProgressConfidencePolicy.canShowPlanRecommendation(
            summary.maintenanceEstimate.sufficiency
        ) else {
            return nil
        }

        let goalDirection = input.goalDirection
            ?? JourneyGoalDirection.resolve(
                startWeightKg: input.profile?.currentWeightKg,
                goalWeightKg: input.profile?.goalWeightKg
            )

        let planInput = PlanRecommendationInput(
            summary: summary,
            currentCalorieTargetKcal: calorieTargetKcal(from: input.profile),
            staticTDEEKcal: staticTDEEKcal(from: input.profile, referenceDate: summary.endDate),
            calorieFloorKcal: calorieFloorKcal(from: input.profile, referenceDate: summary.endDate),
            goalDirection: goalDirection
        )

        return PlanRecommendationPolicy.recommend(planInput)
    }

    private static func planRecommendationBlock(
        from recommendation: WeeklyPlanRecommendation?,
        summary: WeeklyProgressSummary,
        profile: UserProfile?
    ) -> WeeklyPlanRecommendationBlockState? {
        guard let recommendation else { return nil }
        guard recommendation.kind != .notEnoughData else { return nil }

        let currentTarget = calorieTargetKcal(from: profile)
        let suggestedTarget: Int?
        if let delta = recommendation.suggestedCalorieDelta, let currentTarget {
            suggestedTarget = currentTarget + delta
        } else {
            suggestedTarget = nil
        }

        let confidenceLabel = shortConfidenceLabel(for: recommendation.confidence)
        let accessibility = [
            recommendation.title,
            recommendation.message,
            confidenceLabel
        ].joined(separator: ". ")

        return WeeklyPlanRecommendationBlockState(
            title: recommendation.title,
            message: recommendation.message,
            suggestedCalorieDelta: recommendation.suggestedCalorieDelta,
            suggestedTargetKcal: suggestedTarget,
            confidenceLabel: confidenceLabel,
            recommendationKind: recommendation.kind,
            reasons: recommendation.reasons,
            safetyNotes: recommendation.safetyNotes,
            accessibilityLabel: accessibility
        )
    }

    // MARK: Weight trend

    private static func weightTrendBlock(
        from summary: WeeklyProgressSummary
    ) -> WeeklyWeightTrendBlockState? {
        let hasWeightData = summary.startingWeightKg != nil
            || summary.endingWeightKg != nil
            || summary.weightChangeKg != nil
        let hasSpike = summary.hasSuddenSpike

        guard hasWeightData || hasSpike else { return nil }

        let copy = FormaProductCopy.WeeklyReviewPresentation.self
        let changeLabel = summary.weightChangeKg.map { copy.weightTrendValue($0) }
        let weeklyChangeLabel = summary.weeklyWeightChangeKg.map { copy.weightTrendValue($0) }
        let isLimited = summary.weightChangeKg == nil && summary.weeklyWeightChangeKg == nil

        var accessibilityParts = ["Weight trend"]
        if let changeLabel {
            accessibilityParts.append(changeLabel)
        } else {
            accessibilityParts.append(copy.weightUnavailable)
        }
        if hasSpike {
            accessibilityParts.append(FormaProductCopy.WeightSpikeEducation.accessibilityLabel)
        }

        let spikeCopy = FormaProductCopy.WeightSpikeEducation.self
        return WeeklyWeightTrendBlockState(
            title: copy.weightTitle,
            startingWeightLabel: weightLabel(summary.startingWeightKg),
            endingWeightLabel: weightLabel(summary.endingWeightKg),
            changeLabel: changeLabel,
            weeklyChangeLabel: weeklyChangeLabel,
            hasSuddenSpike: hasSpike,
            spikeTitle: hasSpike ? spikeCopy.shortTitle : nil,
            spikeShortBody: hasSpike ? spikeCopy.shortBody : nil,
            spikeDetailBody: hasSpike ? spikeCopy.detailBody : nil,
            spikeAccessibilityLabel: hasSpike ? spikeCopy.accessibilityLabel : nil,
            isLimited: isLimited,
            accessibilityLabel: accessibilityParts.joined(separator: ". ")
        )
    }

    // MARK: Health Intelligence insights

    private static func healthInsights(from input: UnifiedWeeklyReviewInput) -> [WeeklyHealthInsightState] {
        var insights: [WeeklyHealthInsightState] = []

        if let detail = input.healthReviewDetail {
            insights.append(contentsOf: detail.wins.map {
                WeeklyHealthInsightState(
                    id: "hi-\($0.id)",
                    kind: .win,
                    title: FormaProductCopy.WeeklyReviewPresentation.winsHeader,
                    message: $0.message,
                    accessibilityLabel: $0.accessibilityLabel
                )
            })
            insights.append(contentsOf: detail.risks.map {
                WeeklyHealthInsightState(
                    id: "hi-\($0.id)",
                    kind: .risk,
                    title: FormaProductCopy.WeeklyReviewPresentation.risksHeader,
                    message: $0.message,
                    accessibilityLabel: $0.accessibilityLabel
                )
            })
            insights.append(contentsOf: detail.nextWeekFocus.map {
                WeeklyHealthInsightState(
                    id: "hi-\($0.id)",
                    kind: .focus,
                    title: FormaProductCopy.WeeklyReviewPresentation.focusHeader,
                    message: $0.message,
                    accessibilityLabel: $0.accessibilityLabel
                )
            })
        } else if let card = input.healthReviewCard, card.phase == .loaded {
            let supplementalSummary = trimmed(card.summary)
            if let supplementalSummary,
               supplementalSummary != input.summary.summary,
               !supplementalSummary.isEmpty {
                insights.append(
                    WeeklyHealthInsightState(
                        id: "hi-card-summary",
                        kind: .supplemental,
                        title: card.title,
                        message: supplementalSummary,
                        accessibilityLabel: "\(card.title). \(supplementalSummary)"
                    )
                )
            }
        }

        return deduplicatedInsights(insights)
    }

    // MARK: - This Week card

    private struct ThisWeekCardPresentation: Equatable {
        var stateTitle: String
        var summary: String
        var compactStats: [ThisWeekCompactStat]
    }

    private static func thisWeekCardPresentation(
        input: UnifiedWeeklyReviewInput,
        isInsufficientData: Bool,
        isReady: Bool,
        healthInsights: [WeeklyHealthInsightState]
    ) -> ThisWeekCardPresentation {
        let copy = FormaProductCopy.Journey.ThisWeek.self
        let presentation = input.screenPresentation
        let stats = presentation?.weekly.stats
        let compactStats = compactStats(
            screenPresentation: presentation,
            summary: input.summary
        )

        let stateTitle: String
        if isInsufficientData {
            stateTitle = copy.gettingStarted
        } else if presentation?.unlocks.weeklyReview == true {
            stateTitle = copy.weeklyReviewReady
        } else if (stats?.mealLoggingDays ?? input.summary.foodLoggedDays) > 0 {
            stateTitle = copy.buildingConsistency
        } else {
            stateTitle = input.summary.headline
        }

        let summary = thisWeekCardSummary(
            input: input,
            isInsufficientData: isInsufficientData,
            isReady: isReady,
            healthInsights: healthInsights,
            compactStats: compactStats
        )

        return ThisWeekCardPresentation(
            stateTitle: stateTitle,
            summary: summary,
            compactStats: compactStats
        )
    }

    private static func thisWeekCardSummary(
        input: UnifiedWeeklyReviewInput,
        isInsufficientData: Bool,
        isReady: Bool,
        healthInsights: [WeeklyHealthInsightState],
        compactStats: [ThisWeekCompactStat]
    ) -> String {
        let presentation = input.screenPresentation
        let nextAction = presentation?.nextBestAction
        let stats = presentation?.weekly.stats

        if isInsufficientData {
            let highlights = thisWeekHighlightPhrases(
                stats: stats,
                summary: input.summary
            )
            let opening: String
            if highlights.isEmpty {
                opening = nextAction?.detail ?? nextAction?.title ?? input.summary.primaryInsight
            } else {
                opening = "You \(joinedHighlights(highlights))."
            }

            if stats?.mealsLogged == 0 {
                let mealPrompt = FormaProductCopy.Journey.NextBestAction.logFirstMealDetail
                guard opening.localizedCaseInsensitiveContains("first meal") == false else {
                    return opening
                }
                return "\(opening) \(mealPrompt)"
            }

            if let detail = nextAction?.detail,
               !detail.isEmpty,
               !opening.localizedCaseInsensitiveContains(detail) {
                return "\(opening) \(detail)"
            }
            return opening
        }

        if presentation?.unlocks.weeklyReview == true {
            if let win = healthInsights.first(where: { $0.kind == .win })?.message {
                return win
            }
            return trimmed(input.summary.primaryInsight) ?? input.summary.summary
        }

        if isReady, let supplemental = healthInsights.first?.message {
            return supplemental
        }

        if compactStats.isEmpty {
            return input.summary.primaryInsight
        }

        return trimmed(input.summary.summary) ?? input.summary.primaryInsight
    }

    private static func thisWeekHighlightPhrases(
        stats: JourneyWeeklyStatsState?,
        summary: WeeklyProgressSummary
    ) -> [String] {
        var phrases: [String] = []

        if let averageSteps = stats?.averageSteps, averageSteps > 0 {
            phrases.append("averaged \(averageSteps.formatted()) steps")
        }

        let workouts = stats?.workouts ?? summary.trainingDays ?? 0
        if workouts > 0 {
            phrases.append(
                workouts == 1
                    ? "completed your first workout"
                    : "completed \(workouts) workouts"
            )
        }

        let weighIns = stats?.weighIns ?? 0
        if weighIns > 0 {
            phrases.append(
                weighIns == 1
                    ? "logged your first weigh-in"
                    : "logged \(weighIns) weigh-ins"
            )
        }

        let meals = stats?.mealsLogged ?? summary.foodLoggedDays
        if meals > 0 {
            phrases.append(
                meals == 1
                    ? "logged your first meal"
                    : "logged meals on \(meals) days"
            )
        }

        return phrases
    }

    private static func joinedHighlights(_ phrases: [String]) -> String {
        guard !phrases.isEmpty else { return "" }
        if phrases.count == 1 { return phrases[0] }
        if phrases.count == 2 { return "\(phrases[0]) and \(phrases[1])" }
        let head = phrases.dropLast().joined(separator: ", ")
        return "\(head), and \(phrases.last!)"
    }

    private static func compactStats(
        screenPresentation: JourneyScreenPresentationState?,
        summary: WeeklyProgressSummary
    ) -> [ThisWeekCompactStat] {
        let copy = FormaProductCopy.Journey.ThisWeek.self
        var stats: [ThisWeekCompactStat] = []

        let weeklyStats = screenPresentation?.weekly.stats
        if let steps = weeklyStats?.averageSteps, steps > 0 {
            stats.append(ThisWeekCompactStat(id: "steps", label: copy.averageSteps(steps)))
        }

        let workouts = weeklyStats?.workouts ?? summary.trainingDays ?? 0
        stats.append(ThisWeekCompactStat(id: "workouts", label: copy.workouts(workouts)))

        let weighIns = weeklyStats?.weighIns ?? 0
        stats.append(ThisWeekCompactStat(id: "weigh-ins", label: copy.weighIns(weighIns)))

        let meals = weeklyStats?.mealsLogged ?? summary.foodLoggedDays
        stats.append(ThisWeekCompactStat(id: "meals", label: copy.mealsLogged(meals)))

        if let proteinDays = weeklyStats?.proteinLoggingDays, proteinDays >= 3 {
            stats.append(ThisWeekCompactStat(id: "protein", label: copy.proteinDays(proteinDays)))
        }

        if let waterDays = weeklyStats?.waterLoggingDays, waterDays >= 3 {
            stats.append(ThisWeekCompactStat(id: "water", label: copy.waterDays(waterDays)))
        }

        return stats
    }

    // MARK: CTAs

    private static func ctas(
        summary: WeeklyProgressSummary,
        recommendation: WeeklyPlanRecommendation?,
        weeklyReview: JourneyWeeklyReviewState?,
        screenPresentation: JourneyScreenPresentationState? = nil
    ) -> (primary: WeeklyProgressCTA?, secondary: WeeklyProgressCTA?) {
        var primary = screenPresentation.map { cta(from: $0.nextBestAction) }
            ?? cta(from: summary.nextAction, summary: summary)

        if primary == nil {
            primary = keepLoggingCTA(summary: summary)
        }

        if let recommendation,
           recommendation.shouldShowPlanCTA,
           let title = recommendation.ctaTitle {
            let planCTA = WeeklyProgressCTA(
                id: "cta-plan-review",
                kind: .reviewPlan,
                title: title,
                subtitle: recommendation.message,
                accessibilityLabel: "\(title). \(recommendation.message)"
            )
            if primary?.kind == .reviewPlan {
                return (primary, nil)
            }
            return (primary, planCTA)
        }

        if recommendation?.kind == .improveConsistencyFirst {
            return (primary, improveConsistencyCTA())
        }

        if let trainingCTA = trainingCTA(from: weeklyReview) {
            if primary?.kind != trainingCTA.kind {
                return (primary, trainingCTA)
            }
        }

        return (primary, nil)
    }

    private static func cta(
        from action: WeeklyProgressNextAction,
        summary: WeeklyProgressSummary
    ) -> WeeklyProgressCTA? {
        let title = summary.nextActionTitle
        let subtitle = summary.nextActionSubtitle
        let accessibility = [title, subtitle].compactMap { $0 }.joined(separator: ". ")

        switch action {
        case .keepLogging:
            return keepLoggingCTA(summary: summary)
        case .holdSteady:
            return WeeklyProgressCTA(
                id: "cta-hold-steady",
                kind: .holdSteady,
                title: title,
                subtitle: subtitle,
                accessibilityLabel: accessibility
            )
        case .reviewPlan:
            return WeeklyProgressCTA(
                id: "cta-review-plan",
                kind: .reviewPlan,
                title: title,
                subtitle: subtitle,
                accessibilityLabel: accessibility
            )
        case .improveLoggingConsistency:
            return improveConsistencyCTA(title: title, subtitle: subtitle)
        case .logWeightMoreOften:
            return WeeklyProgressCTA(
                id: "cta-log-weight",
                kind: .logWeight,
                title: title,
                subtitle: subtitle,
                accessibilityLabel: accessibility
            )
        case .focusProtein:
            return WeeklyProgressCTA(
                id: "cta-focus-protein",
                kind: .focusProtein,
                title: title,
                subtitle: subtitle,
                accessibilityLabel: accessibility
            )
        case .focusWater:
            return WeeklyProgressCTA(
                id: "cta-focus-water",
                kind: .focusWater,
                title: title,
                subtitle: subtitle,
                accessibilityLabel: accessibility
            )
        case .reviewDailySummary:
            return WeeklyProgressCTA(
                id: "cta-review-daily-summary",
                kind: .keepLogging,
                title: title,
                subtitle: subtitle,
                accessibilityLabel: accessibility
            )
        }
    }

    private static func keepLoggingCTA(summary: WeeklyProgressSummary) -> WeeklyProgressCTA {
        WeeklyProgressCTA(
            id: "cta-keep-logging",
            kind: .keepLogging,
            title: summary.nextActionTitle,
            subtitle: summary.nextActionSubtitle,
            accessibilityLabel: "\(summary.nextActionTitle). \(summary.nextActionSubtitle)"
        )
    }

    private static func improveConsistencyCTA(
        title: String = "Build logging consistency",
        subtitle: String = "Try to log most days next week for a clearer maintenance estimate."
    ) -> WeeklyProgressCTA {
        WeeklyProgressCTA(
            id: "cta-improve-consistency",
            kind: .improveLoggingConsistency,
            title: title,
            subtitle: subtitle,
            accessibilityLabel: "\(title). \(subtitle)"
        )
    }

    private static func trainingCTA(
        from weeklyReview: JourneyWeeklyReviewState?
    ) -> WeeklyProgressCTA? {
        guard let weeklyReview else { return nil }
        guard let journeyCTA = JourneyCTARouter.weeklyTrainingCTA(training: weeklyReview.training) else {
            return nil
        }

        return WeeklyProgressCTA(
            id: "cta-connect-health",
            kind: .connectAppleHealth,
            title: journeyCTA.title,
            subtitle: FormaProductCopy.Journey.WeeklyReview.trainingConnectAppleHealth,
            accessibilityLabel: "\(journeyCTA.title). \(FormaProductCopy.Journey.WeeklyReview.trainingConnectAppleHealth)"
        )
    }

    // MARK: Caveats

    private static func mergedCaveats(
        summary: WeeklyProgressSummary,
        healthReviewDetail: WeeklyReviewDetailState?
    ) -> [String] {
        var caveats = summary.caveats + summary.maintenanceEstimate.caveats

        if let notice = healthReviewDetail?.missingDataNotice,
           !notice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            caveats.append(notice)
        }

        return orderedUnique(caveats)
    }

    // MARK: Confidence & formatting

    private static func confidencePresentation(
        for summary: WeeklyProgressSummary,
        screenPresentation: JourneyScreenPresentationState? = nil
    ) -> (label: String, accessibility: String) {
        if let screenPresentation {
            return (
                label: screenPresentation.copy.confidenceLabel,
                accessibility: screenPresentation.copy.confidenceAccessibilityLabel
            )
        }
        return (
            label: shortConfidenceLabel(for: summary.confidence),
            accessibility: WeeklyProgressConfidencePolicy.confidenceCopy(
                for: summary.confidence,
                hasSuddenSpike: summary.hasSuddenSpike
            )
        )
    }

    private static func cta(
        from action: JourneyNextBestActionState
    ) -> WeeklyProgressCTA {
        let accessibility = action.accessibilityLabel
        switch action.kind {
        case .logFirstMeal, .logMealsConsistently:
            return WeeklyProgressCTA(
                id: "cta-log-food",
                kind: .logFood,
                title: action.title,
                subtitle: action.detail,
                accessibilityLabel: accessibility
            )
        case .logWeightMoreOften:
            return WeeklyProgressCTA(
                id: "cta-log-weight",
                kind: .logWeight,
                title: action.title,
                subtitle: action.detail,
                accessibilityLabel: accessibility
            )
        case .completeFirstWorkout:
            return WeeklyProgressCTA(
                id: "cta-connect-health",
                kind: .connectAppleHealth,
                title: action.title,
                subtitle: action.detail,
                accessibilityLabel: accessibility
            )
        case .syncRecoveryData:
            return WeeklyProgressCTA(
                id: "cta-sync-recovery",
                kind: .connectAppleHealth,
                title: action.title,
                subtitle: action.detail,
                accessibilityLabel: accessibility
            )
        case .keepStreakGoing:
            return WeeklyProgressCTA(
                id: "cta-keep-streak",
                kind: .keepLogging,
                title: action.title,
                subtitle: action.detail,
                accessibilityLabel: accessibility
            )
        }
    }

    private static func shortConfidenceLabel(
        for confidence: WeeklyProgressConfidenceLevel
    ) -> String {
        switch confidence {
        case .unavailable:
            return FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
        case .low:
            return FormaProductCopy.Journey.WeeklyConfidence.building
        case .medium:
            return FormaProductCopy.Journey.WeeklyConfidence.moderate
        case .high:
            return FormaProductCopy.Journey.WeeklyConfidence.high
        }
    }

    private static func trendDirectionLabel(
        for direction: MaintenanceTrendDirection
    ) -> String? {
        switch direction {
        case .losingFasterThanExpected:
            return "Weight moved faster than a typical weekly pace."
        case .losingAboutAsExpected:
            return "Weight trend looks broadly in line with your goal."
        case .losingSlowerThanExpected:
            return "Weight trend is flat or slow for your goal this week."
        case .maintaining:
            return "Weight held steady within a small weekly band."
        case .gaining:
            return "Weight trend moved up this week."
        case .unclear:
            return nil
        }
    }

    private static func dateRangeText(
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> String {
        JourneyFormatter.timelineDateRangeLabel(start: start, end: end, calendar: calendar)
    }

    private static func weightLabel(_ kg: Double?) -> String? {
        guard let kg else { return nil }
        return String(format: "%.1f kg", kg)
    }

    // MARK: Profile helpers

    private static func calorieTargetKcal(from profile: UserProfile?) -> Int? {
        guard let target = profile?.targets.calorieTarget, target > 0 else {
            return nil
        }
        return target
    }

    private static func staticTDEEKcal(
        from profile: UserProfile?,
        referenceDate: Date
    ) -> Int? {
        guard let profile else { return nil }
        guard let result = try? PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        ) else {
            return nil
        }
        return result.tdeeKcal
    }

    private static func calorieFloorKcal(
        from profile: UserProfile?,
        referenceDate: Date
    ) -> Int? {
        guard let profile else { return nil }
        guard let result = try? PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        ) else {
            return nil
        }
        return result.calories.calorieFloorKcal
    }

    // MARK: Utilities

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard seen.insert(trimmed).inserted else { continue }
            ordered.append(trimmed)
        }
        return ordered
    }

    private static func deduplicatedInsights(
        _ insights: [WeeklyHealthInsightState]
    ) -> [WeeklyHealthInsightState] {
        var seen = Set<String>()
        return insights.filter { insight in
            let key = insight.message.lowercased()
            return seen.insert(key).inserted
        }
    }
}
