//
//  LiveThemeSwitchingSnapshotTests.swift
//  Fitness CoachTests
//
//  Forma — Optional PNG exports for blue vs pink live-theme surfaces.
//  Set LIVE_THEME_SNAPSHOTS=1 to write into screenshots/live-theme-switching/.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class LiveThemeSwitchingSnapshotTests: XCTestCase {

  private var writesSnapshots: Bool {
    ProcessInfo.processInfo.environment["LIVE_THEME_SNAPSHOTS"] == "1"
  }

  func testLiveThemeSwitchingSnapshotMatrix() throws {
    guard writesSnapshots else {
      throw XCTSkip("Set LIVE_THEME_SNAPSHOTS=1 to export live theme switching screenshots.")
    }

    let fixtures: [(name: String, palette: AppThemePalette)] = [
      ("today-ocean-blue", .oceanBlue),
      ("today-blossom-pink", .blossomPink),
      ("recovery-card-ocean-blue", .oceanBlue),
      ("recovery-card-blossom-pink", .blossomPink),
      ("nutrition-card-ocean-blue", .oceanBlue),
      ("nutrition-card-blossom-pink", .blossomPink),
      ("next-action-card-ocean-blue", .oceanBlue),
      ("next-action-card-blossom-pink", .blossomPink),
      ("coach-composer-ocean-blue", .oceanBlue),
      ("coach-composer-blossom-pink", .blossomPink),
      ("main-tab-ocean-blue", .oceanBlue),
      ("main-tab-blossom-pink", .blossomPink)
    ]

    for fixture in fixtures {
      try exportSnapshot(name: fixture.name, palette: fixture.palette)
    }
  }

  private func exportSnapshot(name: String, palette: AppThemePalette) throws {
    let view = snapshotView(for: name, palette: palette)
      .frame(width: 390, height: 844)

    let renderer = ImageRenderer(content: view)
    renderer.scale = 3
    guard let image = renderer.uiImage else {
      XCTFail("Failed to render snapshot for \(name)")
      return
    }

    let directory = snapshotDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("\(name).png")
    guard let data = image.pngData() else {
      XCTFail("Failed to encode PNG for \(name)")
      return
    }
    try data.write(to: url)
  }

  @ViewBuilder
  private func snapshotView(for name: String, palette: AppThemePalette) -> some View {
    if name.hasPrefix("today-") {
      MainTabThemePreviewScreens.today(palette: palette)
    } else if name.hasPrefix("recovery-card-") {
      componentCardSnapshot(palette: palette) {
        TodayRecoveryCard(state: TodayHealthIntelligencePreviewData.workoutDay.recoveryCard)
      }
    } else if name.hasPrefix("nutrition-card-") {
      componentCardSnapshot(palette: palette) {
        TodayNutritionProgressCard(
          macros: TodayPreviewData.state.macroHydration.macroSummary,
          water: TodayPreviewData.state.macroHydration.waterSummary,
          calorieSummary: TodayPreviewData.state.mission.calorieSummary
        )
      }
    } else if name.hasPrefix("next-action-card-") {
      componentCardSnapshot(palette: palette) {
        TodayNextBestActionCard(state: TodayHealthIntelligencePreviewData.workoutDay.nextBestAction)
      }
    } else if name.hasPrefix("coach-composer-") {
      componentCardSnapshot(palette: palette, height: 180) {
        CoachComposerSnapshotHost()
      }
    } else if name.hasPrefix("main-tab-") {
      let container = try! AppContainer(inMemory: true)
      MainTabView(container: container)
        .environmentObject(container.authManager)
        .environmentObject(container.refreshCenter)
        .environmentObject(container.trainingInsightsStore)
        .environmentObject(container.trainingInsightsModel)
        .environmentObject(container.healthSyncStateStore)
        .environmentObject(container.healthSummarySyncConsentStore)
        .environmentObject(container.themeStore)
        .formaThemePreview(palette: palette)
    } else {
      Text("Unknown fixture \(name)")
    }
  }

  private func componentCardSnapshot<Content: View>(
    palette: AppThemePalette,
    height: CGFloat = 260,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    ScrollView {
      content()
        .padding(.horizontal, TodayLayout.horizontalPadding)
        .padding(.vertical, FormaTokens.Spacing.md)
    }
    .frame(height: height)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: palette)
  }

  private func snapshotDirectory() -> URL {
    ThemeTestSupport.repositoryRoot(filePath: #filePath)
      .appendingPathComponent("screenshots/live-theme-switching", isDirectory: true)
  }
}

private struct CoachComposerSnapshotHost: View {
  @State private var text = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    CoachComposer(
      text: $text,
      canPickAttachment: true,
      isFocused: $isFocused,
      isSending: false,
      onSend: {},
      onVoiceTap: {},
      onAttachmentSelect: { _ in },
      onRemoveAttachment: {},
      onRetryImageSelection: {}
    )
    .padding(.horizontal, FormaTokens.Spacing.md)
  }
}
