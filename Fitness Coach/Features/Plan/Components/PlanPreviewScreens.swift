//
//  PlanPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Full Plan dashboard previews for strategy fixtures.
//

import SwiftUI

#if DEBUG
enum PlanPreviewScreens {

    enum Scenario: String, CaseIterable {
        case aggressiveCut
        case moderateCut
        case maintenance
        case leanGain
        case lowConfidence
        case strongConfidence
    }

    static func dashboard(_ scenario: Scenario) -> PlanDashboardState {
        switch scenario {
        case .aggressiveCut:
            return PlanMissionControlFixtures.loseDashboard
        case .moderateCut:
            return PlanMissionControlFixtures.moderateDeficitDashboard
        case .maintenance:
            return PlanMissionControlFixtures.maintainDashboard
        case .leanGain:
            return PlanMissionControlFixtures.gainDashboard
        case .lowConfidence:
            return PlanMissionControlFixtures.newUserDashboard
        case .strongConfidence:
            return PlanMissionControlFixtures.activeUserDashboard
        }
    }

    @ViewBuilder
    static func content(
        _ scenario: Scenario,
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        ScrollView {
            PlanDashboardContent(state: dashboard(scenario))
        }
        .formaMainTabScrollInsets()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: appearance, palette: palette)
    }
}

#Preview("Aggressive cut") {
    NavigationStack {
        PlanPreviewScreens.content(.aggressiveCut)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}

#Preview("Moderate cut") {
    NavigationStack {
        PlanPreviewScreens.content(.moderateCut)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}

#Preview("Maintenance") {
    NavigationStack {
        PlanPreviewScreens.content(.maintenance)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}

#Preview("Lean gain") {
    NavigationStack {
        PlanPreviewScreens.content(.leanGain)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}

#Preview("Low confidence") {
    NavigationStack {
        PlanPreviewScreens.content(.lowConfidence)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}

#Preview("Strong confidence") {
    NavigationStack {
        PlanPreviewScreens.content(.strongConfidence)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
    }
}

#Preview("Aggressive cut — small iPhone") {
    NavigationStack {
        PlanPreviewScreens.content(.aggressiveCut)
            .navigationTitle(FormaProductCopy.PlanHeader.title)
            .frame(width: 375, height: 667)
    }
}
#endif
