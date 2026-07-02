//
//  FormaThemeScreenModifier.swift
//  Fitness Coach
//
//  Forma — Applies root appearance override and propagates the resolved theme.
//

import SwiftUI

struct FormaRootThemeModifier: ViewModifier {
    @ObservedObject var store: ThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    func body(content: Content) -> some View {
        // Explicit dependencies keep palette/appearance changes live across auth, onboarding, and tabs.
        let activePalette = store.palette
        let activeAppearance = store.appearance
        let state = FormaThemeRootState.make(store: store, systemColorScheme: systemColorScheme)
        FormaThemeAccess.update(resolved: state.resolved)

        return content
            .preferredColorScheme(state.preferredColorScheme)
            .environment(\.formaResolvedTheme, state.resolved)
            .environment(\.formaThemePalette, state.legacyPalette)
            .environment(\.themePalette, state.resolved.themePalette)
            .tint(state.resolved.themePalette.primary)
    }
}

extension View {

    /// Apply once at the app root. Do not nest inside feature screens.
    func formaRootTheme(store: ThemeStore) -> some View {
        modifier(FormaRootThemeModifier(store: store))
    }
}

#if DEBUG
enum FormaThemeEnvironmentAssertions {

    @MainActor
    static func assertRootThemeReachable(
        from store: ThemeStore,
        systemColorScheme: ColorScheme
    ) {
        let state = FormaThemeRootState.make(store: store, systemColorScheme: systemColorScheme)
        assert(
            state.resolved.colors == store.resolvedTheme(systemColorScheme: systemColorScheme).colors,
            "Root theme state must match ThemeStore resolution."
        )
    }
}
#endif
