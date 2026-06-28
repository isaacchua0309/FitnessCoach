//
//  TodayMealsPreview.swift
//  Fitness Coach
//
//  Forma — Grouped Today meals by type with logged / missing states.
//

import SwiftUI

struct TodayMealsPreview: View {
    let entries: [FoodEntry]
    let date: Date
    let onAddMeal: (MealType) -> Void
    let onEditEntry: (FoodEntry) -> Void
    let onDeleteEntry: (FoodEntry) -> Void

    @State private var expandedGroups: Set<MealType> = []

    private var section: TodayMealsSectionState {
        TodayMealsGroupingEngine.build(entries: entries, date: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TodayLayout.headerToCardSpacing) {
            TodaySectionLabel(title: FormaProductCopy.Today.Meals.sectionTitle)

            if section.isFullyEmpty {
                Text(FormaProductCopy.Today.Meals.emptyDayHint)
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FitPilotPlanCard {
                VStack(spacing: 0) {
                    ForEach(section.groups) { group in
                        mealGroupRow(group)

                        if group.mealType != section.groups.last?.mealType {
                            FitPilotPlanRowDivider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mealGroupRow(_ group: TodayMealGroupState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            mealGroupHeader(group)

            if group.isLogged {
                loggedEntries(for: group)
            }
        }
        .padding(.vertical, FormaTokens.Spacing.xs)
    }

    private func mealGroupHeader(_ group: TodayMealGroupState) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: FormaTokens.Spacing.xs) {
                    Text(FormaProductCopy.Today.Meals.mealTitle(group.mealType, isOptional: group.isOptional))
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.textPrimary)

                    if group.isOptional, !group.isLogged {
                        Text(FormaProductCopy.Today.Meals.optionalLabel)
                            .font(FormaTokens.Typography.caption)
                            .foregroundStyle(FormaTokens.Color.textTertiary)
                    }
                }

                if group.isLogged {
                    Text(
                        FormaProductCopy.Today.Meals.loggedSummary(
                            calories: group.totalCalories,
                            protein: group.totalProtein
                        )
                    )
                    .font(FormaTokens.Typography.caption)
                    .foregroundStyle(FormaTokens.Color.textSecondary)
                } else {
                    Text(FormaProductCopy.Today.Meals.notLogged)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(
                            group.isPastDueMissing
                                ? FormaTokens.Color.textSecondary
                                : FormaTokens.Color.textTertiary
                        )
                }
            }

            Spacer(minLength: 8)

            if group.isLogged {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(FormaTokens.Color.accent)
                    .accessibilityLabel("Logged")
            } else {
                Button {
                    onAddMeal(group.mealType)
                } label: {
                    Text(FormaProductCopy.Today.Meals.addAction)
                        .font(FormaTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(FormaTokens.Color.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(FormaProductCopy.Today.Meals.addAccessibilityLabel(for: group.mealType))
                .accessibilityHint(FormaProductCopy.Today.Meals.addAccessibilityHint)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.md)
    }

    @ViewBuilder
    private func loggedEntries(for group: TodayMealGroupState) -> some View {
        let isExpanded = expandedGroups.contains(group.mealType)
        let previewLimit = TodayMealsGroupingEngine.entryPreviewLimit
        let visibleEntries = isExpanded || !group.hasMultipleEntries
            ? group.entries
            : Array(group.entries.prefix(previewLimit))

        if group.hasMultipleEntries {
            VStack(spacing: 0) {
                ForEach(visibleEntries) { entry in
                    entryButton(entry)

                    if entry.id != visibleEntries.last?.id {
                        FitPilotPlanRowDivider()
                            .padding(.leading, FormaTokens.Spacing.md)
                    }
                }

                expandToggle(for: group, isExpanded: isExpanded)
            }
            .padding(.top, FormaTokens.Spacing.xs)
        } else if let entry = group.entries.first {
            entryButton(entry)
                .padding(.top, FormaTokens.Spacing.xs)
        }
    }

    private func entryButton(_ entry: FoodEntry) -> some View {
        Button {
            onEditEntry(entry)
        } label: {
            FoodTimelineRow(entry: entry, showsMealType: false)
                .padding(.horizontal, FormaTokens.Spacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityHint(FormaProductCopy.Today.Meals.editAccessibilityHint)
        .contextMenu {
            Button {
                onEditEntry(entry)
            } label: {
                Label(
                    FormaProductCopy.Today.Meals.contextMenuEdit,
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

    private func expandToggle(for group: TodayMealGroupState, isExpanded: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedGroups.remove(group.mealType)
                } else {
                    expandedGroups.insert(group.mealType)
                }
            }
        } label: {
            Text(
                isExpanded
                    ? FormaProductCopy.Today.Meals.collapseEntries
                    : FormaProductCopy.Today.Meals.expandEntries
                        + " (\(group.entries.count))"
            )
            .font(FormaTokens.Typography.caption.weight(.medium))
            .foregroundStyle(FormaTokens.Color.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Empty day") {
    TodayMealsPreview(
        entries: [],
        date: Date(),
        onAddMeal: { _ in },
        onEditEntry: { _ in },
        onDeleteEntry: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}

#Preview("Partial day") {
    TodayMealsPreview(
        entries: TodayPreviewData.foodEntries,
        date: Date(),
        onAddMeal: { _ in },
        onEditEntry: { _ in },
        onDeleteEntry: { _ in }
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
