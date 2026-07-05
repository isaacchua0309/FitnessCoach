//
//  FormaProductCopy+Auth.swift
//  Fitness Coach
//
//  Auth and account entry copy — sign-in, public entry, account restore, and account settings.
//

import Foundation

extension FormaProductCopy {
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
}
