//
//  PlanGoalSelectionView.swift
//  Fitness Coach
//
//  Forma — Goal picker for the Edit Plan wizard.
//

import SwiftUI

struct PlanGoalSelectionView: View {
    @Binding var selection: PlanGoalType
    let recommendedGoal: PlanGoalType
    let onSelect: (PlanGoalType) -> Void

    private var options: [PlanGoalOptionPresentation] {
        PlanGoalSelectionBuilder.options(recommendedGoal: recommendedGoal)
    }

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(options) { option in
                PlanGoalSelectionCard(
                    presentation: option,
                    isSelected: selection == option.goalType,
                    action: {
                        guard selection != option.goalType else { return }
                        selection = option.goalType
                        onSelect(option.goalType)
                    }
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview {
    struct PreviewHost: View {
        @State private var selection: PlanGoalType = .loseFat

        var body: some View {
            PlanGoalSelectionView(
                selection: $selection,
                recommendedGoal: .loseFat,
                onSelect: { _ in }
            )
            .padding()
            .background(FormaPlanTokens.Color.planBackground)
        }
    }

    return PreviewHost()
        .formaThemePreview()
}
#endif
