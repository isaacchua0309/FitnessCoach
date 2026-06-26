//
//  FormaBrandMark.swift
//  Fitness Coach
//
//  Forma — In-app brand mark sourced from the App Icon asset.
//

import SwiftUI

struct FormaBrandMark: View {

    enum Size {
        case small
        case medium
        case large
    }

    enum AccessibilityMode {
        /// Hidden from VoiceOver when adjacent copy carries the brand (e.g. sign-in hero).
        case decorative
        /// Exposes "Forma" when the mark is the primary brand identifier.
        case branded
    }

    var size: Size = .medium
    var accessibilityMode: AccessibilityMode = .decorative

    @ScaledMetric(relativeTo: .largeTitle) private var smallSide: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var mediumSide: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var largeSide: CGFloat = 72

    var body: some View {
        Image("FormaAppIcon")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: sideLength, height: sideLength)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: sideLength * Self.iconCornerRadiusRatio,
                    style: .continuous
                )
            )
            .accessibilityElement(children: .ignore)
            .accessibilityHidden(accessibilityMode == .decorative)
            .accessibilityLabel(FormaProductCopy.appName)
            .accessibilityAddTraits(accessibilityMode == .branded ? .isImage : [])
    }

    /// Matches the iOS app-icon squircle proportion.
    private static let iconCornerRadiusRatio: CGFloat = 0.2237

    private var sideLength: CGFloat {
        switch size {
        case .small: smallSide
        case .medium: mediumSide
        case .large: largeSide
        }
    }
}

#Preview("Sizes") {
    VStack(spacing: 32) {
        FormaBrandMark(size: .small)
        FormaBrandMark(size: .medium)
        FormaBrandMark(size: .large)
        FormaBrandMark(size: .medium, accessibilityMode: .branded)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(FormaTokens.Color.canvas)
    .preferredColorScheme(.dark)
}
