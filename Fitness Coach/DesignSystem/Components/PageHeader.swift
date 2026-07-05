//
//  PageHeader.swift
//  Fitness Coach
//
//  Forma — Shared large-title header for main tab root screens.
//

import SwiftUI

struct PageHeader<TrailingAction: View>: View {
    let title: String
    var subtitle: String?

    @ViewBuilder var trailingAction: () -> TrailingAction

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailingAction: @escaping () -> TrailingAction = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailingAction = trailingAction
    }

    var body: some View {
        let _ = themeManager.themeRevision

        VStack(alignment: .leading, spacing: FormaMainTabLayout.headerTitleSubtitleSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)

                Spacer(minLength: FormaTokens.Spacing.xs)

                trailingAction()
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isHeader)
    }

    private var titleFont: Font {
        if dynamicTypeSize >= .accessibility1 {
            return FormaTokens.Typography.sectionTitle.weight(.bold)
        }
        return FormaTokens.Typography.screenTitle
    }

    private var accessibilitySummary: String {
        var parts = [title]
        if let subtitle, !subtitle.isEmpty {
            parts.append(subtitle)
        }
        return parts.joined(separator: ". ")
    }
}

#if DEBUG
#Preview {
    PageHeader(
        title: "Today",
        subtitle: "Monday, 6 July",
        trailingAction: {
            PageActionPill(title: "Needs focus")
        }
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
