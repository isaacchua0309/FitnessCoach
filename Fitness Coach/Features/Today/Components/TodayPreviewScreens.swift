//
//  TodayPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Full Today dashboard previews for layout QA.
//

import SwiftUI

#if DEBUG
@MainActor
enum TodayPreviewScreens {

    @ViewBuilder
    static func dashboard(
        _ state: TodayDashboardState,
        healthIntelligenceSection: TodayHealthIntelligenceSectionState? = nil,
        isHealthIntelligenceUIEnabled: Bool = false
    ) -> some View {
        TodayReadOnlyPreviewSupport.screen(
            state,
            healthIntelligenceSection: healthIntelligenceSection,
            isHealthIntelligenceUIEnabled: isHealthIntelligenceUIEnabled
        )
    }
}

#Preview("Brand new day") {
    TodayPreviewScreens.dashboard(TodayPreviewData.brandNewDay)
}

#Preview("Breakfast logged") {
    TodayPreviewScreens.dashboard(TodayPreviewData.breakfastLogged)
}

#Preview("Protein behind") {
    TodayPreviewScreens.dashboard(TodayPreviewData.proteinBehind)
}

#Preview("Water behind") {
    TodayPreviewScreens.dashboard(TodayPreviewData.waterBehind)
}

#Preview("Calories exceeded") {
    TodayPreviewScreens.dashboard(TodayPreviewData.caloriesExceeded)
}

#Preview("Workout completed") {
    TodayPreviewScreens.dashboard(TodayPreviewData.workoutCompleted)
}

#Preview("End of day") {
    TodayPreviewScreens.dashboard(TodayPreviewData.endOfDay)
}

#Preview("Apple Health disconnected") {
    TodayPreviewScreens.dashboard(TodayPreviewData.healthDisconnected)
}

#Preview("Apple Health connected with recovery") {
    TodayPreviewScreens.dashboard(
        TodayPreviewData.partialDay,
        healthIntelligenceSection: TodayHealthIntelligencePreviewData.readyDay,
        isHealthIntelligenceUIEnabled: true
    )
}

#Preview("Protein target complete") {
    TodayPreviewScreens.dashboard(TodayPreviewData.completeDay)
}

#Preview("Fully logged water") {
    TodayPreviewScreens.dashboard(TodayPreviewData.waterBehind)
}

#Preview("Brand new day — iPhone SE") {
    TodayPreviewScreens.dashboard(TodayPreviewData.brandNewDay)
}

#Preview("Calories exceeded — Pro Max") {
    TodayPreviewScreens.dashboard(TodayPreviewData.caloriesExceeded)
}

#Preview("Protein behind — large text") {
    TodayPreviewScreens.dashboard(TodayPreviewData.proteinBehind)
        .dynamicTypeSize(.accessibility2)
}

#Preview("End of day — large text") {
    TodayPreviewScreens.dashboard(TodayPreviewData.endOfDay)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Theme — Blossom Pink") {
    TodayPreviewScreens.dashboard(TodayPreviewData.partialDay)
        .formaThemePreview(palette: .blossomPink)
}
#endif
