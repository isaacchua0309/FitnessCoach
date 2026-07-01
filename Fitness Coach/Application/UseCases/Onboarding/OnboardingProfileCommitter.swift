//
//  OnboardingProfileCommitter.swift
//  Fitness Coach
//
//  Commits onboarding profile drafts through FitnessActionCenter.
//

import Foundation

enum OnboardingProfileCommitError: Error, Equatable {
    case missingGeneratedPlan
    case missingBirthDate
    case form(OnboardingFormError)
    case invalidInput(String)
    case unknown
}

@MainActor
struct OnboardingProfileCommitter {

    let actionCenter: FitnessActionCenter
    let userProfileReader: any UserProfileReading

    func commitIfNeeded(
        formState: OnboardingFormState,
        generatedPlan: CalorieTargetResult?
    ) throws -> Bool {
        guard let generatedPlan else {
            throw OnboardingProfileCommitError.missingGeneratedPlan
        }

        if try userProfileReader.getCurrentProfile() != nil {
            return false
        }

        var mutableForm = formState
        mutableForm.applyTrainingRhythmDefaultsForCurrentActivity()
        let draft = try mutableForm.makeUserProfileDraft(targets: generatedPlan.targets)
        if draft.birthDate == nil {
            throw OnboardingProfileCommitError.missingBirthDate
        }
        _ = try actionCenter.createProfile(draft)
        return true
    }

    func userFacingMessage(for error: Error) -> String {
        switch error {
        case OnboardingProfileCommitError.missingGeneratedPlan:
            return FormaProductCopy.Error.generatePlan
        case OnboardingProfileCommitError.missingBirthDate:
            return FormaProductCopy.Onboarding.Flow.Birthday.birthDateRequiredMessage
        case OnboardingProfileCommitError.form(let formError):
            return formError.message
        case OnboardingProfileCommitError.invalidInput(let message):
            return message
        case let error as OnboardingFormError:
            return error.message
        case ServiceError.invalidInput(let message):
            return message
        default:
            return FormaProductCopy.Error.createProfile
        }
    }
}
