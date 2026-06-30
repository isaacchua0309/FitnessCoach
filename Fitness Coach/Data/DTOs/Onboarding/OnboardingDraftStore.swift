//
//  OnboardingDraftStore.swift
//  Fitness Coach
//
//  Forma — UserDefaults persistence for in-progress onboarding drafts.
//

import Foundation

struct OnboardingDraftStore: Sendable {

    static let userDefaultsKey = "forma.onboarding.draft"
    static let supportedDraftVersion = OnboardingDraft.currentDraftVersion

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func saveDraft(_ draft: OnboardingDraft) {
        guard draft.draftVersion == Self.supportedDraftVersion,
              OnboardingStep(rawValue: draft.currentStepRawValue) != nil,
              let data = try? encoder.encode(draft) else {
            return
        }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func loadDraft() -> OnboardingDraft? {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return nil
        }

        if let draft = try? decoder.decode(OnboardingDraft.self, from: data),
           draft.draftVersion == Self.supportedDraftVersion,
           OnboardingStep(rawValue: draft.currentStepRawValue) != nil {
            return draft
        }

        if let legacy = try? decoder.decode(OnboardingDraftV1.self, from: data),
           legacy.draftVersion == OnboardingDraftMigration.legacyDraftVersion {
            let migrated = OnboardingDraftMigration.upgrade(from: legacy)
            saveDraft(migrated)
            return migrated
        }

        clearDraft()
        return nil
    }

    func clearDraft() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }

    var hasDraft: Bool {
        loadDraft() != nil
    }
}
