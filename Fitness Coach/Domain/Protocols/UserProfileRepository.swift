//
//  UserProfileRepository.swift
//  Fitness Coach
//
//  Domain protocols for user profile persistence.
//

import Foundation

@MainActor
protocol UserProfileReading: AnyObject {
    func getCurrentProfile() throws -> UserProfile?
    func getCurrentProfileOwnerUID() throws -> String?
    func currentProfileOwnership(for sessionUID: String) throws -> ProfileOwnershipStatus
}

@MainActor
protocol UserProfileWriting: AnyObject {
    @discardableResult
    func createProfile(_ draft: UserProfileDraft, ownerUID: String? = nil) throws -> UserProfile
    @discardableResult
    func updateProfile(_ update: UserProfileUpdate) throws -> UserProfile
    @discardableResult
    func updateTargets(_ targets: UserTargets) throws -> UserProfile
    @discardableResult
    func assignOwnerUID(_ uid: String) throws -> UserProfile
    @discardableResult
    func restoreProfile(from document: CloudUserProfileDocument, ownerUID: String) throws -> UserProfile
    @discardableResult
    func replaceLocalProfile(
        with document: CloudUserProfileDocument,
        ownerUID: String
    ) throws -> UserProfile
}

extension UserProfileService: UserProfileReading, UserProfileWriting {}
