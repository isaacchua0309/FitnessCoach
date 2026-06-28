//
//  LaunchLoadingView.swift
//  Fitness Coach
//
//  FitPilot — Launch splash while auth session is being determined.
//

import SwiftUI

struct LaunchLoadingView: View {

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        PublicEntryLoadingView(
            message: FormaProductCopy.PublicEntry.Loading.appLaunch,
            palette: palette
        )
    }
}
