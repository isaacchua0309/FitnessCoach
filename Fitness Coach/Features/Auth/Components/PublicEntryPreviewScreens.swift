//
//  PublicEntryPreviewScreens.swift
//  Fitness Coach
//
//  Forma — Xcode previews for public entry surfaces.
//

import SwiftUI

#if DEBUG
enum PublicEntryPreviewScreens {

    private static let analytics = NoOpPublicEntryAnalyticsLogger()

    @ViewBuilder
    static func welcome(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        PublicWelcomeView(
            analyticsLogger: analytics,
            onCreateMyPlan: {},
            onSignIn: {}
        )
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func existingSignIn(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark,
        localError: ExistingUserSignInFailureKind? = nil
    ) -> some View {
        ExistingUserSignInView(
            analyticsLogger: analytics,
            localError: localError,
            onBack: {},
            onCreateMyPlan: {},
            onSignInRequested: {}
        )
        .environmentObject(AuthManager())
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func noExistingProfile(
        palette: AppThemePalette = .oceanBlue,
        appearance: AppAppearanceMode = .dark
    ) -> some View {
        NoExistingProfileFoundView(
            analyticsLogger: analytics,
            onStartOnboarding: {},
            onUseAnotherAccount: {}
        )
        .formaThemePreview(appearance: appearance, palette: palette)
    }

    @ViewBuilder
    static func appLaunchLoading(palette: AppThemePalette = .default) -> some View {
        LaunchLoadingView()
            .formaThemePreview(palette: palette)
    }

    @ViewBuilder
    static func restoringPlanLoading(palette: AppThemePalette = .default) -> some View {
        ExistingUserSignInResolvingView()
            .formaThemePreview(palette: palette)
    }

    @ViewBuilder
    static func profileLookupFailed(palette: AppThemePalette = .default) -> some View {
        ExistingUserProfileLookupFailedView(onRetry: {})
            .formaThemePreview(palette: palette)
    }

    @ViewBuilder
    static func failureBanner(
        kind: ExistingUserSignInFailureKind,
        palette: AppThemePalette = .default
    ) -> some View {
        PublicEntryFailureBannerPreview(kind: kind)
            .formaThemePreview(palette: palette)
    }
}

private struct PublicEntryFailureBannerPreview: View {
    let kind: ExistingUserSignInFailureKind

    @Environment(\.formaResolvedTheme) private var resolvedTheme

    private var presentation: ExistingUserSignInPolicy.FailurePresentation {
        ExistingUserSignInPolicy.presentation(for: kind)
    }

    private var palette: PublicWelcomeTheme.Palette {
        PublicWelcomeTheme.palette(from: resolvedTheme)
    }

    var body: some View {
        PublicEntryFailureBanner(
            title: presentation.title,
            message: presentation.message,
            palette: palette
        )
        .padding(.horizontal, FormaTokens.Spacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PublicEntryScreenBackground(palette: palette))
    }
}

#Preview("Welcome — Ocean Blue") {
    PublicEntryPreviewScreens.welcome()
}

#Preview("Welcome — Blossom Pink") {
    PublicEntryPreviewScreens.welcome(palette: .blossomPink)
}

#Preview("Welcome — Emerald Green") {
    PublicEntryPreviewScreens.welcome(palette: .emeraldGreen)
}

#Preview("Welcome — Sunset Orange") {
    PublicEntryPreviewScreens.welcome(palette: .sunsetOrange)
}

#Preview("Existing sign-in — Ocean Blue") {
    PublicEntryPreviewScreens.existingSignIn()
}

#Preview("Existing sign-in — Blossom Pink") {
    PublicEntryPreviewScreens.existingSignIn(palette: .blossomPink)
}

#Preview("Existing sign-in — Emerald Green") {
    PublicEntryPreviewScreens.existingSignIn(palette: .emeraldGreen)
}

#Preview("Existing sign-in — auth failed") {
    PublicEntryPreviewScreens.existingSignIn(localError: .authFailed)
}

#Preview("Existing sign-in — network failed") {
    PublicEntryPreviewScreens.existingSignIn(localError: .networkFailed)
}

#Preview("Existing sign-in — cancelled") {
    PublicEntryPreviewScreens.existingSignIn(localError: .authCancelled)
}

#Preview("No profile found — Default") {
    PublicEntryPreviewScreens.noExistingProfile()
}

#Preview("No profile found — Blossom Pink") {
    PublicEntryPreviewScreens.noExistingProfile(palette: .blossomPink)
}

#Preview("No profile found — Emerald Green") {
    PublicEntryPreviewScreens.noExistingProfile(palette: .emeraldGreen)
}

#Preview("Loading — app launch") {
    PublicEntryPreviewScreens.appLaunchLoading()
}

#Preview("Loading — restoring plan") {
    PublicEntryPreviewScreens.restoringPlanLoading()
}

#Preview("Error — profile lookup failed") {
    PublicEntryPreviewScreens.profileLookupFailed()
}

#Preview("Error — failure banner") {
    PublicEntryPreviewScreens.failureBanner(kind: .profileLookupFailed)
}
#endif
