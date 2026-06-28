//
//  PublicEntryAnalyticsLogging.swift
//  Fitness Coach
//
//  Forma — Typed public welcome / entry analytics events.
//

import Foundation

enum PublicEntryAnalyticsEvent: String, Sendable {
    case welcomeViewed = "public_welcome_viewed"
    case welcomeCreatePlanTapped = "public_welcome_create_plan_tapped"
    case welcomeSignInTapped = "public_welcome_sign_in_tapped"
    case existingSignInViewed = "existing_sign_in_viewed"
    case existingSignInStarted = "existing_sign_in_started"
    case existingSignInSucceeded = "existing_sign_in_succeeded"
    case existingSignInFailed = "existing_sign_in_failed"
    case existingSignInNoProfileFound = "existing_sign_in_no_profile_found"
    case noExistingProfileViewed = "no_existing_profile_viewed"
    case noExistingProfileStartOnboardingTapped = "no_existing_profile_start_onboarding_tapped"
    case noExistingProfileUseAnotherAccountTapped = "no_existing_profile_use_another_account_tapped"
    case logoutCompletedPublicEntryShown = "logout_completed_public_entry_shown"
}

enum PublicEntryEntrySource: String, Sendable {
    case freshInstall = "fresh_install"
    case logout = "logout"
    case sessionExpired = "session_expired"
}

struct PublicEntryAnalyticsProperties: Sendable {
    var authProvider: String?
    var hasLocalProfile: Bool?
    var profileResolutionResult: String?
    var entrySource: String?
    var reason: String?

    func asParameters() -> [String: String] {
        var parameters: [String: String] = [:]
        if let authProvider { parameters["auth_provider"] = authProvider }
        if let hasLocalProfile {
            parameters["has_local_profile"] = hasLocalProfile ? "true" : "false"
        }
        if let profileResolutionResult {
            parameters["profile_resolution_result"] = profileResolutionResult
        }
        if let entrySource { parameters["entry_source"] = entrySource }
        if let reason { parameters["reason"] = reason }
        return parameters
    }

    func merging(_ overlay: PublicEntryAnalyticsProperties) -> PublicEntryAnalyticsProperties {
        PublicEntryAnalyticsProperties(
            authProvider: overlay.authProvider ?? authProvider,
            hasLocalProfile: overlay.hasLocalProfile ?? hasLocalProfile,
            profileResolutionResult: overlay.profileResolutionResult ?? profileResolutionResult,
            entrySource: overlay.entrySource ?? entrySource,
            reason: overlay.reason ?? reason
        )
    }
}

protocol PublicEntryAnalyticsLogging: Sendable {
    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties)
}
