//
//  OnboardingGenerationDelayProviding.swift
//  Fitness Coach
//
//  Forma — Injectable delay for onboarding plan generation minimum display time.
//

import Foundation

protocol OnboardingGenerationDelayProviding: Sendable {
    func delay(for duration: TimeInterval) async
}

struct SystemOnboardingGenerationDelayProvider: OnboardingGenerationDelayProviding, Sendable {
    func delay(for duration: TimeInterval) async {
        guard duration > 0 else { return }
        let nanoseconds = UInt64(duration * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

struct ImmediateOnboardingGenerationDelayProvider: OnboardingGenerationDelayProviding, Sendable {
    func delay(for duration: TimeInterval) async {}
}
