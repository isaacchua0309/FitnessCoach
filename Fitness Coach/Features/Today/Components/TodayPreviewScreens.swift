//
//  TodayPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Full Today dashboard previews for layout QA.
//

import SwiftUI

#if DEBUG
enum TodayPreviewScreens {

    @ViewBuilder
    static func dashboard(_ state: TodayDashboardState) -> some View {
        TodayReadOnlyPreviewSupport.screen(state, name: "Today")
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

#Preview("Brand new day — small phone") {
    TodayPreviewScreens.dashboard(TodayPreviewData.brandNewDay)
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}

#Preview("Protein behind — large text") {
    TodayPreviewScreens.dashboard(TodayPreviewData.proteinBehind)
        .dynamicTypeSize(.accessibility2)
}
#endif
