//
//  ProfileModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for the user's fitness plan strategy.
//

import Combine
import Foundation

@MainActor
final class ProfileModel: ObservableObject {

    @Published private(set) var viewState: ProfileViewState = .loading
    @Published var isShowingEditSheet = false
    @Published var isShowingSettingsSheet = false
    @Published var isShowingTargetRegenerationSheet = false
    @Published private(set) var generatedTargetPreview: CalorieTargetResult?
    @Published private(set) var formErrorMessage: String?
    @Published var editFormState: ProfileFormState?

    private let actionCenter: FitnessActionCenter
    private let userProfileService: UserProfileService
    private let targetService: TargetService

    init(
        actionCenter: FitnessActionCenter,
        userProfileService: UserProfileService,
        targetService: TargetService
    ) {
        self.actionCenter = actionCenter
        self.userProfileService = userProfileService
        self.targetService = targetService
    }

    // MARK: Loading

    func loadProfile() async {
        viewState = .loading
        await refresh()
    }

    func refresh() async {
        do {
            guard let profile = try userProfileService.getCurrentProfile() else {
                viewState = .empty
                return
            }
            viewState = .loaded(PlanStateBuilder.dashboardState(profile: profile))
        } catch {
            viewState = .error("Could not load your plan.")
        }
    }

    // MARK: Sheets

    func showEditPlan() {
        guard case .loaded(let state) = viewState else { return }
        formErrorMessage = nil
        editFormState = ProfileFormState(profile: state.profile)
        isShowingEditSheet = true
    }

    func showSettings() {
        guard case .loaded(let state) = viewState else { return }
        formErrorMessage = nil
        editFormState = ProfileFormState(profile: state.profile)
        isShowingSettingsSheet = true
    }

    func dismissEditPlan() {
        formErrorMessage = nil
        editFormState = nil
        isShowingEditSheet = false
    }

    func dismissSettings() {
        formErrorMessage = nil
        isShowingSettingsSheet = false
    }

    func dismissTargetRegeneration() {
        generatedTargetPreview = nil
        isShowingTargetRegenerationSheet = false
    }

    func clearError() {
        formErrorMessage = nil
    }

    // MARK: Mutations

    func createDefaultProfile() async {
        do {
            let formState = ProfileFormState.defaultDraftValues()
            let input = try formState.makeCalorieTargetInput()
            let result = targetService.generateInitialTargets(from: input)
            var draftForm = formState
            draftForm.applyGeneratedTargets(result.targets)
            let draft = try draftForm.makeDraft(targets: result.targets)
            _ = try userProfileService.createProfile(draft)
            await refresh()
            actionCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            viewState = .error(error.message)
        } catch ServiceError.invalidInput(let message) {
            viewState = .error(message)
        } catch {
            viewState = .error("Could not save your plan.")
        }
    }

    func savePlanFromWizard(_ formState: ProfileFormState) async {
        do {
            var state = formState
            let input = try state.makeCalorieTargetInput()
            let result = targetService.generateInitialTargets(from: input)
            state.applyGeneratedTargets(result.targets)
            let update = try state.makeUpdate()
            _ = try actionCenter.updatePlan(update)
            dismissEditPlan()
            dismissSettings()
            await refresh()
            actionCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
        } catch {
            formErrorMessage = "Could not save your plan."
        }
    }

    func saveSettings(_ formState: ProfileFormState) async {
        do {
            let update = try formState.makeUpdate()
            _ = try actionCenter.updatePlan(update)
            await refresh()
            actionCenter.notifyDataChanged()
            formErrorMessage = nil
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
        } catch {
            formErrorMessage = "Could not save settings."
        }
    }

    func previewRegeneratedTargets(from formState: ProfileFormState) async {
        do {
            let input = try formState.makeCalorieTargetInput()
            generatedTargetPreview = targetService.generateInitialTargets(from: input)
            isShowingTargetRegenerationSheet = true
            formErrorMessage = nil
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch {
            formErrorMessage = "Could not regenerate targets."
        }
    }

    func applyGeneratedTargets() async {
        guard let preview = generatedTargetPreview else { return }
        do {
            _ = try actionCenter.applyPlanTargets(preview.targets)
            dismissTargetRegeneration()
            if isShowingEditSheet, var formState = editFormState {
                formState.applyGeneratedTargets(preview.targets)
                editFormState = formState
            }
            await refresh()
            actionCenter.notifyDataChanged()
        } catch {
            formErrorMessage = "Could not regenerate targets."
        }
    }
}
