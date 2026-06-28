//
//  FormaScreenLoadingView.swift
//  Fitness Coach
//
//  Forma — Full-screen loading state for tab dashboards.
//

import SwiftUI

struct FormaScreenLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: FormaTokens.Spacing.sm) {
            SwiftUI.ProgressView()
                .tint(FormaTokens.Color.accent)
            Text(message)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FormaTokens.Color.canvas)
    }
}

#Preview {
    FormaScreenLoadingView(message: FormaProductCopy.Loading.today)
        .formaThemePreview()
}
