//
//  FitPilotScreenStyle.swift
//  Fitness Coach
//
//  FitPilot — Shared visual tokens for Plan, Settings, and Account.
//

import SwiftUI

enum FitPilotScreenStyle {
    static let horizontalPadding = FormaTokens.Spacing.pageHorizontal
    static let sectionSpacing: CGFloat = 22
    static let rowMinHeight = FormaTokens.Layout.minTouchTarget
    static let rowVerticalPadding: CGFloat = 11
    static let cardCornerRadius = FormaTokens.Radius.compact
    static let scrollBottomInset = FormaTokens.Layout.tabBarScrollPadding

    static let settingsRowInsets = EdgeInsets(
        top: FitPilotScreenStyle.rowVerticalPadding,
        leading: FormaTokens.Spacing.md,
        bottom: FitPilotScreenStyle.rowVerticalPadding,
        trailing: FormaTokens.Spacing.md
    )

    static let activeRowBackground = FormaTokens.Color.surface
    static let disabledRowBackground = FormaTokens.Color.surfaceSubtle
}

// MARK: - Plan

struct FitPilotPlanCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                    .fill(FormaTokens.Color.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: FitPilotScreenStyle.cardCornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        FormaTokens.Color.accent.opacity(0.14),
                                        FormaTokens.Color.border
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
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
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.sm) {
                    Text(label)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .frame(width: 88, alignment: .leading)
                    Text(value)
                        .font(FormaTokens.Typography.sectionSubtitle)
                        .foregroundStyle(FormaTokens.Color.textPrimary)
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
            .overlay(FormaTokens.Color.border)
    }
}

// MARK: - Settings

struct FitPilotSettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textSecondary)
            .textCase(nil)
    }
}

struct FitPilotComingSoonRow: View {
    let title: String

    var body: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.textTertiary)
            Spacer(minLength: 8)
            Text("Coming soon")
                .font(FormaTokens.Typography.caption)
                .foregroundStyle(FormaTokens.Color.textTertiary.opacity(0.9))
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
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }

    func fitPilotDarkGroupedList() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .tint(FormaTokens.Color.accent)
    }

    func fitPilotScrollBottomInset() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: FitPilotScreenStyle.scrollBottomInset)
        }
    }

    func fitPilotFormScreen() -> some View {
        self
            .background(FormaTokens.Color.canvas.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .fitPilotScrollBottomInset()
    }

    func fitPilotFormSection() -> some View {
        listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    func fitPilotSettingsRowChrome(isEnabled: Bool = true) -> some View {
        listRowInsets(FitPilotScreenStyle.settingsRowInsets)
            .listRowBackground(
                isEnabled
                    ? FitPilotScreenStyle.activeRowBackground
                    : FitPilotScreenStyle.disabledRowBackground
            )
    }
}
