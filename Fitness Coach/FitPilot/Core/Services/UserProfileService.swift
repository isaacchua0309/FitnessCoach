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

    init(store: SwiftDataStore, dateProvider: DateProviding = SystemDateProvider()) {
        self.store = store
        self.dateProvider = dateProvider
    }

    // MARK: Read

    func getCurrentProfile() throws -> UserProfile? {
        try latestProfileEntity()?.toModel()
    }

    // MARK: Restore

    func restoreProfile(from document: CloudUserProfileDocument) throws -> UserProfile {
        if try getCurrentProfile() != nil {
            throw ServiceError.invalidInput("A profile already exists on this device.")
        }

        let profile = document.makeUserProfile()
        let entity = UserProfileEntity(model: profile)
        try store.insert(entity)
        return entity.toModel()
    }

    // MARK: Create

    func createProfile(_ draft: UserProfileDraft) throws -> UserProfile {
        try validate(draft)

        let now = dateProvider.now
        let profile = UserProfile(
            id: UUID(),
            name: draft.name,
            age: draft.age,
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
            updatedAt: now
        )

        let entity = UserProfileEntity(model: profile)
        try store.insert(entity)
        return entity.toModel()
    }

    // MARK: Update

    func updateProfile(_ update: UserProfileUpdate) throws -> UserProfile {
        guard let entity = try latestProfileEntity() else {
            throw ServiceError.missingUserProfile
        }

        if let name = update.name { entity.name = name }
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
        guard draft.age > 0 else { throw ServiceError.invalidInput("Age must be greater than zero.") }
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
