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
    static func screen(
        _ scenario: Scenario,
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        MainTabPageScaffold(
            title: FormaProductCopy.PlanHeader.title,
            subtitle: FormaProductCopy.PlanHeader.subtitle,
            sectionSpacing: PlanLayout.sectionSpacing,
            trailingAction: {
                PageActionPill(title: FormaProductCopy.PlanMissionControl.adjustPlanPill)
            }
        ) {
            PlanDashboardContent(
                state: dashboard(scenario),
                onOpenSettings: {}
            )
        }
        .formaThemePreview(appearance: appearance, palette: palette)
    }
}

#Preview("Aggressive cut") {
    PlanPreviewScreens.screen(.aggressiveCut)
}

#Preview("Moderate cut") {
    PlanPreviewScreens.screen(.moderateCut)
}

#Preview("Maintenance") {
    PlanPreviewScreens.screen(.maintenance)
}

#Preview("Lean gain") {
    PlanPreviewScreens.screen(.leanGain)
}

#Preview("Low confidence") {
    PlanPreviewScreens.screen(.lowConfidence)
}

#Preview("Strong confidence") {
    PlanPreviewScreens.screen(.strongConfidence)
}

#Preview("Aggressive cut — small iPhone") {
    PlanPreviewScreens.screen(.aggressiveCut)
        .frame(width: 375, height: 667)
}
#endif
