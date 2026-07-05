//
//  PageActionPill.swift
//  Fitness Coach
//
//  Forma — Compact top-right action pill for main tab page headers.
//

import SwiftUI

struct PageActionPill: View {
    let title: String
    var accessibilityHint: String?
    var action: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        let _ = themeManager.themeRevision

        Group {
            if let action {
                Button(action: action) {
                    pillLabel
                }
                .buttonStyle(.plain)
                .accessibilityHint(accessibilityHint ?? "")
            } else {
                pillLabel
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .accessibilityLabel(title)
    }

    private var pillLabel: some View {
        Text(title)
            .font(FormaTokens.Typography.caption2.weight(.semibold))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .background(theme.accentSoftBackground)
            .clipShape(Capsule())
    }
}

#if DEBUG
#Preview {
    PageActionPill(title: "Needs focus")
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview()
}
#endif
