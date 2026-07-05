//
//  GoalOptionSelector.swift
//  Fitness Coach
//
//  Forma — Goal option list for the Adjust Plan flow.
//

import SwiftUI

struct GoalOptionSelector: View {
    @Binding var selection: PlanGoalType
    let options: [PlanGoalOption]
    let onSelect: (PlanGoalType) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LazyVStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(options) { option in
                GoalOptionCard(
                    goal: option,
                    isSelected: selection == option.goalType,
                    isRecommended: option.isRecommended,
                    onSelect: {
                        guard selection != option.goalType else { return }
                        selection = option.goalType
                        onSelect(option.goalType)
                    }
                )
            }
        }
        .animation(
            PlanEditMotion.animation(PlanEditMotion.selection, reduceMotion: reduceMotion),
            value: selection
        )
        .accessibilityElement(children: .contain)
        .formaThemeReactive()
    }
}

extension GoalOptionSelector {

    init(
        selection: Binding<PlanGoalType>,
        recommendedGoal: PlanGoalType,
        onSelect: @escaping (PlanGoalType) -> Void
    ) {
        self.init(
            selection: selection,
            options: PlanGoalSelectionBuilder.options(recommendedGoal: recommendedGoal),
            onSelect: onSelect
        )
    }
}

#if DEBUG
#Preview {
    struct PreviewHost: View {
        @State private var selection: PlanGoalType = .loseFat

        var body: some View {
            GoalOptionSelector(
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
