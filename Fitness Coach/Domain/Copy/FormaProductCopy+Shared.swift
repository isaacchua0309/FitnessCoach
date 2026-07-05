//
//  FormaProductCopy+Shared.swift
//  Fitness Coach
//
//  Shared product copy — common strings, loading, errors, empty states, and legal.
//

import Foundation

extension FormaProductCopy {
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
    // MARK: - Legal

    enum Legal {
        static var productName: String { appName }
        /// Placeholder support address shown in Terms and Privacy. Confirm before App Store release.
        static let supportEmail = "support@forma.app"
        static let effectiveDate = "June 26, 2026"
    }
}
