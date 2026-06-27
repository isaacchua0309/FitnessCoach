//
//  OnboardingKeyboardMonitor.swift
//  Fitness Coach
//
//  FitPilot AI — Tracks keyboard visibility for onboarding layout.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class OnboardingKeyboardMonitor: ObservableObject {
    @Published private(set) var isVisible = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        let center = NotificationCenter.default

        center.publisher(for: UIResponder.keyboardWillShowNotification)
            .merge(with: center.publisher(for: UIResponder.keyboardWillChangeFrameNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.updateVisibility(from: notification, showing: true)
            }
            .store(in: &cancellables)

        center.publisher(for: UIResponder.keyboardWillHideNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.isVisible = false
                }
            }
            .store(in: &cancellables)
    }

    private func updateVisibility(from notification: Notification, showing: Bool) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let isKeyboardOnScreen = frame.height > 50 && frame.minY < frame.maxY
        guard isKeyboardOnScreen else {
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = false
            }
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = showing
        }
    }
}

enum OnboardingKeyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
