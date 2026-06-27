//
//  CloudUserProfileStoring.swift
//  Fitness Coach
//
//  FitPilot — Protocol for minimal cloud profile snapshot read/write.
//

import Foundation

enum CloudUserProfileStoreError: Error, Equatable {
    case notAuthenticated
    case permissionDenied
    case unavailable(String)
}

protocol CloudUserProfileStoring: Sendable {
    func fetch(uid: String) async throws -> CloudUserProfileDocument?
    func save(profile: UserProfile, uid: String) async throws
}
