//
//  FormaTransientBanner.swift
//  Fitness Coach
//
//  Forma — Non-blocking bottom banner for transient errors and notices.
//

import SwiftUI

struct FormaTransientBanner: View {
    let message: String
    var style: Style = .error

    enum Style: Equatable {
        case success
        case error
    }

    var body: some View {
        Text(message)
            .font(FormaTokens.Typography.bodyMedium)
            .foregroundStyle(foregroundColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, FormaTokens.Spacing.md)
            .padding(.vertical, FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: FormaTokens.Radius.button, style: .continuous)
                    .fill(backgroundColor)
            )
            .shadow(color: FormaTokens.Color.shadow.opacity(0.18), radius: 10, y: 4)
            .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
            .accessibilityAddTraits(.isStaticText)
    }

    private var backgroundColor: SwiftUI.Color {
        switch style {
        case .success:
            return FormaTokens.Theme.primary.opacity(0.94)
        case .error:
            return FormaTokens.Color.destructive.opacity(0.94)
        }
    }

    private var foregroundColor: SwiftUI.Color {
        switch style {
        case .success:
            return FormaTokens.Theme.textOnAccent
        case .error:
            return FormaTokens.Color.ctaText
        }
    }
}

#Preview {
    VStack(spacing: FormaTokens.Spacing.md) {
        Spacer()
        FormaTransientBanner(message: "Added 500 ml", style: .success)
        FormaTransientBanner(message: "Couldn't add water. Try again.", style: .error)
    }
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
