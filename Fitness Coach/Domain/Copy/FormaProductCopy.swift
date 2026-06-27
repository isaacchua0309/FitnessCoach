//
//  FormaProductCopy.swift
//  Fitness Coach
//
//  Forma — Centralized user-facing product copy.
//

import Foundation

enum FormaProductCopy {

    static let appName = "Forma"
    static let tagline = "Fitness, shaped around you."
    static let shortValueProp = "Build your plan, log with Coach, and make steady progress."

    // MARK: - Common

    enum Common {
        static let tryAgain = "Try again"
        static let retry = "Retry"
        static let refresh = "Refresh"
        static let getStarted = "Get started"
        static let continueAction = "Continue"
        static let back = "Back"
        static let completeRequiredFields = "Fill in the required fields to continue."
    }

    // MARK: - Loading

    enum Loading {
        static let app = "Loading Forma…"
        static let today = "Loading today…"
        static let plan = "Loading your plan…"
        static let journey = "Loading your journey…"
        static let training = "Loading training…"
        static let generatingPlan = "Generating your plan…"
        static let creatingProfile = "Creating your profile…"
    }

    // MARK: - Errors

    enum Error {
        static let loadToday = "We couldn't load today's log. Check your connection and try again."
        static let refreshToday = "We couldn't refresh today. Try again in a moment."
        static let loadPlan = "We couldn't load your plan. Try again in a moment."
        static let savePlan = "We couldn't save your plan. Your changes weren't applied."
        static let saveSettings = "We couldn't save those settings. Try again."
        static let regenerateTargets = "We couldn't regenerate targets. Check your inputs and try again."
        static let loadProfile = "We couldn't load your profile. Try again in a moment."
        static let loadJourney = "We couldn't load your journey. Try again in a moment."
        static let loadTraining = "We couldn't load training data. Try again in a moment."
        static let generatePlan = "We couldn't generate your plan. Check your inputs and try again."
        static let createProfile = "We couldn't create your profile. Try again in a moment."
        static let profileExists = "You already have a profile on this device."
        static let checkInputs = "Please check your inputs and try again."
        static let coachSessionTitle = "Couldn't start Coach"
        static let coachSessionMessage = "We couldn't verify your session. Check your connection and try again."
        static let coachUnavailable =
            "Coach is temporarily unavailable. Please try again later."
        static let coachNotUnderstood =
            "I couldn't quite follow that. Try rephrasing, or log with explicit calories and macros."
        static let signInTitle = "Couldn't sign in"
        static let signInMessage = "We couldn't sign you in. Check your connection and try again."
    }

    // MARK: - Sign-in

    enum SignIn {
        static let valueProposition = shortValueProp
        static let continueWithGoogle = "Continue with Google"
        static let signingIn = "Signing in…"
        static let signingInAccessibility = "Signing in"
        static let signInCancelled = "Sign-in was cancelled."
        static let trustNote = "Your Google account keeps your plan available."
        static let legalIntro = "By continuing, you agree to Forma's"
        static let termsLinkTitle = "Terms"
        static let privacyPolicyLinkTitle = "Privacy Policy"

        static let benefits: [(icon: String, title: String)] = [
            ("target", "Personalized daily targets"),
            ("bubble.left.and.bubble.right.fill", "Natural-language logging with Coach"),
            ("chart.line.uptrend.xyaxis", "Progress across nutrition and habits")
        ]
    }

    // MARK: - Onboarding

    enum Onboarding {

        // MARK: V2 (onboarding revamp)

        enum V2 {

            static let startingTargetsPhrase = "starting targets"
            static let adjustsWithRealData = "Forma will adjust as real progress data comes in."

            enum Landing {
                static let title = FormaProductCopy.tagline
                static let subtitle =
                    "Build a realistic plan, log with Coach, and make steady progress without crash dieting."
                static let benefits: [(icon: String, title: String)] = [
                    ("target", "Realistic targets from your starting point"),
                    ("heart.text.square.fill", "Calm daily guidance, not guilt"),
                    ("chart.line.uptrend.xyaxis", "Progress across nutrition and habits")
                ]
                static let bullets: [String] = benefits.map(\.title)
                static let cta = Common.getStarted
                static let existingAccountAction = "I already have an account"
                static let existingAccountAccessibilityHint = "Sign in to restore your saved plan"
            }

            enum MissingCloudProfile {
                static let title = "Looks like you're new"
                static let body =
                    "We couldn't find a saved Forma plan for this Google account. Let's set up your account."
                static let continueCTA = Common.continueAction
            }

            enum BootstrapError {
                static let title = "Couldn't check your saved plan"
                static let body = "Check your connection and try again."
                static let retryCTA = Common.tryAgain
            }

            enum Welcome {
                static let title = "Welcome to Forma"
                static let subtitle = "A few answers help us estimate your starting targets."
                static let valueCards: [(icon: String, text: String)] = [
                    ("target", "A daily calorie target"),
                    ("fork.knife", "Protein, carb, and fat targets"),
                    ("chart.line.uptrend.xyaxis", "A realistic pace"),
                    ("bubble.left.and.bubble.right.fill", "Coach-first logging"),
                    ("arrow.triangle.2.circlepath", "Weekly adjustments as your trend changes")
                ]
                static let microcopy = "Use your best estimate. You can change everything later."
            }

            enum Motivation {
                static let title = "What are you doing this for?"
                static let subtitle = "Optional — this helps Coach match your tone, not your math."
                static let optionalHint = "Optional — pick what fits, or continue whenever you're ready."
                static let feedbackTitle = "Noted"
                static let confidenceFeedback =
                    "We'll keep the pace steady so progress feels real, not rushed."
                static let performanceFeedback =
                    "We'll avoid cutting too deep so training stays supported."
                static let lowStressFeedback =
                    "Coach will keep logging simple — no streak pressure."
                static let defaultFeedback =
                    "We'll use this to personalize how Coach talks with you."
                static let feedbackMessage = defaultFeedback
            }

            enum Body {
                static let title = "Your body basics"
                static let subtitle = "Age, height, and weight help estimate your starting targets."
                static let unitSectionTitle = "Units"
                static let unitMetricLabel = "Metric"
                static let unitImperialLabel = "Imperial"
                static let genderLabel = "Sex"
                static let genderHelper = "Used only for target estimation."
                static let bodyFatLabel = "Know your body fat?"
                static let bodyFatHelper = "Optional. Leave blank if you do not know."
                static let bodyFatPlaceholder = "Optional"
            }

            enum BodyFeedback {
                static let title = "Basics look good"
                static let message =
                    "These are starting estimates only — Forma adjusts once your real trend comes in."
            }

            enum GoalFeedback {
                static let title = "Goal set"
                static let message = "Forma will use an expected pace that protects energy and recovery."
                static let maintainMessage = "Forma will set starting targets around your current weight."
                static let gainMessage = "Forma will set starting targets for steady, realistic progress."
            }

            enum Goal {
                static let title = "Set your destination"
                static let subtitle =
                    "Pick a target and pace that protect energy and training."
                static let goalWeightLabel = "Goal weight"
                static let paceSectionTitle = "Weight-loss pace"
                static let sustainableHeadline = "This looks sustainable."
                static let demandingHeadline = "This pace is demanding — monitor energy and recovery."
                static let cautionHeadline = "This pace may be hard to sustain."
                static let maintainTitle = "Maintenance target"
                static let maintainMessage =
                    "Weight-loss pace applies when your goal is below your current weight. Forma will match calories to maintenance for now."
                static let gainTitle = "Building target"
                static let gainMessage =
                    "Forma will set starting targets for steady progress toward your goal weight."
                static let goalMustBeBelowCurrent =
                    "For weight loss, choose a goal weight below your current weight."
                static let bmiWarning =
                    "This goal weight may fall below a healthy range for your height. Consider a higher target."
                static let expectedPaceLabel = "Expected pace"
                static let estimatedTimelineLabel = "Estimated timeline"
                static let dailyDeficitLabel = "Daily deficit"
            }

            enum ActivityFeedback {
                static let title = "Rhythm noted"
                static let sedentaryFeedback =
                    "We'll start with a realistic target and focus on consistency."
                static let moderatelyActiveFeedback =
                    "We'll balance fat loss with enough fuel for training."
                static let athleteFeedback =
                    "We'll avoid a deficit that cuts into recovery."
                static let defaultFeedback =
                    "This helps Forma set a better starting target."
            }

            enum Activity {
                static let title = "Your activity"
                static let subtitle =
                    "This helps Forma estimate your baseline burn and recovery needs."
                static let trainingRhythmSectionTitle = "Training rhythm"
                static let trainingDaysLabel = "Training days per week"
                static let trainingDaysHelper =
                    "Strength, sport, classes, or structured cardio."
                static let averageStepsLabel = "Average steps per day"
                static let averageStepsHelper = "A rough weekly average is enough."
            }

            enum Preferences {
                static let title = "Make Forma fit your life"
                static let subtitle =
                    "Optional details help Coach give more useful suggestions."
                static let optionalHint =
                    "All optional — skip anything you're unsure about."
                static let nameLabel = "What should Coach call you?"
                static let namePlaceholder = "Optional"
                static let nameHelper = "Used for friendly Coach messages."
                static let eatingSectionTitle = "Diet preferences"
                static let dietPlaceholder =
                    "Example: halal, no pork, high protein, simple meals"
                static let dietHelper =
                    "Optional. Add allergies or strong preferences later in Plan if needed."
                static let loggingSectionTitle = "Logging preferences"
                static let feedbackTitle = "Noted"
                static let naturalLanguageFeedback =
                    "Coach will be ready to log meals, water, weight, and workouts from natural language."
                static let noPressureFeedback =
                    "No problem. You can start with targets and use Coach when you're ready."
                static let skipHint =
                    "Skip anything you're unsure about. You can update your plan anytime."
            }

            enum Summary {
                static let title = "Almost ready"
                static let subtitle = "Review your choices — Forma will build starting targets from these."
                static let buildPlanCTA = "Build my plan"
                static let goalLabel = "Goal"
                static let paceLabel = "Pace"
                static let activityLabel = "Activity"
                static let loggingLabel = "Logging"
                static let motivationLabel = "Motivation"
                static let motivationDefault = "Steady progress"
                static let loggingDefault = "Flexible · use Coach when you're ready"
                static let maintenancePaceSummary = "Maintenance · no weekly loss target"
            }

            enum Generating {
                static let title = "Building your Forma plan…"
                static let checklist: [String] = [
                    "Estimating your baseline",
                    "Setting your calorie target",
                    "Balancing macros",
                    "Preparing Coach",
                    "Outlining your first-week focus"
                ]
                static let failureMessage =
                    "We couldn't build your plan just now. Check your details and try again."
                static let reviewDetailsCTA = "Review details"
            }

            enum PlanReveal {
                static let title = "Your plan is ready"
                static let subtitle = "These are your starting targets. \(Onboarding.V2.adjustsWithRealData)"
                static let journeySectionTitle = "Your journey"
                static let dailyTargetSectionTitle = "Daily target"
                static let macrosSectionTitle = "Daily macros"
                static let firstWeekSectionTitle = "Your first week"
                static let savePlanCTA = "Save plan"
                static let adjustPlanCTA = "Adjust plan"
                static let firstWeekBullets: [String] = [
                    "Hit your calorie target most days",
                    "Get enough protein",
                    "Log meals with Coach",
                    "Weigh in consistently"
                ]
                static let maintainCalorieExplanation =
                    "Balanced around maintenance while Forma learns your trend."
                static let gainCalorieExplanation =
                    "A modest surplus to support steady progress."
            }

            enum SavePlan {
                static let title = "Save your plan"
                static let subtitle =
                    "Your plan is saved on this device. Sign in with Google to sync it across devices."
                static let trustNote = "Sign-in backs up your plan — your starting targets stay the same."
                static let localOnlyHint = "Everything stays on this device until you sign in."
                static let continueWithoutAccountCTA = "Continue without account"
                static let planSavedOnDeviceTitle = "Your plan is saved on this device"
                static let signInRetryMessage = "Sign-in didn't finish. Your plan is still saved on this device — try again when you're ready."
                static let signedInSubtitle =
                    "Your plan will be saved to your Google account so you can pick up on any device."
                static let signedInContinueCTA = Common.continueAction
            }

            enum Validation {
                static let age = "Enter a valid age."
                static let height = "Enter a valid height."
                static let currentWeight = "Enter your current weight."
                static let goalWeight = "Enter your goal weight."
                static let trainingFrequency = "Training days per week should be 0 or more."
                static let averageSteps = "Average steps should be 0 or more."
                static let bodyFatRange = "Enter a body fat percentage between 0 and 80, or leave it blank."
                static let pace = "Choose a sustainable expected pace."
                static let summaryIncomplete =
                    "Complete the required steps so Forma can build your starting targets."
            }
        }

        // MARK: Legacy (v1) — aliases for existing onboarding views

        static let welcomeTitle = V2.Welcome.title
        static let welcomeHeadline = V2.Welcome.subtitle
        static let startButton = "Start Forma"
        static let welcomeBody = """
            Forma sets your starting targets, keeps the day simple, and lets Coach handle food, water, weight, and training from natural language.
            """
        static let welcomeFeatures: [(icon: String, text: String)] = V2.Welcome.valueCards
        static let welcomeInfoTitle = "About a minute to start"
        static let welcomeInfoMessage = V2.Welcome.microcopy
        static let activityBaselineSubtitle = "This helps Forma estimate your baseline burn and recovery needs."
        static let goalPaceSubtitle = "You can adjust expected pace later once Forma sees your trend."
        static let goalSubtitle = "Pick a realistic goal weight and an expected pace that protects training and recovery."
        static let planPreviewSubtitle = V2.PlanReveal.subtitle
        static let planBaselineMessage = "Your first week is a baseline. Log when you can and weigh in a few times so Forma can adjust."
        static let planNotGeneratedTitle = "Complete your setup first"
        static let planNotGeneratedMessage = "Go back and finish your details so Forma can generate starting targets."
        static let aggressivePlanWarning = "This expected pace is demanding. Watch energy, sleep, and how training feels."
        static let planMathSectionTitle = "Behind your numbers"
        static let preferencesSubtitle = V2.Preferences.subtitle
        static let coachFirstLoggingMessage = "After setup, Coach is where you'll log food, water, weight, workouts, and daily check-ins."
        static let noPressureMessage = V2.Preferences.skipHint

        enum Validation {
            static let age = V2.Validation.age
            static let height = V2.Validation.height
            static let currentWeight = V2.Validation.currentWeight
            static let goalWeight = V2.Validation.goalWeight
            static let trainingFrequency = V2.Validation.trainingFrequency
            static let averageSteps = V2.Validation.averageSteps
            static let bodyFatRange = V2.Validation.bodyFatRange
        }
    }

    // MARK: - Account

    enum Account {
        static let logoutConfirmationTitle = "Log out of Forma?"
        static let logoutConfirmationMessage = "You'll need to sign in again to use Forma. Your local data on this device will not be deleted."
        static let signOutHint = "Sign out of Forma on this device"
        static let signOutDataNote = "Signing out won't delete your local data."
    }

    // MARK: - Empty states

    enum EmptyState {
        static let todayTitle = "Set up your profile"
        static let todayProfileRequired = "Create your profile first so Forma can generate targets and start today's log."
        static let planTitle = "Build your plan"
        static let planGetStarted = "Share your goal with Forma and we'll create a personalized calorie, macro, and training blueprint."
        static let journeyTitle = "Your journey starts with a few logs"
        static let journeyBody = "Log meals, water, or weight in Coach to see your trend."

        enum Meals {
            static let title = "No meals yet."
            static let body = "Log your first meal to start today's picture."
            static let action = "Log meal"
            static let actionAccessibilityHint = "Opens Coach to log a meal"
        }

        enum WeightTrend {
            static let body = "Log weight a few times to reveal your trend."
            static let action = "Log weight"
            static let actionAccessibilityHint = "Opens Coach to log weight"
        }

        enum Consistency {
            static let body = "Log meals, water, or weight for a few days so Forma can show your trend."
            static let action = "Log today"
            static let actionAccessibilityHint = "Opens Coach"
        }

        enum CoachConversation {
            static let body = "Start with a quick log or ask Coach what to do next."
        }

        enum TrainingInsights {
            static let notConnectedBody = TrainingIntegrationCopy.includeWorkoutsInProgress
            static let notConnectedAction = TrainingIntegrationCopy.connectAppleHealth
            static let connectedEmptyTitle = TrainingIntegrationCopy.connectedEmptyTitle
            static let connectedEmptyBody = TrainingIntegrationCopy.connectedEmptyMessage
        }
    }

    // MARK: - Today

    enum Today {
        static let askCoachCTATitle = "Update today with Coach"
        static let askCoachCTASubtitle = "Log meals, water, weight, or training."
        static let askCoachCTAAccessibilityHint = "Opens Coach"
        static let mealsEmptyTitle = EmptyState.Meals.title
        static let mealsEmptyBody = EmptyState.Meals.body
        static let mealsLogMealAction = EmptyState.Meals.action
        static let mealsLogMealAccessibilityHint = EmptyState.Meals.actionAccessibilityHint
        static let caloriesRemaining = "Calories remaining"
        static let caloriesAboveTarget = "Above today's target"
        static let defaultCoachNote = "Anchor your next meal with protein."
        static let focusSectionTitle = "Today's focus"
        static let focusProteinLow = "Anchor your next meal with protein."
        static let focusWaterLow = "Drink water before your next meal."
        static let focusLogWeight = "Log your weight to keep your trend accurate."
        static let focusTraining = "Keep training simple and consistent."
        static let focusOnTrack = "You're on track. Keep the next choice simple."
        static let nextActionsSectionTitle = "Next actions"
        static let targetsSectionTitle = "Targets"
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
        static let nextActionQuickChipTitle = "Coach"
        static let nextActionCoachHint = "Opens Coach"
        static let nextActionConnectAppleHealthHint = "Connect Apple Health for training insights"
        static let nextActionTrainingInsightsHint = "Opens Training Insights"

        static func workoutsToday(_ count: Int) -> String {
            count == 1 ? "1 workout today" : "\(count) workouts today"
        }
        static let showCarbsAndFat = "Show carbs & fat"
        static let hideCarbsAndFat = "Hide carbs & fat"
        static let syncAccessibilityLabel = "Sync today"
        static let syncAccessibilityHint = "Reloads your local food, water, and workout log."
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

    // MARK: - Journey

    enum Journey {
        static let sectionGoalProgress = "Goal progress"
        static let sectionCoachNote = "Coach note"
        static let sectionThisWeek = "This week"
        static let sectionBuildRhythm = "Build your rhythm"
        static let sectionConsistency = "Consistency"
        static let momentumEmptyBody = EmptyState.Consistency.body
        static let logToday = EmptyState.Consistency.action
        static let metricCurrent = "Current"
        static let metricGoal = "Goal"
        static let metricToGo = "To go"
        static let statusOnTrack = "On track"
        static let statusNeedsAttention = "Needs attention"
        static let statusBehind = "Behind"
        static let statusUnderTarget = "Under target"
        static let statusAboveTarget = "Above target"
        static let statusNoData = "—"
        static let workoutNone = "None yet"
        static let noAppleHealthWorkoutsThisWeek = "No Apple Health workouts this week."
        static let trainingDataFromAppleHealth = TrainingIntegrationCopy.trainingInsightsUseAppleHealth
        static let progressEarlyDays = "Early days — each log sharpens your trend."
        static let milestoneCurrent = "Current"
        static let milestoneNext = "Next"
        static let milestoneGoal = "Goal"
        static let consistencySubtitle = "Logged days help Forma understand your trend."
        static let weightTrendEmpty = EmptyState.WeightTrend.body
        static let logWeightAction = EmptyState.WeightTrend.action
        static let logWeightAccessibilityHint = EmptyState.WeightTrend.actionAccessibilityHint
        static let logWeightWithCoach = "Log weight with Coach"
        static let coachInsightFallback = "Keep logging meals and training so Forma can show better patterns."
        static let coachInsightGettingStarted = "You're getting started. A few consistent logs will make your trend clearer."
        static let achievementUnlocked = "Completed"
        static let achievementLocked = "Not yet completed"
        static let milestonesNeedGoal = "Set a goal in Plan to see your weight roadmap."

        static func remainingToGo(_ kg: String) -> String { "\(kg) to go" }
        static func nextCheckpoint(_ kg: String) -> String { "Next checkpoint: \(kg)" }
        static func nextMilestone(_ kg: String) -> String { "Next milestone: \(kg)" }
        static func nextStop(_ kg: String) -> String { "Next stop: \(kg)" }
        static func loggedDaysThisMonth(_ count: Int) -> String {
            count == 1 ? "1 day logged this month" : "\(count) days logged this month"
        }
        static func analyticsBasedOnDays(_ days: Int) -> String {
            days == 1 ? "Based on 1 logged day" : "Based on \(days) logged days"
        }

        enum WeeklySnapshot {
            static let protein = "Protein"
            static let water = "Water"
            static let training = "Training"
            static let calories = "Calories"

            static let statusOnTrack = "On track"
            static let statusNeedsAttention = "Needs attention"
            static let statusNotStarted = "Not started"
            static let statusBuilding = "Building"
            static let statusUnderTarget = "Under target"
            static let statusAboveTarget = "Above target"

            static let trainingConnectAppleHealth = TrainingIntegrationCopy.includeWorkoutsInProgress

            static func daysAchieved(achieved: Int, total: Int) -> String {
                "\(achieved) of \(total) days"
            }

            static func workoutDaysLine(days: Int) -> String {
                days == 1 ? "1 workout day" : "\(days) workout days"
            }
        }
    }

    // MARK: - Coach

    enum Coach {
        static let headerSubtitle = "What do you want to log or ask?"
        static let todaySoFarSectionTitle = "Today so far"
        static let suggestedNextSectionTitle = "Suggested next"
        static let quickActionsSectionTitle = "Quick actions"
        static let emptyIntro = EmptyState.CoachConversation.body
        static let composerPlaceholder = "Message Coach…"
        static let foodEstimatePending = "Food estimate ready"
        static let reviewEstimate = "Review estimate"
        static let logPending = "Log"
        static let confirmPending = "Confirm"
        static let editPending = "Edit"
        static let discardPending = "Discard"
        static let foodEditPortionFooter = "Edit if the portion or cut is different."
        static let foodEditIngredientsFooter = "Edit if you know the ingredients."
        static let foodConfirmBelowFooter = "Confirm below to add it."
        static let pendingBarHint = "Use the bar below to log, edit, or discard."
    }

    // MARK: - Food form

    enum FoodForm {
        static let estimateSection = "Estimate"
        static let whatYouAteSection = "What you ate"
        static let portionSection = "Portion"
        static let nutritionSection = "Nutrition"
        static let advancedSection = "More details"

        static let foodName = "Food name"
        static let foodNamePlaceholder = "e.g. chicken rice"
        static let mealType = "Meal type"
        static let amount = "Amount"
        static let amountPlaceholder = "1"
        static let unit = "Unit"
        static let unitPlaceholder = "g, pieces, bowl…"
        static let calories = "Calories"
        static let protein = "Protein"
        static let carbs = "Carbs"
        static let fat = "Fat"
        static let fiber = "Fiber"
        static let sodium = "Sodium"
        static let notes = "Notes"
        static let notesPlaceholder = "Optional notes"

        static let kcalUnit = "kcal"
        static let gramsUnit = "g"
        static let mgUnit = "mg"
        static let mlUnit = "ml"
        static let kgUnit = "kg"
    }

    // MARK: - Plan rationale

    enum PlanRationale {
        static let sectionTitle = "Why this plan?"
        static let maintenanceEstimate = "Maintenance estimate"
        static let dailyDeficit = "Daily deficit"
        static let target = "Target"
        static let protein = "Protein"
        static let water = "Water"
        static let proteinRecoverySuffix = "to support strength and recovery"
        static let proteinGainSuffix = "to support muscle gain and recovery"
        static let viewCalculationDetails = "View calculation details"
    }

    // MARK: - What happens next

    enum WhatHappensNext {
        static let sectionTitle = "What happens next"
        static let currentPhase = "Current phase"
        static let nextCheckpoint = "Next checkpoint"
        static let likelyNextStep = "Likely next step"
        static let possibleRoadmap = "One possible path"

        static let cutFocus = "Focus on protein, sleep, and steady logging."
        static let buildFocus = "Focus on protein, training quality, and steady logging."
        static let maintenanceFocus = "Focus on consistency, sleep, and steady logging."
        static let miniCutFocus = "Focus on protein, sleep, and accurate logging."

        static let defaultCheckpoint = "Review after 4 weeks or when your weight trend stalls."

        static let maintenanceNextStep = "Hold your new weight before changing strategy."
        static let leanBulkNextStep = "A gradual surplus could make sense once you're settled at goal weight."
        static let miniCutNextStep = "A short cut could help if you want to lean out after gaining."
    }

    // MARK: - Profile form

    enum ProfileForm {
        static let baselineWeight = "Baseline weight"
        static let goalWeight = "Goal weight"
        static let calorieAggressiveness = "Calorie aggressiveness"
        static let calorieTarget = "Calorie target"
        static let proteinTarget = "Protein target"
        static let carbTarget = "Carb target"
        static let fatTarget = "Fat target"
        static let weeklyLoss = "Expected weekly loss"
        static let waterTarget = "Water target"
        static let activityLevel = "Activity level"
        static let trainingDays = "Training days per week"
        static let averageSteps = "Average steps per day"
        static let strengthSessions = "Strength sessions per week"
        static let name = "Name"
        static let age = "Age"
        static let sex = "Sex"
        static let height = "Height"
        static let bodyFat = "Body fat"
        static let unitSystem = "Unit system"
    }

    // MARK: - Legal

    enum Legal {
        static var productName: String { appName }
    }
}
