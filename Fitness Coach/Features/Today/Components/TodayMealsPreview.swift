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
    let onLogFirstMeal: () -> Void
    let onEditEntry: (FoodEntry) -> Void
    let onDeleteEntry: (FoodEntry) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.theme) private var theme

    private var section: TodayMealsSectionState {
        TodayMealsGroupingEngine.build(entries: entries, date: date)
    }

    var body: some View {
        let _ = themeManager.themeRevision

        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            SectionLabel(title: FormaProductCopy.Today.Meals.sectionTitle)

            if section.isFullyEmpty {
                emptyDayCard
            } else {
                loggedMealsCard
            }
        }
        .todayLiveTheme()
    }

    private var emptyDayCard: some View {
        MainTabCard {
            VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                Text(FormaProductCopy.Today.Meals.emptyDayMessage)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button(FormaProductCopy.Today.Meals.logFirstMealCTA, action: onLogFirstMeal)
                    .font(FormaTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .leading)
                    .accessibilityLabel(FormaProductCopy.Today.Meals.logFirstMealCTA)
                    .accessibilityHint(FormaProductCopy.Today.Meals.logFirstMealAccessibilityHint)
            }
            .padding(.vertical, FormaTokens.Spacing.sm)
        }
        .accessibilityElement(children: .contain)
    }

    private var loggedMealsCard: some View {
        MainTabCard {
            VStack(spacing: 0) {
                ForEach(section.groups) { group in
                    if group.isLogged {
                        mealGroupRow(group)

                        if group.mealType != section.groups.last?.mealType {
                            FormaPlanRowDivider()
                        }
                    }
                }

                let unloggedGroups = section.groups.filter { !$0.isLogged }
                if !unloggedGroups.isEmpty {
                    if section.groups.contains(where: \.isLogged) {
                        FormaPlanRowDivider()
                    }

                    ForEach(unloggedGroups) { group in
                        mealGroupRow(group)

                        if group.mealType != unloggedGroups.last?.mealType {
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
                    .font(FormaTokens.Typography.caption2.weight(.semibold))
                    .foregroundStyle(theme.accent)
                    .frame(minHeight: FormaTokens.Layout.minTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(FormaProductCopy.Today.Meals.addAccessibilityLabel(for: group.mealType))
            .accessibilityHint(display.accessibilityHint ?? "")
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
        .padding(.vertical, TodayLayout.compactSpacing)
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
                    .foregroundStyle(theme.accent)
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
            theme.accentSoftBackground.opacity(0.45),
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
                    .foregroundStyle(theme.primaryText)

                if display.isOptional {
                    Text(FormaProductCopy.Today.Meals.optionalLabel)
                        .font(FormaTokens.Typography.caption2)
                        .foregroundStyle(theme.tertiaryText)
                }
            }

            Text(display.statusLine)
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(isLogged ? theme.secondaryText : theme.tertiaryText)

            if let detailLine = display.detailLine {
                Text(detailLine)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(theme.secondaryText)
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
        onLogFirstMeal: {},
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
        onLogFirstMeal: {},
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
        onLogFirstMeal: {},
        onEditEntry: { _ in },
        onDeleteEntry: { _ in }
    )
    .padding()
    .dynamicTypeSize(.accessibility2)
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
