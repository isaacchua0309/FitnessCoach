//
//  OnboardingPillGrid.swift
//  Fitness Coach
//
//  Forma — Compact pill grid for single- or multi-select onboarding choices.
//

import SwiftUI

struct OnboardingPillGrid<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let titleForItem: (Item) -> String
    var subtitleForItem: ((Item) -> String?)? = nil
    var columnCount: Int = 2
    var accessibilityGroupLabel: String?

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: OnboardingLayout.compactFieldSpacing),
            count: max(1, columnCount)
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: OnboardingLayout.compactFieldSpacing) {
            ForEach(items, id: \.self) { item in
                pill(for: item, isSelected: selection == item) {
                    selection = item
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityGroupLabel ?? "Options")
    }

    private func pill(for item: Item, isSelected: Bool, action: @escaping () -> Void) -> some View {
        OnboardingPillButton(
            title: titleForItem(item),
            subtitle: subtitleForItem?(item),
            isSelected: isSelected,
            action: action
        )
        .accessibilityLabel(pillAccessibilityLabel(for: item, isSelected: isSelected))
    }

    private func pillAccessibilityLabel(for item: Item, isSelected: Bool) -> String {
        let title = titleForItem(item)
        if let subtitle = subtitleForItem?(item) {
            return isSelected ? "\(title), \(subtitle), selected" : "\(title), \(subtitle)"
        }
        return isSelected ? "\(title), selected" : title
    }
}

struct OnboardingMultiPillGrid<Item: Hashable>: View {
    let items: [Item]
    @Binding var selections: Set<Item>
    let titleForItem: (Item) -> String
    var subtitleForItem: ((Item) -> String?)? = nil
    var columnCount: Int = 2
    var accessibilityGroupLabel: String?

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: OnboardingLayout.compactFieldSpacing),
            count: max(1, columnCount)
        )
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: OnboardingLayout.compactFieldSpacing) {
            ForEach(items, id: \.self) { item in
                let isSelected = selections.contains(item)
                OnboardingPillButton(
                    title: titleForItem(item),
                    subtitle: subtitleForItem?(item),
                    isSelected: isSelected
                ) {
                    if isSelected {
                        selections.remove(item)
                    } else {
                        selections.insert(item)
                    }
                }
                .accessibilityLabel(pillAccessibilityLabel(for: item, isSelected: isSelected))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityGroupLabel ?? "Options")
    }

    private func pillAccessibilityLabel(for item: Item, isSelected: Bool) -> String {
        let title = titleForItem(item)
        if let subtitle = subtitleForItem?(item) {
            return isSelected ? "\(title), \(subtitle), selected" : "\(title), \(subtitle)"
        }
        return isSelected ? "\(title), selected" : title
    }
}

// MARK: - Pill button

struct OnboardingPillButton: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.primaryText : OnboardingTheme.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(OnboardingTheme.tertiaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .fill(isSelected ? FormaTokens.Color.accentMuted : FormaTokens.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? OnboardingTheme.selectedBorder : OnboardingTheme.border,
                        lineWidth: isSelected ? 1.4 : 1
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Vertical list of `OnboardingChoiceRow` items.
struct OnboardingChoiceGrid<Item: Identifiable & Hashable>: View {
    let items: [Item]
    let iconForItem: (Item) -> String
    let titleForItem: (Item) -> String
    var subtitleForItem: ((Item) -> String?)? = nil
    @Binding var selection: Item
    var accessibilityGroupLabel: String?

    var body: some View {
        VStack(spacing: OnboardingLayout.compactFieldSpacing) {
            ForEach(items) { item in
                OnboardingChoiceRow(
                    icon: iconForItem(item),
                    title: titleForItem(item),
                    subtitle: subtitleForItem?(item),
                    isSelected: selection == item
                ) {
                    selection = item
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityGroupLabel ?? "Choices")
    }
}

#Preview("Sex pills") {
    OnboardingPillGrid(
        items: Sex.allCases,
        selection: .constant(.female),
        titleForItem: { OnboardingFormatter.sex($0) },
        columnCount: 2,
        accessibilityGroupLabel: "Sex"
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Steps bands") {
    OnboardingPillGrid(
        items: OnboardingDailyStepsBand.allCases,
        selection: .constant(.moderate),
        titleForItem: \.title,
        subtitleForItem: \.subtitle,
        columnCount: 2,
        accessibilityGroupLabel: "Daily movement"
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Training days") {
    OnboardingPillGrid(
        items: OnboardingTrainingDaysOption.allCases,
        selection: .constant(.three),
        titleForItem: \.displayLabel,
        columnCount: 4,
        accessibilityGroupLabel: "Training days per week"
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}

#Preview("Multi diet chips") {
    OnboardingMultiPillGrid(
        items: OnboardingDietPreferenceChip.allCases,
        selections: .constant([.highProtein, .simpleMeals]),
        titleForItem: \.title,
        columnCount: 2,
        accessibilityGroupLabel: "Diet preferences"
    )
    .padding()
    .background(OnboardingTheme.background)
    .preferredColorScheme(.dark)
}
