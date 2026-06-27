//
//  OnboardingFieldNavigator.swift
//  Fitness Coach
//
//  FitPilot AI — Coordinates field focus, scroll, and keyboard accessory actions.
//

import Combine
import SwiftUI

@MainActor
final class OnboardingFieldNavigator: ObservableObject {
    @Published private(set) var scrollToID: AnyHashable?
    @Published private(set) var canFocusPrevious = false
    @Published private(set) var canFocusNext = false
    @Published private(set) var isFieldFocused = false

    private var focusPreviousAction: (() -> Void)?
    private var focusNextAction: (() -> Void)?
    private var dismissFocusAction: (() -> Void)?

    func scrollTo(_ id: AnyHashable?) {
        guard let id else { return }
        scrollToID = id
    }

    func updateFocus(
        fieldID: AnyHashable?,
        canPrevious: Bool,
        canNext: Bool,
        onPrevious: (() -> Void)?,
        onNext: (() -> Void)?,
        onDismiss: (() -> Void)?
    ) {
        isFieldFocused = fieldID != nil
        canFocusPrevious = canPrevious
        canFocusNext = canNext
        focusPreviousAction = onPrevious
        focusNextAction = onNext
        dismissFocusAction = onDismiss

        if let fieldID {
            scrollTo(fieldID)
        }
    }

    func clearFocus() {
        isFieldFocused = false
        canFocusPrevious = false
        canFocusNext = false
        focusPreviousAction = nil
        focusNextAction = nil
        dismissFocusAction = nil
    }

    func focusPrevious() {
        focusPreviousAction?()
    }

    func focusNext() {
        focusNextAction?()
    }

    func dismissFocus() {
        dismissFocusAction?()
        OnboardingKeyboard.dismiss()
        clearFocus()
    }
}

private struct OnboardingFieldNavigatorKey: EnvironmentKey {
    static let defaultValue: OnboardingFieldNavigator? = nil
}

extension EnvironmentValues {
    var onboardingFieldNavigator: OnboardingFieldNavigator? {
        get { self[OnboardingFieldNavigatorKey.self] }
        set { self[OnboardingFieldNavigatorKey.self] = newValue }
    }
}
