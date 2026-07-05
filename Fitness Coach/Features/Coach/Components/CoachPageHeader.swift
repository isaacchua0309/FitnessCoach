//
//  CoachPageHeader.swift
//  Fitness Coach
//
//  Forma — Shared in-scroll page header for Coach dashboard and chat modes.
//

import SwiftUI

enum CoachPageHeaderMode: Equatable {
    case dashboard
    case conversation
}

struct CoachPageHeader: View {
    var mode: CoachPageHeaderMode

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    var body: some View {
        let _ = themeManager.themeRevision
        let _ = theme.accent

        return PageHeader(
            title: FormaProductCopy.Coach.screenTitle,
            subtitle: subtitle
        )
        .padding(.horizontal, FormaMainTabLayout.horizontalPadding)
        .padding(.top, FormaMainTabLayout.headerTopPadding)
        .padding(.bottom, FormaMainTabLayout.headerBottomPadding)
        .accessibilityIdentifier(CoachAccessibilityIdentifier.pageHeader)
    }

    private var subtitle: String {
        switch mode {
        case .dashboard:
            return FormaProductCopy.Coach.headerSubtitle
        case .conversation:
            return FormaProductCopy.Coach.chatHeaderSubtitle
        }
    }
}

#if DEBUG
#Preview("Dashboard") {
    CoachPageHeader(mode: .dashboard)
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
}

#Preview("Conversation") {
    CoachPageHeader(mode: .conversation)
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
}
#endif
