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
    static let shortValueProp = "Build your plan, log with Coach, and make steady progress across nutrition and training."

    // MARK: - Common

    enum Common {
        static let tryAgain = "Try again"
        static let retry = "Retry"
        static let refresh = "Refresh"
        static let getStarted = "Get started"
        static let continueAction = "Continue"
        static let back = "Back"
        static let completeRequiredFields = "Complete the required fields to continue."
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
        static let coachUnavailable = "Coach is briefly unavailable. Try again in a moment."
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
        static let trustNote = "Your Google account keeps your plan available when you sign in."
        static let legalIntro = "By continuing, you agree to Forma's"
        static let termsLinkTitle = "Terms"
        static let privacyPolicyLinkTitle = "Privacy Policy"

        static let benefits: [(icon: String, title: String)] = [
            ("target", "A plan and daily targets shaped to you"),
            ("bubble.left.and.bubble.right.fill", "Natural-language logging with Coach"),
            ("chart.line.uptrend.xyaxis", "Progress across nutrition and training")
        ]
    }

    // MARK: - Onboarding

    enum Onboarding {
        static let welcomeTitle = "Welcome to Forma"
        static let welcomeHeadline = "Stay consistent today — Forma shapes the plan around you."
        static let startButton = "Start Forma"
        static let welcomeBody = """
            Forma sets your targets, keeps the day simple, and lets Coach handle food, water, weight, and training from natural language.
            """
        static let welcomeFeatures: [(icon: String, text: String)] = [
            ("target", "Daily calorie and macro targets shaped to you"),
            ("bolt.fill", "Log meals, water, weight, and workouts in Coach"),
            ("sparkles", "Weekly insights and calm coaching guidance")
        ]
        static let welcomeInfoTitle = "About a minute to start"
        static let welcomeInfoMessage = "You're getting started — keep the first week simple. Use your best estimates; you can adjust everything later in Plan."
        static let activityBaselineSubtitle = "This helps Forma estimate your baseline burn and recovery needs."
        static let goalPaceSubtitle = "You can adjust this later once Forma sees your trend."
        static let goalSubtitle = "Pick a realistic goal weight and a pace that protects training and recovery."
        static let planPreviewSubtitle = "These are your starting numbers. Forma will help you adjust as real progress data comes in."
        static let planBaselineMessage = "Your first week is a baseline. Log daily and weigh in so Forma can make better adjustments."
        static let planNotGeneratedTitle = "Complete your setup first"
        static let planNotGeneratedMessage = "Go back and finish your details so Forma can generate starting targets."
        static let aggressivePlanWarning = "This pace is aggressive. Watch energy, sleep, and how training feels."
        static let planMathSectionTitle = "Behind your numbers"
        static let preferencesSubtitle = "Optional details help Coach sound more personal and keep meal ideas relevant."
        static let coachFirstLoggingMessage = "After setup, Coach is where you'll log food, water, weight, workouts, and daily check-ins."
        static let noPressureMessage = "Skip these if you want. You can update your plan anytime in Plan."

        enum Validation {
            static let age = "Enter a valid age."
            static let height = "Enter a valid height."
            static let currentWeight = "Enter your current weight."
            static let goalWeight = "Enter your goal weight."
            static let trainingFrequency = "Training frequency must be zero or greater."
            static let averageSteps = "Average steps must be zero or greater."
            static let bodyFatRange = "Body fat must be between 0 and 80."
        }
    }

    // MARK: - Account

    enum Account {
        static let logoutConfirmationTitle = "Log out of Forma?"
        static let logoutConfirmationMessage = "You'll need to sign in again to use Forma. Your local data on this device will not be deleted."
        static let signOutHint = "Sign out of Forma on this device"
        static let dataSeparateNote = "Deleting app data is separate from signing out."
    }

    // MARK: - Empty states

    enum EmptyState {
        static let todayTitle = "Set up your profile"
        static let todayProfileRequired = "Create your profile first so Forma can generate targets and start today's log."
        static let planTitle = "Build your plan"
        static let planGetStarted = "Share your goal with Forma and we'll create a personalized calorie, macro, and training blueprint."
        static let journeyTitle = "Your journey starts with a few logs"
        static let journeyBody = "Log weight, food, or water in Coach to see trends and weekly insights."
    }

    // MARK: - Today

    enum Today {
        static let askCoachCTA = "Need to update today? Ask Coach"
        static let mealsEmptyHint = "No meals logged yet. Ask Coach to log your first meal."
        static let caloriesRemaining = "Calories remaining"
        static let caloriesAboveTarget = "Above today's target"
        static let defaultCoachNote = "Anchor your next meal with protein."
    }

    // MARK: - Training

    enum Training {
        static let restDayGuidance = "When you train, tell Coach what you did. Forma will track volume, streaks, and muscle balance."
        static let noWorkoutsHint = "No workouts yet. Tell Coach what you trained."
        static let muscleEmptyHint = "Log workouts in Coach to see muscle balance."
        static let workoutCorrectionHint = "Need a correction? Tell Coach."
    }

    // MARK: - Journey

    enum Journey {
        static let proteinStrong = "Hit most days"
        static let proteinWeak = "Anchor your next meal with protein"
        static let waterStrong = "Hydration on track"
        static let waterWeak = "Front-load water earlier in the day"
        static let logMealsToTrack = "Log meals in Coach to track"
        static let noWorkoutsYet = "None yet — log training in Coach"
        static let kcalUnderTarget = "kcal under target"
        static let kcalAboveTarget = "kcal above target"
        static let milestonesNeedGoal = "Set a goal in Plan to see your weight roadmap."
    }

    // MARK: - Coach

    enum Coach {
        static let headerSubtitle = "What do you want to log or ask?"
        static let emptyIntro = "Tell Forma what you ate, drank, weighed, or trained."
        static let emptyToolbarHint = "Quick commands are in the toolbar below."
        static let composerPlaceholder = "Message Coach…"
        static let foodEstimatePending = "Food estimate ready"
        static let reviewEstimate = "Review estimate"
        static let examplePrompts = [
            "Log chicken rice for lunch",
            "I drank 600ml water",
            "I did bench press today"
        ]
    }

    // MARK: - Legal

    enum Legal {
        static var productName: String { appName }
    }
}
