//
//  QuickActionChips.swift
//  Fitness Coach
//
//  FitPilot AI — Horizontal row of Coach quick action chips.
//

import SwiftUI

struct QuickActionChips: View {
    let actions: [CoachQuickAction]
    let isDisabled: Bool
    let onTap: (CoachQuickAction) -> Void

    init(
        actions: [CoachQuickAction] = CoachQuickAction.allCases,
        isDisabled: Bool = false,
        onTap: @escaping (CoachQuickAction) -> Void
    ) {
        self.actions = actions
        self.isDisabled = isDisabled
        self.onTap = onTap
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    Button {
                        onTap(action)
                    } label: {
                        Label(action.label, systemImage: action.systemImage)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

#Preview {
    QuickActionChips { _ in }
}
