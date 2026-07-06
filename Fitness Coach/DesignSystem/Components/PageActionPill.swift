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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let _ = themeManager.themeRevision
        let _ = theme.accent

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
        .formaThemeReactive()
    }

    private var pillLabel: some View {
        Text(title)
            .font(FormaTokens.Typography.caption2.weight(.semibold))
            .foregroundStyle(theme.accent)
            .lineLimit(pillLineLimit)
            .minimumScaleFactor(MainTabResponsiveLayout.headerMinimumScaleFloor)
            .multilineTextAlignment(.center)
            .padding(.horizontal, FormaTokens.Spacing.sm)
            .padding(.vertical, FormaTokens.Spacing.xs)
            .background(theme.accentSoftBackground)
            .clipShape(Capsule())
    }

    private var pillLineLimit: Int {
        dynamicTypeSize >= .accessibility2 ? 2 : 1
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
