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
}

struct PublicEntryAnalyticsProperties: Sendable {
    var reason: String?

    func asParameters() -> [String: String] {
        guard let reason else { return [:] }
        return ["reason": reason]
    }
}

protocol PublicEntryAnalyticsLogging: Sendable {
    func log(_ event: PublicEntryAnalyticsEvent, properties: PublicEntryAnalyticsProperties)
}
