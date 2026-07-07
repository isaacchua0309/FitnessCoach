//
//  JourneyPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Full Journey dashboard previews for every persona fixture.
//

import SwiftUI

#if DEBUG
@MainActor
enum JourneyPreviewScreens {

  @ViewBuilder
  static func dashboard(
    _ scenario: JourneyPreviewData.Scenario,
    palette: AppThemePalette = .oceanBlue,
    healthIntelligenceSectionState: JourneyHealthIntelligenceSectionState? = nil
  ) -> some View {
    let state = JourneyPreviewData.dashboard(scenario)

    MainTabPageScaffold(
      title: FormaProductCopy.Journey.Header.title,
      subtitle: FormaProductCopy.Journey.Header.subtitle,
      sectionSpacing: JourneyLayout.sectionSpacing
    ) {
      JourneyDashboardContent(
        state: state,
        healthIntelligenceUIEnabled: healthIntelligenceSectionState != nil,
        healthIntelligenceSectionState: healthIntelligenceSectionState,
        onGoToToday: {},
        onConnectHealth: {}
      )
    }
    .formaThemePreview(palette: palette)
  }
}

#Preview("New user") {
  JourneyPreviewScreens.dashboard(.brandNewUser)
}

#Preview("Week 1 user") {
  JourneyPreviewScreens.dashboard(.weekOne)
}

#Preview("Weight loss user") {
  JourneyPreviewScreens.dashboard(.strongMomentum)
}

#Preview("Highly consistent user") {
  JourneyPreviewScreens.dashboard(.highlyConsistent)
}

#Preview("Insufficient data user") {
  JourneyPreviewScreens.dashboard(.sparseData)
}

#Preview("New user — dark mode") {
  JourneyPreviewScreens.dashboard(.brandNewUser)
    .preferredColorScheme(.dark)
}

#Preview("Data-rich — dark mode") {
  JourneyPreviewScreens.dashboard(.highlyConsistent)
    .preferredColorScheme(.dark)
}

#Preview("New user — large text") {
  JourneyPreviewScreens.dashboard(.brandNewUser)
    .dynamicTypeSize(.accessibility2)
}

#Preview("Data-rich — large text") {
  JourneyPreviewScreens.dashboard(.strongMomentum)
    .dynamicTypeSize(.accessibility2)
}

#Preview("Journey — Blossom Pink") {
  JourneyPreviewScreens.dashboard(.strongMomentum, palette: .blossomPink)
}

#Preview("Journey — Emerald Green") {
  JourneyPreviewScreens.dashboard(.highlyConsistent, palette: .emeraldGreen)
}

#Preview("Health Intelligence enabled") {
  JourneyPreviewScreens.dashboard(
    .strongMomentum,
    healthIntelligenceSectionState: JourneyHealthIntelligencePreviewData.strongWeek
  )
}
#endif
