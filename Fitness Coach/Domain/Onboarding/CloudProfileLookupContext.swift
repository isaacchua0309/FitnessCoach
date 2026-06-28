//
//  CloudProfileLookupContext.swift
//  Fitness Coach
//
//  Forma — Caller context for read-only cloud profile resolution.
//

import Foundation

enum CloudProfileLookupContext: String, Equatable, Sendable {
    case onboardingCompletion
    case bootstrap
    case ownershipResolution
    case returningSignIn
    case accountSwitch
    case normalLaunch
    case profileUpload
}
