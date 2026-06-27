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
    @Published private(set) var keyboardHeight: CGFloat = 0

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
                    self?.keyboardHeight = 0
                }
            }
            .store(in: &cancellables)
    }

    private func updateVisibility(from notification: Notification, showing: Bool) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let isKeyboardOnScreen = frame.height > 50 && frame.minY < UIScreen.main.bounds.height
        guard isKeyboardOnScreen else {
            withAnimation(.easeOut(duration: 0.25)) {
                isVisible = false
                keyboardHeight = 0
            }
            return
        }

        let overlap = max(0, UIScreen.main.bounds.height - frame.minY)
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = showing
            keyboardHeight = overlap
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
