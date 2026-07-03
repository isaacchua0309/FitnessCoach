//
//  FormaTransientBanner.swift
//  Fitness Coach
//
//  Forma — Non-blocking bottom banner for transient errors and notices.
//

import SwiftUI

struct FormaTransientBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(FormaTokens.Typography.bodyMedium)
            .foregroundStyle(FormaTokens.Color.ctaText)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .fill(FormaTokens.Color.destructive.opacity(0.94))
            )
            .shadow(color: FormaTokens.Color.shadow.opacity(0.18), radius: 10, y: 4)
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    VStack {
        Spacer()
        FormaTransientBanner(message: "Couldn't log water. Try again.")
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
