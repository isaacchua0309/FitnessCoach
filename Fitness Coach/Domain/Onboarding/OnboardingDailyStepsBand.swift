//
//  OnboardingDailyStepsBand.swift
//  Fitness Coach
//
//  Forma — Broad movement bands for training rhythm defaults.
//

import Foundation

enum OnboardingDailyStepsBand: String, CaseIterable, Equatable, Identifiable, Sendable, Codable {
    case low
    case moderate
    case high
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .notSure: return "Not sure"
        }
    }

    var subtitle: String {
        switch self {
        case .low: return "Mostly seated · under 5k steps"
        case .moderate: return "Regular walking · about 5–9k steps"
        case .high: return "Very active days · 9k+ steps"
        case .notSure: return "We'll start with a sensible default"
        }
    }

    var representativeSteps: Int {
        switch self {
        case .low: return 3_000
        case .moderate: return 6_000
        case .high: return 9_000
        case .notSure: return 5_000
        }
    }

    static func infer(from averageStepsText: String) -> OnboardingDailyStepsBand? {
        guard let steps = Int(averageStepsText.trimmingCharacters(in: .whitespacesAndNewlines)),
              steps >= 0 else {
            return nil
        }
        return infer(fromSteps: steps)
    }

    static func infer(fromSteps steps: Int) -> OnboardingDailyStepsBand {
        if steps == OnboardingDailyStepsBand.notSure.representativeSteps {
            return .notSure
        }
        if steps < 5_000 { return .low }
        if steps < 9_000 { return .moderate }
        return .high
    }
}

enum OnboardingTrainingDaysChip: Int, CaseIterable, Equatable, Identifiable, Sendable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    case four = 4
    case fivePlus = 5

    var id: Int { rawValue }

    var displayLabel: String {
        switch self {
        case .fivePlus: return "5+"
        default: return "\(rawValue)"
        }
    }

    var storedTrainingDays: Int {
        switch self {
        case .fivePlus: return 5
        default: return rawValue
        }
    }

    static func chip(for trainingDays: Int) -> OnboardingTrainingDaysChip {
        switch trainingDays {
        case 0: return .zero
        case 1: return .one
        case 2: return .two
        case 3: return .three
        case 4: return .four
        default: return .fivePlus
        }
    }
}

extension OnboardingFormState {
    var dailyStepsBand: OnboardingDailyStepsBand {
        get {
            OnboardingDailyStepsBand.infer(from: averageStepsText) ?? .moderate
        }
        set {
            averageStepsText = String(newValue.representativeSteps)
            hasManuallyEditedAverageSteps = true
        }
    }

    var trainingDaysSelection: Int {
        get {
            parsedTrainingDays ?? ActivityTrainingDefaultsResolver()
                .defaults(for: activityLevel)
                .trainingDaysPerWeek
        }
        set {
            setTrainingFrequencyPerWeekText(String(max(0, min(7, newValue))))
        }
    }

    var trainingDaysChip: OnboardingTrainingDaysChip {
        get {
            OnboardingTrainingDaysChip.chip(for: trainingDaysSelection)
        }
        set {
            trainingDaysSelection = newValue.storedTrainingDays
        }
    }
}
