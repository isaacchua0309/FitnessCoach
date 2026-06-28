//
//  OnboardingModelTestSupport.swift
//  Fitness CoachTests
//
//  Shared helpers for canonical onboarding model navigation in tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
enum OnboardingModelTestSupport {

    static let referenceDate = FormaCalculationTestFixtures.referenceDate

    static func seedCanonicalForm(
        _ formState: inout OnboardingFormState,
        birthDate: Date? = nil
    ) {
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &formState)
        if let birthDate {
            formState.birthDate = birthDate
            formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        } else {
            OnboardingBirthdayValues.applyDefaultsIfNeeded(to: &formState)
        }
        formState.sex = .female
        OnboardingActivityLevelValues.select(.moderatelyActive, in: &formState)
        formState.selectPaceChoice(.moderate)
    }

    static func advanceTo(
        _ target: OnboardingStep,
        model: OnboardingModel,
        seedForm: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        if seedForm {
            seedCanonicalForm(&model.formState)
        }

        var iterations = 0
        while model.currentStep != target {
            iterations += 1
            XCTAssertLessThanOrEqual(iterations, 30, "Onboarding navigation loop", file: file, line: line)

            switch model.currentStep {
            case .appleHealth:
                model.goNext()
                await waitToLeave(.appleHealth, model: model, file: file, line: line)
            case .generatingPlan:
                await model.flushPendingGenerationForTesting()
            default:
                model.goNext()
            }
        }
    }

    static func waitToLeave(
        _ step: OnboardingStep,
        model: OnboardingModel,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<300 {
            if model.currentStep != step { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting to leave \(step)", file: file, line: line)
    }
}
