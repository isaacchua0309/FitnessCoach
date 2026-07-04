//
//  TodayMealsPreview.swift
//  Fitness Coach
//
//  Forma — Compact grouped Today meals by type.
//

import SwiftUI

struct TodayMealsPreview: View {
    let entries: [FoodEntry]
    let date: Date
    let mealsEmptyKind: TodayMealsEmptyKind
    let onAddMeal: (MealType) -> Void
    let onEditEntry: (FoodEntry) -> Void
    let onDeleteEntry: (FoodEntry) -> Void

    private var section: TodayMealsSectionState {
        TodayMealsGroupingEngine.build(entries: entries, date: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Meals.sectionTitle)

            FormaPlanCard {
                VStack(spacing: 0) {
                    ForEach(section.groups) { group in
                        mealGroupRow(group)

                        if group.mealType != section.groups.last?.mealType {
                            FormaPlanRowDivider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mealGroupRow(_ group: TodayMealGroupState) -> some View {
        let display = TodayMealsSectionFormatting.rowDisplayModel(for: group)

        if group.isLogged {
            loggedMealRow(group: group, display: display)
        } else {
            emptyMealRow(group: group, display: display)
        }
    }

    private func emptyMealRow(group: TodayMealGroupState, display: TodayMealRowDisplayModel) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            mealTitleBlock(display: display, isLogged: false)

            Spacer(minLength: FormaTokens.Spacing.xs)

            Button {
                onAddMeal(group.mealType)
            } label: {
                Text(FormaProductCopy.Today.Meals.addAction)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(FormaTokens.Theme.primary)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(FormaProductCopy.Today.Meals.addAccessibilityLabel(for: group.mealType))
            .accessibilityHint(display.accessibilityHint ?? "")
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, TodayLayout.cardRowVerticalPadding)
    }

    private func loggedMealRow(group: TodayMealGroupState, display: TodayMealRowDisplayModel) -> some View {
        Button {
            if let entry = group.entries.first {
                onEditEntry(entry)
            }
        } label: {
            HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
                mealTitleBlock(display: display, isLogged: true)

                Spacer(minLength: FormaTokens.Spacing.xs)

                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(FormaTokens.Theme.primary)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: FormaTokens.Layout.minTouchTarget)
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, TodayLayout.cardRowVerticalPadding)
        .background(
            FormaTokens.Theme.softBackground.opacity(0.45),
            in: RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.accessibilityLabel)
        .accessibilityHint(display.accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            ForEach(group.entries) { entry in
                Button {
                    onEditEntry(entry)
                } label: {
                    Label(
                        entry.name,
                        systemImage: "pencil"
                    )
                }

                Button(role: .destructive) {
                    onDeleteEntry(entry)
                } label: {
                    Label(
                        FormaProductCopy.Today.Meals.contextMenuDelete,
                        systemImage: "trash"
                    )
                }
            }
        }
    }

    private func mealTitleBlock(display: TodayMealRowDisplayModel, isLogged: Bool) -> some View {
        VStack(alignment: .leading, spacing: TodayLayout.compactSpacing) {
            HStack(spacing: FormaTokens.Spacing.xs) {
                Text(display.title)
                    .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                    .foregroundStyle(FormaTokens.Color.textPrimary)

                if display.isOptional {
                    Text(FormaProductCopy.Today.Meals.optionalLabel)
                        .font(FormaTokens.Typography.caption2)
                        .foregroundStyle(FormaTokens.Color.textTertiary)
                }
            }

            Text(display.statusLine)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(isLogged ? FormaTokens.Color.textSecondary : FormaTokens.Color.textTertiary)

            if let detailLine = display.detailLine {
                Text(detailLine)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
            }
        }
    }
}

#Preview("Empty day") {
    TodayMealsPreview(
        entries: [],
        date: Date(),
        mealsEmptyKind: .newDayNoMeals,
        onAddMeal: { _ in },
        onEditEntry: { _ in },
        onDeleteEntry: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Partial day") {
    TodayMealsPreview(
        entries: TodayPreviewData.foodEntries,
        date: Date(),
        mealsEmptyKind: .hasMeals,
        onAddMeal: { _ in },
        onEditEntry: { _ in },
        onDeleteEntry: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Large text") {
    TodayMealsPreview(
        entries: TodayPreviewData.foodEntries,
        date: Date(),
        mealsEmptyKind: .hasMeals,
        onAddMeal: { _ in },
        onEditEntry: { _ in },
        onDeleteEntry: { _ in },
        onLogFirstMeal: {}
    )
    .padding()
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
