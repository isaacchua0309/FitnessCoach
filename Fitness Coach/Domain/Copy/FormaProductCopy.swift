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
        static let coachTimeout =
            "Coach took too long to respond. Please try again."
        static let coachNotUnderstood =
            "I couldn't quite follow that. Try rephrasing, or log with explicit calories and macros."
        static let coachNetworkUnavailable =
            "Coach couldn't reach the server. Check your connection and try again."
        static let coachPhotoTooLarge =
            "That photo is too large to send for analysis. Try a closer crop."
        static let coachPhotoEncodingFailed =
            "That photo couldn't be prepared for analysis. Try again."
        static let coachPhotoRejected =
            "Coach couldn't use that photo for analysis. Try another image."
        static let coachPhotoAnalysisUnreadable =
            "Coach couldn't read a reliable nutrition estimate from that photo."
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

    // MARK: - Public entry (logged-out welcome + returning user sign-in)

    enum PublicEntry {

        enum Loading {
            static let appLaunch = FormaProductCopy.Loading.app
            static let restoringPlan = ExistingUserSignIn.resolvingMessage
        }

        enum Welcome {
            static let title = "Welcome to Forma"
            static let headline = "The smarter way to lose weight without restrictive diets."
            static let supportingCopy =
                "Build a personalized nutrition plan, track your meals effortlessly, and stay consistent every day."
            static let createMyPlanCTA = "Create My Plan"
            static let existingAccountPrompt = "Already have an account?"
            static let signInCTA = "Sign In →"

            static let benefits: [(icon: String, title: String)] = [
                ("target", "Personalized calorie targets"),
                ("bolt.fill", "Fast meal logging"),
                ("chart.line.uptrend.xyaxis", "Long-term progress")
            ]

            static let createPlanAccessibilityHint =
                "Start building your personalized nutrition plan"
            static let signInAccessibilityLabel = "Sign in to an existing account"
            static let signInAccessibilityHint = "Open the returning member sign-in screen"
            static let benefitsAccessibilityLabel = "Plan benefits"
        }

        enum ExistingUserSignIn {
            static let title = "Welcome back"
            static let subtitle = "Sign in to continue your Forma plan."
            static let supportingCopy =
                "Your plan, progress, and settings will be restored if they exist for this account."
            static let resolvingMessage = "Looking for your Forma plan…"
            static let newToFormaPrompt = "New to Forma?"
            static let createMyPlanCTA = "Create My Plan"
            static let createMyPlanAccessibilityHint =
                "Start building a new Forma plan"
            static let backAccessibilityLabel = "Back to welcome"
            static let googleSignInCTA = FormaProductCopy.SignIn.continueWithGoogle
            static let googleSignInAccessibilityHint =
                "Sign in to restore your Forma plan"

            enum Error {
                static let cancelledTitle = "Sign-in cancelled"
                static let cancelledMessage = "You can try again when you're ready."
                static let authFailedTitle = FormaProductCopy.Error.signInTitle
                static let authFailedMessage = "We couldn't sign you in. Please try again."
                static let networkFailedTitle = "Connection problem"
                static let networkFailedMessage =
                    "We couldn't reach Forma. Check your connection and try again."
                static let profileLookupFailedTitle = "Couldn't load your plan"
                static let profileLookupFailedMessage =
                    "We signed you in but couldn't restore your Forma plan. Try again."
            }

            enum ProfileLookupFailed {
                static let title = "Couldn't load your Forma plan"
                static let body =
                    "Check your connection and try again. We won't assume you're new to Forma."
                static let retryCTA = "Try again"
            }
        }

        enum NoExistingPlan {
            static let title = "We couldn't find a Forma plan for this account"
            static let subtitle =
                "This account doesn't have a saved plan yet. Let's build one now."
            static let supportingCopy = "New to Forma? This only takes about 2 minutes."
            static let startOnboardingCTA = "Start Onboarding"
            static let useAnotherAccountCTA = "Use another account"
            static let startOnboardingAccessibilityHint = "Begin building your Forma plan"
            static let useAnotherAccountAccessibilityHint =
                "Sign out and choose a different account"
        }
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
                static let title = "Forma creates long-term results"
                static let subtitle = "Backed by science.\nBuilt around lasting habits."
                static let takeaway = "Small consistent habits beat restrictive dieting."
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
                    "Sync workouts and activity to improve your progress insights."
                static let connectCTA = "Connect Apple Health"
                static let skipCTA = "Skip for now"
                static let unavailableCTA = "Apple Health unavailable"
                static let connectedCTA = Common.continueAction
                static let requestingMessage = "Opening Apple Health…"
                static let connectedMessage = "Apple Health connected."
                static let deniedMessage =
                    "No problem — you can connect later in Settings."
                static let unavailableMessage =
                    "Apple Health isn't available on this device."
                static let failedMessage =
                    "Something went wrong. Try again or skip for now."
                static let summaryCardTitle = "What Forma can read"
                static let readableDataRows: [String] = [
                    "Workouts and duration",
                    "Active calories",
                    "Training consistency"
                ]
                static let readableDataAccessibilityLabel =
                    "What Forma can read: workouts and duration, active calories, training consistency."
                static let privacyTitle = "Private by design"
                static let privacyBody =
                    "Forma only reads data you allow. You can connect later."
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
        static let todayTitle = "Set up your plan first"
        static let todayProfileRequired = "Finish your profile on Plan so Forma can build today's targets."
        static let planTitle = "Build your plan"
        static let planGetStarted =
            "Set a goal and Forma will build your calorie, macro, and training targets."
        static let planGetStartedAccessibilityHint = "Creates your first plan"
        static let journeyTitle = FormaProductCopy.Journey.StartingEmptyState.title
        static let journeyBody = FormaProductCopy.Journey.StartingEmptyState.body

        enum Meals {
            static let title = "Ready for your first log"
            static let body = "Pick a meal below or tap Log meal — we'll track the rest."
            static let action = "Log meal"
            static let actionAccessibilityHint = "Opens meal logging"
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
        static let mealsEmptyTitle = FormaProductCopy.EmptyState.Meals.title
        static let mealsEmptyBody = FormaProductCopy.EmptyState.Meals.body
        static let mealsLogMealAction = FormaProductCopy.EmptyState.Meals.action
        static let mealsLogMealAccessibilityHint = FormaProductCopy.EmptyState.Meals.actionAccessibilityHint
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
            static let logFirstMeal = "Log your first meal to start today."
            static let proteinBehind = "Add protein at your next meal."
            static let waterBehind = "Drink water before your next meal."
            static let bothBehind = "Catch up on protein and water at your next break."
            static let overTarget = "Above target — keep logging honestly."
            static let postWorkoutProtein = "Refuel with protein after your workout."
        }

        enum EndOfDay {
            static let wrapUp = "Wrap up today when you're ready."
            static let reviewPrompt = "Review today's log with Coach."
            static let reviewAction = "Review today"
        }

        enum EmptyState {
            static let missingProfileTitle = "Set up your plan first"
            static let missingProfileBody = "Finish your profile on Plan so Forma can build today's targets."
            static let missingProfileAction = "Open Plan"
            static let missingProfileActionHint = "Opens Plan to finish your profile"

            static let newProfileMissionStatus = "Your plan is ready. Log your first meal to start today."
            static let newDayMissionStatus = "New day, fresh targets. Log your first meal when you're ready."

            static let newProfileMealsTitle = "Ready for your first log"
            static let newProfileMealsBody = "Pick a meal below or tap Log meal — we'll track the rest."

            static let newDayMealsTitle = "Nothing logged yet today"
            static let newDayMealsBody = "Your usual rhythm picks up with one quick log."

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
        static let nextActionQuickChipTitle = "Coach"
        static let nextActionCoachHint = "Opens Coach"
        static let nextActionConnectAppleHealthHint = "Connect Apple Health for training insights"
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
            static let logBreakfastSubtitle = "A morning log helps Forma guide the rest of your day."
            static let logFirstMealTitle = "Log your first meal to start today."
            static let logFirstMealSubtitle = "A quick log helps Forma guide the rest of your day."
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

            static let sheetLogMealTitle = "Log meal"
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

        enum Meals {
            static let sectionTitle = "Meals"
            static let readyStatus = "Ready"
            static let addAction = "Add"
            static let optionalLabel = "Optional"
            static let loggedAccessibilityValue = "Logged"
            static let loggedAccessibilityHint = "Edit this food entry"
            static let addAccessibilityHint = "Log food for this meal"
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
            static let sectionTitle = "Quick Actions"
            static let fabAccessibilityLabel = "Quick log"
            static let fabAccessibilityHint = "Log food, water, weight, or open Coach"
            static let addWaterSheetTitle = "Add water"
            static let addWaterSheetBody = "Pick an amount to log now."
            static let scanFoodUnavailableNote = "Photo scan is coming soon — use manual entry for now."

            static func inlineAccessibilityHint(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "Opens food photo scan"
                case .logMeal: return "Opens meal logging"
                case .manualEntry: return "Opens manual meal entry"
                case .addWater: return "Opens water logging"
                case .logWeight: return "Opens weight logging"
                case .logWorkout: return "Opens workout logging"
                }
            }

            static func title(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "Scan Food"
                case .logMeal: return "Log Meal"
                case .manualEntry: return "Manual Entry"
                case .addWater: return "Add Water"
                case .logWeight: return "Log Weight"
                case .logWorkout: return "Log Workout"
                }
            }

            static func symbolName(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "camera.viewfinder"
                case .logMeal: return "fork.knife"
                case .manualEntry: return "square.and.pencil"
                case .addWater: return "drop.fill"
                case .logWeight: return "scalemass.fill"
                case .logWorkout: return "figure.run"
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
        static let statusNoData = "—"

        enum StartingEmptyState {
            static let title = "Your journey is just starting."
            static let body = "Log meals, workouts, water, and weight to build your transformation story."
            static let action = "Go to Today"
        }

        enum Momentum {
            static let sectionTitle = "Momentum"
            static let buildingHeadline = "You're building consistency."
            static let keepStreakAlive = "Log today to keep your streak alive."

            static func activeHeadline(days: Int) -> String {
                "\(days)-day logging streak"
            }

            static func longestStreakDetail(days: Int) -> String {
                "Your longest streak is \(days) days."
            }
        }

        enum Hero {
            static let newUserTitle = "Your journey is just starting."
            static let newUserPrimary = "Build your first week."
            static let newUserBody = "Log today to start creating your transformation story."
            static let newUserAction = "Log today"

            static let earlyHabitsTitle = "Building Momentum"
            static let earlyHabitsBody = "Every healthy decision is starting to compound."

            static let weightLossTitle = "Transformation in progress"
            static let gainProgressTitle = "Transformation in progress"
            static let strongConsistencyTitle = "Strong Momentum"
            static let strongConsistencyBody = "Your habits are becoming consistent."

            static let noGoalTitle = "Building Momentum"
            static let noGoalPrimary = "Keep logging"
            static let noGoalBody = "Log meals and weight so Forma can map your progress."

            static func weekLabel(_ week: Int) -> String {
                "Week \(week)"
            }

            static func kgLost(_ kg: String) -> String {
                "\(kg) lost"
            }

            static func kgGained(_ kg: String) -> String {
                "\(kg) gained"
            }

            static func percentTowardGoal(_ percent: Int) -> String {
                "\(percent)% of the way to your goal."
            }

            static func daysShowingUp(_ days: Int) -> String {
                days == 1 ? "1 day showing up" : "\(days) days showing up"
            }

            static func compactWeights(started: String, today: String, goal: String) -> String {
                "\(started) → \(today) → \(goal)"
            }

            static func accessibilitySummary(title: String, primary: String, body: String) -> String {
                "\(title). \(primary). \(body)"
            }
        }

        enum GoalProjection {
            static let sectionTitle = "Goal projection"

            static let insufficientTitle = "Projection unlocks soon"
            static let insufficientDetail = "Log weight for 7 days so Forma can estimate your pace."

            static let towardGoalTitle = "At your current pace"
            static let flatTrendTitle = "Your weight is holding steady"
            static let flatTrendDetail = "Keep logging so Forma can detect your real trend."
            static let awayFromGoalTitle = "Your trend needs more consistency"
            static let awayFromGoalDetail = "Focus on meals and weigh-ins this week."

            static let goalReachedTitle = "Goal reached"
            static let goalReachedDetail = "You're at your target weight. Keep your habits steady."

            static func towardGoalDetail(goalWeight: String, date: String) -> String {
                "You may reach \(goalWeight) around \(date)."
            }

            static func accessibilitySummary(title: String, detail: String) -> String {
                "\(title). \(detail)"
            }
        }

        static func analyticsBasedOnDays(_ days: Int) -> String {
            days == 1 ? "Based on 1 logged day" : "Based on \(days) logged days"
        }

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

            static func remainingToGo(_ kg: String) -> String {
                "\(kg) to go"
            }

            static func accessibilitySummary(
                headline: String,
                changeValue: String,
                started: String,
                today: String,
                goal: String,
                progressLabel: String,
                emotionalStatus: String,
                startedFootnote: String?
            ) -> String {
                var parts = [
                    "\(headline) \(changeValue).",
                    "Started \(started), today \(today), goal \(goal).",
                    progressLabel + ".",
                    emotionalStatus + "."
                ]
                if let startedFootnote {
                    parts.insert("Started weight from \(startedFootnote.lowercased()).", at: 2)
                }
                return parts.joined(separator: " ")
            }
        }

        enum Milestones {
            static let sectionTitle = "Milestones"
            static let nextUp = "Next up"
            static let emptyBody = "Log your first meal to start building your milestone path."

            enum NextAchievement {
                static let header = "Next Achievement"

                static let firstMealTitle = "Log Your First Meal"
                static let firstFullDayTitle = "Complete Your First Full Day"
                static let firstWorkoutTitle = "Complete Your First Workout"
                static let weightThreeTimesTitle = "Log Weight 3 Times"
                static let firstWeekTitle = "First Week Complete"
                static let proteinThreeDaysTitle = "Hit Protein 3 Days in a Week"
                static let waterThreeDaysTitle = "Hit Water 3 Days in a Week"
                static let firstKgTitle = "Lose Your First Kilogram"
                static let firstKgGainTitle = "Gain Your First Kilogram"
                static let fourWorkoutWeeksTitle = "Complete 4 Workout Weeks"
                static let firstMonthTitle = "Complete Your First Month"

                static let firstMealReward = "Log your first meal to start your milestone path."
                static let firstFullDayReward = "Complete a full day of logging to build momentum."
                static let firstWorkoutReward = "Show up for your first workout to unlock training milestones."
                static let weightThreeTimesReward = "Three weigh-ins help Forma see your real trend."
                static let firstWeekReward = "Complete your first week to unlock your first Journey chapter."
                static let proteinThreeDaysReward = "Three protein days in a week builds a strong anchor."
                static let waterThreeDaysReward = "Three water days in a week keeps your routine steady."
                static let firstKgReward = "Your first kilogram toward goal is a major checkpoint."
                static let fourWorkoutWeeksReward = "Four workout weeks turn training into a habit."
                static let firstMonthReward = "Your first month of consistency becomes part of your story."

                static func progressDays(current: Int, total: Int) -> String {
                    "\(current) / \(total) days"
                }

                static func progressCount(current: Int, total: Int, unit: String) -> String {
                    "\(current) / \(total) \(unit)"
                }

                static func progressKg(current: Double, total: Double) -> String {
                    let currentLabel = String(format: "%.1f", current)
                    let totalLabel = String(format: "%.0f", total)
                    return "\(currentLabel) / \(totalLabel) kg"
                }

                static func accessibilitySummary(
                    header: String,
                    title: String,
                    progress: String,
                    reward: String
                ) -> String {
                    "\(header). \(title). \(progress). \(reward)"
                }
            }

            static let loggedFirstMeal = "Logged first meal"
            static let proteinFiveDays = "Hit protein target 5 days"
            static let waterFiveDays = "Hit water target 5 days"
            static let loggedFirstWorkout = "Logged first workout"
            static let loggingStreakSeven = "7-day logging streak"
            static let loggedThirtyMeals = "Logged 30 meals"
            static let halfwayToGoal = "Halfway to goal"
            static let loggedHundredMeals = "Logged 100 meals"

            static func progressLabel(percent: Int) -> String {
                "\(percent)% there"
            }

            static func firstWeekTitle(direction: JourneyGoalDirection) -> String {
                direction == .maintain
                    ? "Stayed consistent for first week"
                    : "First week complete"
            }

            static func firstKilogramTitle(direction: JourneyGoalDirection) -> String {
                switch direction {
                case .lose: return "Lost first kilogram"
                case .gain: return "Gained first kilogram"
                case .maintain: return "Stayed consistent for first week"
                }
            }

            static func tenKilogramTitle(direction: JourneyGoalDirection) -> String {
                switch direction {
                case .lose: return "10 kg lost"
                case .gain: return "10 kg gained"
                case .maintain: return "10 kg tracked"
                }
            }

            enum Accessibility {
                static let unlocked = "Unlocked"
                static let nextUp = "Next up"
                static let upcoming = "Coming up"

                static func progressPercent(_ percent: Int) -> String {
                    "\(percent) percent there"
                }
            }
        }

        enum Timeline {
            static let sectionTitle = "Your story"
            static let emptyBody = "Your story starts today."

            static let startedForma = "Started Forma"
            static let loggedFirstMeal = "Logged first meal"
            static let completedFirstWorkout = "Completed first workout"
            static let loggedFirstWeight = "Logged first weigh-in"
            static let completedFirstFullDay = "Completed first full day"
            static let completedFirstWeek = "Completed first week"
            static let stayedConsistentFirstWeek = "Stayed consistent for first week"
            static let proteinThreeDaysInWeek = "Hit protein goal for 3 days"
            static let waterThreeDaysInWeek = "Hit water goal for 3 days"
            static let reachedNewChapter = "Reached a new chapter"
            static let completedFirstMonth = "Completed first month"

            static func lostFirstKilogram() -> String { "Lost first 1 kg" }
            static func gainedFirstKilogram() -> String { "Gained first 1 kg" }

            enum Reflection {
                static let startedForma = "This is where your transformation began."
                static let loggedFirstMeal = "You began building your daily rhythm."
                static let completedFirstWorkout = "Your training story started here."
                static let loggedFirstWeight = "Your first weigh-in marks the start of your trend."
                static let completedFirstFullDay = "A full day of logging builds real momentum."
                static let completedFirstWeek = "Seven days in — consistency is forming."
                static let lostFirstKg = "Your effort is starting to show."
                static let gainedFirstKg = "Your consistency is starting to pay off."
                static let proteinThreeDays = "Protein is becoming a steady anchor."
                static let waterThreeDays = "Hydration is turning into a habit."
                static let reachedNewChapter = "A new chapter of your journey is opening."
                static let completedFirstMonth = "Your first month is part of your story now."
            }

            static func reflection(for type: JourneyTimelineEventType) -> String? {
                switch type {
                case .onboardingStarted:
                    return Reflection.startedForma
                case .firstMealLogged:
                    return Reflection.loggedFirstMeal
                case .firstWorkoutLogged:
                    return Reflection.completedFirstWorkout
                case .firstWeightLogged:
                    return Reflection.loggedFirstWeight
                case .firstFullDayComplete:
                    return Reflection.completedFirstFullDay
                case .firstWeekComplete:
                    return Reflection.completedFirstWeek
                case .firstKgTowardGoal:
                    return Reflection.lostFirstKg
                case .proteinThreeDaysInWeek:
                    return Reflection.proteinThreeDays
                case .waterThreeDaysInWeek:
                    return Reflection.waterThreeDays
                case .chapterReached:
                    return Reflection.reachedNewChapter
                case .firstMonthComplete:
                    return Reflection.completedFirstMonth
                default:
                    return nil
                }
            }
        }

        typealias StoryTimeline = Timeline

        enum HabitLabels {
            static let foodLoggingLabel = "Food logging consistency"
            static let proteinLabel = "Protein consistency"
            static let waterLabel = "Water consistency"
            static let calorieLabel = "Calorie adherence"
            static let trainingLabel = "Training consistency"
            static let weightLabel = "Weight logging consistency"
            static let weekendLabel = "Weekend logging"
        }

        enum PersonalizedInsights {
            static let sectionTitle = "Personal insights"

            static let learningTitle = "Forma is learning your pattern."
            static let learningDetail =
                "Log meals, water, workouts, and weight this week to unlock personal insights."

            static let proteinStrongestTitle = "Protein is becoming your strongest habit."
            static let waterStrongestTitle = "Water is becoming a steady habit."
            static let workoutConsistencyTitle = "Training is showing up in your week."
            static let weightTrendTowardTitle = "Your weight trend is moving in the right direction."
            static let weightTrendMaintainTitle = "Your weight trend is holding steady."
            static let weekendCalorieTitle = "Your weekends are where calories drift."
            static let bestHabitTitle = "This is your strongest habit this week."
            static let biggestOpportunityTitle = "Your biggest opportunity this week"

            static func proteinDaysThisWeek(_ days: Int) -> String {
                "You hit protein \(days) \(days == 1 ? "day" : "days") this week."
            }

            static func waterDaysThisWeek(_ days: Int) -> String {
                "You hit water \(days) \(days == 1 ? "day" : "days") this week."
            }

            static func workoutDaysThisWeek(_ days: Int, expected: Int) -> String {
                if expected > 0 {
                    return "You completed \(days) of \(expected) planned workout days."
                }
                return days == 1
                    ? "You logged 1 workout day this week."
                    : "You logged \(days) workout days this week."
            }

            static func weekendCalorieDrift(averageKcal: Int) -> String {
                "Saturday and Sunday averaged \(averageKcal) kcal above target."
            }

            static func sevenDayAverageChange(deltaKg: Double, direction: JourneyGoalDirection) -> String {
                let magnitude = abs(deltaKg)
                let formatted = magnitude.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", magnitude)
                    : String(format: "%.1f", magnitude)
                switch direction {
                case .lose:
                    return deltaKg < 0
                        ? "Your 7-day average is down \(formatted) kg."
                        : "Your 7-day average is up \(formatted) kg."
                case .gain:
                    return deltaKg > 0
                        ? "Your 7-day average is up \(formatted) kg."
                        : "Your 7-day average is down \(formatted) kg."
                case .maintain:
                    return "Your 7-day average moved by \(formatted) kg."
                }
            }

            static func bestHabitDetail(habit: String, days: Int, total: Int) -> String {
                "You stayed consistent with \(habit.lowercased()) on \(days) of \(total) days."
            }

            static func opportunityDetail(habit: String) -> String {
                "A little more focus on \(habit.lowercased()) would balance your week."
            }
        }

        enum Header {
            static let title = "Your journey"
        }

        enum Chapters {
            static let sectionTitle = "Your chapter"
            static let emptyBody = "Log your first meal to begin Chapter 1."

            static func chapterLabel(_ number: Int) -> String {
                "Chapter \(number)"
            }

            static func nextUnlock(_ chapterTitle: String) -> String {
                "Next: \(chapterTitle)"
            }

            static func title(for chapter: Int) -> String {
                switch chapter {
                case 1: return "Building Foundations"
                case 2: return "Creating Consistency"
                case 3: return "Building Momentum"
                case 4: return "Transformation"
                case 5: return "Lifestyle"
                default: return "Lifestyle"
                }
            }
        }

        enum MonthlyRecap {
            static let minimumFoodLogDaysForRecap = 5

            static let mealsLoggedTitle = "Meals logged"
            static let proteinTitle = "Protein"
            static let waterTitle = "Water"
            static let caloriesTitle = "Calories"
            static let workoutDaysTitle = "Workout days"
            static let weightTitle = "Weight"
            static let bestStreakTitle = "Best streak"
            static let overallTitle = "Overall"

            static let teaserDetail =
                "Complete more logs to unlock your first monthly recap."

            static func sectionTitle(monthName: String) -> String {
                "\(monthName) Recap"
            }

            static func teaserTitle(monthName: String) -> String {
                "\(monthName) is building."
            }

            static func mealsLoggedValue(_ count: Int) -> String {
                "\(count)"
            }

            static func hitRatePercent(_ percent: Int) -> String {
                "\(percent)%"
            }

            static func workoutDays(_ count: Int) -> String {
                "\(count)"
            }

            static func bestStreak(days: Int) -> String {
                days == 1 ? "1 day" : "\(days) days"
            }

            static func weightChange(deltaKg: Double) -> String {
                let formatted = abs(deltaKg).truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", abs(deltaKg))
                    : String(format: "%.1f", abs(deltaKg))
                if deltaKg < -0.05 {
                    return "-\(formatted) kg"
                }
                if deltaKg > 0.05 {
                    return "+\(formatted) kg"
                }
                return "\(formatted) kg"
            }

            enum Grade: String, Equatable, Sendable {
                case starting
                case building
                case consistent
                case strong
                case excellent

                var label: String {
                    switch self {
                    case .starting: return "Starting"
                    case .building: return "Building"
                    case .consistent: return "Consistent"
                    case .strong: return "Strong month"
                    case .excellent: return "Excellent month"
                    }
                }
            }

            static func overallGrade(_ grade: Grade) -> String {
                grade.label
            }

            static let buildingBody = teaserDetail

            static func loggedDaysSummary(_ days: Int) -> String {
                days == 1
                    ? "You logged 1 day this month."
                    : "You logged \(days) days this month."
            }

            static func bestHabit(for kind: JourneyHabitKind) -> String {
                switch kind {
                case .foodLogging:
                    return "Food logging was your strongest habit this month."
                case .protein:
                    return "Protein was your strongest habit this month."
                case .water:
                    return "Water was your strongest habit this month."
                case .calorieAdherence:
                    return "Calorie adherence was your strongest habit this month."
                case .training:
                    return "Training was your strongest habit this month."
                case .weightLogging:
                    return "Weight logging was your strongest habit this month."
                case .weekendLogging:
                    return "Weekend logging was your strongest habit this month."
                }
            }

            static func weightDelta(deltaKg: Double, direction: JourneyGoalDirection) -> String {
                weightChange(deltaKg: deltaKg)
            }
        }

        enum CTA {
            static let updateGoal = "Update goal"
            static let opensCoach = "Opens Coach"
            static let opensPlan = "Opens Plan to update your goal"
            static let opensPlanForAppleHealth = "Opens Plan to connect Apple Health"
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

        enum EmptyState {
            static let weightTrendBody = FormaProductCopy.EmptyState.WeightTrend.body
            static let weightTrendAction = FormaProductCopy.EmptyState.WeightTrend.action
            static let weightTrendActionHint = FormaProductCopy.EmptyState.WeightTrend.actionAccessibilityHint
            static let consistencyBody = FormaProductCopy.EmptyState.Consistency.body
            static let timelineBody = Timeline.emptyBody
            static let milestonesBody = Milestones.emptyBody
        }

        enum WeeklyReview {
            static let sectionTitle = "This week"
            static let foodTitle = "Food Logging"
            static let proteinTitle = "Protein"
            static let waterTitle = "Water"
            static let trainingTitle = "Workout"
            static let calorieTitle = "Calorie Target"
            static let weightTitle = "Weight Logging"
            static let trainingNone = "None yet"

            static let weightUnavailable = "Log weight to see weekly change"
            static let trainingConnectAppleHealth = TrainingIntegrationCopy.includeWorkoutsInProgress
            static let noFoodLogsSummary = "Log a meal to start building your weekly pattern."
            static let emptyState = "Your weekly pattern starts today."
            static let oneMoreDayMomentum = "One more day builds momentum."

            static func weekDayCount(current: Int, total: Int) -> String {
                "\(current) / \(total) days"
            }

            static func streakLabel(days: Int) -> String {
                "🔥 \(days)-day streak"
            }

            static func dayFraction(achieved: Int, total: Int) -> String {
                "\(achieved)/\(total) days"
            }

            static func gymFraction(achieved: Int, expected: Int) -> String {
                "\(achieved)/\(expected)"
            }

            static func trainingDays(_ count: Int) -> String {
                count == 1 ? "1 day" : "\(count) days"
            }

            static func foodLoggedDaysSummary(_ days: Int) -> String {
                "You logged food \(days) of 7 days this week."
            }

            static func strongWeekSummary(highlights: String) -> String {
                "Strong week for \(highlights)."
            }

            static func weekOverWeekFood(
                achieved: Int,
                total: Int,
                previousAchieved: Int
            ) -> String {
                "Food \(achieved)/\(total) vs \(previousAchieved)/\(total) last week"
            }

            static func weekOverWeekProtein(
                achieved: Int,
                total: Int,
                previousAchieved: Int
            ) -> String {
                "Protein \(achieved)/\(total) vs \(previousAchieved)/\(total) last week"
            }

            static func weekOverWeekWater(
                achieved: Int,
                total: Int,
                previousAchieved: Int
            ) -> String {
                "Water \(achieved)/\(total) vs \(previousAchieved)/\(total) last week"
            }

            static func weekOverWeekTraining(
                achieved: Int,
                previousAchieved: Int
            ) -> String {
                "Training \(achieved) vs \(previousAchieved) last week"
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
        static let composerPhotoClarificationPlaceholder = "Add a detail about your meal…"
        static let foodEstimatePending = "Food estimate ready"
        static let reviewEstimate = "Review estimate"
        static let logPending = "Log"
        static let confirmPending = "Confirm"
        static let editPending = "Edit"
        static let discardPending = "Discard"
        static let retryMealPhotoAnalysis = "Retry analysis"
        static let removePhotoBeforeAddingAnother = "Remove the current photo before adding another."
        static let photoAnalysisLeadIn = "From your meal photo:"
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
        static let componentsSection = "Components"
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
        static let sectionTitle = "Why This Works"
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

        static let accessibilityOnboardingBaseline = "Current weight uses your starting baseline."
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

        static let planAssumptionsSectionTitle = "Activity Assumptions"
        static let planAssumptionsActivity = "Activity level"
        static let planAssumptionsEstimatedSteps = "Estimated Steps"
        static let planAssumptionsTraining = "Training"
        static let planAssumptionsNote =
            "Your activity level shapes your calorie estimate. Apple Health adds training insights but won't change targets."
        static let adjustActivity = "Update activity level"
        static let planAssumptionsAppleHealth = "Apple Health"

        static let appleHealthInsightsNote =
            "Apple Health informs training insights. It does not automatically change your calorie targets."
        static let editSafetyCopy =
            "You can adjust your plan anytime as your progress changes."
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

        static let lastUpdateReasonHeading = "Reason:"
        static let confidenceSafeCopy =
            "These targets are estimates from what you've shared. Keep logging for sharper weekly feedback."

        static let planConfidenceSectionTitle = "Plan Confidence"
        static let planConfidenceWhyHeading = "What's working:"
        static let planConfidenceMissingHeading = "To improve accuracy:"

        static func planConfidenceScore(_ percent: Int) -> String {
            "Plan confidence: \(percent)%"
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
            "Last updated: \(label)"
        }

        static let todayMissionSectionTitle = "Today's Mission"
        static let goToToday = "Go to Today"
        static let goToTodayAccessibilityHint = "Opens the Today tab"
        static let goToJourneyAccessibilityHint = "Opens the Journey tab"
        static let adjustPlanAccessibilityHint = "Opens the plan editor"
        static let seeCalculationAccessibilityHint = "Shows how your targets were calculated"
        static let updateActivityAccessibilityHint = "Opens activity settings in the plan editor"
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
        static let weekEmptyState = "Log meals and weight on Today to see how this week is going."
        static let weekOverallHeadline = "This week"

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

    // MARK: - Plan calculation details

    enum PlanCalculation {
        static let personalDetailsSectionTitle = "Personal details"
        static let personalDetailsAgeFromBirthday = "Derived from your birthday."
        static let personalDetailsAgeLegacy = "From your profile age."
        static let bodyDetailsSettingsTitle = "Body & stats"
        static let bodyDetailsSettingsFootnote =
            "To update these, use Adjust Plan on the Plan tab."
    }

    // MARK: - Settings

    enum Settings {

        /// Theme preferences screen and color palette copy.
        enum Theme {
            static let screenTitle = "Theme"
            static let navigationRowTitle = "Theme"
            static let appearanceSectionTitle = "Appearance"
            static let colorThemeSectionTitle = "Color Theme"
            static let livePreviewSectionTitle = "Preview"
            static let livePreviewPrimaryButton = "Continue"
            static let livePreviewLogPill = "Log meal"
            static let livePreviewProgressLabel = "Calories"
            static let livePreviewProgressValue = "68%"
            static let livePreviewAccessibilityLabel =
                "Live theme preview showing a primary button, progress, tab selection, and coach log action"

            enum Appearance {
                static let systemTitle = "System"
                static let systemDescription = "Match device appearance"
                static let lightTitle = "Light"
                static let lightDescription = "Always use light appearance"
                static let darkTitle = "Dark"
                static let darkDescription = "Always use dark appearance"
            }

            enum ColorPalette {
                static let oceanBlueTitle = "Ocean Blue"
                static let oceanBlueDescription = "Calm and focused"
                static let blossomPinkTitle = "Blossom Pink"
                static let blossomPinkDescription = "Warm and friendly"
                static let emeraldGreenTitle = "Emerald Green"
                static let emeraldGreenDescription = "Fresh and healthy"
                static let sunsetOrangeTitle = "Sunset Orange"
                static let sunsetOrangeDescription = "Energetic and bold"
            }

            enum Error {
                static let loadFailedTitle = "Couldn't load your theme"
                static let loadFailedMessage =
                    "We restored Forma's default look. You can pick a color theme below."
            }

            static func appearanceTitle(for mode: AppAppearanceMode) -> String {
                switch mode {
                case .system: Appearance.systemTitle
                case .light: Appearance.lightTitle
                case .dark: Appearance.darkTitle
                }
            }

            static func appearanceDescription(for mode: AppAppearanceMode) -> String {
                switch mode {
                case .system: Appearance.systemDescription
                case .light: Appearance.lightDescription
                case .dark: Appearance.darkDescription
                }
            }

            static func colorPaletteTitle(for palette: AppThemePalette) -> String {
                switch palette {
                case .oceanBlue: ColorPalette.oceanBlueTitle
                case .blossomPink: ColorPalette.blossomPinkTitle
                case .emeraldGreen: ColorPalette.emeraldGreenTitle
                case .sunsetOrange: ColorPalette.sunsetOrangeTitle
                }
            }

            static func colorPaletteDescription(for palette: AppThemePalette) -> String {
                switch palette {
                case .oceanBlue: ColorPalette.oceanBlueDescription
                case .blossomPink: ColorPalette.blossomPinkDescription
                case .emeraldGreen: ColorPalette.emeraldGreenDescription
                case .sunsetOrange: ColorPalette.sunsetOrangeDescription
                }
            }

            static func appearanceAccessibilityLabel(
                for mode: AppAppearanceMode,
                isSelected: Bool
            ) -> String {
                let selection = isSelected ? "selected, " : ""
                return "\(appearanceTitle(for: mode)), \(selection)\(appearanceDescription(for: mode))"
            }

            static func colorPaletteAccessibilityLabel(
                for palette: AppThemePalette,
                isSelected: Bool
            ) -> String {
                let title = colorPaletteTitle(for: palette)
                let description = colorPaletteDescription(for: palette)
                let selection = isSelected ? "selected" : "not selected"
                return "\(title), \(description), \(selection)"
            }
        }
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
