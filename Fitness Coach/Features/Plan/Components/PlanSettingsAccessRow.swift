//
//  PlanSettingsAccessRow.swift
//  Fitness Coach
//
//  Forma — Secondary settings entry on the Plan dashboard.
//

import SwiftUI

struct PlanSettingsAccessRow: View {
    let onOpenSettings: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: onOpenSettings) {
            HStack(spacing: FormaTokens.Spacing.sm) {
                Image(systemName: "gearshape")
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
                    .accessibilityHidden(true)

                Text(FormaProductCopy.Settings.Hub.screenTitle)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(FormaProductCopy.Settings.Hub.screenTitle)
        .accessibilityHint("Opens app settings")
        .accessibilityIdentifier("plan-settings-access")
    }
}

#if DEBUG
#Preview {
    PlanSettingsAccessRow(onOpenSettings: {})
        .padding(.horizontal, PlanLayout.horizontalPadding)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
