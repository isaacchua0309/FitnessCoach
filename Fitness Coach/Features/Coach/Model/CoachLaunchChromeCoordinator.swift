//
//  CoachLaunchChromeCoordinator.swift
//  Fitness Coach
//
//  Forma — Ephemeral launch presentation and composer chrome orchestration.
//

import Foundation

@MainActor
protocol CoachLaunchChromeDelegate: AnyObject {
    var launchChrome: CoachLaunchChromeState { get }
    func applyLaunchChrome(_ state: CoachLaunchChromeState)
}

@MainActor
final class CoachLaunchChromeCoordinator {

    private weak var delegate: CoachLaunchChromeDelegate?
    private let inputCoordinator: CoachInputCoordinator

    init(inputCoordinator: CoachInputCoordinator) {
        self.inputCoordinator = inputCoordinator
    }

    func configure(delegate: CoachLaunchChromeDelegate) {
        self.delegate = delegate
    }

    func launch(with intent: CoachLaunchIntent) {
        abandonLaunchSession()

        switch intent {
        case .normal:
            return
        case .prefill(let text):
            inputCoordinator.setText(text)
            requestComposerFocus()
        case .logMeal, .logWater:
            guard let presentation = CoachLaunchPresentationBuilder.presentation(for: intent) else { return }
            inputCoordinator.clearComposerContent()
            apply(
                CoachModelStateReducer.applyLaunchPresentation(
                    chrome,
                    presentation: presentation,
                    requestsCameraPresentation: false
                )
            )
        case .analyzePhotoMeal(let openCameraImmediately):
            guard let presentation = CoachLaunchPresentationBuilder.presentation(for: intent) else { return }
            inputCoordinator.clearComposerContent()
            apply(
                CoachModelStateReducer.applyLaunchPresentation(
                    chrome,
                    presentation: presentation,
                    requestsCameraPresentation: openCameraImmediately
                )
            )
        }
    }

    func consumeLaunchPresentation() {
        apply(CoachModelStateReducer.consumeLaunchPresentation(chrome))
    }

    func consumeComposerFocusRequest() {
        apply(CoachModelStateReducer.consumeComposerFocusRequest(chrome))
    }

    func consumeCameraPresentationRequest() {
        apply(CoachModelStateReducer.clearCameraPresentationRequest(chrome))
    }

    func handleCoachBecameInactive(hasEmptyComposer: Bool) {
        apply(
            CoachModelStateReducer.clearCameraPresentationRequest(
                CoachModelStateReducer.consumeLaunchPresentation(chrome)
            )
        )
        if hasEmptyComposer {
            clearComposerLaunchChrome()
        }
    }

    func noteComposerInteraction() {
        consumeLaunchPresentation()
    }

    func requestComposerFocus() {
        apply(CoachModelStateReducer.requestComposerFocus(chrome))
    }

    func clearComposerLaunchChrome() {
        apply(CoachModelStateReducer.clearComposerLaunchChrome(chrome))
    }

    private func abandonLaunchSession() {
        apply(CoachModelStateReducer.abandonLaunchSession(chrome))
    }

    private var chrome: CoachLaunchChromeState {
        delegate?.launchChrome ?? .initial
    }

    private func apply(_ state: CoachLaunchChromeState) {
        delegate?.applyLaunchChrome(state)
    }
}
