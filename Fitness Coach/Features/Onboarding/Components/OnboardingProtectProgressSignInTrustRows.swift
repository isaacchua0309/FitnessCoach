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

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(displayedRows) { row in
                trustRow(icon: row.icon, title: row.title)
            }
        }
        .padding(.horizontal, FormaTokens.Spacing.sm)
        .padding(.vertical, FormaTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .fill(FormaTokens.Color.surfaceSubtle)
        }
        .overlay {
            RoundedRectangle(cornerRadius: FormaTokens.Radius.compact, style: .continuous)
                .stroke(OnboardingTheme.border.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(trustAccessibilitySummary)
    }

    private var rowSpacing: CGFloat {
        usesSingleColumn ? 6 : 8
    }

    private var trustAccessibilitySummary: String {
        displayedRows.map(\.title).joined(separator: ". ")
    }

    private func trustRow(icon: String, title: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: FormaTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.accent)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(usesSingleColumn ? 3 : 2)
                .minimumScaleFactor(0.9)
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
