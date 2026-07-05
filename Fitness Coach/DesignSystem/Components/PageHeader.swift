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
        let _ = theme.accent

        VStack(alignment: .leading, spacing: FormaMainTabLayout.headerTitleSubtitleSpacing) {
            HStack(alignment: .top, spacing: FormaTokens.Spacing.sm) {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(titleLineLimit)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(0)

                trailingAction()
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(theme.tertiaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(MainTabResponsiveLayout.pageSubtitleLineLimit(for: dynamicTypeSize))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isHeader)
        .formaThemeReactive()
    }

    private var titleFont: Font {
        if MainTabResponsiveLayout.usesCompactPageTitle(for: dynamicTypeSize) {
            return FormaTokens.Typography.sectionTitle.weight(.bold)
        }
        return FormaTokens.Typography.screenTitle
    }

    private var titleLineLimit: Int {
        MainTabResponsiveLayout.usesCompactPageTitle(for: dynamicTypeSize) ? 3 : 2
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
#Preview("Today + pill") {
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

#Preview("Plan + Adjust — small phone") {
    PageHeader(
        title: "Plan",
        subtitle: FormaProductCopy.PlanHeader.subtitle,
        trailingAction: {
            PageActionPill(title: FormaProductCopy.PlanMissionControl.adjustPlanPill)
        }
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .frame(width: MainTabResponsiveLayout.compactPhoneWidth)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Coach — large text") {
    PageHeader(
        title: FormaProductCopy.Coach.screenTitle,
        subtitle: FormaProductCopy.Coach.headerSubtitle
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Journey — large text") {
    PageHeader(
        title: FormaProductCopy.Journey.Header.title,
        subtitle: FormaProductCopy.Journey.Header.subtitle
    )
    .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
