//
//  LiveThemeDebugHarness.swift
//  Fitness Coach
//
//  Forma — DEBUG-only harness for toggling palette while screens stay mounted.
//

import SwiftUI

#if DEBUG
enum LiveThemeDebugHarness {

  /// Toolbar menu that calls `ThemeManager.setTheme` for every registered palette.
  static func themeSwitcherMenu(themeManager: ThemeManager) -> some View {
    Menu("Theme") {
      ForEach(AppThemePalette.allCases) { palette in
        Button {
          themeManager.setTheme(palette)
        } label: {
          if themeManager.selectedTheme == palette {
            Label(palette.displayName, systemImage: "checkmark")
          } else {
            Text(palette.displayName)
          }
        }
      }
    }
  }

  /// Wraps content in a `NavigationStack` with live root theme injection and a theme switcher.
  static func shell<Content: View>(
    title: String,
    initialPalette: AppThemePalette = .oceanBlue,
    appearance: AppAppearanceMode = .dark,
    @ViewBuilder content: @escaping (ThemeStore) -> Content
  ) -> some View {
    LiveThemeDebugShell(
      title: title,
      initialPalette: initialPalette,
      appearance: appearance,
      content: content
    )
  }
}

private struct LiveThemeDebugShell<Content: View>: View {
  let title: String
  let initialPalette: AppThemePalette
  let appearance: AppAppearanceMode
  @ViewBuilder let content: (ThemeStore) -> Content

  @StateObject private var themeStore: ThemeStore

  init(
    title: String,
    initialPalette: AppThemePalette,
    appearance: AppAppearanceMode,
    @ViewBuilder content: @escaping (ThemeStore) -> Content
  ) {
    self.title = title
    self.initialPalette = initialPalette
    self.appearance = appearance
    self.content = content

    let defaults = ThemeStore.previewUserDefaults()
    let store = ThemeStore(userDefaults: defaults)
    store.setAppearance(appearance)
    store.setTheme(initialPalette)
    _themeStore = StateObject(wrappedValue: store)
  }

  var body: some View {
    NavigationStack {
      content(themeStore)
        .environmentObject(themeStore)
        .formaRootTheme()
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            LiveThemeDebugHarness.themeSwitcherMenu(themeManager: themeStore)
          }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview("Today — live theme toggle") {
  LiveThemeDebugHarness.shell(title: "Today") { _ in
    TodayReadOnlyPreviewSupport.screen(
      TodayPreviewData.state,
      healthIntelligenceSection: TodayHealthIntelligencePreviewData.workoutDay,
      isHealthIntelligenceUIEnabled: true
    )
  }
}

#Preview("Main tab — live theme toggle") {
  let container = try! AppContainer(inMemory: true)
  return LiveThemeDebugHarness.shell(title: "Tabs") { themeStore in
    MainTabView(container: container)
      .environmentObject(container.authManager)
      .environmentObject(container.refreshCenter)
      .environmentObject(container.trainingInsightsStore)
      .environmentObject(container.trainingInsightsModel)
      .environmentObject(container.healthSyncStateStore)
      .environmentObject(container.healthSummarySyncConsentStore)
      .environmentObject(themeStore)
  }
}

#Preview("Coach composer — live theme toggle") {
  LiveThemeDebugHarness.shell(title: "Coach") { _ in
    CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
      .environmentObject(AppRefreshCenter())
      .environmentObject(AuthManager())
  }
}
#endif
