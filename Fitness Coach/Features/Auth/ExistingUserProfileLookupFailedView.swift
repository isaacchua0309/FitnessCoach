//
//  ExistingUserProfileLookupFailedView.swift
//  Fitness Coach
//
//  Forma — Retry UI when profile lookup fails during returning-member sign-in.
//

import SwiftUI

struct ExistingUserProfileLookupFailedView: View {

    let onRetry: () -> Void

    private let copy = FormaProductCopy.PublicEntry.ExistingUserSignIn.ProfileLookupFailed.self

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        PublicEntryErrorScreen(
            title: copy.title,
            bodyCopy: copy.body,
            retryCTA: copy.retryCTA,
            palette: palette,
            onRetry: onRetry
        )
    }
}
