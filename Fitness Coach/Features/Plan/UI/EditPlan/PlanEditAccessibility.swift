//
//  PlanEditAccessibility.swift
//  Fitness Coach
//
//  Forma — VoiceOver helpers for the Edit Plan wizard.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum PlanEditSelectionAccessibilityPolicy {

    /// Selected cards render a trailing checkmark (hidden from VoiceOver; value carries state).
    static let includesCheckmarkForSelectedState = true

    /// Selected cards expose `.isSelected` for VoiceOver.
    static let includesSelectedTraitForSelectedState = true

    /// Selection state is exposed via `accessibilityValue`, not only color.
    static let includesSelectionInAccessibilityValue = true

    /// Selected cards use a thicker border stroke in addition to fill tint.
    static let includesBorderForSelectedState = true

    /// Selectable cards meet the 44pt minimum touch target.
    static let meetsMinimumTouchTarget = true
}

enum PlanEditAccessibility {

    static let minimumTouchTarget: CGFloat = FormaTokens.Layout.minTouchTarget

    static func selectionValue(isSelected: Bool) -> String {
        isSelected
            ? FormaProductCopy.PlanEditAccessibility.selected
            : FormaProductCopy.PlanEditAccessibility.notSelected
    }

    static func progressValue(currentStep: Int, stepCount: Int) -> String {
        FormaProductCopy.PlanEditAccessibility.progressValue(
            currentStep: currentStep,
            stepCount: stepCount
        )
    }

    static func announce(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
#if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: trimmed)
#endif
    }
}

// MARK: - Announcement modifier

private struct PlanEditAccessibilityAnnouncementModifier: ViewModifier {
    let message: String?

    @State private var lastAnnouncedMessage: String?

    func body(content: Content) -> some View {
        content
            .onAppear {
                announceIfNeeded(message)
            }
            .onChange(of: message) { _, newValue in
                announceIfNeeded(newValue)
            }
    }

    private func announceIfNeeded(_ newValue: String?) {
        guard let newValue, newValue != lastAnnouncedMessage else { return }
        lastAnnouncedMessage = newValue
        PlanEditAccessibility.announce(newValue)
    }
}

extension View {

    func planEditAnnounces(_ message: String?) -> some View {
        modifier(PlanEditAccessibilityAnnouncementModifier(message: message))
    }

    func planEditSupportsDynamicType() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility5)
    }
}
