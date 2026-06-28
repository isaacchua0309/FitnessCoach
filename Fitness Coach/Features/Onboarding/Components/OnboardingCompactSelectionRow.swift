//
//  OnboardingCompactSelectionRow.swift
//  Fitness Coach
//
//  Forma — Compact selectable row for onboarding option lists.
//

import SwiftUI

struct OnboardingCompactSelectionRow: View {
    let title: String
    var subtitle: String?
    var icon: String = "circle"
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var showsSubtitle: Bool {
        guard let subtitle, !subtitle.isEmpty else { return false }
        return dynamicTypeSize < .accessibility1
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? OnboardingTheme.accent : OnboardingTheme.secondaryText)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if showsSubtitle, let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, OnboardingLayout.compactCardPadding)
            .frame(minHeight: OnboardingLayout.selectionRowMinHeight, alignment: .center)
            .background(isSelected ? OnboardingTheme.accentMuted : Color.clear)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: OnboardingTheme.compactCornerRadius, style: .continuous)
                        .stroke(OnboardingTheme.selectedBorder, lineWidth: 1.2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityLabel: String {
        let base = subtitle.map { "\(title), \($0)" } ?? title
        return isSelected ? "\(base), selected" : base
    }
}

struct OnboardingCompactSelectionList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .onboardingCompactCard()
    }
}

#Preview("Rows") {
    VStack(spacing: 0) {
        OnboardingCompactSelectionList {
            OnboardingCompactSelectionRow(
                title: "Feel confident in clothes",
                subtitle: "Steady progress without extremes.",
                icon: "sparkles",
                isSelected: true,
                action: {}
            )
            Divider().overlay(OnboardingTheme.border)
            OnboardingCompactSelectionRow(
                title: "Improve health",
                subtitle: "Support sleep, recovery, and how you feel.",
                icon: "heart.fill",
                isSelected: false,
                action: {}
            )
        }
    }
    .padding()
    .background(OnboardingTheme.background)
    .formaThemePreview()
}
