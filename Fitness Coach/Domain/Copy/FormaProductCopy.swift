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
                static let title = "Your Forma plan is ready"
                static let subtitle = "Built from your body, goal, and activity level."
                static let fallbackTitle = "Your starting plan is ready"
                static let fallbackSubtitle = "Built from your onboarding answers."
                static let journeySectionTitle = "Your goal"
                static let dailyTargetSectionTitle = "Daily target"
                static let dailyMissionSectionTitle = "Your daily mission"
                static let heroCalorieExplanation =
                    "Balanced around your selected pace and activity."
                static let cutCalorieExplanation =
                    "Designed for steady, sustainable progress."
                static let viewMacrosCTA = "View macros"
                static let hideMacrosCTA = "Hide macros"
                static let savePlanCTA = "Save my plan"
                static let adjustPlanCTA = "Adjust plan"
                static let maintainCalorieExplanation =
                    "We'll help you stay consistent with clear daily targets."
                static let gainCalorieExplanation =
                    "Designed to help you eat enough consistently."
                static let keyTargetsSectionTitle = "Your daily mission"
                static let signedOutSaveTrustNote =
                    "One tap with Google keeps your plan backed up."
                static let signedInSaveTrustNote =
                    "Save your plan to keep it across devices."
                static let nextStepLine =
                    "Next: log your first meal and watch Today update your progress."

                enum GoalHero {
                    static let sectionTitle = "Your goal"

                    static func maintainHeadline(targetWeight: String) -> String {
                        "Maintain around \(targetWeight)"
                    }

                    static let maintainSupport =
                        "We'll help you stay consistent with clear daily targets."

                    static func lossHeadline(targetWeight: String) -> String {
                        "Lose toward \(targetWeight)"
                    }

                    static func lossProgress(currentWeight: String, targetWeight: String) -> String {
                        "From \(currentWeight) to \(targetWeight)"
                    }

                    static let lossSupport = "Designed for steady, sustainable progress."

                    static func gainHeadline(targetWeight: String) -> String {
                        "Gain toward \(targetWeight)"
                    }

                    static func gainProgress(currentWeight: String, targetWeight: String) -> String {
                        "From \(currentWeight) to \(targetWeight)"
                    }

                    static let gainSupport =
                        "Designed to help you eat enough consistently."
                }

                enum Focus {
                    static let maintainTitle = "Focus on consistency"
                    static let maintainBody =
                        "Hit your calories, protein, and water most days."
                    static let lossTitle = "Focus on steady progress"
                    static let lossBody =
                        "Stay close to your target and prioritize protein."
                    static let gainTitle = "Focus on eating enough"
                    static let gainBody =
                        "Hit your calories and protein consistently."
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

                enum Reassurance {
                    static let title = "Ready to start simple"
                    static let body =
                        "Log your meals and follow your daily targets on Today."
                    static let bullets = [
                        "No crash dieting",
                        "Targets can be adjusted later",
                        "Your Today screen keeps progress simple"
                    ]
                }
            }

            enum SavePlan {
                static let title = "Save your plan"
                static let subtitle =
                    "Your plan is saved on this device. Sign in with Google to sync it across devices."
                static let trustNote = "Sign-in backs up your plan — your starting targets stay the same."
                static let localOnlyHint = "Everything stays on this device until you sign in."
                static let planSavedOnDeviceTitle = "Your plan is saved on this device"
                static let signInRetryMessage = "Sign-in didn't finish. Your plan is still saved on this device — try again when you're ready."
                static let googleSignInCTA = "Save & continue"
                static let googleSignInAccessibilityHint =
                    "Save your plan and sync with Google"
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
                /// Legacy alias kept for guardrail/copy audits.
                static let trustCardCopy = trustNote
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
                static let title = "We understand you"
                static let subtitle =
                    "Your body, goal, and lifestyle — shaped into one plan."
                static let buildPlanCTA = "Build my plan"
                static let buildPlanCTAHint =
                    "Daily calories, macros, and your pace — next."
                static let goalSectionTitle = "Your goal"
                static let goalFallbackHero = "Your goal is set"
                static let goalFallbackSubtitle =
                    "We'll shape your starting targets from what you've shared."
                static let maintainGoalSubtitle = "We'll help you stay consistent."

                enum Insight {
                    static let lossTitle = "A realistic target — smart choice"
                    static let loss =
                        "You picked steady progress over extremes. We'll shape daily habits you can actually keep."
                    static let gainTitle = "Built for consistency"
                    static let gain =
                        "We'll turn your goal into daily fuel targets that support steady progress."
                    static let maintainTitle = "Stay in your range"
                    static let maintain =
                        "Clear daily goals help you stay near where you want to be — without guesswork."
                    static let fallbackTitle = "Ready when you are"
                    static let fallback =
                        "We'll shape your starting targets from what you've shared so far."
                }

                enum ProfileMirror {
                    static let title = "What we heard"
                    static let measurements = "Your measurements"
                    static let profile = "Your profile"
                    static let activity = "How you move"
                    static let target = "Where you're headed"
                    static let accessibilityList =
                        "your measurements, profile, activity level, and target weight"
                }

                enum Anticipation {
                    static let sectionTitle = "What you'll unlock"
                    static let bullets: [(icon: String, title: String)] = [
                        ("flame.fill", "Daily calorie target"),
                        ("chart.line.uptrend.xyaxis", "Your progress pace"),
                        ("calendar", "Habits you can keep")
                    ]
                    static let accessibilityLabel =
                        "What you'll unlock: daily calorie target, your progress pace, habits you can keep."
                }

                enum Details {
                    static let title = "Edit your answers"
                    static let collapsedSummary = "Height, weight, birthday, sex, activity"
                    static let collapsedAccessibilityHint =
                        "Expand to edit height, weight, birthday, sex, and activity."
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
                static let savePlanCTA = "Save & continue"
                static let signedOutSaveTrustNote =
                    "One tap with Google keeps your plan backed up."
                static let signedInSaveTrustNote =
                    "Save your plan to keep it across devices."

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
        static let journeyTitle = "Your journey starts with a few logs"
        static let journeyBody = "Log meals, water, or weight in Coach to see your trend."

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
            static let noDataYet = "No workouts or steps yet today — rest days count too."
            static let stepsUnavailable = "Steps unavailable"
            static let disconnectedMessage = "Activity stays optional. Connect Apple Health when you want steps and workouts here."
            static let disconnectedDeniedMessage = "Apple Health access is off. Turn it on in Settings to see activity here."

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
            static let caloriesRemainingLabel = "Calories remaining"
            static let caloriesOverLabel = "Above today's target"
            static let remainingSuffix = "remaining"
            static let overSuffix = "over"
            static let statusOnTrack = "You're perfectly on track."
            static let statusStartFirstMeal = "Start with your first meal."
            static let statusOverTarget = "You're above today's target — keep logging honestly."
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
            static let sectionTitle = "Quick Actions"
            static let fabAccessibilityLabel = "Quick log"
            static let fabAccessibilityHint = "Log food, water, weight, or open Coach"
            static let addWaterSheetTitle = "Add water"
            static let addWaterSheetBody = "Pick an amount to log now."
            static let scanFoodUnavailableNote = "Photo scan is coming soon — use manual entry for now."

            static func inlineAccessibilityHint(for kind: TodayQuickActionKind) -> String {
                switch kind {
                case .scanFood: return "Opens food photo scan"
                case .manualEntry: return "Opens manual meal entry"
                case .addWater: return "Opens water logging"
                case .logWeight: return "Opens weight logging"
                case .askCoach: return FormaProductCopy.Today.askCoachCTAAccessibilityHint
                }
            }

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
        static let statusNoData = "—"

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

        typealias StoryTimeline = Timeline

        enum HabitInsights {
            static let sectionTitle = "Habit insights"
            static let lockedBody = "Keep logging to unlock habit insights."
            static let strongestTitle = "Your strongest habit"
            static let nextFocusTitle = "Your next focus"
            static let suggestionTitle = "Next step"

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
            static let suggestLogNextMeal = "Log your next meal to keep your momentum going."
            static let suggestCaloriePlanning = "Plan tomorrow's meals tonight to build consistency."
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
        }

        enum ProgressAttribution {
            static let sectionTitle = "What's driving your progress"
            static let biggestReasonTitle = "A steady pattern likely helped most."
            static let insufficientTitle = "Your consistency is starting to create a useful pattern."
            static let insufficientDetail = "Keep logging meals and weight so Forma can spot what's helping."

            static let calorieLikelyHelpedTitle = "Your calorie consistency likely helped most."
            static let proteinAnchorTitle = "Protein likely became one of your strongest anchors."
            static let loggingControlTitle = "Logging more often likely gave you better control."
            static let trainingRhythmTitle = "Your training rhythm likely became more consistent."
            static let habitsBeforeScaleTitle = "Your habits are building before the scale catches up."
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

        typealias WhyProgress = ProgressAttribution

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
            static let earnExplanation = "Earn XP by logging consistently and building momentum."
            static let emptyBody = "Log your first meal to start earning XP and building momentum."

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
            static let habitInsightsBody = HabitInsights.lockedBody
            static let personalRecordsBody = PersonalRecords.lockedBody
            static let timelineBody = Timeline.emptyBody
            static let milestonesBody = Milestones.emptyBody
            static let levelBody = Level.emptyBody
        }

        enum DetailedAnalytics {
            static let title = "Detailed analytics"
            static let subtitle = "Nutrition, water, training, and trend details"
            static let weightTrendTitle = "Weight trend"
            static let nutritionTitle = "Nutrition"
            static let waterTitle = "Water"
            static let trainingTitle = "Training"
            static let rangeTitle = "Range"
            static let noWorkoutsThisWeek = "No Apple Health workouts this week."
            static let trainingSourceNote = TrainingIntegrationCopy.trainingInsightsUseAppleHealth

            enum WeightTrend {
                static let spikeUp = "A recent bump is likely water retention — your longer trend matters more."
                static let spikeGeneral = "Daily weight jumped — often water or sodium. Keep logging and watch the weekly shape."
                static let decreasing = "The trend is moving toward your goal. Stay patient through normal daily fluctuations."
                static let increasing = "Weight has drifted up recently. Review intake and recovery when you're ready."
                static let stable = "Weight is holding steady — recomposition and maintenance both show up here first."
                static let insufficientData = FormaProductCopy.EmptyState.WeightTrend.body
            }
        }

        enum WeeklyReview {
            static let sectionTitle = "This week"
            static let foodTitle = "Logged food"
            static let proteinTitle = "Protein goal"
            static let waterTitle = "Water goal"
            static let trainingTitle = "Gym goal"
            static let calorieTitle = "Calorie target"
            static let weightTitle = "Weight"
            static let trainingNone = "None yet"

            static let weightUnavailable = "Log weight to see weekly change"
            static let trainingConnectAppleHealth = TrainingIntegrationCopy.includeWorkoutsInProgress
            static let noFoodLogsSummary = "Log a meal to start building your weekly pattern."

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

            enum Appearance {
                static let systemTitle = "System"
                static let systemDescription = "Match device appearance"
                static let lightTitle = "Light"
                static let lightDescription = "Always use light appearance"
                static let darkTitle = "Dark"
                static let darkDescription = "Always use dark appearance"
            }

            enum ColorPalette {
                static let defaultTitle = "Default Forma"
                static let defaultDescription = "Forma's signature palette."
                static let pinkTitle = "Pink"
                static let pinkDescription = "Warm rose tones."
                static let coolBlueTitle = "Cool Blue"
                static let coolBlueDescription = "Calm blue tones."
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
                case .default: ColorPalette.defaultTitle
                case .pink: ColorPalette.pinkTitle
                case .coolBlue: ColorPalette.coolBlueTitle
                }
            }

            static func colorPaletteDescription(for palette: AppThemePalette) -> String {
                switch palette {
                case .default: ColorPalette.defaultDescription
                case .pink: ColorPalette.pinkDescription
                case .coolBlue: ColorPalette.coolBlueDescription
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
                let selection = isSelected ? "selected, " : ""
                let normalizedDescription = colorPaletteDescription(for: palette)
                    .replacingOccurrences(of: ",", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                return "\(colorPaletteTitle(for: palette)), \(selection)\(normalizedDescription)"
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
