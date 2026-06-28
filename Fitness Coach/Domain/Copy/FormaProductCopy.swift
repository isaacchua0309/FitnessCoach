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
        static let cancel = "Cancel"
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

        // MARK: Shared (auth, plan tail, validation)

        enum V2 {

            static let startingTargetsPhrase = "starting targets"
            static let adjustsWithRealData = "Forma will adjust as real progress data comes in."

            enum MissingCloudProfile {
                static let title = "Looks like you're new"
                static let body =
                    "We couldn't find a saved Forma plan for this Google account. Let's set up your account."
                static let continueCTA = Common.continueAction
            }

            enum ProfileConflict {
                static let title = "We found an existing Forma plan"
                static let body =
                    "This Google account already has a saved plan. You can restore it, or replace it with the plan on this device."
                static let restoreCTA = "Restore existing plan"
                static let useDevicePlanCTA = "Use this device plan"
                /// Legacy alias retained for older call sites.
                static let useNewPlanCTA = useDevicePlanCTA
                static let existingPlanLabel = "Existing plan"
                static let devicePlanLabel = "This device plan"
                /// Legacy alias retained for older call sites.
                static let newPlanLabel = devicePlanLabel
                static let dailyTargetLabel = "Daily target"
                static let goalWeightLabel = "Goal weight"
                static let updatedLabel = "Updated"
                static let paceLabel = "Selected pace"
                static let useDevicePlanConfirmTitle = "Replace your saved plan?"
                static let useDevicePlanConfirmBody =
                    "This will replace the plan saved to your Google account with the profile on this device."
                static let useDevicePlanConfirmAction = "Use this device plan"
                static let cancelAction = Common.cancel
            }

            enum CloudCheckFailed {
                static let title = BootstrapError.title
                static let body = BootstrapError.body
                static let retryCTA = BootstrapError.retryCTA
            }

            enum CloudUploadFailed {
                static let title = "Plan saved on this device"
                static let body =
                    "We couldn't back it up to your Google account yet. Check your connection and try again."
                static let retryCTA = Common.tryAgain
                static let continueCTA = "Continue for now"
            }

            enum BootstrapError {
                static let title = "Couldn't check your saved plan"
                static let body = "Check your connection and try again."
                static let retryCTA = Common.tryAgain
            }

            enum AccountProfileMismatch {
                static let title = "This device has another Forma profile"
                static let body =
                    "The profile saved on this device does not match the Google account you just signed in with."
                static let restoreCTA = "Restore my Google account plan"
                static let useDeviceProfileCTA = "Use this device profile"
                static let signOutCTA = "Sign out"
                static let useDeviceProfileConfirmTitle = "Use this device profile?"
                static let useDeviceProfileConfirmBody =
                    "Your Google account does not have a saved plan yet. Forma will keep using the profile on this device and link it to your account. Nothing is uploaded until you choose to save."
                static let useDeviceProfileConfirmAction = "Use this device profile"
                static let cancelAction = Common.cancel
            }

            enum Body {
                static let unitSectionTitle = "Units"
                static let unitMetricLabel = "Metric"
                static let unitImperialLabel = "Imperial"
            }

            enum Goal {
                static let changeMaintainLabel = "Maintain"
                static let changeLosePrefix = "Lose"
                static let changeGainPrefix = "Gain"
                static let sustainableHeadline = "This looks sustainable."
                static let demandingHeadline = "This pace is demanding — monitor energy and recovery."
                static let cautionHeadline = "This pace may be hard to sustain."
                static let goalMustBeBelowCurrent =
                    "For weight loss, choose a goal weight below your current weight."
                static let bmiWarning =
                    "This goal weight may fall below a healthy range for your height. Consider a higher target."
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
                static let title = "Your starting plan is ready"
                static let subtitle =
                    "Built around your body, goal, activity, and selected pace."
                static let journeySectionTitle = "Goal"
                static let dailyTargetSectionTitle = "Daily target"
                static let heroCalorieExplanation =
                    "Balanced around your selected pace and activity."
                static let cutCalorieExplanation =
                    "A realistic target designed to support fat loss while protecting energy and training."
                static let viewMacrosCTA = "View macros"
                static let hideMacrosCTA = "Hide macros"
                static let savePlanCTA = "Save my plan"
                static let adjustPlanCTA = "Adjust plan"
                static let maintainCalorieExplanation =
                    "Balanced around maintenance while Forma learns your trend."
                static let gainCalorieExplanation =
                    "A modest surplus to support steady progress."
                static let keyTargetsSectionTitle = "Your daily targets"
                static let signedOutSaveTrustNote =
                    "Save your plan with Google so you can pick up where you left off."
                static let signedInSaveTrustNote =
                    "Your plan will be saved to your account."

                enum Strategy {
                    static let gentleCut = "Gentle cut"
                    static let moderateCut = "Moderate cut"
                    static let fasterCut = "Faster cut"
                    static let customCut = "Custom cut"
                    static let maintenance = "Maintenance"
                    static let leanGain = "Lean gain"
                }

                enum Status {
                    static let sustainableTitle = "Sustainable starting point"
                    static let aggressiveDeficitTitle = "This pace is more demanding"
                    static let aggressiveDeficitBody =
                        "You can still continue, but a slower pace may be easier to sustain."
                    static let lowCalorieTitle = "This target may be too low"
                    static let lowCalorieBody =
                        "Consider adjusting your pace to protect energy and recovery."
                    static let maintenanceTitle = "Maintenance target"
                    static let maintenanceBody =
                        "Forma will help you hold steady while it learns your trend."
                }

                enum Reassurance {
                    static let title = "Ready to start simple"
                    static let body =
                        "Log honestly, follow the daily targets, and Forma will adjust as your real progress comes in."
                    static let bullets = [
                        "No crash dieting",
                        "Targets can be adjusted later",
                        "Your plan improves with consistent logs"
                    ]
                }
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
                static let bodyFatRange = "Enter a percentage between 3 and 70, or leave it blank."
                static let pace = "Choose a sustainable expected pace."
                static let summaryIncomplete =
                    "Complete the required steps so Forma can build your starting targets."
            }
        }

        // MARK: Flow (product onboarding copy)

        enum Flow {
            enum IntroProof {
                static let title = "Forma creates long-term results"
                static let subtitle = "Backed by science, powered by AI"
                static let caption = "Build habits that help your progress last."
                static let continueCTA = "Next"
            }

            enum HeightWeight {
                static let title = "Height & Weight"
                static let subtitle = "Select your measurements"
                static let helper =
                    "Why we need this: to calculate your daily calorie and macro targets accurately."
                static let heightLabel = "Height"
                static let weightLabel = "Current weight"
                static let feetLabel = "Feet"
                static let inchesLabel = "Inches"
            }

            enum Validation {
                static let heightOutOfRange = "Choose a height between 120 and 220 cm."
                static let weightOutOfRange = "Choose a weight between 35 and 200 kg."
            }

            enum TargetWeight {
                static let title = "What's your target weight?"
                static let subtitle = "Set a realistic goal you'd like to reach"
                static let lossRulerAccessibilityLabel = "Weight to lose"
                static let unsafeGoalMessage =
                    "Choose a target within a healthy range for your height and current weight."
                static func currentToTargetSummary(current: String, target: String) -> String {
                    "Current \(current) → Target \(target)"
                }
            }

            enum TargetEncouragement {
                static let lossTitlePrefix = "Losing "
                static let lossTitleSuffix = " is a realistic target."
                static let fallbackTitle = "This is a realistic target."
                static let subtitle = "We'll help you build steady habits to get there."
                static let continueCTA = "Next"

                static func lossTitle(amount: String) -> String {
                    "\(lossTitlePrefix)\(amount)\(lossTitleSuffix)"
                }
            }

            enum Birthday {
                static let title = "When were you born?"
                static let subtitle = "This will be used to calibrate your custom plan."
                static let sexSectionTitle = "Biological sex for calorie calculation"
                static let birthDateRequiredMessage = "Select your birthday."
                static let ageOutOfRangeMessage =
                    "Age must be between \(BirthDateAgeResolver.minimumAge) and \(BirthDateAgeResolver.maximumAge)."
                static let sexRequiredMessage = "Select male or female for calorie calculation."
            }

            enum Activity {
                static let title = "How Active Are You?"
                static let subtitle = "Be honest — this affects your calorie target."
                static let optionsAccessibilityLabel = "Activity level options"
                static let sedentaryDescription = "Little or no exercise"
                static let lightlyActiveDescription = "Light exercise 1–3 days/week"
                static let moderatelyActiveDescription = "Moderate exercise 3–5 days/week"
                static let veryActiveDescription = "Hard exercise 6–7 days/week"
                static let extraActiveDescription = "Very hard exercise & physical job"
            }

            enum AppleHealth {
                static let title = "Connect to Apple Health"
                static let subtitle =
                    "Sync your daily activity between Forma and the Health app for the best results."
                static let optionalNote =
                    "Optional — you can connect later in Settings."
                static let benefitsAccessibilityLabel = "Apple Health benefits"
                static let benefits = TrainingIntegrationCopy.lockedBenefits
            }

            enum AlmostThere {
                static let title = "You're almost there!"
                static let subtitle = "Let's discover what Forma can do for you"
                static let continueCTA = "Next"
            }

            enum AlmostThereFeatures {
                static let bullets: [(icon: String, title: String, subtitle: String)] = [
                    (
                        "camera.viewfinder",
                        "Scan any meal",
                        "Point your camera and get instant nutrition info"
                    ),
                    (
                        "chart.line.uptrend.xyaxis",
                        "Track your progress",
                        "See how your habits improve week over week"
                    ),
                    (
                        "person.3.fill",
                        "Challenge friends",
                        "Compete on leaderboards and stay motivated"
                    ),
                    (
                        "arrow.triangle.2.circlepath",
                        "Adaptive goals",
                        "Calorie targets that adjust to your lifestyle"
                    )
                ]
            }

            enum FormaProof {
                static let title = "Lose more weight with Forma than on your own"
                static let subtitle = "Forma makes it easy and holds you accountable."
                static let continueCTA = "Next"
            }

            enum Summary {
                static let title = "Almost ready"
                static let subtitle = "Review your details — Forma will build starting targets from these."
                static let buildPlanCTA = "Build my plan"
                static let heightLabel = "Height"
                static let currentWeightLabel = "Current weight"
                static let targetWeightLabel = "Target weight"
                static let ageLabel = "Age"
                static let sexLabel = "Sex"
                static let activityLabel = "Activity"
            }

            enum PlanReveal {
                static let title = "Your plan is ready"
                static let subtitle = "Starting targets built from your answers."
                static let savePlanCTA = "Save & continue"
                static let signedOutSaveTrustNote =
                    "One tap with Google keeps your plan if you switch devices."
                static let signedInSaveTrustNote =
                    "Your plan saves to your account when you continue."

                static func timelineLine(estimatedWeeksLabel: String, goalWeightLabel: String) -> String {
                    "\(estimatedWeeksLabel) to reach \(goalWeightLabel)"
                }
            }

            enum SavePlan {
                static let title = "Keep your plan"
                static let subtitle = "Sign in to sync across devices — one tap."
                static let recapSectionTitle = "Your daily target"
                static let trustNote = "Your targets stay the same — sign-in just backs them up."
                static let localOnlyHint = "Saved on this device until you sign in."
                static let signedInSubtitle =
                    "Tap continue to save your plan to your Google account."
            }

            enum Components {
                static let progressAccessibilityLabel = "Onboarding progress"
                static let helperAccessibilityPrefix = "Additional guidance"
                static let rulerAccessibilityLabel = "Value selector"
                static let rulerDecrementAccessibilityLabel = "Decrease value"
                static let rulerIncrementAccessibilityLabel = "Increase value"
                static let wheelPickerAccessibilityLabel = "Picker"
            }

            enum IntroProofFeatures {
                static let bullets: [(icon: String, title: String, subtitle: String)] = [
                    (
                        "target",
                        "Realistic targets",
                        "Starting numbers that fit your body and routine."
                    ),
                    (
                        "heart.text.square.fill",
                        "Calm daily guidance",
                        "Steady coaching without guilt or crash-diet pressure."
                    ),
                    (
                        "chart.line.uptrend.xyaxis",
                        "Progress you can sustain",
                        "Forma adjusts as real data comes in."
                    )
                ]
            }

            enum Proof {
                enum TrajectoryComparison {
                    static let formaLabel = "Forma"
                    static let traditionalLabel = "Traditional diet"
                    static let formaDescription = "Maintains weight loss over time"
                    static let traditionalDescription = "Often rebounds"
                    static let disclaimer = "Illustrative example — individual results vary."
                    static let chartAccessibilityLabel =
                        "Illustrative weight trajectory. Forma maintains loss over time while a traditional diet often rebounds."
                }

                enum WeightMaintenance {
                    static let title = "Weight stays steady with Forma"
                    static let subtitle = "Illustrative trend — your plan adapts to real logging."
                    static let caption = "Example maintenance curve over 12 weeks"
                    static let yAxisLabel = "Weight"
                }

                enum Comparison {
                    static let title = "More sustainable daily targets"
                    static let subtitle = "Illustrative comparison — not a guarantee."
                    static let formaLabel = "Forma"
                    static let typicalLabel = "Typical crash diet"
                    static let metricLabel = "Daily target sustainability"
                    static let formaValueLabel = "Steady"
                    static let typicalValueLabel = "Restrictive"
                }

                enum WeightLossComparison {
                    static let withoutFormaLabel = "Without Forma"
                    static let withFormaLabel = "With Forma"
                    static let withoutFormaValue = "~2 kg lost"
                    static let withFormaValue = "~5 kg lost"
                    static let withoutFormaBarFill = 0.4
                    static let withFormaBarFill = 1.0
                    static let disclaimer = "Illustrative example — individual results vary."
                    static let chartAccessibilityLabel =
                        "Illustrative weight loss comparison. With Forma about five kilograms lost versus about two kilograms without Forma."
                }
            }
        }

        // MARK: Legacy aliases (shared validation + plan tail)

        static let planBaselineMessage = "Your first week is a baseline. Log when you can and weigh in a few times so Forma can adjust."
        static let planNotGeneratedTitle = "Complete your setup first"
        static let planNotGeneratedMessage = "Go back and finish your details so Forma can generate starting targets."

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
        static let logoutConfirmationMessage =
            "Signing out keeps this device's local data unless you delete it. If another account signs in, Forma will ask before using or replacing this profile."
        static let signOutHint = "Sign out of Forma on this device"
        static let signOutDataNote = logoutConfirmationMessage
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

        enum MacroBalance {
            static let sectionTitle = "Macro balance"
            static let protein = "Protein"
            static let carbs = "Carbs"
            static let fat = "Fat"
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
        }

        enum Activity {
            static let sectionTitle = "Today's Activity"
            static let stepsLabel = "Steps"
            static let workoutLabel = "Workout"
            static let weeklyProgressLabel = "This week"
            static let noDataYet = "No activity data yet."
            static let stepsUnavailable = "Steps unavailable"
            static let disconnectedMessage = "Connect Apple Health to see steps and workouts here."
            static let disconnectedDeniedMessage = "Apple Health access is off. Manage permissions to see activity."

            static func stepsToday(_ count: Int) -> String {
                "\(TodayActivitySectionFormatting.formatSteps(count)) steps"
            }

            static func typicalStepsAssumption(_ steps: Int) -> String {
                "Typical: \(TodayActivitySectionFormatting.formatSteps(steps))/day"
            }

            static func sessionsThisWeek(completed: Int, target: Int) -> String {
                "\(completed) of \(target) sessions"
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

        enum Momentum {
            static let sectionTitle = "Today's Momentum"
            static let startStreakToday = "Start your streak today."

            static func loggingStreakLine(days: Int) -> String {
                "Logging streak: \(dayCount(days))"
            }

            static func weekProgressLine(loggedDays: Int, totalDays: Int) -> String {
                "This week: \(loggedDays) of \(totalDays) days logged"
            }

            static func proteinStreakLine(days: Int) -> String {
                "Protein streak: \(dayCount(days))"
            }

            static func waterStreakLine(days: Int) -> String {
                "Water streak: \(dayCount(days))"
            }

            private static func dayCount(_ days: Int) -> String {
                days == 1 ? "1 day" : "\(days) days"
            }
        }

        enum DailySummary {
            static let sectionTitle = "Daily Summary"
            static let cardTitle = "Today"
            static let calories = "Calories"
            static let protein = "Protein"
            static let water = "Water"
            static let workout = "Workout"
            static let overallTitle = "Overall"
            static let explanationCaption = "Tap for how your score is calculated."
            static let explanationHint = "Shows how today's completion score is calculated"
            static let explanationTitle = "How your score works"
            static let explanationDone = "Done"
            static let accessibilityMet = "met"
            static let accessibilityNotMet = "not met"
            static let accessibilityNotApplicable = "not applicable"

            static func overallComplete(_ percent: Int) -> String {
                "\(percent)% complete"
            }

            static let explanationDetail = """
            Your daily score counts how many of today's targets you've met — not how far you've missed them.

            • Calories: within 10% of your target once you've logged food
            • Protein: at least 90% of your target
            • Water: at least 80% of your target
            • Workout: logged when training applies to your plan

            Overall is the share of applicable targets met today. Going over on calories doesn't reduce other targets — each counts separately.
            """
        }

        enum CoachTip {
            static let sectionTitle = "Coach Tip"
            static let accessibilityHint = "Opens Coach"

            static let morningNoBreakfast =
                "Start with breakfast when you're ready — protein and fiber help you stay steady through lunch."

            static func lunchProteinGap(caloriesRemaining: String, proteinGrams: Int) -> String {
                "You have \(caloriesRemaining) kcal left. Aim for \(proteinGrams)g protein at lunch."
            }

            static let eveningSimpleDinner =
                "Dinner can be simple: lean protein, rice, and vegetables."

            static let overTarget =
                "You're above today's target — keep logging honestly. Weekly consistency matters more than one meal."

            static let allGoalsMet =
                "Nice work today — protein and hydration are on track. Finish the day steady."
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
        static let nextActionQuickChipTitle = "Coach"
        static let nextActionCoachHint = "Opens Coach"
        static let nextActionConnectAppleHealthHint = "Connect Apple Health for training insights"
        static let nextActionTrainingInsightsHint = "Opens Training Insights"

        static func workoutsToday(_ count: Int) -> String {
            count == 1 ? "1 workout today" : "\(count) workouts today"
        }

        enum Mission {
            static let sectionTitle = "Today's Mission"
            static let caloriesRemainingLabel = "Calories remaining"
            static let caloriesOverLabel = "Above today's target"
            static let remainingSuffix = "remaining"
            static let overSuffix = "over"
            static let statusOnTrack = "You're perfectly on track."
            static let statusStartFirstMeal = "Start with your first meal."
            static let statusOverTarget = "You're slightly over today — no panic, just keep logging."
            static let statusProteinGap = "Protein is your biggest gap today."
            static let statusNearTarget = "You're close to today's target — finish strong."
            static let proteinOnTrack = "Protein on track"
        }

        enum NextAction {
            static let sectionTitle = "Next Best Action"
            static let logFirstMealTitle = "Log your first meal to start today."
            static let logFirstMealSubtitle = "A quick log helps Forma guide the rest of your day."
            static let addWaterSubtitle = "Staying hydrated makes the rest of your targets easier."
            static let logWeightTitle = "Log your weight today."
            static let logWeightSubtitle = "A quick weigh-in keeps your trend useful."
            static let connectHealthTitle = TrainingIntegrationCopy.connectAppleHealth
            static let connectHealthSubtitle = "Workouts and activity show up in Training Insights."
            static let reviewTodayTitle = "Review today before you wrap up."
            static let reviewTodaySubtitle = "Take a minute to reflect on what went well."
            static let onTrackTitle = "You're on track today."
            static let onTrackSubtitle = "Keep the next choice simple."

            static let ctaLogMeal = "Log meal"
            static let ctaPlanMeal = "Plan meal"
            static let ctaAddWater = "Add water"
            static let ctaLogWeight = "Log weight"
            static let ctaConnectHealth = "Connect Apple Health"
            static let ctaReviewToday = "Review today"

            static let sheetLogMealTitle = "Log meal"
            static let sheetLogWeightTitle = "Log weight"
            static let sheetLogWeightSection = "Today's weight"
            static let sheetWeightField = "Weight (kg)"
            static let sheetWeightPlaceholder = "e.g. 72.5"
            static let sheetSave = "Save"
            static let primaryButtonHint = "Performs this action on Today"

            static func eatProteinTitle(grams: Int) -> String {
                "Eat \(grams)g protein in your next meal."
            }

            static let eatProteinSubtitle = "You're a bit behind on protein — one solid meal helps."

            static func drinkWaterTitle(amountMl: Int) -> String {
                "Drink \(amountMl)ml water."
            }

            static func logMissedMealTitle(_ mealType: MealType) -> String {
                "Log \(mealLabel(mealType)) to keep today accurate."
            }

            static func logMissedMealSubtitle(_ mealType: MealType) -> String {
                "It's past \(mealLabel(mealType)) time — logging keeps your day honest."
            }

            static func ctaLogMeal(_ mealType: MealType) -> String {
                "Log \(mealLabel(mealType))"
            }

            static func primaryButtonLabel(for cta: NextBestActionCTA) -> String? {
                switch cta {
                case .logMeal:
                    return ctaLogMeal
                case .scanFood:
                    return "Scan food"
                case .addWater:
                    return ctaAddWater
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

        enum Meals {
            static let sectionTitle = "Meals"
            static let notLogged = "Not logged"
            static let addAction = "Add"
            static let optionalLabel = "Optional"
            static let loggedAccessibilityHint = "Edit this food entry"
            static let addAccessibilityHint = "Log food for this meal"
            static let expandEntries = "Show all items"
            static let collapseEntries = "Show less"
            static let emptyDayHint = "Log a meal to start today's picture."
            static let editSheetTitle = "Edit food"
            static let saveEditAction = "Save"
            static let deleteAction = "Delete entry"
            static let editAccessibilityHint = "Edit this food entry"
            static let contextMenuEdit = "Edit"
            static let contextMenuDelete = "Delete"
            static let deleteConfirmationTitle = "Delete this entry?"
            static let deleteConfirmationMessage = "This removes the food from today's log."
            static let deleteConfirmAction = "Delete"
            static let deleteCancelAction = "Cancel"

            static func loggedSummary(calories: Int, protein: Double) -> String {
                "\(calories) kcal · \(FoodEntryFormFormatter.formatMacro(protein))g protein"
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
            static let fabAccessibilityLabel = "Quick log"
            static let fabAccessibilityHint = "Log food, water, weight, or open Coach"
            static let addWaterSheetTitle = "Add water"
            static let addWaterSheetBody = "Pick an amount to log now."
            static let scanFoodUnavailableNote = "Photo scan is coming soon — use manual entry for now."

            static func title(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "Scan Food"
                case .manualEntry: return "Manual Entry"
                case .addWater: return "Add Water"
                case .logWeight: return "Log Weight"
                case .askCoach: return "Ask Coach"
                }
            }

            static func symbolName(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "camera.viewfinder"
                case .manualEntry: return "square.and.pencil"
                case .addWater: return "drop.fill"
                case .logWeight: return "scalemass.fill"
                case .askCoach: return "bubble.left.and.bubble.right.fill"
                }
            }

            static func waterAmountLabel(_ amountMl: Int) -> String {
                amountMl >= 1_000 ? "\(amountMl / 1_000)L" : "\(amountMl)ml"
            }

            static func waterAmountAccessibilityLabel(_ amountMl: Int) -> String {
                "Add \(amountMl) milliliters of water"
            }
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
        static let sectionCoachNote = "Coach note"
        static let sectionThisWeek = "This week"
        static let sectionBuildRhythm = "Build your rhythm"
        static let sectionConsistency = "Consistency"
        static let momentumEmptyBody = EmptyState.Consistency.body
        static let logToday = EmptyState.Consistency.action
        static let statusOnTrack = "On track"
        static let statusNeedsAttention = "Needs attention"
        static let statusBehind = "Behind"
        static let statusUnderTarget = "Under target"
        static let statusAboveTarget = "Above target"
        static let statusNoData = "—"
        static let workoutNone = "None yet"
        static let noAppleHealthWorkoutsThisWeek = "No Apple Health workouts this week."
        static let trainingDataFromAppleHealth = TrainingIntegrationCopy.trainingInsightsUseAppleHealth
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
        static func nextMilestone(_ kg: String) -> String { "Next milestone: \(kg)" }
        static func nextStop(_ kg: String) -> String { "Next stop: \(kg)" }

        enum Transformation {
            static let lostHeadline = "You've lost"
            static let gainedHeadline = "You've gained"
            static let maintainingHeadline = "You're maintaining"
            static let columnStarted = "Started"
            static let columnToday = "Today"
            static let columnGoal = "Goal"
            static let onboardingBaseline = "Onboarding"
            static let paceForecastFallback = "Keep logging and Forma will forecast your pace."
            static let progressStarting = "0% complete"
            static let progressAccessibilityLabel = "Progress toward goal"

            static let emotionalLayingFoundation = "Laying the foundation"
            static let emotionalMomentumBuilding = "Momentum Building"
            static let emotionalAheadOfSchedule = "You're ahead of schedule"
            static let emotionalClosingIn = "Closing in"

            static func paceForecast(month: String) -> String {
                "At this pace you'll reach your goal in \(month)."
            }

            static func progressComplete(_ percent: Int) -> String {
                "\(percent)% complete"
            }

            static func loggingStreak(days: Int) -> String {
                "\(days)-day logging streak"
            }
        }

        enum Milestones {
            static let sectionTitle = "Milestones"
            static let nextUp = "Next up"
            static let emptyBody = "Log your first meal to start unlocking milestones."

            static func progressLabel(percent: Int) -> String {
                "\(percent)% there"
            }
        }

        enum StoryTimeline {
            static let sectionTitle = "Your story"
            static let emptyBody = "Your story starts today."

            static let startedForma = "Started Forma"
            static let loggedFirstMeal = "Logged first meal"
            static let loggedFirstWater = "Logged first water"
            static let loggedFirstWeight = "Logged first weight"
            static let completedFirstWorkoutWeek = "Completed first workout week"
            static let completedFirstWeek = "Completed first week"
            static let stayedConsistentFirstWeek = "Stayed consistent for first week"
            static let loggedThirtyMeals = "Logged 30 meals"
            static let reachedHalfway = "Reached halfway to goal"
            static let monthlyRecapCompleted = "Monthly recap completed"

            static func hitCalorieGoalDays(_ count: Int) -> String {
                "Hit calorie goal \(count) days"
            }

            static func hitProteinGoalDays(_ count: Int) -> String {
                "Hit protein target \(count) days"
            }

            static func lostFirstKilogram() -> String { "Lost first kilogram" }
            static func gainedFirstKilogram() -> String { "Gained first kilogram" }

            static func longestLoggingStreak(days: Int) -> String {
                "Reached \(days)-day logging streak"
            }
        }

        enum HabitInsights {
            static let sectionTitle = "Your habits"
            static let lockedBody = "Keep logging to unlock habit insights."
            static let strongestTitle = "Your strongest habit"
            static let weakestTitle = "Weakest habit"
            static let suggestionTitle = "Suggestion"

            static let foodLoggingLabel = "Food logging consistency"
            static let proteinLabel = "Protein consistency"
            static let waterLabel = "Water consistency"
            static let calorieLabel = "Calorie adherence"
            static let trainingLabel = "Training consistency"
            static let weightLabel = "Weight logging consistency"
            static let weekendLabel = "Weekend logging"

            static let suggestWeekendLogging = "Try logging lunch first on weekends."
            static let suggestWaterCheckIn = "Add a water check-in after breakfast."
            static let suggestProteinFirstMeal = "Keep prioritising protein at your first meal."
            static let suggestLogWeightTwice = "Log weight twice this week to sharpen your trend."
            static let suggestLogNextMeal = "Log your next meal to keep your rhythm going."
            static let suggestCaloriePlanning = "Plan tomorrow's meals tonight to stay on target."
            static let suggestTrainingWalk = "A short walk or workout counts — start with ten minutes."

            static func strongestQualitative(percent: Int) -> String {
                switch percent {
                case 90...: return "Excellent."
                case 75..<90: return "Strong."
                case 60..<75: return "Solid."
                case 40..<60: return "Building."
                default: return "Getting started."
                }
            }

            static func weakestScorePrefix(percent: Int) -> String? {
                percent < 60 ? "Only" : nil
            }
        }

        enum WhyProgress {
            static let sectionTitle = "Why you're progressing"
            static let biggestReasonTitle = "The biggest reason"
            static let insufficientTitle = "Your consistency is starting to create a useful pattern."
            static let insufficientDetail = "Keep logging meals and weight so Forma can spot what's helping."

            static let calorieLikelyHelpedTitle = "Your calorie consistency likely helped most."
            static let proteinAnchorTitle = "Protein became one of your strongest anchors."
            static let loggingControlTitle = "Logging more often gave you better control."
            static let trainingRhythmTitle = "Your training rhythm became more consistent."
            static let habitsBeforeScaleTitle = "Your habits are forming before the scale catches up."
            static let waterSupportTitle = "Water consistency likely supported your routine."

            static func stayedWithinCalories(achieved: Int, eligible: Int) -> String {
                "You stayed within calories \(achieved) of the last \(eligible) days."
            }

            static func increasedProteinConsistency(percent: Int) -> String {
                "You increased protein consistency by \(percent)%."
            }

            static func loggedFoodDaysThisWeek(_ days: Int) -> String {
                days == 1
                    ? "You logged food 1 day this week."
                    : "You logged food \(days) days this week."
            }

            static func trainingDaysThisWeek(_ days: Int) -> String {
                days == 1
                    ? "Training showed up 1 day this week."
                    : "Training showed up \(days) days this week."
            }

            static func improvedWaterConsistency(percent: Int) -> String {
                "Water consistency improved by \(percent)% week over week."
            }

            static func weightTrendTowardGoal(direction: JourneyGoalDirection) -> String {
                switch direction {
                case .lose:
                    return "Your weight trend is moving toward your goal."
                case .gain:
                    return "Your weight trend is moving toward your gain goal."
                case .maintain:
                    return "Your weight trend is staying steady around your target."
                }
            }
        }

        enum BeforeToday {
            static let sectionTitle = "Before vs today"
            static let maintenanceLabel = "Maintenance"
            static let targetLabel = "Target"
            static let adaptedTargetCopy = "Your target has adapted with you"
        }

        enum PersonalRecords {
            static let sectionTitle = "Personal records"
            static let lockedBody = "Keep logging to unlock personal records."
            static let earlyRecord = "Early record"

            static let longestStreakTitle = "Longest streak"
            static let highestProteinWeekTitle = "Highest protein week"
            static let largestWeeklyLossTitle = "Largest weekly weight loss"
            static let largestWeeklyGainTitle = "Largest weekly weight gain"
            static let mostStableWeekTitle = "Most stable week"
            static let mostConsistentMonthTitle = "Most consistent month"
            static let bestWaterWeekTitle = "Best water week"
            static let mostTrainingSessionsTitle = "Most training sessions"
            static let mostMealsLoggedTitle = "Most meals logged"

            static func streakDays(_ days: Int) -> String {
                days == 1 ? "1 day" : "\(days) days"
            }

            static func proteinPerDay(_ grams: Double) -> String {
                let rounded = grams.rounded()
                return rounded.truncatingRemainder(dividingBy: 1) == 0
                    ? "\(Int(rounded))g/day"
                    : "\(Int(rounded))g/day"
            }

            static func daysOfWeek(_ days: Int) -> String {
                "\(days)/7 days"
            }

            static func sessionsPerWeek(_ count: Int) -> String {
                count == 1 ? "1/week" : "\(count)/week"
            }

            static func mealsLoggedInWeek(_ days: Int) -> String {
                days == 1 ? "1 day" : "\(days) days"
            }

            static func averageOverDays(_ days: Int) -> String {
                "Avg over \(days) logged days"
            }

            static func loggedDaysInMonth(_ days: Int) -> String {
                days == 1 ? "1 day logged" : "\(days) days logged"
            }
        }

        enum MonthlyRecap {
            static let buildingBody = "Your first monthly recap is building."

            static let weightTitle = "Weight"
            static let caloriesTitle = "Calories"
            static let proteinTitle = "Protein"
            static let waterTitle = "Water"
            static let trainingTitle = "Training"
            static let loggedDaysTitle = "Logged days"

            static func sectionTitle(monthName: String) -> String {
                "\(monthName) Summary"
            }

            static func loggedDaysSummary(_ days: Int) -> String {
                days == 1
                    ? "You logged 1 day this month."
                    : "You logged \(days) days this month."
            }

            static func calorieAdherence(percent: Int) -> String {
                "\(percent)% adherence"
            }

            static func adherencePercent(_ percent: Int) -> String {
                "\(percent)%"
            }

            static func trainingSessions(_ count: Int) -> String {
                count == 1 ? "1 session" : "\(count) sessions"
            }

            static func loggedDaysValue(_ days: Int) -> String {
                days == 1 ? "1 day" : "\(days) days"
            }

            static func bestHabit(for kind: JourneyHabitKind) -> String {
                switch kind {
                case .foodLogging:
                    return "Food logging was your strongest habit."
                case .protein:
                    return "Protein was your strongest habit."
                case .water:
                    return "Water was your strongest habit."
                case .calorieAdherence:
                    return "Calorie adherence was your strongest habit."
                case .training:
                    return "Training was your strongest habit."
                case .weightLogging:
                    return "Weight logging was your strongest habit."
                case .weekendLogging:
                    return "Weekend logging was your strongest habit."
                }
            }

            static func weightDelta(deltaKg: Double, direction: JourneyGoalDirection) -> String {
                let magnitude = String(format: "%.1fkg", abs(deltaKg))
                switch direction {
                case .lose:
                    if deltaKg < -0.05 { return "↓ \(magnitude)" }
                    if deltaKg > 0.05 { return "↑ \(magnitude)" }
                    return magnitude
                case .gain:
                    if deltaKg > 0.05 { return "↑ \(magnitude)" }
                    if deltaKg < -0.05 { return "↓ \(magnitude)" }
                    return magnitude
                case .maintain:
                    return String(format: "±%.1fkg", abs(deltaKg))
                }
            }
        }

        enum Level {
            static let sectionTitle = "Your level"
            static let xpLabel = "XP"
            static let earnExplanation = "Earn XP by logging consistently and hitting your goals."
            static let emptyBody = "Log your first meal to start earning XP."

            static func levelLabel(_ level: Int) -> String {
                "Level \(level)"
            }

            static func xpProgress(current: Int, required: Int) -> String {
                "\(current) / \(required) XP"
            }

            static func title(for level: Int) -> String {
                switch level {
                case 1:
                    return "Getting Started"
                case 2:
                    return "Building Habits"
                case 3:
                    return "Rhythm Builder"
                case 4:
                    return "Steady Progress"
                case 5:
                    return "Momentum Builder"
                case 6:
                    return "Habit Keeper"
                case 7:
                    return "Consistency Master"
                case 8:
                    return "Goal Driver"
                case 9:
                    return "Long-game Athlete"
                default:
                    return "Transformation Leader"
                }
            }
        }

        enum Streaks {
            static let buildingConsistency = "You're building consistency."
            static let keepStreakAlive = "Log today to keep your streak alive."

            static func loggingStreak(days: Int) -> String {
                "\(days)-day logging streak"
            }

            static func longestLoggingStreak(days: Int) -> String {
                "Your longest streak is \(days) days."
            }

            static func proteinStreak(days: Int) -> String {
                days == 1 ? "1-day protein streak" : "\(days)-day protein streak"
            }

            static func waterStreak(days: Int) -> String {
                days == 1 ? "1-day water streak" : "\(days)-day water streak"
            }

            static func trainingStreakWeeks(weeks: Int) -> String {
                weeks == 1 ? "1-week training streak" : "\(weeks)-week training streak"
            }

            static func keepStreakAlive(streakDays: Int) -> String {
                "Log today to keep your \(streakDays)-day streak alive."
            }
        }

        static func loggedDaysThisMonth(_ count: Int) -> String {
            count == 1 ? "1 day logged this month" : "\(count) days logged this month"
        }
        static func analyticsBasedOnDays(_ days: Int) -> String {
            days == 1 ? "Based on 1 logged day" : "Based on \(days) logged days"
        }

        enum WeeklyReview {
            static let foodTitle = "Logged food"
            static let proteinTitle = "Protein goal"
            static let waterTitle = "Water goal"
            static let trainingTitle = "Gym goal"
            static let calorieTitle = "Calorie target"
            static let weightTitle = "Weight"

            static let weightUnavailable = "Log weight to see weekly change"
            static let trainingConnectAppleHealth = TrainingIntegrationCopy.includeWorkoutsInProgress
            static let noFoodLogsSummary = "Log a meal to start your weekly review."

            static func dayFraction(achieved: Int, total: Int) -> String {
                "\(achieved)/\(total) days"
            }

            static func gymFraction(achieved: Int, expected: Int) -> String {
                "\(achieved)/\(expected)"
            }
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
        static let sectionTitle = "Why This Plan Works"
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
        static let seeCalculation = "See calculation"

        static let dailyDeficit = "Daily deficit"
        static let target = "Target"
        static let protein = "Protein"
        static let water = "Water"
        static let proteinRecoverySuffix = "to support strength and recovery"
        static let proteinGainSuffix = "to support muscle gain and recovery"
        static let viewCalculationDetails = "See calculation"
    }

    // MARK: - Plan Mission Control

    enum PlanMissionControl {
        static let heroSectionTitle = "Your Goal"
        static let adjustPlan = "Adjust Plan"
        static let progressOnPlan = "On plan"
        static let headlineLoseFallback = "Lose weight"
        static let headlineGainFallback = "Gain weight"
        static let headlineMaintainFallback = "Maintain your weight"

        static let statusStartLogging = "Your plan is set. Start logging today."
        static let statusBuildingMomentum = "You're building momentum."
        static let statusAheadOfSchedule = "You're ahead of schedule."
        static let statusStayConsistent = "Stay consistent this week."

        static let accessibilityOnboardingBaseline = "Current weight uses your onboarding baseline."
        static let accessibilityProgressZero = "0 percent complete"

        static func headlineLose(_ amount: String) -> String { "Lose \(amount)" }
        static func headlineGain(_ amount: String) -> String { "Gain \(amount)" }
        static func headlineMaintain(_ amount: String) -> String { "Maintain \(amount)" }

        static func progressRoute(_ current: String, _ goal: String) -> String {
            "Current \(current) → Goal \(goal)"
        }

        static func progressRouteMaintain(_ current: String) -> String {
            "Current \(current) · Goal hold"
        }

        static func progressComplete(_ percent: Int) -> String {
            "\(percent)% complete"
        }

        static func expectedCompletion(_ label: String) -> String {
            "Expected completion: \(label)"
        }

        static func expectedProgress(_ amount: String) -> String {
            "Expected progress: \(amount)/week"
        }

        static func accessibilityProgressComplete(_ percent: Int) -> String {
            "\(percent) percent complete"
        }

        static let dailySurplus = "Daily surplus"

        static let planAssumptionsSectionTitle = "Plan Assumptions"
        static let planAssumptionsActivity = "Activity"
        static let planAssumptionsEstimatedSteps = "Estimated Steps"
        static let planAssumptionsTraining = "Training"
        static let planAssumptionsNote =
            "These assumptions were selected during onboarding. Apple Health can improve your insights, but your calorie target will not auto-change."
        static let adjustActivity = "Adjust activity"
        static let planAssumptionsAppleHealth = "Apple Health"

        static let appleHealthInsightsNote =
            "Apple Health informs training insights. It does not automatically change your calorie targets."
        static let editSafetyCopy =
            "Adjusting your plan recalculates targets from your goal, body stats, and activity level."
        static let planAdjustmentSectionTitle = "Adjust Plan"
        static let adjustPlanCurrentHeading = "Current:"
        static let adjustPlanGoalLabel = "Goal"
        static let adjustPlanTargetWeightLabel = "Target Weight"
        static let adjustPlanActivityLabel = "Activity"
        static let adjustPlanDailyTargetLabel = "Daily Target"
        static let adjustPlanGoalLose = "Lose weight"
        static let adjustPlanGoalGain = "Gain weight"
        static let adjustPlanGoalMaintain = "Maintain weight"
        static let planCreatedFromOnboarding =
            "Your plan was created from your onboarding answers."
        static let planUpdatedAfterEdit =
            "Your plan was last updated when you adjusted it."
        static let confidenceSafeCopy =
            "These targets are estimates built from what you've shared. Log consistently for the best results."

        static let planConfidenceSectionTitle = "Plan Confidence"
        static let planConfidenceWhyHeading = "Why:"
        static let planConfidenceMissingHeading = "Missing:"

        static func planConfidenceScore(_ percent: Int) -> String {
            "\(percent)%"
        }

        static let confidenceRecentWeightLogged = "Recent weight logged"
        static let confidenceActivityLevelSelected = "Activity level selected"
        static let confidenceBirthdayHeightAvailable = "Birthday and height available"
        static let confidenceConsistentFoodLogging = "Consistent food logging"
        static let confidenceAppleHealthConnected = "Apple Health connected"
        static let confidenceTargetsReasonable = "Calorie targets look reasonable"
        static let confidenceTargetsGuardrailed = "Targets include sensible guardrails"

        static let missingRecentWeighIn = "No recent weigh-in"
        static let missingFoodLogs = "Not enough food logs yet"
        static let missingBirthdayHeight = "Birthday and height not fully set"

        static let confidenceSafetyOk = "Targets pass Forma's safety checks."
        static let confidenceSafetyCaution = "Targets include safety guardrails for your pace."
        static let confidenceSafetyWarning = "Your pace is demanding — review targets before committing."
        static let confidenceBirthdayAge = "Age is derived from your birthday."
        static let confidenceWeightTrend = "Recent weight entries improve projections."
        static let confidenceWeeklyLogging = "This week's logging supports adherence tracking."

        static let missingCalculation = "Plan calculation unavailable."
        static let missingBirthday = "Add your birthday for precise age-based estimates."
        static let missingWeightLogs = "Log weight to track goal progress."
        static let missingWeeklyLogs = "Log meals on Today to see weekly adherence."

        static let goalMilestoneDetail = "Your next weight checkpoint on the way to goal."
        static let checkpointMilestoneDetail = "A stepping-stone weight before your final goal."
        static let trainingConnectHealth = "Connect Apple Health to compare planned vs logged training."

        static func estimatedCompletion(_ label: String) -> String {
            "Expected completion: \(label)"
        }

        static func expectedWeeklyLoss(_ amount: String) -> String {
            "Expected pace: \(amount)/week"
        }

        static func totalToLose(_ amount: String) -> String {
            "\(amount) to lose"
        }

        static func totalToGain(_ amount: String) -> String {
            "\(amount) to gain"
        }

        static func remainingToMilestone(_ amount: String) -> String {
            "\(amount) to go"
        }

        static func lastUpdated(_ label: String) -> String {
            "Last updated \(label)"
        }

        static let todayMissionSectionTitle = "Today's Mission"
        static let goToToday = "Go to Today"
        static let targetUnavailable = "—"

        static func todayMissionDesignedForProgress(_ weeklyAmount: String) -> String {
            "Designed for about \(weeklyAmount)/week progress."
        }

        static func todayMissionProgressFallback(for direction: PlanMissionGoalDirection) -> String {
            switch direction {
            case .lose:
                return "Designed to support steady fat loss."
            case .gain:
                return "Designed to support gradual lean gains."
            case .maintain:
                return "Designed to hold your current weight."
            }
        }

        static func weekStatusCopy(for status: PlanWeekOverallStatus, hasWeeklyData: Bool) -> String {
            guard hasWeeklyData else {
                return weekEmptyState
            }
            switch status {
            case .strong:
                return "Strong week so far."
            case .onTrack:
                return "On track so far."
            case .building:
                return "Building momentum this week."
            case .incomplete:
                return "Keep logging to sharpen this week's picture."
            }
        }

        static let weekSectionTitle = "This Week"
        static let weekEmptyState = "Start logging today to see your weekly plan progress."
        static let weekOverallHeadline = "Overall:"

        static func weekDayAdherence(_ metric: String, achieved: Int, total: Int) -> String {
            "\(metric): \(achieved) / \(total) days"
        }

        static func weekTrainingSessions(achieved: Int, expected: Int) -> String {
            "Training: \(achieved) / \(expected) sessions"
        }

        static let weekTrainingUnavailable = "Training: No sessions planned"
        static let weekTrainingConnectHealth = "Training: Connect Apple Health"
        static let weekWeightUnavailable = "Weight: Log weight to track change"

        static let nextMilestoneSectionTitle = "Next Milestone"
        static let goToJourney = "View Journey"
        static let nextMilestoneEmpty = "Keep logging to unlock your next milestone."

        static func weightCheckpointHeadline(action: String, remaining: String, target: String) -> String {
            "\(action) \(remaining) to reach \(target)"
        }

        static func loggingConsistencyHeadline(daysRemaining: Int) -> String {
            daysRemaining >= 7
                ? "Complete 7 days of logging"
                : "Complete \(daysRemaining) more days of logging this week"
        }

        static let proteinAdherenceHeadline = "Hit protein 5 days this week"

        static func trainingAdherenceHeadline(sessionsRemaining: Int) -> String {
            sessionsRemaining == 1
                ? "Complete 1 more training session this week"
                : "Complete \(sessionsRemaining) training sessions this week"
        }

        static func weightCheckpointDetail(isGoal: Bool) -> String {
            isGoal ? goalMilestoneDetail : checkpointMilestoneDetail
        }

        static let loggingMilestoneDetail =
            "Consistent logging helps Forma track progress and refine your plan."
        static let proteinMilestoneDetail =
            "Protein supports recovery and helps protect muscle while you progress."
        static let trainingMilestoneDetail =
            "Training sessions count toward the weekly rhythm your plan assumes."
    }

    // MARK: - What happens next

    // MARK: - Plan calculation details

    enum PlanCalculation {
        static let personalDetailsSectionTitle = "Personal details"
        static let personalDetailsAgeFromBirthday = "Derived from your birthday."
        static let personalDetailsAgeLegacy = "From your profile age."
        static let bodyDetailsSettingsTitle = "Body & stats"
        static let bodyDetailsSettingsFootnote =
            "To update these, use Adjust Plan on the Plan tab."
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
        /// Placeholder support address shown in Terms and Privacy. Confirm before App Store release.
        static let supportEmail = "support@forma.app"
        static let effectiveDate = "June 26, 2026"
    }
}
