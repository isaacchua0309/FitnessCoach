//
//  AccountRestoreFailedView.swift
//  Fitness Coach
//
//  Forma — Retry UI when account data restore fails after sign-in.
//

import SwiftUI

struct AccountRestoreFailedView: View {

    let message: String
    let onRetry: () -> Void

    private let copy = FormaProductCopy.AccountRestore.Failed.self

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        PublicEntryErrorScreen(
            title: copy.title,
            bodyCopy: message,
            retryCTA: copy.retryCTA,
            palette: palette,
            onRetry: onRetry
        )
    }
}
