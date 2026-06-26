//
//  FitPilotScreenStyle.swift
//  Fitness Coach
//
//  FitPilot — Shared visual tokens for Plan, Settings, and Account.
//

import SwiftUI

enum FitPilotScreenStyle {
    static let horizontalPadding = OnboardingTheme.pagePadding
    static let sectionSpacing: CGFloat = 22
    static let rowMinHeight: CGFloat = 44
    static let rowVerticalPadding: CGFloat = 11
    static let cardCornerRadius = OnboardingTheme.compactCornerRadius
    static let scrollBottomInset: CGFloat = 20
}

// MARK: - Plan

struct FitPilotPlanCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardShape.fill(OnboardingTheme.card))
            .overlay(cardShape.stroke(OnboardingTheme.border, lineWidth: 1))
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
    }
}

struct FitPilotPlanDisplayRow: View {
    let label: String
    let value: String
    var multilineValue = false

    var body: some View {
        Group {
            if multilineValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .frame(width: 88, alignment: .leading)
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight, alignment: .center)
        .padding(.vertical, 2)
    }
}

struct FitPilotPlanRowDivider: View {
    var body: some View {
        Divider()
            .overlay(OnboardingTheme.border)
    }
}

// MARK: - Settings

struct FitPilotSettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(OnboardingTheme.secondaryText)
            .textCase(nil)
    }
}

struct FitPilotComingSoonRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(OnboardingTheme.tertiaryText)
            Spacer(minLength: 8)
            Text("Coming soon")
                .font(.caption)
                .foregroundStyle(OnboardingTheme.tertiaryText.opacity(0.85))
        }
        .frame(minHeight: FitPilotScreenStyle.rowMinHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), coming soon")
    }
}

// MARK: - Screen chrome

extension View {
    func fitPilotDarkScreenBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(OnboardingTheme.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }

    func fitPilotDarkGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .fitPilotDarkScreenBackground()
    }

    func fitPilotScrollBottomInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: FitPilotScreenStyle.scrollBottomInset)
        }
    }
}
