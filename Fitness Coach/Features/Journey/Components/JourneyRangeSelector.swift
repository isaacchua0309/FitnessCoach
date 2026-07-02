//
//  JourneyRangeSelector.swift
//  Fitness Coach
//
//  FitPilot AI — Fixed MVP range selector for Progress.
//

import SwiftUI

struct JourneyRangeSelector: View {
    let selectedRangeDays: Int
    let onSelect: (Int) -> Void

    private let ranges = [7, 14, 28]

    var body: some View {
        Picker("Range", selection: Binding(
            get: { selectedRangeDays },
            set: { onSelect($0) }
        )) {
            ForEach(ranges, id: \.self) { days in
                Text("\(days)d").tag(days)
            }
        }
        .pickerStyle(.segmented)
        .tint(FormaTokens.Theme.primary)
    }
}

#Preview("Dark") {
    JourneyRangeSelector(selectedRangeDays: 28) { _ in }
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .dark)
}

#Preview("Light") {
    JourneyRangeSelector(selectedRangeDays: 14) { _ in }
        .padding()
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .light)
}
