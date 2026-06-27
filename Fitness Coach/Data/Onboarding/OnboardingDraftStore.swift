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
        guard let data = try? encoder.encode(draft) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func loadDraft() -> OnboardingDraft? {
        guard let data = userDefaults.data(forKey: Self.userDefaultsKey) else {
            return nil
        }

        do {
            let draft = try decoder.decode(OnboardingDraft.self, from: data)
            guard isSupported(draft) else {
                clearDraft()
                return nil
            }
            return draft
        } catch {
            clearDraft()
            return nil
        }
    }

    func clearDraft() {
        userDefaults.removeObject(forKey: Self.userDefaultsKey)
    }

    var hasDraft: Bool {
        loadDraft() != nil
    }

    private func isSupported(_ draft: OnboardingDraft) -> Bool {
        draft.draftVersion == Self.supportedDraftVersion
            && OnboardingStep.fromPersistedRawValue(draft.currentStepRawValue) != nil
    }
}
