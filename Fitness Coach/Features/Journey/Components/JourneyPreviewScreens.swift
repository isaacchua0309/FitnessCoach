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
      JourneyDashboardContent(state: JourneyPreviewData.dashboard(scenario))
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview(palette: palette)
    .navigationTitle("Journey")
  }
}

#Preview("Journey — Blossom Pink") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.strongMomentum, palette: .blossomPink)
  }
}

#Preview("Journey — Emerald Green") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.strongMomentum, palette: .emeraldGreen)
  }
}

#Preview("Brand new user") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.brandNewUser)
  }
}

#Preview("Week 1 — 3 days") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.weekOne)
  }
}

#Preview("Strong momentum") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.strongMomentum)
  }
}

#Preview("Plateau") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.plateau)
  }
}

#Preview("Near goal") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.nearGoal)
  }
}

#Preview("Gain goal") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.gainGoal)
  }
}

#Preview("Maintain goal") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.maintainGoal)
  }
}

#Preview("Health disconnected") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.healthDisconnected)
  }
}

#Preview("Health connected") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.healthConnected)
  }
}

#Preview("Sparse data") {
  NavigationStack {
    JourneyPreviewScreens.dashboard(.sparseData)
  }
}
#endif
