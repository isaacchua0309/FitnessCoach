//
//  UserProfileService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns user profile creation, reading, and updating.
//

import Foundation
import SwiftData

@MainActor
final class UserProfileService {

    private let store: SwiftDataStore
    private let dateProvider: DateProviding

    init(store: SwiftDataStore, dateProvider: DateProviding? = nil) {
        self.store = store
        self.dateProvider = dateProvider ?? SystemDateProvider()
    }

    // MARK: Read

    func getCurrentProfile() throws -> UserProfile? {
        try latestProfileEntity()?.toModel()
    }

    func getCurrentProfileOwnerUID() throws -> String? {
        try getCurrentProfile()?.ownerUID
    }

    func currentProfileOwnership(for sessionUID: String) throws -> ProfileOwnershipStatus {
        guard let profile = try getCurrentProfile() else {
            return .unowned
        }
        guard let ownerUID = profile.ownerUID else {
            return .unowned
        }
        return ownerUID == sessionUID
            ? .matchesSession
            : .mismatched(localOwnerUID: ownerUID)
    }

    // MARK: Restore

    func restoreProfile(from document: CloudUserProfileDocument, ownerUID: String) throws -> UserProfile {
        if try getCurrentProfile() != nil {
            throw ServiceError.invalidInput("A profile already exists on this device.")
        }

        return try insertProfile(from: document, ownerUID: ownerUID)
    }

    /// Replaces the on-device profile with a cloud snapshot (onboarding conflict resolution).
    func replaceLocalProfile(
        with document: CloudUserProfileDocument,
        ownerUID: String
    ) throws -> UserProfile {
        if let existing = try latestProfileEntity() {
            try store.delete(existing)
        }
        return try insertProfile(from: document, ownerUID: ownerUID)
    }

    /// Replaces the on-device profile with onboarding draft data (re-commit during onboarding).
    func replaceLocalProfile(
        with draft: UserProfileDraft,
        ownerUID: String? = nil
    ) throws -> UserProfile {
        if let existing = try latestProfileEntity() {
            try store.delete(existing)
        }
        return try createProfile(draft, ownerUID: ownerUID)
    }

    private func insertProfile(
        from document: CloudUserProfileDocument,
        ownerUID: String
    ) throws -> UserProfile {
        var profile = document.makeUserProfile()
        profile.ownerUID = ownerUID
        let entity = UserProfileEntity(model: profile)
        try store.insert(entity)
        return entity.toModel()
    }

    // MARK: Create

    func createProfile(_ draft: UserProfileDraft, ownerUID: String? = nil) throws -> UserProfile {
        try validate(draft)

        let now = dateProvider.now
        let resolvedAge = BirthDateAgeResolver.resolvedAge(
            birthDate: draft.birthDate,
            legacyAge: draft.age,
            referenceDate: now
        )
        let profile = UserProfile(
            id: UUID(),
            ownerUID: ownerUID,
            name: draft.name,
            birthDate: draft.birthDate,
            age: resolvedAge,
            sex: draft.sex,
            heightCm: draft.heightCm,
            currentWeightKg: draft.currentWeightKg,
            goalWeightKg: draft.goalWeightKg,
            estimatedBodyFatPercentage: draft.estimatedBodyFatPercentage,
            activityLevel: draft.activityLevel,
            trainingFrequencyPerWeek: draft.trainingFrequencyPerWeek,
            averageSteps: draft.averageSteps,
            dietPreference: draft.dietPreference,
            unitSystem: draft.unitSystem,
            targets: draft.targets,
            createdAt: now,
            updatedAt: now,
            lastPlanUpdateReason: .onboarding
        )

        let entity = UserProfileEntity(model: profile)
        try store.insert(entity)
        return entity.toModel()
    }

    /// Binds the current on-device profile to a signed-in Firebase account after successful cloud resolution.
    func assignOwnerUID(_ uid: String) throws -> UserProfile {
        guard let entity = try latestProfileEntity() else {
            throw ServiceError.missingUserProfile
        }
        entity.ownerUID = uid
        entity.updatedAt = dateProvider.now
        try save()
        return entity.toModel()
    }

    // MARK: Update

    func updateProfile(_ update: UserProfileUpdate) throws -> UserProfile {
        guard let entity = try latestProfileEntity() else {
            throw ServiceError.missingUserProfile
        }

        if let name = update.name { entity.name = name }
        if let birthDate = update.birthDate {
            entity.birthDate = birthDate
            entity.age = BirthDateAgeResolver.resolvedAge(
                birthDate: birthDate,
                legacyAge: entity.age,
                referenceDate: dateProvider.now
            )
        }
        if let age = update.age {
            guard age > 0 else { throw ServiceError.invalidInput("Age must be greater than zero.") }
            entity.age = age
        }
        if let sex = update.sex { entity.sexRawValue = sex.rawValue }
        if let heightCm = update.heightCm {
            guard heightCm > 0 else { throw ServiceError.invalidInput("Height must be greater than zero.") }
            entity.heightCm = heightCm
        }
        if let currentWeightKg = update.currentWeightKg {
            guard currentWeightKg > 0 else { throw ServiceError.invalidInput("Weight must be greater than zero.") }
            entity.currentWeightKg = currentWeightKg
        }
        if let goalWeightKg = update.goalWeightKg {
            guard goalWeightKg > 0 else { throw ServiceError.invalidInput("Goal weight must be greater than zero.") }
            entity.goalWeightKg = goalWeightKg
        }
        if let bodyFat = update.estimatedBodyFatPercentage { entity.estimatedBodyFatPercentage = bodyFat }
        if let activityLevel = update.activityLevel { entity.activityLevelRawValue = activityLevel.rawValue }
        if let trainingFrequency = update.trainingFrequencyPerWeek {
            entity.trainingFrequencyPerWeek = max(trainingFrequency, 0)
        }
        if let averageSteps = update.averageSteps { entity.averageSteps = max(averageSteps, 0) }
        if let dietPreference = update.dietPreference { entity.dietPreference = dietPreference }
        if let unitSystem = update.unitSystem { entity.unitSystemRawValue = unitSystem.rawValue }
        if let targets = update.targets { apply(targets: targets, to: entity) }
        if let reason = update.lastPlanUpdateReason {
            entity.lastPlanUpdateReasonRawValue = reason.rawValue
        }

        entity.updatedAt = dateProvider.now
        try save()
        return entity.toModel()
    }

    func updateTargets(_ targets: UserTargets) throws -> UserProfile {
        guard let entity = try latestProfileEntity() else {
            throw ServiceError.missingUserProfile
        }
        apply(targets: targets, to: entity)
        entity.updatedAt = dateProvider.now
        try save()
        return entity.toModel()
    }

    // MARK: Helpers

    /// MVP policy: if multiple profiles exist, the most recently updated one is
    /// treated as the current profile.
    private func latestProfileEntity() throws -> UserProfileEntity? {
        var descriptor = FetchDescriptor<UserProfileEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func apply(targets: UserTargets, to entity: UserProfileEntity) {
        entity.calorieTarget = targets.calorieTarget
        entity.proteinTarget = targets.proteinTarget
        entity.carbTarget = targets.carbTarget
        entity.fatTarget = targets.fatTarget
        entity.waterTargetMl = targets.waterTargetMl
        entity.expectedWeeklyWeightLossKg = targets.expectedWeeklyWeightLossKg
        entity.aggressivenessRawValue = targets.aggressiveness.rawValue
    }

    private func validate(_ draft: UserProfileDraft) throws {
        let resolvedAge = BirthDateAgeResolver.resolvedAge(
            birthDate: draft.birthDate,
            legacyAge: draft.age
        )
        guard resolvedAge > 0 else { throw ServiceError.invalidInput("Age must be greater than zero.") }
        guard draft.heightCm > 0 else { throw ServiceError.invalidInput("Height must be greater than zero.") }
        guard draft.currentWeightKg > 0 else { throw ServiceError.invalidInput("Weight must be greater than zero.") }
        guard draft.goalWeightKg > 0 else { throw ServiceError.invalidInput("Goal weight must be greater than zero.") }
    }

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the user profile.")
        }
    }
}
