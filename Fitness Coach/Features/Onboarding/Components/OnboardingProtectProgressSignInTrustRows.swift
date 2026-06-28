//
//  OnboardingProtectProgressSignInTrustRows.swift
//  Fitness Coach
//
//  Forma — Premium trust rows below protect-progress sign-in.
//

import SwiftUI

struct OnboardingProtectProgressSignInTrustRows: View {
    var visibleRowLimit: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.onboardingPlanRevealUsesCompactLayout) private var usesCompactLayout

    private let rows = FormaProductCopy.Onboarding.V2.SavePlan.signInTrustRows

    private var displayedRows: [FormaProductCopy.Onboarding.V2.SavePlan.SignInTrustRow] {
        let limit = visibleRowLimit ?? rows.count
        return Array(rows.prefix(max(1, limit)))
    }

    private var usesSingleColumn: Bool {
        dynamicTypeSize.isAccessibilitySize
            || dynamicTypeSize >= .accessibility1
            || usesCompactLayout
    }

    private var columns: [GridItem] {
        if usesSingleColumn {
            return [GridItem(.flexible(), spacing: FormaTokens.Spacing.xs)]
        }
        return [
            GridItem(.flexible(), spacing: FormaTokens.Spacing.sm),
            GridItem(.flexible(), spacing: FormaTokens.Spacing.sm)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: FormaTokens.Spacing.xs) {
            ForEach(displayedRows) { row in
                trustRow(icon: row.icon, title: row.title)
            }
        }
        .onboardingPlanRevealCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { OnboardingPlanRevealCardBackground(surface: .subtle) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(trustAccessibilitySummary)
    }

    private var trustAccessibilitySummary: String {
        displayedRows.map(\.title).joined(separator: ". ")
    }

    private func trustRow(icon: String, title: String) -> some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(OnboardingTheme.accent.opacity(0.1))
                    .overlay {
                        Circle()
                            .stroke(OnboardingTheme.accent.opacity(0.16), lineWidth: 1)
                    }

                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(usesSingleColumn ? 3 : 2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(title)
    }
}

#if DEBUG
#Preview {
    OnboardingProtectProgressSignInTrustRows(visibleRowLimit: 5)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
}

#Preview("Compact limit") {
    OnboardingProtectProgressSignInTrustRows(visibleRowLimit: 3)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .environment(\.onboardingPlanRevealUsesCompactLayout, true)
}

#Preview("Large Dynamic Type") {
    OnboardingProtectProgressSignInTrustRows(visibleRowLimit: 3)
        .padding()
        .background(OnboardingTheme.background)
        .formaThemePreview()
        .dynamicTypeSize(.accessibility2)
}
#endif
