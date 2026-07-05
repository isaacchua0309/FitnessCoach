//
//  SectionLabel.swift
//  Fitness Coach
//
//  Forma — Shared uppercase section label for main tab dashboards.
//

import SwiftUI

struct SectionLabel: View {
    let title: String
    var style: Style = .default

    enum Style {
        /// Standard section label — secondary text.
        case `default`
        /// Softer label for measurement rows and quiet sections.
        case muted
    }

    @Environment(\.theme) private var theme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let _ = themeManager.themeRevision
        let _ = theme.accent

        Text(title)
            .font(labelFont)
            .foregroundStyle(labelColor)
            .textCase(.uppercase)
            .tracking(tracking)
            .padding(.bottom, FormaMainTabLayout.sectionLabelBottomSpacing)
            .accessibilityAddTraits(.isHeader)
            .formaThemeReactive()
    }

    private var labelFont: Font {
        switch style {
        case .default:
            return FormaTokens.Typography.caption.weight(.semibold)
        case .muted:
            return FormaTokens.Typography.caption.weight(.medium)
        }
    }

    private var labelColor: Color {
        switch style {
        case .default:
            return theme.secondaryText
        case .muted:
            return theme.tertiaryText
        }
    }

    private var tracking: CGFloat {
        switch style {
        case .default:
            return 0.5
        case .muted:
            return 0.4
        }
    }
}

/// Backward-compatible alias for existing call sites.
typealias FormaSectionLabel = SectionLabel

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: FormaTokens.Spacing.md) {
        SectionLabel(title: "Today's mission")
        SectionLabel(title: "Targets", style: .muted)
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
