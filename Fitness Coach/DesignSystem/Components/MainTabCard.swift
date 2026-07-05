//
//  MainTabCard.swift
//  Fitness Coach
//
//  Forma — Shared card container for main tab dashboards.
//

import SwiftUI

struct MainTabCard<Content: View>: View {
    var style: FormaCardChrome.Style = .surface
    var compact: Bool = false
    @ViewBuilder var content: Content

    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let _ = themeManager.themeRevision
        return content
            .padding(.horizontal, compact ? FormaMainTabLayout.cardCompactPadding : FormaMainTabLayout.cardPadding)
            .padding(.vertical, compact ? FormaTokens.Spacing.sm : FormaMainTabLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                FormaCardChrome.background(style, cornerRadius: FormaMainTabLayout.cardCornerRadius)
            }
            .formaThemeReactive()
    }
}

#if DEBUG
#Preview {
    MainTabCard {
        Text("Card content")
            .foregroundStyle(FormaTokens.Color.textPrimary)
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
#endif
