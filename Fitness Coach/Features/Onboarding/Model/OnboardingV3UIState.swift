//
//  OnboardingV3UIState.swift
//  Fitness Coach
//
//  Forma — Tap-first onboarding v3 UI helpers and ephemeral session state.
//

import Foundation

// MARK: - Ephemeral session (not persisted in OnboardingDraft)

/// Transient v3 UI flags that should not change draft schema.
struct OnboardingV3UISessionState: Equatable, Sendable {
    /// User opened the custom pace screen from the pace step.
    var showsCustomPace: Bool = false
    /// User opened optional name / free-text diet details.
    var showsPreferenceDetails: Bool = false
}

// MARK: - Daily steps bands

/// Broad movement bands replacing numeric step entry on the training rhythm screen.
enum OnboardingDailyStepsBand: String, CaseIterable, Equatable, Identifiable, Sendable, Codable {
    case low
    case moderate
    case high
    case notSure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .notSure:
            return "Not sure"
        }
    }

    var subtitle: String {
        switch self {
        case .low:
            return "Mostly seated · under 5k steps"
        case .moderate:
            return "Regular walking · about 5–9k steps"
        case .high:
            return "Very active days · 9k+ steps"
        case .notSure:
            return "We'll start with a sensible default"
        }
    }

    /// Representative step count stored in `OnboardingFormState.averageStepsText`.
    var representativeSteps: Int {
        switch self {
        case .low:
            return 3_000
        case .moderate:
            return 6_000
        case .high:
            return 9_000
        case .notSure:
            return 5_000
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

        switch steps {
        case ..<4_500:
            return .low
        case 4_500..<7_500:
            return .moderate
        default:
            return .high
        }
    }
}

// MARK: - Training days chips

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
        case .fivePlus:
            return "5+"
        default:
            return "\(rawValue)"
        }
    }

    var storedTrainingDays: Int {
        switch self {
        case .fivePlus:
            return 5
        default:
            return rawValue
        }
    }

    static func chip(for trainingDays: Int) -> OnboardingTrainingDaysChip {
        switch trainingDays {
        case 0:
            return .zero
        case 1:
            return .one
        case 2:
            return .two
        case 3:
            return .three
        case 4:
            return .four
        default:
            return .fivePlus
        }
    }
}

// MARK: - Legacy alias (previews / component gallery)

typealias OnboardingTrainingDaysOption = OnboardingTrainingDaysChip

// MARK: - Optional diet chips

enum OnboardingDietPreferenceChip: String, CaseIterable, Equatable, Identifiable, Sendable {
    case highProtein
    case simpleMeals
    case noPork
    case halal
    case vegetarian
    case lowDairy
    case busySchedule
    case budgetFriendly
    case addLater

  /// Display order on the preferences screen.
    static let foodPreferenceOptions: [OnboardingDietPreferenceChip] = [
        .highProtein, .simpleMeals, .noPork, .halal, .vegetarian,
        .lowDairy, .busySchedule, .budgetFriendly, .addLater
    ]

    static let multiSelectOptions: [OnboardingDietPreferenceChip] =
        foodPreferenceOptions.filter { $0 != .addLater }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highProtein:
            return "High protein"
        case .simpleMeals:
            return "Simple meals"
        case .noPork:
            return "No pork"
        case .halal:
            return "Halal"
        case .vegetarian:
            return "Vegetarian"
        case .lowDairy:
            return "Low dairy"
        case .busySchedule:
            return "Busy schedule"
        case .budgetFriendly:
            return "Budget-friendly"
        case .addLater:
            return "I'll add later"
        }
    }

    /// Stored representation in `dietPreference` (comma-separated phrases).
    var storedPhrase: String {
        switch self {
        case .highProtein:
            return "High protein"
        case .simpleMeals:
            return "Simple meals"
        case .noPork:
            return "No pork"
        case .halal:
            return "Halal"
        case .vegetarian:
            return "Vegetarian"
        case .lowDairy:
            return "Low dairy"
        case .busySchedule:
            return "Busy schedule"
        case .budgetFriendly:
            return "Budget-friendly"
        case .addLater:
            return "I'll add later"
        }
    }

    var isExclusiveDeferral: Bool {
        self == .addLater
    }

    static func selectedChips(from dietPreference: String) -> Set<OnboardingDietPreferenceChip> {
        let normalized = dietPreference
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        var selected = Set<OnboardingDietPreferenceChip>()
        for chip in allCases {
            if normalized.contains(chip.storedPhrase.lowercased()) {
                selected.insert(chip)
            }
        }
        return selected
    }
}

// MARK: - Picker defaults

enum OnboardingV3PickerDefaults {
    static let ageRange = 16...90
    static let defaultAge = 28

    static let metricHeightCmRange = 120.0...220.0
    static let defaultHeightCm = 170.0

    static let metricWeightKgRange = 35.0...200.0
    static let defaultWeightKg = 70.0

    static let imperialHeightInchesRange = 47.0...87.0
    static let imperialWeightLbRange = 80.0...440.0
}

// MARK: - FormState bridges

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

    mutating func ensureTrainingRhythmValues() {
        let trimmedDays = trainingFrequencyPerWeekText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSteps = averageStepsText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDays.isEmpty || trimmedSteps.isEmpty {
            applyTrainingRhythmDefaultsForCurrentActivity()
        }
    }

    var selectedDietChips: Set<OnboardingDietPreferenceChip> {
        OnboardingDietPreferenceChip.selectedChips(from: dietPreference)
    }

    mutating func toggleDietChip(_ chip: OnboardingDietPreferenceChip) {
        if chip.isExclusiveDeferral {
            if selectedDietChips.contains(.addLater) {
                dietPreference = ""
            } else {
                dietPreference = OnboardingDietPreferenceChip.addLater.storedPhrase
            }
            return
        }

        var selected = selectedDietChips
        selected.remove(.addLater)

        if selected.contains(chip) {
            selected.remove(chip)
        } else {
            selected.insert(chip)
        }

        dietPreference = Self.dietPreferenceText(
            from: selected,
            customText: customDietPreferenceText
        )
    }

    var customDietPreferenceText: String {
        get {
            let chipPhrases = Set(
                OnboardingDietPreferenceChip.allCases.map { $0.storedPhrase.lowercased() }
            )
            return dietPreference
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !chipPhrases.contains($0.lowercased()) }
                .joined(separator: ", ")
        }
        set {
            var selected = selectedDietChips
            selected.remove(.addLater)
            dietPreference = Self.dietPreferenceText(from: selected, customText: newValue)
        }
    }

    private static func dietPreferenceText(
        from chips: Set<OnboardingDietPreferenceChip>,
        customText: String
    ) -> String {
        var parts = OnboardingDietPreferenceChip.multiSelectOptions
            .filter { chips.contains($0) }
            .map(\.storedPhrase)

        let trimmedCustom = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustom.isEmpty {
            parts.append(trimmedCustom)
        }

        return parts.joined(separator: ", ")
    }

    private static func dietPreferenceText(from chips: Set<OnboardingDietPreferenceChip>) -> String {
        dietPreferenceText(from: chips, customText: "")
    }

    mutating func applyTrainingRhythmDefaultsForCurrentActivity() {
        let defaults = ActivityTrainingDefaultsResolver().defaults(for: activityLevel)
        trainingFrequencyPerWeekText = String(defaults.trainingDaysPerWeek)
        averageStepsText = String(defaults.averageStepsPerDay)
        lastAutoTrainingDefaults = defaults
        hasManuallyEditedTrainingDays = false
        hasManuallyEditedAverageSteps = false
    }
}
