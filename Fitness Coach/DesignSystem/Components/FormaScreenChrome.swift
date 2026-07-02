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
            .scrollContentBackground(.hidden)
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
            .tint(FormaTokens.Theme.primary)
    }

    func formaScrollBottomInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: FormaTokens.Layout.tabBarScrollPadding)
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
            .listRowBackground(
                isEnabled
                    ? FormaTokens.Color.surface
                    : FormaTokens.Color.surfaceSubtle
            )
            .allowsHitTesting(isEnabled)
    }
}
