//
//  FormaScreenChrome.swift
//  Fitness Coach
//
//  Forma — Screen background and grouped-list modifiers.
//

import SwiftUI

extension View {
    func formaScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
    }

    func formaGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .listSectionSpacing(FormaTokens.Spacing.sm)
            .scrollContentBackground(.hidden)
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
            .tint(FormaTokens.Theme.primary)
    }

    func formaScrollBottomInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: FormaTokens.Layout.tabBarScrollPadding)
                .allowsHitTesting(false)
        }
    }

    func formaFormScreen() -> some View {
        self
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
            .formaScrollBottomInset()
    }

    func formaFormSection() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func formaSettingsRowChrome(isEnabled: Bool = true) -> some View {
        listRowInsets(FormaTokens.Layout.settingsRowInsets)
            .listRowBackground(SettingsListRowBackground(isEnabled: isEnabled))
            .allowsHitTesting(isEnabled)
    }

    /// Centers readable settings detail content and caps width on large phones.
    func formaSettingsDetailContent() -> some View {
        frame(maxWidth: FormaTokens.Layout.maxContentWidth)
            .frame(maxWidth: .infinity)
    }

    /// Shared scroll layout for pushed settings detail screens.
    func formaSettingsDetailScreen<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .formaSettingsDetailContent()
                .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
                .padding(.top, SettingsChromeAccessibility.detailPageTopPadding)
                .padding(.bottom, SettingsChromeAccessibility.detailPageBottomPadding)
        }
        .formaScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .formaScrollBottomInset()
    }
}

/// Decorative settings list-row fill. Must not participate in hit testing or it blocks row taps.
private struct SettingsListRowBackground: View {
    let isEnabled: Bool

    var body: some View {
        Rectangle()
            .fill(isEnabled ? FormaTokens.Color.surface : FormaTokens.Color.surfaceSubtle)
            .allowsHitTesting(false)
    }
}
