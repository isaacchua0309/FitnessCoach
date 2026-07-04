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
        static let ok = "OK"
        static let done = "Done"
        static let completeRequiredFields = "Fill in the required fields to continue."
    }

    // MARK: - Account restore (Phase 4)

    enum AccountRestore {
        static let restoringMessage = "Restoring your logs and progress…"

        enum Progress {
            static let checkingAccount = "Checking account…"
            static let restoringProfile = "Restoring your plan…"
            static let restoringRecentLogs = "Restoring your recent meals and water…"
            static let restoringWeightHistory = "Restoring your weight history…"
            static let preparingDashboard = "Preparing your dashboard…"
        }

        enum Partial {
            static let title = "Some data is still syncing"
            static let body =
                "Some data could not be restored yet. You can continue and we'll retry in the background."
            static let continueCTA = "Continue to Forma"
        }

        enum Offline {
            static let title = "You're offline"
            static let body =
                "You're offline. You can continue with local data, and we'll restore your account when you're back online."
            static let continueCTA = "Continue to Forma"
        }

        enum Completed {
            static let message = "Your account is ready."
        }

        enum Failed {
            static let title = "Couldn't restore your account data"
            static let body = "We couldn't restore your account data. Please try again."
            static let retryCTA = "Try again"
            static let signOutCTA = "Sign out"
        }

        enum TimedOut {
            static let body =
                "Restore is taking longer than expected. You can keep using Forma while we finish in the background."
        }

        enum Pending {
            static let title = "Restoring your account"
            static let defaultBody =
                "Your account data is still syncing. Your history will appear here shortly."
            static let partialBody =
                "Some data could not be restored yet. You can continue and we'll retry in the background."
            static let offlineBody =
                "Progress will appear after your account data restores."
            static let todayBody =
                "Your meals and logs are still restoring. They'll appear here once sync finishes."
        }
    }

    // MARK: - Loading

    enum Loading {
        static let app = "Loading Forma…"
        static let today = "Loading today…"
        static let plan = "Loading your plan…"
        static let journey = "Loading your journey…"
        static let training = "Loading training…"
        static let settings = "Loading settings…"
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
        static let coachPhotoTooLarge = Coach.mealPhotoPreparationFailed
        static let coachPhotoEncodingFailed = Coach.mealPhotoPreparationFailed
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

    // MARK: - Account

    enum Account {
        static let logoutConfirmationTitle = "Log out of Forma?"
        static let logoutConfirmationMessage =
            "Signing out keeps this device's local data unless you delete it."
        static let signOutHint = "Sign out of Forma on this device"
        static let signOutUnavailableHint = "Unavailable while signing in"
        static let missingNameFallback = "Not provided"
        static let missingEmailFallback = "Not provided"
        static let signedInBadgeGoogle = "Signed in with Google"
        static let signedInBadgeGeneric = "Signed in"
        static let signInMethodGoogle = "Google"
        static let detailNameLabel = "Name"
        static let detailEmailLabel = "Email"
        static let detailSignInLabel = "Sign-in"
        static let avatarAccessibilityLabel = "Profile photo"
        static let logoutButtonTitle = "Log out"
        static let logoutConfirmActionTitle = "Log Out"
        static let logoutCancelActionTitle = "Cancel"
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
            static let body = "Tell Coach with a photo, voice note, or quick description — we'll track the rest."
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

        enum HealthIntelligence {
            static let loadingTitle = FormaProductCopy.HealthIntelligence.Loading.title
            static let loadingSubtitle = FormaProductCopy.HealthIntelligence.Loading.subtitle(for: .journey)
            static let loadingAccessibilityLabel = FormaProductCopy.HealthIntelligence.Loading.accessibilityLabel
            static let limitedEstimate = FormaProductCopy.HealthIntelligence.limitedEstimateLabel
            static let unavailableTitle =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .journey).title
            static let unavailableSubtitle =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .journey).bannerMessage
            static let connectHealthTitle =
                FormaProductCopy.HealthIntelligence.NoHealthPermission.title
            static let connectHealthMessage =
                FormaProductCopy.HealthIntelligence.NoHealthPermission.message
            static let connectHealthCTA =
                FormaProductCopy.HealthIntelligence.NoHealthPermission.actionTitle
            static let connectedNoWorkoutsMessage =
                FormaProductCopy.HealthIntelligence.message(for: .noHealthDataYet, surface: .journey).message
            static let errorTitle =
                FormaProductCopy.HealthIntelligence.SyncFailed.title
            static let errorSubtitle =
                FormaProductCopy.HealthIntelligence.message(for: .syncFailed, surface: .journey).bannerMessage
            static let staleDataLabel = FormaProductCopy.Today.HealthIntelligence.staleDataLabel
            static let syncFailedWithCacheLabel = FormaProductCopy.Today.HealthIntelligence.syncFailedWithCacheLabel

            enum RecoveryTimeline {
                static let sectionTitle = "Recovery timeline"
                static let headline = "Last 7 days"
                static let headline14Days = "Last 14 days"
                static let emptyMessage = "Recovery trends appear after a few days of synced signals."
                static let limitedTimelineNote =
                    "Limited timeline — recovery history is still building from Apple Health."
            }

            enum WorkoutHistory {
                static let sectionTitle = "Recent workouts"
                static let headline = "Last 30 days"
                static let emptyMessage = "Workouts from Apple Health will show up here."
            }

            enum Milestones {
                static let sectionTitle = "Health milestones"
                static let headline = "Highlights"
                static let emptyMessage = "Milestones appear as workouts and recovery patterns build."
            }

            enum Progress {
                static let sectionTitle = "Health progress"
                static let headline = "This week at a glance"
                static let emptyMessage = "Weekly health progress unlocks with more synced activity."
            }

            static let milestoneAchieved = "Achieved"
            static let milestoneInProgress = "In progress"
            static let milestoneUpcoming = "Up next"

            static func workoutStreak(_ days: Int) -> String {
                days == 1 ? "1-day workout streak" : "\(days)-day workout streak"
            }

            static func longestWorkout(minutes: Int, title: String) -> String {
                "Longest session: \(durationLabel(minutes: minutes)) \(title)"
            }

            static func mostActiveDay(steps: Int, dateLabel: String) -> String {
                "Most active day: \(steps.formatted()) steps on \(dateLabel)"
            }

            static func workoutConsistency(days: Int, windowDays: Int) -> String {
                "\(days) workout days in the last \(windowDays) days"
            }

            static func weightTrend(_ changeKg: Double) -> String {
                let formatted = String(format: "%.1f", abs(changeKg))
                if changeKg < 0 {
                    return "\(formatted) kg down this week"
                }
                if changeKg > 0 {
                    return "\(formatted) kg up this week"
                }
                return "Weight held steady this week"
            }

            static func recoveryScoreLabel(_ score: Int) -> String {
                "Score \(score)"
            }

            enum WeeklyReview {
                static let sectionTitle = "Weekly health review"
            }

            static func durationLabel(minutes: Int) -> String {
                guard minutes > 0 else { return "—" }
                if minutes >= 60 {
                    let hours = minutes / 60
                    let remainder = minutes % 60
                    if remainder == 0 {
                        return hours == 1 ? "1 hr" : "\(hours) hr"
                    }
                    return "\(hours) hr \(remainder) min"
                }
                return "\(minutes) min"
            }

            static func demandLabel(_ demand: String) -> String {
                switch demand.lowercased() {
                case "high": return "High demand"
                case "moderate": return "Moderate demand"
                case "low": return "Low demand"
                default: return demand.capitalized
                }
            }

            static func workoutsThisWeek(_ count: Int) -> String {
                count == 1 ? "1 workout" : "\(count) workouts"
            }

            static func limitedRecoveryDays(_ count: Int) -> String {
                count == 1 ? "1 day with limited recovery" : "\(count) days with limited recovery"
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
        static let scanMealPrefill = "Scan my meal"
        static let mealLoggingComposerPlaceholder = "Send a photo or describe your meal."

        static func mealLoggingComposerPlaceholder(mealType: MealType?) -> String {
            switch mealType {
            case .breakfast:
                return "What did you eat for breakfast? Send a photo or describe your meal."
            case .lunch:
                return "What did you eat for lunch? Send a photo or describe your meal."
            case .dinner:
                return "What did you eat for dinner? Send a photo or describe your meal."
            case .snack:
                return "What did you eat for a snack? Send a photo or describe your meal."
            case .unknown, nil:
                return "What did you eat? Send a photo or describe your meal."
            }
        }

        static let composerListeningPlaceholder = "Listening…"
        static let composerPhotoClarificationPlaceholder = "Add a detail about your meal…"
        static let foodEstimatePending = "Food estimate ready"
        static let reviewEstimate = "Review estimate"
        static let logPending = "Log"
        static let confirmPending = "Confirm"
        static let editPending = "Edit"
        static let discardPending = "Discard"
        static let retryMealPhotoAnalysis = "Retry analysis"
        static let removePhotoBeforeAddingAnother = "Remove the current photo before adding another."
        static let composerImageProcessing = "Preparing photo…"
        static let composerImageRetry = "Retry"
        static let mealPhotoPreparationFailed =
            "Couldn't prepare this photo. Try taking another photo in better lighting."
        static let photoAnalysisLeadIn = "From your meal photo:"
        static let foodEditPortionFooter = "Edit if the portion or cut is different."
        static let foodEditIngredientsFooter = "Edit if you know the ingredients."
        static let foodConfirmBelowFooter = "Confirm below to add it."
        static let pendingBarHint = "Use the bar below to log, edit, or discard."
        static let foodLoggedTimelineNote = "Added to today's timeline."
        static let pendingReviewBeforeLogging = "Please review before logging."
        static let pendingSourceMealPhoto = "Source: meal photo"
        static let pendingSourceCommonFood = "Source: usual food"

        static func latestMealLine(name: String, calories: Int) -> String {
            "Latest: \(name) · \(calories) kcal"
        }

        enum Launch {
            static let logMealBody = "Send a photo, speak, or describe your meal — whatever is easiest."
            static let analyzePhotoHeadline = "Scan your meal"
            static let analyzePhotoBody = "Take a photo or describe what you ate — Coach handles the rest."
            static let logWaterHeadline = "Log water"
            static let logWaterBody = "Tap below to add water, or tell Coach how much you drank."
            static let chipSectionTitle = "Get started"

            static func logMealHeadline(mealType: MealType?) -> String {
                switch mealType {
                case .breakfast: return "Log breakfast"
                case .lunch: return "Log lunch"
                case .dinner: return "Log dinner"
                case .snack: return "Log a snack"
                case .unknown, nil: return "Log your meal"
                }
            }

            static func waterLogCommand(amountMl: Int) -> String {
                "Add \(amountMl)ml water"
            }

            enum Chip {
                static let takePhoto = "Take photo"
                static let describeMeal = "Describe meal"
                static let useVoice = "Use voice"
                static let takePhotoHint = "Opens the camera to photograph your meal"
                static let describeMealHint = "Focuses the message field to type your meal"
                static let useVoiceHint = "Starts voice input for your meal"
                static let addWaterHint = "Sends a water log command to Coach"

                static func addWater(amountMl: Int) -> String {
                    amountMl >= 1_000 ? "Add \(amountMl / 1_000)L water" : "Add \(amountMl)ml water"
                }
            }
        }
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

        static let editNutritionTitle = "Edit nutrition"
        static let createCustomFoodTitle = "Create custom food"

        static let kcalUnit = "kcal"
        static let gramsUnit = "g"
        static let mgUnit = "mg"
        static let mlUnit = "ml"
        static let kgUnit = "kg"
    }

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
        static let recommendedBadge = "Recommended for you"

        static let loseFatTitle = "Lose fat"
        static let loseFatExplanation = "Trim body fat while keeping strength on the menu."
        static let loseFatOutcome = "Gradual scale changes with room to stay consistent."

        static let maintainTitle = "Maintain weight"
        static let maintainExplanation = "Hold your weight steady while you build habits."
        static let maintainOutcome = "Daily targets stay near maintenance so progress feels calm."

        static let gainMuscleTitle = "Build muscle"
        static let gainMuscleExplanation = "Fuel training with a modest surplus."
        static let gainMuscleOutcome = "Weight may climb slowly while strength gets priority."
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
            "Update your goal, target weight, activity, or calories."

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

    // MARK: - Settings

    enum Settings {

        enum Hub {
            static let screenTitle = "Settings"
            static let doneAccessibilityLabel = "Done"
            static let accountSectionTitle = "Account"
            static let preferencesSectionTitle = "Preferences"
            static let integrationsSectionTitle = "Integrations"
            static let privacyDataSectionTitle = "Privacy & Data"
            static let supportSectionTitle = "Support"
            static let aboutSectionTitle = "About"
            static let developerSectionTitle = "Developer"
        }

        enum Rows {
            static let account = "Account"
            static let units = "Units"
            static let appleHealth = "Apple Health"
            static let privacyPolicy = "Privacy Policy"
            static let exportData = "Export Data"
            static let deleteAccount = "Delete Account"
            static let deleteLocalDeviceData = "Delete Local Data"
            static let sendFeedback = "Send Feedback"
            static let contactSupport = "Contact Support"
            static let reportProblem = "Report a Problem"
            static let appVersion = "App Version"
            static let termsOfService = "Terms of Service"
            static let authDiagnostics = "Auth diagnostics"
            static let pipelineTraces = "Pipeline traces"
            static let healthIntelligenceSnapshot = "Health intelligence snapshot"
            static let coachContextInspector = "Coach context inspector"
            static let accountSyncDiagnostics = "Account sync diagnostics"
            static let accountRestoreDiagnostics = "Account restore diagnostics"
        }

        enum Developer {
            static let sectionFooter = "Debug tools are only visible in internal builds."
        }

        enum Support {
            static let feedbackMailSubject = "Forma Feedback"
            static let contactMailSubject = "Forma Support"
            static let reportProblemMailSubject = "Forma Problem Report"
            static let sectionFooter = "We read every message. Diagnostics help us troubleshoot — no health data is included."
            static let diagnosticsHeader = "Diagnostics"
            static let feedbackMailPrompt = "Share your feedback:"
            static let contactMailPrompt = "How can we help?"
            static let reportProblemMailPrompt = "What went wrong?"
        }

        enum Status {
            static let connected = "Connected"
            static let notConnected = "Not connected"
            static let metric = "Metric"
            static let imperial = "Imperial"
        }

        enum AppleHealth {
            static let screenTitle = "Apple Health"
            static let healthDataDetailsTitle = "Health data details"
            static let permissionsSectionTitle = "Permissions"
            static let statusLabel = "Connection status"
            static let lastLocalSyncLabel = "Last local sync"
            static let lastRemoteSyncLabel = "Last remote summary sync"
            static let remoteSummarySyncLabel = "Remote summary sync"
            static let lastSyncNever = "Not yet synced"
            static let statusConnected = "Connected"
            static let statusPartiallyConnected = "Partially connected"
            static let statusNotConnected = "Not connected"
            static let statusPermissionNeeded = "Permission needed"
            static let statusUnavailable = "Unavailable"
            static let statusConnecting = "Connecting…"
            static let connectAction = "Connect Apple Health"
            static let connectingAction = "Connecting…"
            static let refreshHealthDataAction = "Refresh health data"
            static let refreshingHealthDataAction = "Refreshing…"
            static let openHealthAppAction = "Manage in Apple Health"
            static let manageHealthDataSyncAction = "Manage health data sync"
            static let deleteRemoteSummariesAction = "Delete remote health summaries"
            static let deletingRemoteSummariesAction = "Deleting…"
            static let loadFailedMessage = "Couldn't load Apple Health settings. Try again."
            static let healthKitUnavailableMessage =
                "Apple Health isn't available on this device. Health settings stay read-only here."
            static let deleteRemoteSummariesFailedMessage =
                "Couldn't delete remote health summaries. Try again when you're signed in."
            static let connectAccessibilityHint = "Requests permission to read selected Apple Health signals"
            static let connectingAccessibilityHint = "Unavailable while connecting"
            static let openHealthAccessibilityHint = "Opens the Health app to manage Forma permissions"
            static let refreshHealthDataAccessibilityHint = "Refreshes cached health summaries on this device"
            static let manageHealthDataSyncAccessibilityHint = "Opens cloud health summary sync settings"
            static let deleteRemoteSummariesAccessibilityHint =
                "Deletes normalized health summaries stored for your account"

            enum RemoteSync {
                static let screenTitle = "Health data sync"
                static let intro =
                    "Choose whether Forma stores normalized health summaries in your account. Raw HealthKit samples are never uploaded."
                static let statusLabel = "Sync status"
                static let lastSyncLabel = "Last remote sync"
                static let lastSyncNever = "Not yet synced"
                static let syncNowAction = "Sync now"
                static let syncingAction = "Syncing…"
                static let deleteRemoteSummariesAction = "Delete remote health summaries"
                static let deleteConfirmationTitle = "Delete remote health summaries?"
                static let deleteConfirmationMessage =
                    "This removes normalized health summaries stored for your Forma account. Your Apple Health data is not changed."
                static let deleteConfirmActionTitle = "Delete summaries"
                static let statusDisabled = "Off"
                static let statusIdle = "Ready"
                static let statusSyncing = "Syncing"
                static let statusSucceeded = "Up to date"
                static let statusPartialSuccess = "Partially synced"
                static let statusFailed = "Needs attention"

                enum Consent {
                    static let toggleTitle = "Sync health summaries"
                    static let toggleDescription =
                        "Forma can sync normalized health summaries to keep Coach and weekly insights consistent across devices. This may include daily step totals, workout summaries, recovery status, and weekly review summaries. Forma does not upload raw Apple Health samples."
                    static let enableTitle = "Enable health summary sync?"
                    static let enableMessage = toggleDescription
                    static let enableConfirmAction = "Enable sync"
                    static let disableTitle = "Turn off health summary sync?"
                    static let disableMessage =
                        "Forma will stop syncing new health summaries. Local Apple Health features on this device keep working."
                    static let disableConfirmAction = "Turn off sync"
                    static let disableAndDeleteAction = "Turn off and delete summaries"
                    static let statusOn = "On"
                    static let statusOff = "Off"
                    static let statusNotSet = "Not enabled"
                }
            }

            // Legacy copy retained for settings hub row summaries.
            static let readsWorkoutsCopy =
                "Forma reads workouts to improve activity, Plan confidence, and Journey insights."
            static let doesNotWriteCopy =
                "Forma does not write or change your Health data."
            static let connectionCardTitle = "Connection"
            static let lastSyncLabel = "Last sync"
            static let permissionsLabel = "Permissions"
            static let accessLabel = "Access"
            static let permissionsWorkouts = "Workouts"
            static let accessManagedInHealthApp = "Managed in Health app"
        }

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

        /// Units preference screen copy.
        enum Units {
            static let screenTitle = "Units"
            static let unitSystemSectionTitle = "Unit system"
            static let examplesSectionTitle = "Examples"
            static let storageFootnote =
                "Forma stores values consistently and converts them for display."
            static let imperialDisplayOnlyFootnote =
                "Imperial changes display units only. Values are stored internally in metric."

            static let exampleWeightLabel = "Weight"
            static let exampleHeightLabel = "Height"
            static let exampleWaterLabel = "Water"
            static let exampleEnergyLabel = "Energy"

            static func unitSystemPickerLabel(for unitSystem: UnitSystem) -> String {
                switch unitSystem {
                case .metric:
                    return "Metric (kg, cm, ml)"
                case .imperial:
                    return "Imperial (lb, ft/in, fl oz)"
                }
            }

            static func unitSystemAccessibilityLabel(
                for unitSystem: UnitSystem,
                isSelected: Bool
            ) -> String {
                let selection = isSelected ? "selected" : "not selected"
                return "\(unitSystemPickerLabel(for: unitSystem)), \(selection)"
            }
        }

        /// Body & stats settings screen copy.
        enum BodyDetails {
            static let profileDetailsSectionTitle = "Profile details"
            static let introCopy =
                "These details help Forma estimate targets and personalize your plan."
            static let updateInPlanCTA = "Update in Plan"
            static let updateInPlanAccessibilityHint = "Opens Adjust Plan to update your body details"
            static let startingWeightLabel = "Starting weight"
            static let currentWeightLabel = "Current weight"
            static let notSetValue = "Not set"
        }

        /// Privacy & Data settings section copy.
        enum PrivacyData {
            static let sectionFooter =
                "Your fitness data stays on this device unless you choose to sign in or use connected services."

            static let deleteAccountConfirmationTitle = "Delete your account?"
            static let deleteAccountConsequenceBullets: [String] = [
                "Deleting your account removes your Forma account and app data stored with your account.",
                "This cannot be undone.",
                "This does not delete data stored in Apple Health.",
                "This does not delete your Google account."
            ]
            static let deleteAccountConfirmActionTitle = "Delete account"
            static let deleteAccountConfirmAccessibilityHint =
                "Permanently deletes your Forma account and associated app data. This cannot be undone."

            static let deleteLocalDeviceDataConfirmationTitle = "Delete local data on this device?"
            static let deleteLocalDeviceDataConsequenceBullets: [String] = [
                "This removes Forma data stored on this device only. Your cloud account and sign-in stay active.",
                "Your cloud-backed data remains and can be restored when you sign in again on this device.",
                "This cannot be undone.",
                "This does not delete data stored in Apple Health.",
                "This does not delete your Google account."
            ]
            static let deleteLocalDeviceDataConfirmActionTitle = "Delete local data only"
            static let deleteLocalDeviceDataConfirmAccessibilityHint =
                "Permanently removes Forma data from this device only. Your cloud account stays active."

            static let typedConfirmationPrompt = "Type DELETE to confirm"
            static let typedConfirmationPlaceholder = "DELETE"
            static let typedConfirmationAccessibilityHint =
                "Required safety confirmation. Type DELETE in capital letters to enable deletion."

            static let deletionProgressPreparing = "Preparing…"
            static let deletionProgressDeletingAccountData = "Deleting account data…"
            static let deletionProgressDeletingAccount = "Deleting account…"
            static let deletionProgressRemovingLocalData = "Removing local data…"
            static let deletionProgressCompleted = "Completed"
            static let deletionProgressAccessibilityLabel = "Account deletion in progress"

            static let deletionFlowCancelTitle = "Cancel"
            static let deletionFlowCancelAccessibilityHint = "Cancels account deletion and returns to Settings"
            static let deletionFlowCloseTitle = "Close"
            static let deletionFlowRetryTitle = "Retry"
            static let deletionFlowReauthenticateTitle = "Reauthenticate and continue"
            static let deletionReauthenticationMessage =
                "Confirm your identity to continue account deletion."
            static let deletionFlowReauthenticateAccessibilityHint =
                "Confirms your identity so account deletion can continue"
            static let deletionFlowUnavailableTitle = "Deletion isn't available"
            static let deletionFlowUnavailableMessage =
                "Account deletion could not start. Sign in and try again."

            static let deleteUnavailableTitle = "Deletion isn't available yet"
            static let deleteUnavailableMessage =
                "Data deletion is not available in this version of Forma. Contact \(FormaProductCopy.Legal.supportEmail) for help."

            static let deletionGenericErrorMessage =
                "Account deletion could not be completed. Try again."
            static let deletionOfflineErrorMessage =
                "Connect to the internet to delete your account data."
            static let deletionPermissionDeniedErrorMessage =
                "You do not have permission to delete this account data."
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

    // MARK: - Weekly review presentation

    enum WeeklyReviewPresentation {
        static let sectionTitle = "Weekly health review"
        static let loadingTitle = "Loading weekly review"
        static let loadingSubtitle = "Summarizing your week."
        static let loadingAccessibilityLabel = "Loading weekly health review"
        static let emptyTitle = "Weekly review building"
        static let notEnoughDataTitle = "Not enough data yet"
        static let notEnoughDataSummary =
            "Log meals, workouts, and recovery signals for at least 7 days to unlock your weekly review."
        static let notEnoughDataRequirements =
            "Requires: 7 days of activity or recovery signals, plus consistent meal logging."
        static let emptySummary =
            "Keep logging meals, workouts, and recovery signals to unlock your weekly health review."
        static let emptyAccessibilityLabel = "Weekly health review unavailable. Keep logging to unlock it."
        static let partialDataSummary =
            "Your weekly health patterns are summarized using the data available this week."

        static let confidenceHigh = "High confidence"
        static let confidenceModerate = "Moderate confidence"
        static let confidenceLow = "Limited confidence"

        static let statUnavailable = "Not enough data"
        static let weightUnavailable = "Log weight to see weekly change"
        static let nutritionLimitedDetail = "Limited nutrition data this week"
        static let activityLimitedDetail = "Limited activity data this week"
        static let recoveryLimitedDetail = "Limited recovery data this week"

        static let workoutsTitle = "Workouts"
        static let stepsTitle = "Average steps"
        static let proteinTitle = "Protein days"
        static let caloriesTitle = "Calorie days"
        static let waterTitle = "Water days"
        static let recoveryTitle = "Recovery"
        static let weightTitle = "Weight trend"
        static let loggingTitle = "Logging days"

        static let statsSectionTitle = "This week at a glance"
        static let limitedStatAccessibilitySuffix = "Limited data"

        static let winsHeader = "Wins"
        static let risksHeader = "Watch next week"
        static let focusHeader = "Next week focus"

        static func generatedAtLabel(for date: Date, calendar: Calendar = .current) -> String {
            let dayLabel = JourneyFormatter.timelineDayLabel(date, calendar: calendar)
            return "Updated \(dayLabel)"
        }

        static func missingDataNotice(for signals: Set<WeeklyReviewMissingSignal>) -> String {
            guard !signals.isEmpty else { return "" }

            let labels = missingSignalLabels(for: signals).sorted()
            if labels.count == 1 {
                return "\(labels[0]) was limited this week, so parts of this review use partial data."
            }
            let joined = labels.dropLast().joined(separator: ", ")
            let last = labels.last ?? "Some signals"
            return "\(joined), and \(last) were limited this week, so parts of this review use partial data."
        }

        static func confidenceLabel(for confidence: WeeklyReviewConfidence) -> String {
            switch confidence {
            case .high: return confidenceHigh
            case .moderate: return confidenceModerate
            case .low: return confidenceLow
            }
        }

        static func workoutsValue(count: Int, minutes: Int) -> String {
            guard count > 0 else { return "None logged" }
            let workoutLabel = count == 1 ? "1 workout" : "\(count) workouts"
            guard minutes > 0 else { return workoutLabel }
            return "\(workoutLabel) · \(FormaProductCopy.Journey.HealthIntelligence.durationLabel(minutes: minutes))"
        }

        static func dayCountValue(_ count: Int, total: Int = 7) -> String {
            "\(count) of \(total) days"
        }

        static func weightTrendValue(_ changeKg: Double) -> String {
            let formatted = String(format: "%.1f", abs(changeKg))
            if changeKg < 0 {
                return "\(formatted) kg down"
            }
            if changeKg > 0 {
                return "\(formatted) kg up"
            }
            return "Held steady"
        }

        static func recoveryValue(score: Double?) -> String {
            guard let score else { return statUnavailable }
            return "Avg \(Int(score.rounded()))"
        }

        private static func missingSignalLabels(for signals: Set<WeeklyReviewMissingSignal>) -> [String] {
            signals.map { signal in
                switch signal {
                case .sleep: return "Sleep"
                case .hrv: return "Heart variability"
                case .weight: return "Weight"
                case .nutrition: return "Nutrition"
                case .workouts: return "Workouts"
                case .activity: return "Activity"
                case .recovery: return "Recovery"
                }
            }
        }
    }

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

    // MARK: - Legal

    enum Legal {
        static var productName: String { appName }
        /// Placeholder support address shown in Terms and Privacy. Confirm before App Store release.
        static let supportEmail = "support@forma.app"
        static let effectiveDate = "June 26, 2026"
    }
}
