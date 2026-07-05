//
//  FormaProductCopy+Today.swift
//  Fitness Coach
//
//  Today tab and training integration copy.
//

import Foundation

extension FormaProductCopy {
    // MARK: - Today

    enum Today {
        static let askCoachCTAAccessibilityHint = "Opens Coach"
        static let mealsLogMealAccessibilityHint = FormaProductCopy.EmptyState.Meals.actionAccessibilityHint
        static let focusProteinLow = "Anchor your next meal with protein."
        static let focusWaterLow = "Drink water before your next meal."
        static let focusLogWeight = "Log your weight to keep your trend accurate."
        static let focusTraining = "Keep training simple and consistent."
        static let focusOnTrack = "You're on track. Keep the next choice simple."

        enum Header {
            static let title = "Today"
        }

        enum MacroBalance {
            static let sectionTitle = "Nutrition"
            static let protein = "Protein"
            static let calories = "Calories"
            static let carbs = "Carbs"
            static let fat = "Fat"
            static let water = "Water"
            static let remainingSuffix = "remaining"
            static let overSuffix = "over"
            static let atTarget = "At target"
            static let noTarget = "No target set"

            static func ratio(consumed: Double, target: Double) -> String {
                "\(FoodEntryFormFormatter.formatMacro(consumed)) / \(FoodEntryFormFormatter.formatMacro(target))g"
            }

            static func loggedAmount(_ consumed: Double) -> String {
                "\(FoodEntryFormFormatter.formatMacro(consumed))g logged"
            }

            static func remaining(grams: Double) -> String {
                "\(FoodEntryFormFormatter.formatMacro(max(grams, 0)))g \(remainingSuffix)"
            }

            static func over(grams: Double) -> String {
                "\(FoodEntryFormFormatter.formatMacro(max(grams, 0)))g \(overSuffix)"
            }

            static func caloriesRatio(consumed: Int, target: Int) -> String {
                "\(TodayMissionHeroFormatting.calories(consumed)) / \(TodayMissionHeroFormatting.calories(target)) kcal"
            }

            static func loggedCalories(_ consumed: Int) -> String {
                "\(TodayMissionHeroFormatting.calories(consumed)) kcal logged"
            }

            static func caloriesRemaining(_ amount: Int) -> String {
                "\(TodayMissionHeroFormatting.calories(max(amount, 0))) kcal \(remainingSuffix)"
            }

            static func caloriesOver(_ amount: Int) -> String {
                "\(TodayMissionHeroFormatting.calories(max(amount, 0))) kcal \(overSuffix)"
            }

            static func waterRatio(consumedMl: Int, targetMl: Int) -> String {
                "\(consumedMl) / \(targetMl) ml"
            }

            static func loggedWater(_ consumedMl: Int) -> String {
                "\(consumedMl) ml logged"
            }

            static func waterRemaining(_ amountMl: Int) -> String {
                "\(max(amountMl, 0))ml \(remainingSuffix)"
            }

            static func waterOver(_ amountMl: Int) -> String {
                "\(max(amountMl, 0))ml \(overSuffix)"
            }
        }

        enum Activity {
            static let sectionTitle = "Today's Activity"
            static let stepsUnavailable = "Steps unavailable"
            static let workoutCompletedLine = "Workout: Completed"
            static let workoutPlannedLine = "Workout: Planned"
            static let workoutNotLoggedLine = "Workout: Not logged"
            static let healthConnectNote = "Connect Apple Health for steps and workouts."
            static let healthDeniedNote = "Allow Apple Health access in Settings."
            static let healthUnavailableNote = "Apple Health activity is unavailable."

            static func stepsToday(_ count: Int) -> String {
                "\(TodayActivitySectionFormatting.formatSteps(count)) steps"
            }

            static func stepsProgress(current: Int, goal: Int) -> String {
                "\(TodayActivitySectionFormatting.formatSteps(current)) / \(TodayActivitySectionFormatting.formatSteps(goal)) steps"
            }
        }

        enum GoalConnection {
            static let accessibilityTitle = "Long-term goal"
            static let maintainProgress = "Stay consistent today to protect your weekly progress."
            static let openJourneyHint = "Opens Journey"
            static let openPlanHint = "Opens Plan"

            static func kgToGoal(_ kg: String) -> String {
                "\(kg)kg to your goal."
            }

            static func closerToGoal(_ goalKg: String) -> String {
                "Today's effort moves you closer to \(goalKg)kg."
            }
        }

        enum Victory {
            static let startEncouragement = "Start with one log."
            static let firstMeal = "First meal logged. Great start."
            static let proteinTarget = "Protein target reached. Excellent work."
            static let waterTarget = "Water target reached."
            static let workoutCompleted = "Workout completed."
            static let caloriesOnTarget = "Calories stayed on target."
            static let showedUp = "You showed up today."
        }

        enum SmartCoach {
            static let proteinBehind =
                "Protein is behind. Prioritize lean protein at your next meal."
            static let waterBehind = "Hydration is behind. Add water now."
            static let caloriesCloseToTarget =
                "You're close to your calorie limit. Keep dinner simple."
            static let caloriesExceeded =
                "You're above today's calorie target. Focus on hydration and recovery."
            static let workoutRecovery = "Workout logged. Protein helps recovery."
            static let endOfDayIncomplete =
                "Key habits are still open tonight. Finish strong with one more log."
            static let coachProteinAction = "Log protein with Coach"
            static let coachReviewAction = "Review with Coach"
        }

        enum YesterdayReview {
            static let sectionTitle = "Yesterday's review"
            static let viewAction = "View review"
            static let viewHint = "Opens yesterday's daily review"
            static let generateAction = "Generate yesterday's review"
            static let generateHint = "Creates a daily review for yesterday"
            static let generatedSuccess = "Yesterday's review is ready."
            static let generateFailed = "Couldn't generate the review. Try again in Coach."
        }

        enum EndOfDay {
            static let sectionTitle = "Today's Wrap-Up"
            static let overallGreatWork = "Great work"
            static let overallGoodStart = "Good start"
            static let overallStillTime = "Still time to finish strong"
            static let noLogsMessage = "One small log still counts."
            static let seeJourneyAction = "See Journey"
            static let seeJourneyHint = "Opens Journey"
            static let rowCalories = "Calories"
            static let rowProtein = "Protein"
            static let rowWater = "Water"
            static let rowWorkout = "Workout"
            static let rowNotLogged = "Not logged"
            static let workoutCompleted = "Completed"
            static let workoutNotLogged = "Not logged"
        }

        enum EmptyState {
            static let missingProfileTitle = "Set up your plan first"
            static let missingProfileBody = "Finish your profile on Plan so Forma can build today's targets."
            static let missingProfileAction = "Open Plan"
            static let missingProfileActionHint = "Opens Plan to finish your profile"

            static let newProfileMissionStatus = "Your plan is ready. Log your first meal to start today."
            static let newDayMissionStatus = "New day, fresh targets. Log your first meal when you're ready."

            static let newProfileMealsTitle = "Ready for your first log"
            static let newProfileMealsBody = "Tell Coach with a photo, voice note, or quick description — we'll track the rest."

            static let newDayMealsTitle = "Nothing logged yet today"
            static let newDayMealsBody = "Send a photo, speak, or describe your meal in Coach."

            static let logMealAction = "Log meal"
            static let logWeightAction = "Log weight"

            static let loadErrorTitle = "Couldn't load today"
            static let loadErrorLocalBody = "Something went wrong reading your log on this device. Try again."
            static let loadErrorNetworkBody = "We couldn't reach the network. Check your connection and try again."
            static let refreshErrorLocalBody = "Something went wrong refreshing your log. Try again."
            static let refreshErrorNetworkBody = "We couldn't refresh today. Check your connection and try again."

            static let appleHealthTitle = "Apple Health optional"
            static let appleHealthBody = "Connect when you want steps and workouts on Today. Your nutrition log works either way."

            static let noActivityTitle = "Quiet day so far"
            static let noActivityBody = "No workouts or steps yet today — rest days count too."

            static let noRecentWeightTitle = "Weight trend"
            static let noRecentWeightBody = "A quick weigh-in keeps your trend useful. Log when you're ready."
        }
        static let actionLogWeight = "Log weight"
        static let actionPlanProteinMeal = "Plan a protein meal"
        static let actionDrinkWater = "Drink water"
        static let actionConnectAppleHealth = TrainingIntegrationCopy.connectAppleHealth
        static let actionManageHealthAccess = TrainingIntegrationCopy.manageHealthAccess
        static let statusWeightLogged = "Weight logged"
        static let statusProteinOnTrack = "Protein on track"
        static let statusHydrationOnTrack = "Hydration on track"
        static let statusTrainingLogged = "Training logged"
        static let statusWorkoutRecorded = "Workout recorded"
        static let statusNoWorkoutToday = "No workout today"
        static let statusNoAppleHealthWorkoutToday = "No Apple Health workout today"
        static let nextActionTrainingInsightsHint = "Opens Training Insights"

        static func workoutsToday(_ count: Int) -> String {
            count == 1 ? "1 workout today" : "\(count) workouts today"
        }

        enum Mission {
            static let sectionTitle = "Today's Mission"
            static let targetReachedPrimary = "Target reached"
            static let remainingSuffix = "remaining"
            static let overSuffix = "over"
            static let logMealCTA = "Log meal"
            static let statusPlanReady = "Your plan is ready. Log your first meal to start today."
            static let statusOverTarget = "You're over target. Focus on protein and hydration for the rest of today."
            static let statusTargetReached = "Nice work. Keep the rest of the day steady."
            static let missingCalorieTarget = "No calorie target set"
            static let proteinOnTrack = "Protein on track"

            static func goalLine(targetKcal: Int) -> String {
                "Goal: \(TodayMissionHeroFormatting.calories(targetKcal)) kcal"
            }

            static func consumedLine(consumedKcal: Int) -> String {
                "Consumed: \(TodayMissionHeroFormatting.calories(consumedKcal)) kcal"
            }

            static func proteinRemainingLine(grams: Double) -> String {
                "Protein remaining: \(TodayMissionHeroFormatting.proteinGrams(grams))g"
            }

            static func primaryRemaining(_ calories: Int) -> String {
                "\(TodayMissionHeroFormatting.calories(calories)) \(remainingSuffix)"
            }

            static func primaryOver(_ calories: Int) -> String {
                "\(TodayMissionHeroFormatting.calories(calories)) \(overSuffix)"
            }
        }

        enum NextAction {
            static let sectionTitle = "Next Best Action"
            static let logBreakfastTitle = "Log breakfast to start today."
            static let logBreakfastSubtitle = "Send a photo, speak, or describe your meal."
            static let logFirstMealTitle = "Log your first meal to start today."
            static let logFirstMealSubtitle = "Send a photo, speak, or describe your meal."
            static let eatProteinTitle = "Protein is your biggest gap."
            static let eatProteinSubtitle = "A high-protein meal will help protect muscle during your cut."
            static let hydrationBehindTitle = "Hydration is behind."
            static let hydrationBehindSubtitle = "Add water now to stay on pace."
            static let completeWorkoutTitle = "Complete today's workout."
            static let completeWorkoutSubtitle = "Logging movement keeps your plan accurate."
            static let keepDinnerLightTitle = "Keep dinner light tonight."
            static let keepDinnerLightSubtitle = "You're close to your calorie target — lighter choices help you finish on plan."
            static let focusHydrationRecoveryTitle = "Focus on hydration and recovery."
            static let focusHydrationRecoverySubtitle = "You're above today's calorie target. Water and rest matter most now."
            static let allTargetsMetTitle = "Great work — maintain today."
            static let allTargetsMetSubtitle = "Key targets are on track. Stay consistent with your next choices."

            static let ctaLogMeal = "Log meal"
            static let ctaLogBreakfast = "Log breakfast"
            static let ctaScanFood = "Scan food"
            static let ctaAddWater = "Add water"
            static let ctaLogWorkout = "Log workout"
            static let ctaLogDinner = "Log dinner"
            static let ctaLogWeight = "Log weight"
            static let ctaConnectHealth = "Connect Apple Health"
            static let ctaReviewToday = "Review today"

            static let sheetLogWeightTitle = "Log weight"
            static let sheetLogWeightSection = "Today's weight"
            static let sheetWeightField = "Weight (kg)"
            static let sheetWeightPlaceholder = "e.g. 72.5"
            static let sheetSave = "Save"
            static let primaryButtonHint = "Performs this action on Today"

            static func ctaLogMeal(_ mealType: MealType) -> String {
                "Log \(mealLabel(mealType))"
            }

            static func primaryButtonLabel(for cta: NextBestActionCTA) -> String? {
                switch cta {
                case .logMeal:
                    return ctaLogMeal
                case .scanFood:
                    return ctaScanFood
                case .addWater:
                    return ctaAddWater
                case .logWorkout:
                    return ctaLogWorkout
                case .logWeight:
                    return ctaLogWeight
                case .openHealth:
                    return ctaConnectHealth
                case .reviewToday:
                    return ctaReviewToday
                case .none:
                    return nil
                }
            }

            private static func mealLabel(_ mealType: MealType) -> String {
                switch mealType {
                case .breakfast: return "breakfast"
                case .lunch: return "lunch"
                case .dinner: return "dinner"
                case .snack: return "a snack"
                case .unknown: return "a meal"
                }
            }
        }

        enum HealthIntelligence {
            static let loadingTitle = FormaProductCopy.HealthIntelligence.Loading.title
            static let loadingSubtitle = FormaProductCopy.HealthIntelligence.Loading.subtitle(for: .today)
            static let loadingAccessibilityLabel = FormaProductCopy.HealthIntelligence.Loading.accessibilityLabel
            static let limitedEstimate = FormaProductCopy.HealthIntelligence.limitedEstimateLabel
            static let workoutComplete = "Workout complete"
            static let noWorkoutYet = "No workout logged yet"
            static let connectHealthFallback =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthPermission, surface: .today).bannerMessage
            static let continueLoggingFallback =
                FormaProductCopy.HealthIntelligence.message(for: .limitedEstimate, surface: .today).bannerMessage
            static let limitedRecoveryMissingSignals =
                "Recovery estimate is limited because key sleep or heart signals are missing."
            static let limitedRecoveryUnavailable =
                "Recovery estimate is unavailable because not enough signals are available yet."
            static let limitedRecoveryPartialSignals =
                "Recovery estimate is limited because some recovery signals are incomplete."
            static let staleDataLabel = "May be out of date"
            static let syncFailedWithCacheLabel = "Last refresh failed — showing cached data"

            static func missingRecoverySignals(_ signals: [String]) -> String {
                "Missing: \(signals.joined(separator: ", "))."
            }

            enum Recovery {
                static let sectionTitle = "Recovery"
                static let readyExplanation =
                    "Available recovery signals look supportive for your usual plan today."
                static let moderateExplanation =
                    "Available recovery signals look mixed, so steady pacing may work better than pushing hard."
                static let lowExplanation =
                    "Available recovery signals suggest keeping today lighter and prioritizing rest."
            }

            enum DailyMission {
                static let sectionTitle = "Daily mission"
                static let readyHeadline = "Ready for your plan"
                static let moderateHeadline = "Train with care today"
                static let lowHeadline = "Prioritize recovery"
                static let unknownHeadline = "Recovery still forming"
                static let workoutCompleteDetail = "Workout complete — refuel and hydrate."
                static let noWorkoutDetail = "No workout logged yet."

                static func caloriesRemaining(_ kcal: Int) -> String {
                    "\(TodayMissionHeroFormatting.calories(max(kcal, 0))) kcal remaining"
                }

                static func proteinRemaining(_ grams: Double) -> String {
                    "\(TodayMissionHeroFormatting.proteinGrams(max(grams, 0)))g protein remaining"
                }

                static func waterRemaining(_ ml: Int) -> String {
                    "\(max(ml, 0))ml water remaining"
                }
            }

            enum NextAction {
                static let sectionTitle = "Suggested next step"
            }

            enum Workout {
                static let sectionTitle = "Today's workout"
                static let emptyTitle = "No workouts yet"
                static let emptyMessage =
                    "Workout insights appear after Apple Health syncs a workout."
            }

            enum AdaptiveNutrition {
                static let sectionTitle = "Adaptive nutrition"
                static let defaultTitle = "Fuel for today"
                static let postWorkoutTitle = "Refuel after training"

                static func proteinRemaining(_ grams: Int) -> String {
                    "\(grams)g protein left to target"
                }

                static func extraWater(_ ml: Int) -> String {
                    "Aim for \(max(ml, 0))ml extra water today"
                }
            }
        }

        enum Meals {
            static let sectionTitle = "Meals"
            static let readyStatus = "Ready"
            static let addAction = "Add"
            static let optionalLabel = "Optional"
            static let loggedAccessibilityValue = "Logged"
            static let loggedAccessibilityHint = "Edit this food entry"
            static let addAccessibilityHint = "Opens Coach to log food for this meal"
            static let emptyDayHint = "Log with Coach to start today's picture."
            static let editSheetTitle = "Edit nutrition"
            static let saveEditAction = "Save"
            static let deleteAction = "Delete entry"
            static let editAccessibilityHint = "Edit this food entry"
            static let contextMenuEdit = "Edit"
            static let contextMenuDelete = "Delete"
            static let deleteConfirmationTitle = "Delete this entry?"
            static let deleteConfirmationMessage = "This removes the food from today's log."
            static let deleteConfirmAction = "Delete"
            static let deleteCancelAction = "Cancel"

            static func caloriesLine(_ calories: Int) -> String {
                "\(calories) kcal"
            }

            static func proteinLine(_ protein: Double) -> String {
                "\(FoodEntryFormFormatter.formatMacro(protein))g protein"
            }

            static func multipleItemsAccessibilityLabel(_ count: Int) -> String {
                "\(count) logged items"
            }

            static func mealTitle(_ mealType: MealType, isOptional: Bool) -> String {
                switch mealType {
                case .snack:
                    return "Snacks"
                case .breakfast, .lunch, .dinner:
                    return FoodEntryFormFormatter.mealTypeLabel(mealType)
                case .unknown:
                    return "Meal"
                }
            }

            static func addAccessibilityLabel(for mealType: MealType) -> String {
                "Add \(FoodEntryFormFormatter.mealTypeLabel(mealType).lowercased())"
            }
        }

        enum QuickActions {
            static let sectionTitle = "Fast log"
            static let logMealMicrocopy = "Coach will estimate it from a photo, voice note, or text."
            static let scanMealAccessibilityHint = "Opens the camera to scan your meal"

            static func inlineAccessibilityHint(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return scanMealAccessibilityHint
                case .logMeal: return "Opens Coach to log your meal"
                }
            }

            static func title(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "Scan Meal"
                case .logMeal: return "Log Meal"
                }
            }

            static func symbolName(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "camera.viewfinder"
                case .logMeal: return "text.bubble.fill"
                }
            }
        }

        enum Water {
            static let sectionTitle = "Water"
            static let symbolName = "drop.fill"
            static let logFailedMessage = "Couldn't add water. Try again."
            static let tapDebounceSeconds = 0.35

            static func quickAddLabel(_ amountMl: Int) -> String {
                amountMl >= 1_000 ? "+1 L" : "+\(amountMl) ml"
            }

            static func addedMessage(amountMl: Int) -> String {
                if amountMl >= 1_000 {
                    return "Added 1 L"
                }
                return "Added \(amountMl) ml"
            }

            static func waterAmountAccessibilityLabel(_ amountMl: Int) -> String {
                "Add \(amountMl) milliliters of water"
            }
        }

        static let showCarbsAndFat = "Show carbs & fat"
        static let hideCarbsAndFat = "Hide carbs & fat"
    }
    // MARK: - Training

    enum Training {
        static let restDayGuidance = "When you train, Apple Health workouts appear in Training Insights."
        static let noWorkoutsHint = "No Apple Health workouts yet this week."
        static let muscleEmptyHint = "Connect Apple Health to see workout patterns over time."
        static let workoutCorrectionHint = "Workouts come from Apple Health — manage the connection in Settings."

        enum Integration {
            static let connectAppleHealth = TrainingIntegrationCopy.connectAppleHealth
            static let poweredByAppleFitness = TrainingIntegrationCopy.poweredByAppleFitness
            static let valueProposition = TrainingIntegrationCopy.valueProposition
            static let screenTitle = TrainingIntegrationCopy.screenTitle
            static let lockedTitle = TrainingIntegrationCopy.lockedTitle
            static let lockedBody = TrainingIntegrationCopy.lockedBody
            static let lockedSecondaryNote = TrainingIntegrationCopy.lockedSecondaryNote
        }
    }
}
