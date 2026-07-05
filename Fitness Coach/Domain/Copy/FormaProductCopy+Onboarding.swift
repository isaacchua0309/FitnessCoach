//
//  FormaProductCopy+Onboarding.swift
//  Fitness Coach
//
//  Onboarding flow copy.
//

import Foundation

extension FormaProductCopy {
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
                static let existingPlanLabel = "Existing plan"
                static let devicePlanLabel = "This device plan"
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
                static let title = "Building your Forma plan"
                static let successTitle = "Your plan is ready"
                static let checklist: [String] = [
                    "Estimating your baseline",
                    "Setting your calorie target",
                    "Balancing your macros",
                    "Preparing daily guidance",
                    "Getting your plan ready"
                ]
                static let anticipationText = "Your daily targets are almost ready."
                static let slowGenerationMessage = "Still preparing your plan…"
                static let failureTitle = "We couldn't build your plan yet."
                static let failureMessage = "Please try again."
                static let tryAgainCTA = "Try again"
                static let goBackCTA = "Go back"

                enum Subtitle {
                    static let loss = "Preparing targets for steady, sustainable progress."
                    static let gain = "Preparing targets to help you gain consistently."
                    static let maintain = "Preparing targets to help you stay consistent."
                    static let fallback = "Turning your answers into daily targets."
                }
            }

            enum PlanReveal {
                static let cutCalorieExplanation =
                    "Designed for steady, sustainable progress."
                static let adjustPlanCTA = "Adjust plan"
                static let maintainCalorieExplanation =
                    "We'll help you stay consistent with clear daily targets."
                static let gainCalorieExplanation =
                    "Designed to help you eat enough consistently."

                enum Cards {
                    static let destinationBadge = "Your destination"
                    static let journeyTitle = "Your journey"
                    static let firstWeekTitle = "Your first mission"
                    static let dailyFuelTitle = "Daily fuel"
                }

                enum GoalHero {
                    static let sectionTitle = Cards.destinationBadge

                    static func maintainHeadline(targetWeight: String) -> String {
                        "Maintain around \(targetWeight)"
                    }

                    static func lossHeadline(targetWeight: String) -> String {
                        "Reach \(targetWeight)"
                    }

                    static func gainHeadline(targetWeight: String) -> String {
                        "Build toward \(targetWeight)"
                    }
                }

                enum JourneyBelief {
                    static func cut(strategyLabel: String) -> String {
                        "\(strategyLabel) — a pace you chose, realistic and sustainable."
                    }

                    static let maintain =
                        "Stay steady with a rhythm built around your activity and goal."
                    static let gain =
                        "Build gradually with consistent fuel and recovery."
                }

                enum FirstWeek {
                    static let logMealsCut = "Log 4 meals this week"
                    static let proteinCut = "Hit protein most days"
                    static let weighCut = "Weigh in twice"
                    static let logDaysMaintain = "Log 4 days this week"
                    static let caloriesMaintain = "Stay near your calories"
                    static let waterMaintain = "Drink your water goal"
                    static let mealsGain = "Eat 3 solid meals daily"
                    static let proteinGain = "Hit protein every day"
                    static let weighGain = "Log weight once"
                }

                enum Coach {
                    static func cut(goalWeight: String) -> String {
                        "You've got a clear path to \(goalWeight). Start by logging your next meal."
                    }

                    static let maintain =
                        "Your plan is set to keep you steady. Consistency beats perfection."

                    static func gain(goalWeight: String) -> String {
                        "Building toward \(goalWeight) starts with fueling today well."
                    }
                }

                enum Accessibility {
                    static let goal = "Goal"
                    static let journey = Cards.journeyTitle
                    static let firstWeek = Cards.firstWeekTitle
                    static let dailyFuel = Cards.dailyFuelTitle
                }

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
                        "Clear daily targets to help you stay consistent."
                }
            }

            enum SavePlan {
                static let title = "Your plan is ready."
                static let subtitle = "Save it so you can continue exactly where you left off."
                static let subtitleCompact = "Save it before you start."
                static let finalStepLabel = "Final step"
                static let privacyNote =
                    "Secure Google sign-in. No passwords. Your plan stays private."
                static let planSavedOnDeviceTitle = "Your personalized plan is ready"
                static let signInRetryHeadline = "Couldn't save your plan."
                static let signInRetryReassurance =
                    "Your plan is still safely stored on this device."
                static let signInRetryInvitation = "Try again whenever you're ready."
                static var signInRetryAccessibilitySummary: String {
                    [signInRetryHeadline, signInRetryReassurance, signInRetryInvitation].joined(separator: " ")
                }
                static let googleSignInCTA = "Save My Plan"
                static let googleSignInCTASubtitle = "Continue with Google"
                static let googleSignInLoadingTitle = "Saving your plan…"
                static let googleSignInSuccessTitle = "Continue"
                static let googleSignInSuccessAccessibilityLabel = "Sign-in complete. Continue"
                static let googleSignInAccessibilityHint = "Save your personalized plan with Google"
                static let signedInTitle = "Your plan is ready."
                static let signedInSubtitle = "You're signed in. Start when you're ready."
                static let signedInContinueCTA = "Start my plan"
                static let signedInContinueAccessibilityHint = "Start with your personalized plan"
                static let planSummaryCardTitle = "YOUR FORMA PLAN"
                static let planSummaryJourneyLabel = "Journey"
                static let planAchievementTitle = "Your plan"
                static let planAchievementReachVerb = "Reach"
                static let planAchievementMaintainVerb = "Maintain"
                static let planAchievementGainVerb = "Build to"
                static let planAchievementCurrentLabel = "Current"
                static let planAchievementBuiltForYou = "Built around your lifestyle"

                struct SignInTrustRow: Identifiable, Equatable, Sendable {
                    let icon: String
                    let title: String
                    var id: String { title }
                }

                static let signInTrustRows: [SignInTrustRow] = [
                    SignInTrustRow(icon: "arrow.clockwise.circle", title: "Restore your plan instantly"),
                    SignInTrustRow(icon: "iphone.and.arrow.forward", title: "Sync across devices"),
                    SignInTrustRow(icon: "chart.line.uptrend.xyaxis", title: "Keep meal logs and milestones"),
                    SignInTrustRow(icon: "forward.fill", title: "Continue without starting over")
                ]

                static var signInTrustAccessibilitySummary: String {
                    signInTrustRows.map(\.title).joined(separator: ". ")
                }
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
                static let title = "Build results that last"
                static let subtitle =
                    "Forma helps you lose weight through small habits you can actually keep."
                static let insightPill = "Consistency beats restriction."
                static let supportingCopy =
                    "Your plan adapts around your weight, activity, and progress."
                static let takeaway = insightPill
                static let continueCTA = "Next"
            }

            enum HeightWeight {
                static let title = "Height & Weight"
                static let subtitle = "Your measurements personalize every target we build."
                static let helper =
                    "We'll use this to calculate your personalized calorie target."
                static let previewTitle = "Estimated maintenance"
                static let previewPlaceholder = "Choose your height and weight to preview maintenance."
                static let previewFootnote = "Refines after age, sex, and activity."
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
                static let subtitle = "Pick a realistic goal for your plan."
                static let rulerAccessibilityLabel = "Target weight"
                static let interactionHint = "Slide to choose the weight you want to reach."
                static let realisticTargetTitle = "This is a realistic target."
                static let realisticTargetBody = "Small steady progress is easier to maintain."
                static let maintainGoalTitle = "You're maintaining your current weight."
                static let maintainGoalBody = "Forma will help you stay consistent."
                static let gainGoalTitle = "We'll build targets to help you gain steadily."
                static let gainGoalBody = "Forma will shape your plan around steady progress."
                static let unsafeGoalMessage =
                    "Choose a target within a healthy range for your height and current weight."
                static func currentToTargetSummary(current: String, target: String) -> String {
                    "Current \(current) → Goal \(target)"
                }
                static func expectedWeeklyPaceRange(low: String, high: String) -> String {
                    "Expected weekly pace: ~\(low)–\(high)"
                }
            }

            enum TargetEncouragement {
                static let title = "Your goal is realistic"
                static let subtitle = "We'll build your plan around small daily habits."
                static let reassuranceTitle =
                    "Steady progress is easier to maintain than extreme restriction."
                static let reassuranceBody =
                    "Forma will shape your plan around habits you can keep day to day."
                static let fallbackHero = "Your goal is set."
                static let maintainHero = "Maintain your weight"
                static let continueCTA = "Continue"

                static let benefits: [(icon: String, title: String, subtitle: String)] = [
                    (
                        "flame.fill",
                        "Personalized calories",
                        "Targets that fit your body and goal."
                    ),
                    (
                        "calendar",
                        "Habit-based tracking",
                        "Small daily actions, not crash diets."
                    ),
                    (
                        "chart.line.uptrend.xyaxis",
                        "Long-term progress",
                        "Forma adapts as real data comes in."
                    )
                ]
            }

            enum Birthday {
                static let title = "Let's personalize your plan"
                static let subtitle = "We use this to estimate your calorie target."
                static let birthdayLabel = "Birthday"
                static let sexSectionTitle = "Biological sex for calorie calculation"
                static let sexExplanation = "Used only for calorie estimates."
                static let agePreviewPlaceholder = "Select your birthday to calculate your age."
                static let ageExplanation = "Age helps estimate energy needs."
                static let trustNote =
                    "Used only to build your plan. You can update this later."
                static let birthDateRequiredMessage = "Select your birthday to continue."
                static let ageOutOfRangeMessage =
                    "Age must be between \(BirthDateAgeResolver.minimumAge) and \(BirthDateAgeResolver.maximumAge)."
                static let sexRequiredMessage = "Select an option to continue."

                static func agePreview(age: Int) -> String {
                    "You're \(age)"
                }
            }

            enum Activity {
                static let title = "How active are you?"
                static let subtitle = "This helps us estimate your daily calorie target."
                static let optionsAccessibilityLabel = "Activity level options"
                static let selectionRequiredMessage = "Select an activity level to continue."
                static let explanationPlaceholder =
                    "Choose the option that best matches a typical week."
                static let explanationSupporting =
                    "We'll use this to estimate your calorie target. You can adjust your plan later."
                static let sedentaryDescription = "Little or no exercise"
                static let lightlyActiveDescription = "Light exercise 1–3 days/week"
                static let moderatelyActiveDescription = "Moderate exercise 3–5 days/week"
                static let veryActiveDescription = "Hard exercise 6–7 days/week"
                static let extraActiveDescription = "Very hard exercise & physical job"
                static let sedentaryExplanationHeadline =
                    "We'll build your plan around lower daily movement."
                static let lightlyActiveExplanationHeadline =
                    "We'll account for light movement and occasional exercise."
                static let moderatelyActiveExplanationHeadline =
                    "We'll account for regular weekly exercise."
                static let veryActiveExplanationHeadline =
                    "We'll account for frequent hard exercise."
                static let extraActiveExplanationHeadline =
                    "We'll account for very high activity or physical work."
            }

            enum AppleHealth {
                static let title = "Connect Apple Health"
                static let subtitle =
                    "Sync workouts and activity so Forma can adjust your plan with less manual tracking."
                static let connectCTA = "Connect Apple Health"
                static let continueCTA = Common.continueAction
                static let skipCTA = "Skip for now"
                static let requestingMessage = "Opening Apple Health…"
                static let connectedMessage =
                    "Apple Health connected. Your plan can now use activity and workout data."
                static let deniedMessage =
                    "Permission wasn't granted. You can connect Apple Health later in Settings."
                static let unavailableMessage =
                    "Apple Health isn't available on this device. You can continue without it."
                static let failedMessage =
                    "Something went wrong. Try again or skip for now."
                static let summaryCardTitle = "What Forma uses"
                static let permissionItems: [(icon: String, title: String)] = [
                    ("figure.run", "Workouts"),
                    ("flame.fill", "Active energy"),
                    ("calendar.badge.clock", "Training consistency")
                ]
                static let readableDataRows: [String] = permissionItems.map(\.title)
                static let readableDataAccessibilityLabel =
                    "What Forma uses: workouts, active energy, training consistency."
                static let privacyTitle = "Private by design"
                static let privacyBody =
                    "Forma only reads the data you allow. You can change this anytime in Apple Health."
            }

            enum AlmostThere {
                static let title = "Your personalized coach is waiting."
                static let subtitle = ""
                static let headline = "Your personalized coach is waiting."
                static let supporting =
                    "You don't need more motivation. You need a plan built from your body, goal, and how you actually live."
                static let trustFooter =
                    "Forma turns your answers into daily targets — not guesswork."
                static let benefitsAccessibilityLabel =
                    "What changes: Know what to do today. Stop restarting every Monday. Progress you can sustain."
                static let continueCTA = "See what's next"
                static let accessibilitySummary =
                    "Your personalized coach is waiting. You don't need more motivation. You need a plan built from your body, goal, and how you actually live."
            }

            enum AlmostThereBenefits {
                static let items: [(icon: String, title: String)] = [
                    ("sun.max.fill", "Know what to do today"),
                    ("arrow.counterclockwise", "Stop restarting every Monday"),
                    ("chart.line.uptrend.xyaxis", "Progress you can sustain")
                ]
            }

            enum FormaProof {
                static let continueCTA = "Review my blueprint"
                static let visionHeadline = "This becomes your new normal."

                enum Fallback {
                    static let intentLabel = "Your goal"
                    static let targetWeightPlaceholder = "—"
                    static let supporting =
                        "A daily rhythm shaped around what you want to achieve."
                    static let benefits: [(icon: String, title: String)] = [
                        ("scope", "Targets matched to you"),
                        ("repeat", "Habits you can keep"),
                        ("checkmark.seal", "Progress you can trust")
                    ]
                    static let trustNote = "Built from your body, goal, and activity level."
                }

                enum Loss {
                    static let intentLabel = "Lose"
                    static func supporting(targetWeightLabel: String) -> String {
                        "Reach \(targetWeightLabel) with steady habits — not another restart."
                    }
                    static let benefits: [(icon: String, title: String)] = [
                        ("gauge.with.dots.needle.33percent", "A pace you can hold"),
                        ("sun.max.fill", "Daily clarity, not willpower"),
                        ("chart.line.uptrend.xyaxis", "Progress that compounds")
                    ]
                }

                enum Gain {
                    static let intentLabel = "Gain"
                    static func supporting(targetWeightLabel: String) -> String {
                        "Grow toward \(targetWeightLabel) with structure you can repeat."
                    }
                    static let benefits: [(icon: String, title: String)] = [
                        ("flame.fill", "Fuel targets that make sense"),
                        ("repeat", "Consistency over guessing"),
                        ("arrow.up.right", "Gain you can measure")
                    ]
                }

                enum Maintain {
                    static let intentLabel = "Maintain"
                    static func supporting(targetWeightLabel: String) -> String {
                        "Stay near \(targetWeightLabel) without second-guessing every meal."
                    }
                    static let benefits: [(icon: String, title: String)] = [
                        ("shield.lefthalf.filled", "Guardrails, not restrictions"),
                        ("bell.badge", "Catch drift before it sticks"),
                        ("heart.fill", "Balance you can live with")
                    ]
                }

                enum Comparison {
                    static let withoutStructureTitle = "Without structure"
                    static let withFormaTitle = "With Forma"
                    static let withoutBullets = [
                        "Harder to know what to eat",
                        "Progress can feel inconsistent",
                        "Habits are harder to maintain"
                    ]
                    static let withFormaBullets = [
                        "Daily calorie and macro targets",
                        "Fast meal logging",
                        "Progress and habit tracking"
                    ]
                }

                enum Trust {
                    static let personalized =
                        "Built from your body, goal, and activity level."
                }

                static func maintainHero(targetWeightLabel: String) -> String {
                    "Maintain around \(targetWeightLabel)"
                }

                static func lossHero(targetWeightLabel: String) -> String {
                    "Lose toward \(targetWeightLabel)"
                }

                static func gainHero(targetWeightLabel: String) -> String {
                    "Gain toward \(targetWeightLabel)"
                }
            }

            enum Summary {
                static let title = "Your plan blueprint"
                static let subtitle = ""
                static let buildPlanCTA = "Build My Plan"
                static let buildPlanAnticipationHeadline = "Everything is ready."
                static let buildPlanAnticipationSubline = "Your personalized plan is seconds away."
                static let buildPlanAnticipationAccessibilityLabel =
                    "Everything is ready. Your personalized plan is seconds away."

                enum GoalCard {
                    static let paceCaption = "Weekly pace"
                    static let timelineCaption = "Your timeline"
                    static let maintainDirection = "Staying at"
                    static let lossDirection = "Working toward"
                    static let gainDirection = "Building to"
                    static let maintainTimeline = "Healthy sustainable timeline"
                    static let gainTimeline = "Steady, sustainable timeline"
                    static let maintainPace = "Matched to your activity"
                    static let gainPace = "Steady weekly progress"
                    static let fallbackPace = "Personalised to your body"
                    static let fallbackTimeline = "Healthy sustainable timeline"
                    static let fallbackTarget = "Your goal"

                    static func lossTimeline(weeks: Int) -> String {
                        "About \(weeks) weeks to your goal"
                    }
                }

                enum PremiumFeatures {
                    static let items: [(icon: String, title: String, subtitle: String, visualKind: String)] = [
                        ("fork.knife", "Nutrition", "Calories & macros, tuned to you", "nutrition"),
                        ("figure.run", "Activity", "Workouts that adapt with you", "activity"),
                        ("chart.line.uptrend.xyaxis", "Progress", "See what's working over time", "progress")
                    ]
                    static let accessibilityLabel =
                        "Personalised nutrition, adaptive activity, progress tracking."
                }

                enum GeneratedSummary {
                    static let title = "Shaped from your answers"
                    static let activityLevel = "Activity level"
                    static let currentWeight = "Current weight"
                    static let goal = "Goal"
                    static let nutritionTargets = "Nutrition targets"
                    static let lifestyle = "Lifestyle"
                    static let trainingRhythm = "Training rhythm"
                    static let nutritionDetail = "Calories & macros"
                    static let pendingDetail = "—"

                    static func lifestyleDetail(age: Int, sex: String) -> String {
                        "Age \(age) · \(sex)"
                    }

                    static func trainingDetail(daysPerWeek: Int) -> String {
                        daysPerWeek == 1 ? "1 day / week" : "\(daysPerWeek) days / week"
                    }

                    static let accessibilityLabel =
                        "Shaped from your answers: activity level, current weight, goal, nutrition targets, lifestyle, and training rhythm."
                }

                static let heightLabel = "Height"
                static let currentWeightLabel = "Current weight"
                static let targetWeightLabel = "Target weight"
                static let ageLabel = "Age"
                static let sexLabel = "Sex"
                static let activityLabel = "Activity"
            }

            enum PlanReveal {
                static let title = "Your Forma plan is ready"
                static let subtitle = "Built from your body, goal, and activity level."
                static let fallbackTitle = "Your starting plan is ready"
                static let fallbackSubtitle = "Built from your onboarding answers."
                static let savePlanCTA = "Protect my progress"
                static let signedOutSaveTrustNote =
                    "Your plan stays here until you're ready."
                static let signedInSaveTrustNote =
                    "Your progress follows you everywhere."
            }

            enum SavePlan {
                static let title = "Your plan is ready."
                static let subtitle = "Save it so you can continue exactly where you left off."
                static let subtitleCompact = "Save it before you start."
                static let signedInSubtitle = "You're signed in. Start when you're ready."
                static let planAchievementTitle = "Your plan"
                static let planAchievementReachVerb = "Reach"
                static let planAchievementMaintainVerb = "Maintain"
                static let planAchievementGainVerb = "Build to"
                static let planAchievementCurrentLabel = "Current"
                static let planAchievementBuiltForYou = "Built around your lifestyle"
                static let signInTrustRowTitles = [
                    "Restore your plan instantly",
                    "Sync across devices",
                    "Keep meal logs and milestones",
                    "Continue without starting over"
                ]
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
                    static let traditionalLabel = "Restrictive diet"
                    static let formaDescription = "Steady, sustainable progress"
                    static let traditionalDescription = "Fast loss, then regain"
                    static let disclaimer = "Illustrative example — individual results vary."
                    static let chartAccessibilityLabel =
                        "Illustrative weight trajectory. Forma shows steady sustainable progress while a restrictive diet shows fast early loss followed by regain."
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
                    static let disclaimer = "Illustrative example — individual results vary."
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
}
