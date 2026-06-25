//
//  OnboardingModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for first-run onboarding.
//
//  OnboardingModel calls services only. It does not access SwiftData directly,
//  call AI, or coordinate with other feature models.
//

import Combine
import Foundation

@MainActor
final class OnboardingModel: ObservableObject {

    @Published private(set) var currentStep: OnboardingStep = .welcome
    @Published var formState = OnboardingFormState()
    @Published private(set) var viewState: OnboardingViewState = .editing
    @Published private(set) var generatedPlan: CalorieTargetResult?
    @Published private(set) var errorMessage: String?

    private let userProfileService: UserProfileService
    private let targetService: TargetService
    private let onCompletion: () -> Void

    init(
        userProfileService: UserProfileService,
        targetService: TargetService,
        onCompletion: @escaping () -> Void
    ) {
        self.userProfileService = userProfileService
        self.targetService = targetService
        self.onCompletion = onCompletion
    }

    // MARK: Navigation

    func goNext() {
        clearError()

        switch currentStep {
        case .welcome:
            advance(to: .body)
        case .body:
            guard validateCurrentStep() else { return }
            advance(to: .goal)
        case .goal:
            guard validateCurrentStep() else { return }
            advance(to: .activity)
        case .activity:
            guard validateCurrentStep() else { return }
            advance(to: .preferences)
        case .preferences:
            generatePlanPreview()
        case .planPreview:
            break
        }
    }

    func goBack() {
        clearError()
        guard let previous = currentStep.previous else { return }
        if previous != .planPreview {
            generatedPlan = nil
        }
        currentStep = previous
        viewState = .editing
    }

    func clearError() {
        errorMessage = nil
        if case .error = viewState {
            viewState = .editing
        }
    }

    // MARK: Plan Generation

    func generatePlanPreview() {
        viewState = .generatingPlan
        errorMessage = nil

        do {
            try formState.validate(step: .preferences)
            let input = try formState.makeCalorieTargetInput()
            generatedPlan = targetService.generateInitialTargets(from: input)
            currentStep = .planPreview
            viewState = .editing
        } catch let error as OnboardingFormError {
            errorMessage = error.message
            viewState = .editing
        } catch {
            errorMessage = "Could not generate your plan. Please check your inputs."
            viewState = .editing
        }
    }

    // MARK: Completion

    func completeOnboarding() {
        guard let generatedPlan else {
            errorMessage = "Could not generate your plan. Please check your inputs."
            return
        }

        viewState = .completing
        errorMessage = nil

        do {
            if try userProfileService.getCurrentProfile() != nil {
                errorMessage = "A profile already exists."
                viewState = .editing
                return
            }

            let draft = try formState.makeUserProfileDraft(targets: generatedPlan.targets)
            _ = try userProfileService.createProfile(draft)
            onCompletion()
        } catch let error as OnboardingFormError {
            errorMessage = error.message
            viewState = .editing
        } catch ServiceError.invalidInput(let message) {
            errorMessage = message
            viewState = .editing
        } catch {
            errorMessage = "Could not create your profile. Please try again."
            viewState = .editing
        }
    }

    // MARK: Helpers

    private func validateCurrentStep() -> Bool {
        do {
            try formState.validate(step: currentStep)
            return true
        } catch let error as OnboardingFormError {
            errorMessage = error.message
            return false
        } catch {
            errorMessage = "Please check your inputs."
            return false
        }
    }

    private func advance(to step: OnboardingStep) {
        currentStep = step
        viewState = .editing
    }
}
