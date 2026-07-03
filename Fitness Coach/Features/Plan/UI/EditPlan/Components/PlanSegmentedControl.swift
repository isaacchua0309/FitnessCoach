//
//  PlanSegmentedControl.swift
//  Fitness Coach
//
//  Forma — Theme-aware segmented controls for Edit Plan.
//

import SwiftUI

struct PlanSegmentedControl: View {
    let options: [PlanSegmentedOption]
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            ForEach(options) { option in
                chip(for: option)
            }
        }
    }

    private func chip(for option: PlanSegmentedOption) -> some View {
        let isSelected = option.id == selectedID

        return Button {
            onSelect(option.id)
        } label: {
            Text(option.title)
                .font(FormaTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(
                    isSelected
                        ? FormaPlanTokens.Color.planAccent
                        : FormaPlanTokens.Color.planSecondaryText
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: FormaTokens.Layout.minTouchTarget)
                .background {
                    Capsule()
                        .fill(
                            isSelected
                                ? FormaPlanTokens.Color.planAccentSoft
                                : FormaPlanTokens.Color.planUnselectedCardBackground
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(
                            PlanEditSelectionChrome.cardStrokeColor(isSelected: isSelected),
                            lineWidth: PlanEditSelectionChrome.cardStrokeWidth(isSelected: isSelected)
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PlanNativeSegmentedPicker<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder var content: () -> Content

    var body: some View {
        Picker(title, selection: $selection, content: content)
            .pickerStyle(.segmented)
            .tint(FormaPlanTokens.Color.planAccent)
    }
}

#if DEBUG
#Preview {
    PlanSegmentedControl(
        options: [
            PlanSegmentedOption(id: "metric", title: "Metric"),
            PlanSegmentedOption(id: "imperial", title: "Imperial")
        ],
        selectedID: "metric",
        onSelect: { _ in }
    )
    .padding()
    .background(FormaPlanTokens.Color.planBackground)
    .formaThemePreview()
}
#endif
