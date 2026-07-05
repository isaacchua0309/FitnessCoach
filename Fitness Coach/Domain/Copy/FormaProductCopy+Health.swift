//
//  FormaProductCopy+Health.swift
//  Fitness Coach
//
//  Health Intelligence shared and plan presentation copy.
//

import Foundation

extension FormaProductCopy {
    // MARK: - Plan Health Intelligence presentation

    enum PlanHealthIntelligencePresentation {
        static let sectionTitle = "Plan health fit"
        static let confidenceSectionTitle = "Plan confidence"
        static let assumptionsSectionTitle = "What shapes your plan"
        static let dataQualitySectionTitle = "Health signals in use"
        static let coreSignalsSectionTitle = "Health signals in use"
        static let missingSignalsSectionTitle = "Optional improvements"
        static let dataQualityCardSectionTitle = "Data quality"
        static let confidenceReasonsHeading = "What Forma is using"

        static let loadingTitle = FormaProductCopy.HealthIntelligence.Loading.title
        static let loadingSubtitle = FormaProductCopy.HealthIntelligence.Loading.subtitle(for: .plan)
        static let loadingAccessibilityLabel = FormaProductCopy.HealthIntelligence.Loading.accessibilityLabel

        static let emptyTitle =
            FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .plan).title
        static let emptySummary =
            FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .plan).bannerMessage
        static let emptyAccessibilityLabel =
            FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .plan).accessibilityLabel

        static let disclaimer =
            "Coaching estimates only — not a medical assessment."

        static let confidenceUnknown = "Still learning"
        static let confidenceLow = "Limited fit"
        static let confidenceModerate = "Reasonable fit"
        static let confidenceHigh = "Strong fit"

        static let assumptionsSummaryAvailable =
            "Your plan leans on the health patterns below. More consistent data makes adjustments smarter."
        static let assumptionsSummaryLimited =
            "Your plan uses partial health data today. Logging more will sharpen these estimates."
        static let assumptionsSummaryEmpty =
            "Your plan still works from profile settings. Health signals will refine it as they arrive."

        static let dataQualitySummaryAvailable =
            "These signals help Forma judge whether your plan still fits your week."
        static let dataQualitySummaryLimited =
            "Some signals are limited, so plan-fit guidance stays cautious."
        static let dataQualitySummaryEmpty =
            "Health signals have not synced enough yet for plan-fit guidance."
        static let dataQualitySummaryPartial =
            "Apple Health is connected, but only part of your data is syncing."

        static let dataQualityStrongLabel = "Strong data quality"
        static let dataQualityModerateLabel = "Moderate data quality"
        static let dataQualityLimitedLabel = "Limited data quality"

        static let dataQualityStrongExplanation =
            "Most of the health signals Forma uses are syncing consistently."
        static let dataQualityModerateExplanation =
            "Forma has enough to guide your plan, but a few signals are still partial."
        static let dataQualityLimitedExplanation =
            "Plan-fit guidance stays cautious until more health and logging data arrives."

        static let signalAppleHealthWorkouts = "Workouts"
        static let signalStepHistory = "Steps"
        static let signalActiveEnergy = "Active energy"
        static let signalSleep = "Sleep"
        static let signalHeartMetrics = "Heart recovery"
        static let signalWeight = "Weight"
        static let signalNutrition = "Nutrition logs"

        static let signalSynced = "Syncing"
        static let signalPartialSync = "Partial sync"
        static let signalAvailableQualitative = "Available"
        static let signalLimitedSync = "Limited sync"
        static let signalHeartSynced = "Recovery signals syncing"
        static let signalHeartPartial = "Partial heart recovery sync"

        static let assumptionAverageSteps = "Average steps/day"
        static let assumptionWorkoutsPerWeek = "Workouts/week"
        static let assumptionWorkoutLoad = "Workout load"
        static let assumptionRecoveryTrend = "Recovery trend"
        static let assumptionCalorieTarget = "Calorie target"
        static let assumptionProteinTarget = "Protein target"

        static let reasonWorkoutsSyncing = "Apple Health workouts are syncing"
        static let reasonStepsConsistent = "Step history looks consistent"
        static let reasonActiveEnergyAvailable = "Active energy history is available"
        static let reasonSleepAvailable = "Sleep history is contributing"
        static let reasonHeartSignalsAvailable = "Heart recovery signals are contributing"
        static let reasonNutritionLogged = "Nutrition logs are active this week"
        static let reasonWeightLogged = "Recent weigh-ins are logged"
        static let reasonTargetsSet = "Daily targets are set from your plan"

        static let improveConnectHealth = "Connect Apple Health to sync workouts, steps, and recovery signals."
        static let improveLogNutrition = "Log meals for several days to strengthen calorie guidance."
        static let improveLogWeight = "Add a few weigh-ins to improve pace feedback."
        static let improveSleepSync = "Enable sleep access so recovery trend can guide training load."
        static let improveHeartSync = "Allow heart metrics in Apple Health for richer recovery reads."
        static let improvePartialPermissions =
            "Some Apple Health permissions are still partial — open Settings to allow more signals."

        static let signalRecoveryTrend = "Recovery trend"
        static let signalWorkoutConsistency = "Workout consistency"
        static let signalAverageSteps = "Average steps"
        static let signalTrainingFrequency = "Training frequency"
        static let signalHeartVariability = "Heart variability"
        static let signalNutritionLogging = "Nutrition logging"
        static let signalActivityEnergy = "Activity energy"

        static let signalUnavailable = "Not enough data yet"
        static let signalLimitedDetail = "Limited data this period"
        static let signalWeightLogged = "Recent weigh-ins logged"
        static let signalNutritionLogged = "Logging this week"
        static let limitedStatAccessibilitySuffix = "Limited data"

        static let recoveryTrendReady = "Recovery looks steady"
        static let recoveryTrendModerate = "Recovery is mixed"
        static let recoveryTrendLow = "Recovery has been lower"
        static let recoveryTrendUnknown = "Recovery trend unclear"

        static let actionConnectHealthTitle =
            FormaProductCopy.HealthIntelligence.NoHealthPermission.actionTitle
        static let actionConnectHealthMessage =
            FormaProductCopy.HealthIntelligence.NoHealthPermission.message
        static let actionLogWeightTitle = "Log weight this week"
        static let actionLogWeightMessage =
            "A few weigh-ins help Forma track whether your plan pace still makes sense."
        static let actionLogNutritionTitle = "Log meals consistently"
        static let actionLogNutritionMessage =
            "Regular food logs make calorie and protein guidance more trustworthy."
        static let actionEnableSleepTitle = "Improve sleep sync"
        static let actionEnableSleepMessage =
            "Sleep history helps Forma read recovery before suggesting harder training days."
        static let actionEnableHRVTitle = "Add heart variability data"
        static let actionEnableHRVMessage =
            "HRV readings give Forma another recovery cue — optional, but helpful."
        static let actionPartialPermissionsTitle =
            FormaProductCopy.HealthIntelligence.PartialHealthPermission.actionTitle
        static let actionPartialPermissionsMessage =
            FormaProductCopy.HealthIntelligence.PartialHealthPermission.message

        static func confidenceHeadline(label: String) -> String {
            "\(label) for your current plan"
        }

        static func confidenceSummary(score: Double, label: String) -> String {
            switch normalizedConfidenceLabel(label) {
            case confidenceHigh:
                return "Recent health patterns line up well with your plan direction. Forma will still adjust as your week changes."
            case confidenceModerate:
                return "Your plan looks workable with the health data available. Keep logging to strengthen these estimates."
            case confidenceLow:
                return "Health data is still sparse, so treat pace and recovery guidance as a starting point — not an exact target."
            default:
                return score > 0
                    ? "Forma is still learning how your health patterns match this plan."
                    : "Connect health and log a few basics to see how well this plan fits your week."
            }
        }

        static func confidenceLabel(for confidence: PlanHealthConfidence) -> String {
            let normalized = normalizedConfidenceLabel(confidence.label)
            if !normalized.isEmpty, normalized != confidenceUnknown {
                return normalized
            }
            switch confidence.score {
            case 0.7...:
                return confidenceHigh
            case 0.45..<0.7:
                return confidenceModerate
            case 0.01..<0.45:
                return confidenceLow
            default:
                return confidenceUnknown
            }
        }

        static func workoutConsistencyValue(days: Int, windowDays: Int = 7) -> String {
            guard days > 0 else { return "No workouts logged" }
            return "\(days) of \(windowDays) days"
        }

        static func trainingFrequencyValue(days: Int) -> String {
            switch days {
            case 0:
                return "No training days yet"
            case 1:
                return "About 1 day per week"
            case 2...3:
                return "About \(days) days per week"
            default:
                return "About \(days)+ days per week"
            }
        }

        static func averageStepsValue(_ steps: Double?) -> String {
            guard let steps, steps > 0 else { return signalUnavailable }
            return Int(steps.rounded()).formatted()
        }

        static func recoveryTrendValue(score: Int?, status: RecoveryStatus) -> String {
            switch status {
            case .ready:
                return recoveryTrendReady
            case .moderate:
                return recoveryTrendModerate
            case .low:
                return recoveryTrendLow
            case .unknown:
                return recoveryTrendUnknown
            }
        }

        static func averageStepsPerDayValue(_ steps: Double?) -> String {
            guard let steps, steps > 0 else { return signalUnavailable }
            return "\(Int(steps.rounded()).formatted())/day"
        }

        static func workoutsPerWeekValue(_ days: Int?) -> String {
            guard let days else { return signalUnavailable }
            return "\(days) days/week"
        }

        static func workoutLoadValue(_ load: Double?) -> String {
            guard let load, load > 0 else { return signalUnavailable }
            if load >= 200 {
                return "Higher recent load"
            }
            if load >= 100 {
                return "Moderate recent load"
            }
            return "Lighter recent load"
        }

        static func calorieTargetValue(_ target: Int?) -> String {
            guard let target, target > 0 else { return signalUnavailable }
            return "\(target.formatted()) kcal/day"
        }

        static func proteinTargetValue(_ grams: Double?) -> String {
            guard let grams, grams > 0 else { return signalUnavailable }
            return "\(Int(grams.rounded())) g/day"
        }

        static func activeEnergyValue(_ kcal: Double?) -> String {
            guard let kcal, kcal > 0 else { return signalUnavailable }
            return "\(Int(kcal.rounded())) kcal/day avg"
        }

        static func sleepAverageValue(minutes: Double?) -> String {
            guard let minutes, minutes > 0 else { return signalUnavailable }
            let hours = minutes / 60.0
            return String(format: "%.1f h avg", hours)
        }

        static func heartMetricsQualitativeValue(
            baseline: HealthBaselineContext
        ) -> String {
            let hasHRV = baseline.availableSignals.contains(.hrv)
                && baseline.averageHRV28d != nil
            let hasRestingHR = baseline.availableSignals.contains(.restingHeartRate)
                && baseline.averageRestingHeartRate28d != nil

            switch (hasHRV, hasRestingHR) {
            case (true, true):
                return signalHeartSynced
            case (true, false), (false, true):
                return signalHeartPartial
            default:
                return signalUnavailable
            }
        }

        static func dataQualityLabel(for level: PlanHealthDataQualityLevel) -> String {
            switch level {
            case .strong: return dataQualityStrongLabel
            case .moderate: return dataQualityModerateLabel
            case .limited: return dataQualityLimitedLabel
            }
        }

        static func dataQualityExplanation(
            for level: PlanHealthDataQualityLevel,
            connection: PlanHealthConnectionState
        ) -> String {
            if connection == .partial {
                return dataQualitySummaryPartial
            }
            switch level {
            case .strong: return dataQualityStrongExplanation
            case .moderate: return dataQualityModerateExplanation
            case .limited: return dataQualityLimitedExplanation
            }
        }

        private static func normalizedConfidenceLabel(_ label: String) -> String {
            switch label.lowercased() {
            case "high":
                return confidenceHigh
            case "moderate":
                return confidenceModerate
            case "limited", "low":
                return confidenceLow
            case "unknown":
                return confidenceUnknown
            default:
                return label
            }
        }
    }
    // MARK: - Health Intelligence (shared)

    enum HealthIntelligence {
        static let limitedEstimateLabel = "Limited estimate"
        static let partialDataLabel = "Partial data"
        static let buildingLabel = "Still building"

        enum Loading {
            static let title = "Checking health signals"
            static let subtitle = "This usually takes a moment."
            static let accessibilityLabel = "Checking health signals"

            static func subtitle(for surface: HealthIntelligenceSurface) -> String {
                switch surface {
                case .today:
                    return "Reviewing recovery and activity for today."
                case .journey:
                    return "Reviewing recovery and training patterns."
                case .plan:
                    return "Reviewing how your recent data supports this plan."
                case .coach:
                    return "Reviewing health context for Coach."
                }
            }
        }

        enum NoHealthPermission {
            static let title = "Connect Apple Health"
            static let message = "Link Apple Health to unlock recovery and activity insights."
            static let reassurance = "You can keep logging meals and water as usual."
            static let actionTitle = "Connect Apple Health"
        }

        enum Integration {
            struct ActionCopy: Equatable, Sendable {
                let title: String
                let message: String
                let ctaTitle: String?
            }

            static let connectedNoData = ActionCopy(
                title: "Apple Health connected",
                message: "Waiting for today’s activity, sleep, or workout data.",
                ctaTitle: "Refresh Health Data"
            )

            static let connectedPartial = ActionCopy(
                title: "Health data limited",
                message: "Some health signals are unavailable, but Apple Health is connected.",
                ctaTitle: "Review permissions"
            )

            static func connectAction(for status: HealthIntegrationStatus) -> ActionCopy {
                switch status {
                case .permissionDenied:
                    return ActionCopy(
                        title: NoHealthPermission.title,
                        message: "Turn on Apple Health access in Settings to sync activity and recovery.",
                        ctaTitle: PartialHealthPermission.actionTitle
                    )
                case .notRequested, .unknown:
                    return ActionCopy(
                        title: NoHealthPermission.title,
                        message: NoHealthPermission.message,
                        ctaTitle: NoHealthPermission.actionTitle
                    )
                case .unavailableOnDevice, .connectedNoData, .connectedPartial, .connectedReady:
                    return ActionCopy(
                        title: NoHealthPermission.title,
                        message: NoHealthPermission.message,
                        ctaTitle: NoHealthPermission.actionTitle
                    )
                }
            }
        }

        enum PartialHealthPermission {
            static let title = "Some health signals are off"
            static let message =
                "Forma can use what is syncing now. Allow more in Apple Health for fuller insights."
            static let reassurance = "Your plan and logging still work normally."
            static let actionTitle = "Manage Health permissions"
        }

        enum NoHealthDataYet {
            static let title = "Health signals are still building"
            static let message =
                "Apple Health is connected. Insights appear after a few days of synced activity."
            static let reassurance = "Keep logging meals and check back soon."
            static let actionTitle = "Continue logging"
        }

        enum LimitedEstimate {
            static let title = "Limited estimate"
            static let message =
                "Forma has partial recovery signals today, so guidance stays cautious."
            static let reassurance = "Logging meals and water still helps your plan stay on track."
            static let actionTitle = "Ask Coach"
        }

        enum SyncFailed {
            static let title = "Health sync needs another try"
            static let message = "Forma couldn't refresh Apple Health just now."
            static let reassurance = "Your logged data is safe. Pull to refresh or try again later."
            static let actionTitle = "Try again"
        }

        enum UnavailableOnDevice {
            static let title = "Apple Health isn't available here"
            static let message = "This device can't sync Apple Health data."
            static let reassurance = "You can still log meals, water, and weight in Forma."
        }

        static func message(
            for lifecycle: HealthIntelligencePresentationLifecycle,
            surface: HealthIntelligenceSurface = .today
        ) -> HealthIntelligencePresentationMessage {
            switch lifecycle {
            case .loading:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: Loading.title,
                    message: Loading.subtitle(for: surface),
                    reassurance: nil,
                    primaryAction: .none,
                    primaryActionTitle: nil
                )
            case .ready:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: "",
                    message: "",
                    reassurance: nil,
                    primaryAction: .none,
                    primaryActionTitle: nil
                )
            case .noHealthPermission:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: NoHealthPermission.title,
                    message: NoHealthPermission.message,
                    reassurance: NoHealthPermission.reassurance,
                    primaryAction: .connectAppleHealth,
                    primaryActionTitle: NoHealthPermission.actionTitle
                )
            case .partialHealthPermission:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: PartialHealthPermission.title,
                    message: PartialHealthPermission.message,
                    reassurance: PartialHealthPermission.reassurance,
                    primaryAction: .manageHealthPermissions,
                    primaryActionTitle: PartialHealthPermission.actionTitle
                )
            case .noHealthDataYet:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: NoHealthDataYet.title,
                    message: NoHealthDataYet.message,
                    reassurance: NoHealthDataYet.reassurance,
                    primaryAction: .continueLogging,
                    primaryActionTitle: NoHealthDataYet.actionTitle
                )
            case .limitedEstimate:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: LimitedEstimate.title,
                    message: LimitedEstimate.message,
                    reassurance: LimitedEstimate.reassurance,
                    primaryAction: .askCoach,
                    primaryActionTitle: LimitedEstimate.actionTitle
                )
            case .syncFailed:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: SyncFailed.title,
                    message: SyncFailed.message,
                    reassurance: SyncFailed.reassurance,
                    primaryAction: .none,
                    primaryActionTitle: SyncFailed.actionTitle
                )
            case .unavailableOnDevice:
                return HealthIntelligencePresentationMessage(
                    lifecycle: lifecycle,
                    title: UnavailableOnDevice.title,
                    message: UnavailableOnDevice.message,
                    reassurance: UnavailableOnDevice.reassurance,
                    primaryAction: .none,
                    primaryActionTitle: nil
                )
            }
        }

        enum UIState {
            static func message(
                for kind: HealthIntelligenceUIStateKind,
                surface: HealthIntelligenceSurface = .today,
                explicitErrorMessage: String? = nil
            ) -> HealthIntelligenceUIStateMessage {
                switch kind {
                case .loading:
                    return HealthIntelligenceUIStateMessage(
                        title: Loading.title,
                        message: Loading.subtitle(for: surface),
                        reassurance: nil,
                        primaryActionTitle: nil,
                        secondaryActionTitle: nil,
                        primaryAction: .none,
                        secondaryAction: .none
                    )
                case .ready:
                    return HealthIntelligenceUIStateMessage(
                        title: "",
                        message: "",
                        reassurance: nil,
                        primaryActionTitle: nil,
                        secondaryActionTitle: nil,
                        primaryAction: .none,
                        secondaryAction: .none
                    )
                case .noHealthPermission:
                    return HealthIntelligenceUIStateMessage(
                        title: NoHealthPermission.title,
                        message: NoHealthPermission.message,
                        reassurance: NoHealthPermission.reassurance,
                        primaryActionTitle: NoHealthPermission.actionTitle,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .connectAppleHealth,
                        secondaryAction: .continueLogging
                    )
                case .partialPermission:
                    return HealthIntelligenceUIStateMessage(
                        title: PartialHealthPermission.title,
                        message: PartialHealthPermission.message,
                        reassurance: PartialHealthPermission.reassurance,
                        primaryActionTitle: PartialHealthPermission.actionTitle,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .manageHealthPermissions,
                        secondaryAction: .continueLogging
                    )
                case .healthKitUnavailable:
                    return HealthIntelligenceUIStateMessage(
                        title: UnavailableOnDevice.title,
                        message: UnavailableOnDevice.message,
                        reassurance: UnavailableOnDevice.reassurance,
                        primaryActionTitle: nil,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .none,
                        secondaryAction: .continueLogging
                    )
                case .noWorkoutHistory:
                    return HealthIntelligenceUIStateMessage(
                        title: NoWorkoutHistory.title,
                        message: NoWorkoutHistory.message(for: surface),
                        reassurance: NoWorkoutHistory.reassurance,
                        primaryActionTitle: NoWorkoutHistory.primaryAction,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .openPlan,
                        secondaryAction: .continueLogging
                    )
                case .noSleepData:
                    return HealthIntelligenceUIStateMessage(
                        title: NoSleepData.title,
                        message: NoSleepData.message,
                        reassurance: NoSleepData.reassurance,
                        primaryActionTitle: PartialHealthPermission.actionTitle,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .manageHealthPermissions,
                        secondaryAction: .continueLogging
                    )
                case .noHeartData:
                    return HealthIntelligenceUIStateMessage(
                        title: NoHeartData.title,
                        message: NoHeartData.message,
                        reassurance: NoHeartData.reassurance,
                        primaryActionTitle: PartialHealthPermission.actionTitle,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .manageHealthPermissions,
                        secondaryAction: .continueLogging
                    )
                case .notEnoughBaseline:
                    return HealthIntelligenceUIStateMessage(
                        title: NotEnoughBaseline.title,
                        message: NotEnoughBaseline.message(for: surface),
                        reassurance: NotEnoughBaseline.reassurance,
                        primaryActionTitle: Ready.continueLoggingAction,
                        secondaryActionTitle: nil,
                        primaryAction: .continueLogging,
                        secondaryAction: .none
                    )
                case .syncFailed:
                    return HealthIntelligenceUIStateMessage(
                        title: SyncFailed.title,
                        message: explicitErrorMessage ?? SyncFailed.message,
                        reassurance: SyncFailed.reassurance,
                        primaryActionTitle: SyncFailed.actionTitle,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .retrySync,
                        secondaryAction: .continueLogging
                    )
                case .staleData:
                    return HealthIntelligenceUIStateMessage(
                        title: StaleData.title,
                        message: StaleData.message,
                        reassurance: StaleData.reassurance,
                        primaryActionTitle: StaleData.primaryAction,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .refreshHealthData,
                        secondaryAction: .continueLogging
                    )
                case .remoteSyncDisabled:
                    return HealthIntelligenceUIStateMessage(
                        title: RemoteSyncDisabled.title,
                        message: RemoteSyncDisabled.message,
                        reassurance: RemoteSyncDisabled.reassurance,
                        primaryActionTitle: RemoteSyncDisabled.primaryAction,
                        secondaryActionTitle: Ready.continueLoggingAction,
                        primaryAction: .manageHealthDataSync,
                        secondaryAction: .continueLogging
                    )
                case .unknown:
                    return HealthIntelligenceUIStateMessage(
                        title: Unknown.title,
                        message: Unknown.message,
                        reassurance: Unknown.reassurance,
                        primaryActionTitle: Ready.continueLoggingAction,
                        secondaryActionTitle: AskCoach.actionTitle,
                        primaryAction: .continueLogging,
                        secondaryAction: .askCoach
                    )
                }
            }

            enum Ready {
                static let continueLoggingAction = "Continue logging"
            }

            enum AskCoach {
                static let actionTitle = "Ask Coach"
            }

            enum NoWorkoutHistory {
                static let title = "No workout history yet"
                static let reassurance = "Logging meals and water still keeps your plan on track."
                static let primaryAction = "Open Plan"

                static func message(for surface: HealthIntelligenceSurface) -> String {
                    switch surface {
                    case .journey:
                        return "Apple Health is connected, but Forma has not synced workouts yet."
                    case .plan:
                        return "Plan confidence improves after Forma sees workouts from Apple Health."
                    default:
                        return "Workout insights appear after Apple Health syncs a workout."
                    }
                }
            }

            enum NoSleepData {
                static let title = "Sleep data not available"
                static let message =
                    "Recovery guidance stays limited until sleep is shared from Apple Health."
                static let reassurance = "You can still follow your plan and log meals as usual."
            }

            enum NoHeartData {
                static let title = "Heart data not available"
                static let message =
                    "Resting heart rate and HRV help Forma refine recovery guidance when available."
                static let reassurance = "Activity and logging still keep daily guidance useful."
            }

            enum NotEnoughBaseline {
                static let title = "Health signals are still building"
                static let reassurance = "Keep logging meals and check back after a few more days."
                static func message(for surface: HealthIntelligenceSurface) -> String {
                    switch surface {
                    case .plan:
                        return "Forma needs more synced days before plan confidence can strengthen."
                    default:
                        return "Apple Health is connected. Insights improve after more synced days."
                    }
                }
            }

            enum StaleData {
                static let title = "Health data may be out of date"
                static let message = "Forma has not refreshed Apple Health recently on this device."
                static let reassurance = "Your logged meals and water are still up to date."
                static let primaryAction = "Refresh health data"
            }

            enum RemoteSyncDisabled {
                static let title = "Cloud health sync is off"
                static let message =
                    "Normalized health summaries are not syncing across devices because sync is turned off."
                static let reassurance = "Local Apple Health features on this device still work."
                static let primaryAction = "Manage health data sync"
            }

            enum Unknown {
                static let title = "Health insight unavailable"
                static let message = "Forma could not build a health summary for this screen right now."
                static let reassurance = "You can keep logging and try again later."
            }
        }
    }
}
