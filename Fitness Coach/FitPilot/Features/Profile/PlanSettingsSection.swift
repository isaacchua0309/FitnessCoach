//
//  PlanSettingsSection.swift
//  Fitness Coach
//

import SwiftUI

struct PlanSettingsSection: View {
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PlanLayout.itemSpacing) {
            PlanSectionLabel(title: "Settings")

            VStack(spacing: 0) {
                settingsRow("Notifications", action: onOpenSettings)
                divider
                settingsRow("Units", action: onOpenSettings)
                divider
                settingsRow("HealthKit", action: onOpenSettings)
                divider
                settingsRow("Privacy", action: onOpenSettings)
                divider
                settingsRow("AI preferences", action: onOpenSettings)
            }
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 4)
    }

    private func settingsRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}
