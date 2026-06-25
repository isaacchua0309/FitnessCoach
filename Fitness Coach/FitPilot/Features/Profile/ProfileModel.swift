//
//  ProfileModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for profile and settings.
//
//  ProfileModel calls services only. It does not access SwiftData directly,
//  call AI, or coordinate with other feature models.
//

import Combine
import Foundation

@MainActor
final class ProfileModel: ObservableObject {

    @Published private(set) var viewState: ProfileViewState = .loading
    @Published var isShowingEditSheet = false
    @Published var isShowingTargetRegenerationSheet = false
    @Published private(set) var generatedTargetPreview: CalorieTargetResult?
    @Published private(set) var formErrorMessage: String?
    @Published var editFormState: ProfileFormState?

    private let userProfileService: UserProfileService
    private let targetService: TargetService
    private let refreshCenter: AppRefreshCenter

    init(
        userProfileService: UserProfileService,
        targetService: TargetService,
        refreshCenter: AppRefreshCenter
    ) {
        self.userProfileService = userProfileService
        self.targetService = targetService
        self.refreshCenter = refreshCenter
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
            viewState = .loaded(ProfileFormatter.dashboardState(from: profile))
        } catch {
            viewState = .error("Could not load your profile.")
        }
    }

    // MARK: Sheets

    func showEditProfile() {
        guard case .loaded(let state) = viewState else { return }
        formErrorMessage = nil
        editFormState = ProfileFormState(profile: state.profile)
        isShowingEditSheet = true
    }

    func dismissEditProfile() {
        formErrorMessage = nil
        editFormState = nil
        isShowingEditSheet = false
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
            let draft = try formState.makeDraft(targets: result.targets)
            _ = try userProfileService.createProfile(draft)
            await refresh()
            refreshCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            viewState = .error(error.message)
        } catch ServiceError.invalidInput(let message) {
            viewState = .error(message)
        } catch {
            viewState = .error("Could not save your profile.")
        }
    }

    func saveProfile(_ formState: ProfileFormState) async {
        do {
            let update = try formState.makeUpdate()
            _ = try userProfileService.updateProfile(update)
            dismissEditProfile()
            await refresh()
            refreshCenter.notifyDataChanged()
        } catch let error as ProfileFormError {
            formErrorMessage = error.message
        } catch ServiceError.invalidInput(let message) {
            formErrorMessage = message
        } catch {
            formErrorMessage = "Could not save your profile."
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
            _ = try targetService.updateCurrentTargets(preview.targets)
            dismissTargetRegeneration()
            if isShowingEditSheet, var formState = editFormState {
                formState.calorieTargetText = "\(preview.targets.calorieTarget)"
                formState.proteinTargetText = formatDouble(preview.targets.proteinTarget)
                formState.carbTargetText = formatDouble(preview.targets.carbTarget)
                formState.fatTargetText = formatDouble(preview.targets.fatTarget)
                formState.waterTargetMlText = "\(preview.targets.waterTargetMl)"
                formState.expectedWeeklyWeightLossKgText = preview.targets.expectedWeeklyWeightLossKg.map(formatDouble) ?? ""
                formState.aggressiveness = preview.targets.aggressiveness
                editFormState = formState
            }
            await refresh()
            refreshCenter.notifyDataChanged()
        } catch {
            formErrorMessage = "Could not regenerate targets."
        }
    }

    func updateTargets(_ targets: UserTargets) async {
        do {
            _ = try targetService.updateCurrentTargets(targets)
            await refresh()
            refreshCenter.notifyDataChanged()
        } catch {
            formErrorMessage = "Could not save your profile."
        }
    }

    // MARK: Helpers

    private func formatDouble(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"
    }
}
