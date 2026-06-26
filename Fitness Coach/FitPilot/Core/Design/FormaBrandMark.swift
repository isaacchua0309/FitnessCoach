//
//  FormaBrandMark.swift
//  Fitness Coach
//
//  Forma — Reusable premium brand orb for dark surfaces.
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

    @ScaledMetric(relativeTo: .largeTitle) private var smallOrb: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var mediumOrb: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var largeOrb: CGFloat = 72

    var body: some View {
        ZStack {
            outerRing

            innerOrb

            structureGlyph
                .opacity(0.22)

            monogram
        }
        .frame(width: ringDiameter, height: ringDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(accessibilityMode == .decorative)
        .accessibilityLabel(FormaProductCopy.appName)
        .accessibilityAddTraits(accessibilityMode == .branded ? .isImage : [])
    }

    // MARK: - Layers

    private var outerRing: some View {
        Circle()
            .stroke(
                LinearGradient(
                    colors: [
                        FormaTokens.Color.accent.opacity(0.45),
                        FormaTokens.Color.accent.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: ringLineWidth
            )
            .frame(width: ringDiameter, height: ringDiameter)
    }

    private var innerOrb: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        FormaTokens.Color.accent.opacity(0.22),
                        FormaTokens.Color.accent.opacity(0.06)
                    ],
                    center: .center,
                    startRadius: 2,
                    endRadius: orbDiameter * 0.55
                )
            )
            .frame(width: orbDiameter, height: orbDiameter)
            .overlay {
                Circle()
                    .stroke(FormaTokens.Color.border, lineWidth: 0.5)
                    .frame(width: orbDiameter, height: orbDiameter)
            }
    }

    private var structureGlyph: some View {
        Image(systemName: "circle.hexagongrid")
            .font(.system(size: glyphSize, weight: .light))
            .foregroundStyle(FormaTokens.Color.textPrimary)
    }

    private var monogram: some View {
        Text("F")
            .font(.system(size: monogramSize, weight: .semibold, design: .rounded))
            .foregroundStyle(FormaTokens.Color.accent)
    }

    // MARK: - Metrics

    private var orbDiameter: CGFloat {
        switch size {
        case .small: smallOrb
        case .medium: mediumOrb
        case .large: largeOrb
        }
    }

    private var ringDiameter: CGFloat {
        orbDiameter + ringInset * 2
    }

    private var ringInset: CGFloat {
        switch size {
        case .small: 4
        case .medium: 6
        case .large: 8
        }
    }

    private var ringLineWidth: CGFloat {
        switch size {
        case .small: 1
        case .medium: 1.2
        case .large: 1.4
        }
    }

    private var monogramSize: CGFloat {
        orbDiameter * 0.42
    }

    private var glyphSize: CGFloat {
        orbDiameter * 0.78
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
