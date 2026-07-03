//
//  JourneyPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Full Journey dashboard previews for every persona fixture.
//

import SwiftUI

#if DEBUG
enum JourneyPreviewScreens {

  @ViewBuilder
  static func dashboard(_ scenario: JourneyPreviewData.Scenario, palette: AppThemePalette = .oceanBlue) -> some View {
    ScrollView {
      JourneyDashboardContent(
        state: JourneyPreviewData.dashboard(scenario),
        onGoToToday: {}
      )
    }
    .formaMainTabScrollInsets()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: palette)
    .navigationTitle(FormaProductCopy.Journey.Header.title)
  }
}

#Preview("New user") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.brandNewUser)
  }
}

#Preview("Week 1 user") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.weekOne)
  }
}

#Preview("Weight loss user") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.strongMomentum)
  }
}

#Preview("Highly consistent user") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.highlyConsistent)
  }
}

#Preview("Insufficient data user") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.sparseData)
  }
}

#Preview("New user — dark mode") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.brandNewUser)
      .preferredColorScheme(.dark)
  }
}

#Preview("Data-rich — dark mode") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.highlyConsistent)
      .preferredColorScheme(.dark)
  }
}

#Preview("New user — large text") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.brandNewUser)
      .dynamicTypeSize(.accessibility2)
  }
}

#Preview("Data-rich — large text") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.strongMomentum)
      .dynamicTypeSize(.accessibility2)
  }
}

#Preview("Journey — Blossom Pink") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.strongMomentum, palette: .blossomPink)
  }
}

#Preview("Journey — Emerald Green") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.highlyConsistent, palette: .emeraldGreen)
  }
}
#endif
