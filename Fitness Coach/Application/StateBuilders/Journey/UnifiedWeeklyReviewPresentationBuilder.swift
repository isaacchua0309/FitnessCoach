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
        self.calendar = calendar
    }
}

// MARK: - Builder

enum UnifiedWeeklyReviewPresentationBuilder {

    private static let unifiedWeekTitle = "Weekly review"

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
        let confidence = confidencePresentation(for: summary)
        let caveats = mergedCaveats(
            summary: summary,
            healthReviewDetail: input.healthReviewDetail
        )
        let ctas = ctas(
            summary: summary,
            recommendation: recommendation,
            weeklyReview: input.weeklyReview
        )
        let isInsufficientData = insufficientData(summary: summary)
        let isReady = ready(
            summary: summary,
            habitRows: habitRows,
            isInsufficientData: isInsufficientData
        )

        return UnifiedWeeklyReviewState(
            id: summary.id,
            weekTitle: unifiedWeekTitle,
            dateRangeText: dateRangeText(
                start: summary.startDate,
                end: summary.endDate,
                calendar: input.calendar
            ),
            headline: summary.headline,
            summary: summary.summary,
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
            isInsufficientData: isInsufficientData
        )
    }

    static func build(
        dashboard: JourneyDashboardState,
        healthIntelligence: JourneyHealthIntelligenceSectionState? = nil,
        profile: UserProfile? = nil,
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
                calendar: calendar
            )
        )
    }

    static func buildDetail(
        dashboard: JourneyDashboardState,
        healthIntelligence: JourneyHealthIntelligenceSectionState? = nil,
        profile: UserProfile? = nil,
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
            calendar: calendar
        )
        return buildDetail(input)
    }

    static func buildDetail(_ input: UnifiedWeeklyReviewInput) -> WeeklyProgressDetailState {
        let unified = build(input)
        let summary = input.summary
        let maintenance = summary.maintenanceEstimate

        return WeeklyProgressDetailState(
            unified: unified,
            verdictTitle: verdictTitle(for: summary.verdict),
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

    private static func verdictTitle(for verdict: WeeklyProgressVerdict) -> String {
        switch verdict {
        case .notEnoughData:
            return FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
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
                currentWeightKg: input.profile?.currentWeightKg,
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

    // MARK: CTAs

    private static func ctas(
        summary: WeeklyProgressSummary,
        recommendation: WeeklyPlanRecommendation?,
        weeklyReview: JourneyWeeklyReviewState?
    ) -> (primary: WeeklyProgressCTA?, secondary: WeeklyProgressCTA?) {
        var primary = cta(from: summary.nextAction, summary: summary)

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
        for summary: WeeklyProgressSummary
    ) -> (label: String, accessibility: String) {
        (
            label: shortConfidenceLabel(for: summary.confidence),
            accessibility: WeeklyProgressConfidencePolicy.confidenceCopy(
                for: summary.confidence,
                hasSuddenSpike: summary.hasSuddenSpike
            )
        )
    }

    private static func shortConfidenceLabel(
        for confidence: WeeklyProgressConfidenceLevel
    ) -> String {
        switch confidence {
        case .unavailable:
            return FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
        case .low:
            return FormaProductCopy.WeeklyReviewPresentation.confidenceLow
        case .medium:
            return FormaProductCopy.WeeklyReviewPresentation.confidenceModerate
        case .high:
            return FormaProductCopy.WeeklyReviewPresentation.confidenceHigh
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
        let startLabel = JourneyFormatter.timelineDayLabel(start, calendar: calendar)
        let endLabel = JourneyFormatter.timelineDayLabel(end, calendar: calendar)
        return "\(startLabel) – \(endLabel)"
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
