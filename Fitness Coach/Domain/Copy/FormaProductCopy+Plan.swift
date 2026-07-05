//
//  FormaProductCopy+Plan.swift
//  Fitness Coach
//
//  Plan tab and plan edit wizard copy.
//

import Foundation

extension FormaProductCopy {
    // MARK: - Plan rationale

    enum PlanRationale {
        static let sectionTitle = "Why This Works"
        static let maintenanceLine = "Maintenance"
        static let deficitLine = "Deficit"
        static let surplusLine = "Surplus"
        static let targetLine = "Target"
        static let seeCalculation = "View calculation"

        static let guidanceAggressiveCut =
            "This creates an aggressive fat-loss pace. Adjust if energy, hunger, or training performance drops."
        static let guidanceModerateCut =
            "This creates a steady fat-loss pace. Adjust if recovery or training quality slips."
        static let guidanceGentleCut =
            "This creates a gradual fat-loss pace. Adjust if progress stalls or energy fades."
        static let guidanceMaintenance =
            "This keeps intake aligned with estimated maintenance as your weight trends."
        static let guidanceLeanGain =
            "This adds a controlled surplus to support muscle gain alongside training."
        static let guidanceFallback =
            "Targets are based on your profile. Review assumptions if anything looks off."

        static let maintenanceEstimate = "Estimated Maintenance"
        static let healthyDeficit = "Healthy Deficit"
        static let healthySurplus = "Healthy Surplus"
        static let maintenanceTarget = "Maintenance Target"
        static let dailyTarget = "Daily Target"
        static let basedOnHeading = "Based on:"
        static let birthdayDerivedAge = "Birthday-derived age"
        static let currentWeight = "Current weight"
        static let height = "Height"
        static let biologicalSex = "Biological sex"
        static let activityLevel = "Activity level"
        static let goalWeight = "Goal weight"

        static let dailyDeficit = "Daily deficit"
        static let target = "Target"
        static let protein = "Protein"
        static let water = "Water"
        static let proteinRecoverySuffix = "to support strength and recovery"
        static let proteinGainSuffix = "to support muscle gain and recovery"
        static let viewCalculationDetails = "View calculation"
    }

    // MARK: - Plan Status

    enum PlanStatus {
        static let sectionTitle = "Plan Status"
        static let bestForLabel = "Best for"
        static let watchForLabel = "Watch for"

        static let aggressiveCutName = "Aggressive Cut"
        static let aggressiveCutExplanation =
            "A larger calorie deficit designed for faster fat loss."
        static let aggressiveCutBestFor = "Fast fat loss"
        static let aggressiveCutWatchFor =
            "Low energy, poor workout performance, high hunger"

        static let moderateCutName = "Moderate Cut"
        static let moderateCutExplanation =
            "A steady calorie deficit with room for training and recovery."
        static let moderateCutBestFor = "Sustainable fat loss"
        static let moderateCutWatchFor =
            "Plateaus, creeping hunger on hard training days"

        static let gentleCutName = "Gentle Cut"
        static let gentleCutExplanation =
            "A smaller calorie deficit that prioritizes consistency and recovery."
        static let gentleCutBestFor = "Gradual fat loss"
        static let gentleCutWatchFor =
            "Slower scale changes — focus on trends, not daily noise"

        static let maintenanceName = "Maintenance"
        static let maintenanceExplanation =
            "Calorie targets aligned to hold your current weight."
        static let maintenanceBestFor = "Weight stability"
        static let maintenanceWatchFor =
            "Slow drift up or down — adjust if trends shift"

        static let leanGainName = "Lean Gain"
        static let leanGainExplanation =
            "A calorie surplus sized to support muscle and training."
        static let leanGainBestFor = "Building muscle"
        static let leanGainWatchFor =
            "Unwanted fat gain, digestive load, recovery dips"

        static let rebuildName = "Rebuild / Recomposition"
        static let rebuildExplanation =
            "A modest surplus focused on strength and body recomposition."
        static let rebuildBestFor = "Rebuilding muscle while staying lean"
        static let rebuildWatchFor =
            "Fat gain if surplus outpaces training stimulus"

        static let needsReviewName = "Needs Review"
        static let needsReviewExplanation =
            "Forma needs a bit more information before classifying this plan."
        static let needsReviewBestFor = "Confirming your setup"
        static let needsReviewWatchFor =
            "Missing profile details or targets that need adjustment"
    }

    // MARK: - Plan Daily Targets

    enum PlanDailyTargets {
        static let sectionTitle = "Daily Targets"
        static let goToToday = "Go to Today"
        static let goToTodayAccessibilityHint = "Opens the Today tab"

        static let prescriptionLose = "Built for fat loss while preserving muscle."
        static let prescriptionGain = "Built for lean muscle growth and recovery."
        static let prescriptionMaintain = "Designed to maintain your current weight."

        static func trainingTarget(sessionsPerWeek: Int) -> String {
            sessionsPerWeek == 1
                ? "1 training session/week"
                : "\(sessionsPerWeek) training sessions/week"
        }
    }

    // MARK: - Plan Header

    enum PlanHeader {
        static let title = "Plan"
        static let subtitle = "Your strategy, targets, and checkpoints."
    }

    // MARK: - Plan Strategy Hero

    enum PlanStrategyHero {
        static let sectionTitle = "Your Strategy"
        static let dailyTargetLabel = "Daily target"
        static let expectedPaceLabel = "Expected pace"
        static let statusLabel = "Status"

        static let primaryGoalMaintain = "Maintain weight"
        static let primaryGoalGain = "Build muscle"
        static let primaryGoalLoseFallback = "Lose weight"

        static let statusAggressiveCut = "Aggressive Cut"
        static let statusModerateCut = "Moderate Cut"
        static let statusMaintenance = "Maintenance"
        static let statusLeanGain = "Lean Gain"

        static let supportiveAggressiveCut = "Demanding but achievable."
        static let supportiveModerateCut = "Built for steady progress."
        static let supportiveMaintenance = "Designed to maintain your current weight."
        static let supportiveLeanGain = "Built for lean muscle growth."

        static func primaryGoalLose(_ amount: String) -> String { "Lose \(amount)" }

        static func expectedPace(_ amount: String) -> String { "~\(amount)/week" }
    }

    // MARK: - Plan Edit Goal

    enum PlanEditGoal {
        static let sectionTitle = "What are you working toward?"
        static let recommendedBadge = "Recommended"

        static let loseFatTitle = "Lose fat"
        static let loseFatExplanation = "Trim fat, keep strength."
        static let loseFatOutcome = "Steady weekly progress."

        static let maintainTitle = "Maintain weight"
        static let maintainExplanation = "Hold your current weight."
        static let maintainOutcome = "Steady maintenance targets."

        static let gainMuscleTitle = "Build muscle"
        static let gainMuscleExplanation = "Modest surplus for training."
        static let gainMuscleOutcome = "Gradual strength-first gains."
    }

    // MARK: - Plan Edit Target & Pace

    enum PlanEditTarget {
        static let transformationTitle = "Your path"
        static let targetWeightTitle = "Where do you want to land?"
        static let paceTitle = "How fast should change happen?"
        static let currentLabel = "Now"
        static let targetLabel = "Goal"
        static let totalChangeLabel = "Total change"
        static let estimatedDurationLabel = "Time to goal"
        static let estimatedFinishLabel = "Goal date"
        static let unavailable = "—"
        static let advancedCustomTitle = "Your custom pace"
        static let advancedPeriodPickerTitle = "Period"
        static let advancedPeriodWeekly = "Weekly"
        static let advancedPeriodMonthly = "Monthly"
        static let advancedAmountWeeklyTitle = "Lose per week"
        static let advancedAmountMonthlyTitle = "Lose per month"

        static let paceGentleTitle = "Gentle"
        static let paceGentleSubtitle = "Easier to sustain"
        static let paceModerateTitle = "Moderate"
        static let paceModerateSubtitle = "Balanced progress"
        static let paceAggressiveTitle = "Ambitious"
        static let paceAggressiveSubtitle = "Faster results"
        static let paceAdvancedTitle = "Custom"
        static let paceAdvancedSubtitle = "You set the pace"

        static let weeklyChangeLabel = "Weekly change"
        static let monthlyChangeLabel = "Monthly change"
        static let difficultyLabel = "How it feels"
        static let energyPreviewLabel = "Daily energy gap"

        static func estimatedDuration(weeks: Int) -> String {
            weeks == 1 ? "About 1 week" : "About \(weeks) weeks"
        }

        static func validationEnterGoalWeight() -> String {
            "Add a target weight to continue."
        }

        static func validationGoalMustBeLower(current: String) -> String {
            "For fat loss, aim below \(current)."
        }

        static func validationGoalMustBeHigher(current: String) -> String {
            "For muscle gain, aim above \(current)."
        }

        static func validationGoalShouldMatchCurrent(current: String) -> String {
            "For maintenance, stay close to \(current)."
        }

        static func validationGoalOutOfRange(range: String) -> String {
            "Choose a target between \(range)."
        }

        static func validationInvalidNumber() -> String {
            "Use numbers only — decimals are fine."
        }

        static func validationGoalBelowMinimum(minimum: String) -> String {
            "For your height, aim for at least \(minimum)."
        }

        static func validationGoalAboveMaximum(maximum: String) -> String {
            "Choose a target up to \(maximum)."
        }

        static let maintainTargetSummary = "You'll hold steady around your current weight."

        static func maintainAroundWeight(_ weight: String) -> String {
            "You'll maintain around \(weight)."
        }
    }

    // MARK: - Plan Edit Pace Validation

    enum PlanEditPace {
        static let enterBaselineWeight =
            "Enter your current weight to preview pace."
        static let unableToPreview = "We couldn't preview this pace. Try another amount."
        static let mustBePositive = "Pace must be greater than zero for fat loss."
        static let cannotBeNegative = "Pace can't be negative."
        static let goalDateMustBeFuture = "Pick a goal date in the future."
        static func exceedsWeeklyMaximum(_ amount: String) -> String {
            "Keep weekly loss at or below \(amount)."
        }
        static func exceedsMonthlyMaximum(_ amount: String) -> String {
            "Keep monthly loss at or below \(amount)."
        }
        static let aggressivePaceWarning =
            "This pace may be hard to sustain. A slower target can help recovery and consistency."
        static let verySlowPaceWarning =
            "This pace is very gradual — progress may feel slow, but it can be easier to stick with."
        static let activityChangedCustomPace =
            "You updated activity since setting a custom pace. Double-check that pace still feels right."
        static let gainGoalIgnoresCutPace =
            "Muscle gain uses a calorie surplus — your fat-loss pace won't apply."
        static let maintainGoalIgnoresCutPace =
            "Maintenance keeps calories steady — your fat-loss pace won't apply."
    }

    // MARK: - Plan Edit Wizard

    enum PlanEditWizardCopy {
        static let discardChangesTitle = "Discard your edits?"
        static let discardChangesMessage =
            "You have unsaved changes. Leaving now will restore your previous plan."
        static let keepEditing = "Keep Editing"
        static let discardChanges = "Discard Changes"
        static let saveNoChangesHint =
            "Nothing changed — close without saving, or tweak something first."
    }

    // MARK: - Plan Edit Body Baseline

    enum PlanEditBodyBaseline {
        static let sectionTitle = "Your starting point"
        static let summaryTitle = "Body baseline"
        static let coachingLine =
            "Your daily targets update from your goal, pace, and activity level."
        static let heightLabel = "Height"
        static let weightLabel = "Current weight"
        static let heightUnit = "cm"
        static let maintenanceLabel = "Maintenance preview"
        static let bodyContextLabel = "Your stats"
        static let projectionTitle = "What this means for fuel"
        static let unitMetric = "Metric"
        static let unitImperial = "Imperial"

        static func maintenanceAtBaseline(_ kcal: String) -> String {
            "At this size, maintenance is about \(kcal)."
        }

        static let targetAdjustedFromBaseline =
            "We'll shape your daily target from here."

        static let maintenancePlaceholder =
            "Enter height and weight to preview maintenance."

        static func bodyProfileContext(height: String, weight: String) -> String {
            "Based on \(height) and \(weight)."
        }

        static func maintenancePreviewValue(_ kcal: String) -> String {
            "About \(kcal) maintenance"
        }

        static let validationEnterHeight = "Enter your height to continue."
        static let validationEnterWeight = "Enter your current weight to continue."
        static let validationInvalidNumber = "Use numbers only — decimals are fine."
        static let validationHeightOutOfRange = "Choose a height between 120 and 220 cm."
        static let validationWeightOutOfRange = "Choose a weight between 35 and 200 kg."
    }

    // MARK: - Plan Edit Activity

    enum PlanEditActivity {
        static let sectionTitle = "How active are you?"
        static let targetPreviewTitle = "Your targets right now"
        static let maintenanceImpactLabel = "Maintenance"
        static let trainingAssumptionLabel = "Training rhythm"
        static let expertTitle = "Fine-tune assumptions"
        static let expertSubtitle = "Optional details that sharpen your daily targets."
        static let macroTargetsTitle = "Daily targets"
        static let regenerateTargets = "Refresh targets"
        static let macroTargetsNote =
            "Edits save as-is. Refresh to recalculate from your choices."
        static let optionalPlaceholder = "Optional"
        static let calculatingTargets = "Updating your targets…"
        static let previewUnavailable =
            "We couldn't preview targets. Go back and check your entries."

        static let sedentaryDescription = "Mostly sitting"
        static let sedentaryExample = "Little structured exercise"

        static let lightlyActiveDescription = "Light movement"
        static let lightlyActiveExample = "1–3 training days/week"

        static let moderatelyActiveDescription = "Consistent training"
        static let moderatelyActiveExample = "3–5 sessions/week"

        static let veryActiveDescription = "High output"
        static let veryActiveExample = "6–7 hard sessions/week"

        static let athleteDescription = "Performance lifestyle"
        static let athleteExample = "Hard training plus physical job"

        static func maintenanceImpact(_ kcal: String) -> String {
            "About \(kcal) maintenance"
        }

        static func trainingAssumption(days: Int, steps: Int) -> String {
            let dayLabel = days == 1 ? "day" : "days"
            return "\(days) training \(dayLabel)/week · \(steps.formatted()) steps/day"
        }
    }

    // MARK: - Plan Edit Review

    enum PlanEditReview {
        static let finalPlanTitle = "Your plan"
        static let inputChangesTitle = "What changed"
        static let todayChangesTitle = "What changes today"
        static let todayChangesNote =
            "Save to update today's numbers."
        static let todayNoChangeNote =
            "Today's numbers should stay the same after you save."

        static let planUpToDateHeadline = "Your plan is already up to date."
        static let planReadyHeadline = "Your new plan is ready."

        static let goalLabel = "Goal"
        static let currentWeightLabel = "Current weight"
        static let targetWeightLabel = "Target weight"
        static let estimatedFinishLabel = "Goal date"
        static let difficultyAdherenceLabel = "Consistency outlook"
        static let unavailable = "—"

        static let aggressiveDeficitTitle = "This is an aggressive deficit."
        static let aggressiveDeficitBody =
            "Recovery and hunger may be harder. Consider a slower pace if consistency drops."

        static func friendlyChangeSummary(before: String, after: String) -> String {
            "Changed from \(before) to \(after)"
        }
    }

    enum PlanEditWeeklyReview {
        static let defaultTitle = "Review your weekly progress"
        static let defaultMessage =
            "Use this context to decide whether to adjust your plan. Nothing changes until you confirm."
        static let contextCardTitle = "Weekly recommendation"
        static let currentTargetLabel = "Current calorie target"
        static let suggestedChangeLabel = "Optional review"
        static let confidenceLabel = "Confidence"
        static let caveatsTitle = "Keep in mind"
    }

    // MARK: - Plan Target Regeneration

    enum PlanTargetRegeneration {
        static let navigationTitle = "Regenerated Targets"
        static let cancel = "Cancel"
        static let apply = "Apply"
        static let estimatesTitle = "Estimates"
        static let targetsTitle = "Generated Targets"
        static let aggressiveReviewMessage =
            "These targets may be aggressive. Review before applying."
        static let bmrLabel = "BMR"
        static let tdeeLabel = "TDEE"
        static let dailyDeficitLabel = "Daily deficit"
        static let caloriesLabel = "Calories"
        static let proteinLabel = "Protein"
        static let carbsLabel = "Carbs"
        static let fatLabel = "Fat"
        static let waterLabel = "Water"
        static let aggressivenessLabel = "Aggressiveness"
        static let expectedWeeklyLossLabel = "Expected weekly loss"
    }

    // MARK: - Plan Edit Save

    enum PlanEditSave {
        static let planUpdatedTitle = "Plan updated"
        static let todayTargetsRegenerated = "Today's targets are updated."

        static let onTrackMaintaining =
            "You're on track for maintaining your target weight."

        static func onTrackForGoal(_ goal: String, by estimatedDate: String) -> String {
            "You're on track for \(goal) by \(estimatedDate)."
        }

        static func onTrackForGoalOnly(_ goal: String) -> String {
            "You're on track for \(goal)."
        }
    }

    // MARK: - Plan Edit Hero

    enum PlanEditHero {
        static let shellTitle = "Adjust your plan"
        static let motivationalFatLoss = "Let's sharpen your fat-loss plan."
        static let motivationalMaintenance = "Let's keep your plan steady."
        static let motivationalMuscleGain = "Let's fuel your muscle-building plan."
        static let goalLabel = "Goal"
        static let currentWeightLabel = "Current"
        static let targetWeightLabel = "Target"
        static let maintainingTarget = "Holding at your target weight."
        static let weightUnavailable = "—"

        static func totalChangeToTarget(_ amount: String) -> String {
            "\(amount) between now and your goal."
        }

        static func estimatedFinish(_ monthYear: String) -> String {
            "On track for \(monthYear)."
        }
    }

    // MARK: - Plan Edit Difficulty

    enum PlanEditDifficulty {
        static let gentleCut = "Easier to sustain"
        static let moderateCut = "Steady effort"
        static let fasterCut = "More demanding"
        static let customCut = "Sets with your pace"
        static let maintenance = "Low pressure"
        static let leanGain = "Steady build"
    }

    // MARK: - Plan Edit Accessibility

    enum PlanEditAccessibility {
        static let progressLabel = "Plan progress"
        static let selected = "Selected"
        static let notSelected = "Not selected"
        static let selectCardHint = "Double tap to select."
        static let selectGoalCardHint = "Double tap to select this goal"
        static let warningPrefix = "Warning"
        static let errorPrefix = "Error"
        static let emptyFieldValue = "Empty"

        static func progressValue(currentStep: Int, stepCount: Int) -> String {
            "Step \(currentStep + 1) of \(max(stepCount, 1))"
        }

        static func fieldLabel(title: String, unit: String?) -> String {
            guard let unit, !unit.isEmpty else { return title }
            return "\(title), \(unit)"
        }
    }

    // MARK: - Plan Edit Common

    enum PlanEditCommon {
        static let next = "Next"
        static let savePlan = "Save Plan"
        static let cancel = "Cancel"
        static let birthdayTitle = "Birthday"
        static let notSet = "Not set"

        static func ageForPlan(_ age: String) -> String {
            "Age for your plan: \(age)"
        }

        static let sexRequiredNote =
            "Sex helps personalize calorie and macro targets."
    }

    // MARK: - Plan Projection (Edit Plan)

    enum PlanProjection {
        static let incompleteCalculation =
            "Add height, birthday, and activity to see your full preview."
        static let unavailable = "—"
        static let pacePreviewTitle = "Pace outlook"
        static let energyTitle = "Daily fuel"
        static let impactTitle = "What to expect"
        static let maintenanceLabel = "Maintenance"
        static let targetCaloriesLabel = "Daily calories"
        static let proteinLabel = "Protein"
        static let carbsLabel = "Carbs"
        static let fatLabel = "Fat"
        static let waterLabel = "Water"
        static let weeklyPaceLabel = "Weekly"
        static let monthlyPaceLabel = "Monthly"
        static let energyBalanceLabel = "Daily energy gap"
        static let adherenceLabel = "Sticking with it"
        static let recoveryLabel = "Recovery"
        static let hungerLabel = "Hunger"

        static let adherenceHigh = "High — built for steady consistency"
        static let adherenceModerate = "Moderate — reward consistent logging"
        static let adherenceChallenging = "Challenging — protect recovery and sleep"

        static let recoveryLow = "Low strain — gradual changes support recovery"
        static let recoveryModerate = "Moderate — watch training quality on hard weeks"
        static let recoveryHigh = "Higher strain — schedule deloads if performance dips"

        static let hungerLow = "Usually manageable day to day"
        static let hungerModerate = "May notice hunger on harder training days"
        static let hungerHigh = "Expect stronger hunger — plan satisfying meals"

        static let sustainabilityOk =
            "Designed to fit your training and recovery."
        static let sustainabilityCautionPace =
            "A demanding pace — watch energy and hunger."
        static let sustainabilityCalorieFloor =
            "A minimum intake floor keeps fuel supportive."
        static let sustainabilityBalanced =
            "Balanced for progress and recovery."

        static func dailyDeficit(_ kcal: Int) -> String { "\(kcal) kcal below maintenance/day" }
        static func dailySurplus(_ kcal: Int) -> String { "\(kcal) kcal above maintenance/day" }
        static let dailyBalanceNeutral = "Aligned with maintenance"
    }

    // MARK: - Plan Mission Control

    enum PlanMissionControl {
        static let adjustPlan = "Adjust Plan"
        static let adjustPlanCTAHeading = "Need to change direction?"
        static let adjustPlanCTABody =
            "Update your goal, target weight, activity, or calories. "
            + "Forma will not change your targets without confirmation."

        static let weeklyRecommendationSectionTitle = "Weekly recommendation"
        static let formulaMaintenanceLabel = "Initial estimate"
        static let learnedMaintenanceLabel = "Learned maintenance"
        static let learnedMaintenanceUnavailable =
            "Keep logging to learn your maintenance"
        static let weeklyRecommendationSafetyCopy =
            "Forma will not change your targets without confirmation."
        static let weeklyRecommendationReviewPlan = "Review plan"

        static let planAssumptionsSectionTitle = "Plan Assumptions"
        static let planAssumptionsAge = "Age"
        static let planAssumptionsHeight = "Height"
        static let planAssumptionsWeight = "Weight"
        static let planAssumptionsSex = "Sex"
        static let planAssumptionsActivity = "Activity"
        static let planAssumptionsGoalWeight = "Goal weight"
        static let planAssumptionsNotSet = "Not set"
        static let adjustActivity = "Update activity level"
        static let connectAppleHealthAccessibilityHint = "Opens Apple Health settings"
        static let planCreatedFromOnboarding =
            "Set when you first created your plan."
        static let planUpdatedAfterEdit =
            "Your plan was last updated when you adjusted it."
        static let planUpdateReasonGoalChanged =
            "You changed your target weight."
        static let planUpdateReasonActivityChanged =
            "Your activity level was updated."
        static let planUpdateReasonTargetsRegenerated =
            "Your daily targets were recalculated."

        static func planUpdateReason(_ reason: PlanLastUpdateReason) -> String {
            switch reason {
            case .onboarding:
                return planCreatedFromOnboarding
            case .goalChanged:
                return planUpdateReasonGoalChanged
            case .activityChanged:
                return planUpdateReasonActivityChanged
            case .targetsRegenerated:
                return planUpdateReasonTargetsRegenerated
            case .planAdjusted:
                return planUpdatedAfterEdit
            }
        }

        static let planConfidenceSectionTitle = "Plan Confidence"
        static let planConfidenceImproveAccuracyHeading = "Improve accuracy:"
        static let planConfidenceCompactSignalsHeading = "Compact signals:"

        static func planConfidenceScoreHeadline(
            score: Int,
            bucket: PlanConfidenceEstimateBucket
        ) -> String {
            "\(score)% — \(bucket.label) estimate"
        }

        static let planConfidenceActionLogWeight =
            "Log weight 3 times this week"
        static let planConfidenceActionLogMeals =
            "Log meals for 5 days"
        static let planConfidenceActionConnectAppleHealth =
            "Connect Apple Health"
        static let planConfidenceActionAddProfileDetails =
            "Add birthday and height for sharper estimates"

        static let planConfidenceSignalAppleHealth = "Apple Health"
        static let planConfidenceSignalRecentWeighIn = "Recent weigh-in"
        static let planConfidenceSignalFoodLogs = "Food logs"
        static let planConfidenceSignalConnected = "Connected"
        static let planConfidenceSignalNotConnected = "Not connected"
        static let planConfidenceSignalYes = "Yes"
        static let planConfidenceSignalNo = "No"
        static let planConfidenceSignalEnough = "Enough"
        static let planConfidenceSignalNotEnough = "Not enough"

        static let missingCalculation = "Plan calculation unavailable."

        static let adjustPlanAccessibilityHint = "Opens the plan editor"
        static let seeCalculationAccessibilityHint = "Shows how your targets were calculated"
        static let updateActivityAccessibilityHint = "Opens activity settings in the plan editor"
        static let targetUnavailable = "—"

        static let adjustmentRulesSectionTitle = "When to Adjust"
        static let adjustmentRulesReviewHeading = "Review your plan if:"
        static let adjustmentRuleWeightFlat = "Weight is flat for 14 days"
        static let adjustmentRulePoorEnergy = "Energy is poor for 3+ days"
        static let adjustmentRuleTrainingDrops = "Training performance drops"
        static let adjustmentRuleHighHunger = "Hunger is consistently high"
        static let adjustmentRuleWaitForWeeklySignal =
            "Wait for a clear weekly trend before changing calories"
        static let adjustmentRuleAggressiveRecoveryNote =
            "Because this is an aggressive plan, recovery matters."
        static let adjustmentTrendTooEarly = "Your trend is still too early to judge."

        static func adjustmentTrendStable(days: Int) -> String {
            "Your weight has been stable for \(days) days."
        }

        static let planReviewSectionTitle = "Next Review"
        static let planReviewBodyCopy =
            "Forma will review your weight trend and logging consistency."
        static let planReviewReadyHeadline = "Ready for review"
        static let planReviewWeighInHint =
            "Log weight to make your next review more accurate."

        static func planReviewInDays(_ days: Int) -> String {
            days == 1 ? "In 1 day" : "In \(days) days"
        }
    }

    // MARK: - Plan calculation details

    enum PlanCalculation {
        static let personalDetailsSectionTitle = "Personal details"
        static let personalDetailsAgeFromBirthday = "Derived from your birthday."
        static let personalDetailsAgeLegacy = "From your profile age."
        static let bodyDetailsSettingsTitle = "Body & stats"
        /// Legacy footnote — superseded by `Settings.BodyDetails.introCopy` on the Body & stats screen.
        static let bodyDetailsSettingsFootnote =
            "These details help Forma estimate targets and personalize your plan."
    }
}
