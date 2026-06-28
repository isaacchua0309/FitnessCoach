//
//  FormaScreenErrorView.swift
//  Fitness Coach
//
//  Forma — Full-screen error state for tab dashboards.
//

import SwiftUI

struct FormaScreenErrorView: View {
    enum Style {
        /// Today and Journey: larger icon, "Retry" label.
        case tabRoot
        /// Plan and Training: compact icon, "Try again" label.
        case detailScreen
    }

    let message: String
    let onRetry: () -> Void
    var style: Style = .tabRoot

    var body: some View {
        Group {
            switch style {
            case .tabRoot:
                tabRootContent
            case .detailScreen:
                detailScreenContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }

    private var tabRootContent: some View {
        VStack(spacing: FormaTokens.Spacing.md) {
            errorIcon(size: 44, weight: .regular)
            errorMessage
            retryButton(title: FormaProductCopy.Common.retry)
        }
        .padding()
    }

    private var detailScreenContent: some View {
        VStack(spacing: FormaTokens.Spacing.sm + 2) {
            errorIcon(size: 38, weight: .semibold)
            errorMessage
            retryButton(title: FormaProductCopy.Common.tryAgain)
        }
        .padding()
    }

    private var errorMessage: some View {
        Text(message)
            .font(FormaTokens.Typography.sectionTitle)
            .foregroundStyle(FormaTokens.Color.textPrimary)
            .multilineTextAlignment(.center)
    }

    private func errorIcon(size: CGFloat, weight: Font.Weight) -> some View {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: size, weight: weight))
            .foregroundStyle(FormaTokens.Color.warning)
    }

    private func retryButton(title: String) -> some View {
        Button(title, action: onRetry)
            .buttonStyle(.borderedProminent)
            .tint(FormaTokens.Color.ctaBackground)
    }
}

#Preview("Tab root") {
    FormaScreenErrorView(
        message: FormaProductCopy.Error.loadToday,
        onRetry: {},
        style: .tabRoot
    )
    .formaThemePreview()
}

#Preview("Detail screen") {
    FormaScreenErrorView(
        message: FormaProductCopy.Error.loadProfile,
        onRetry: {},
        style: .detailScreen
    )
    .formaThemePreview()
}
