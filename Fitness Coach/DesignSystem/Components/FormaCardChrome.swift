//
//  FormaCardChrome.swift
//  Fitness Coach
//
//  Forma — Shared card backgrounds for dashboard and settings surfaces.
//

import SwiftUI

enum FormaCardChrome {

    enum Style {
        /// Default accent-gradient bordered card (`FormaPlanCard`).
        case surface
        /// Muted metrics card (Today targets).
        case surfaceSubtle
        /// Action card with leading accent stripe (Today next actions).
        case accentLeading
        /// Flat border without accent gradient.
        case bordered
    }

    static let cornerRadius = FormaTokens.Radius.compact

    @ViewBuilder
    static func background(_ style: Style) -> some View {
        FormaCardChromeBackground(style: style)
    }
}

/// Environment-backed card chrome so palette changes repaint without app relaunch.
private struct FormaCardChromeBackground: View {
    let style: FormaCardChrome.Style

    @Environment(\.themePalette) private var palette
    @Environment(\.formaColors) private var colors

    var body: some View {
        switch style {
        case .surface:
            surfaceBackground(accentLeading: false)
        case .surfaceSubtle:
            subtleBackground
        case .accentLeading:
            surfaceBackground(accentLeading: true)
        case .bordered:
            borderedBackground
        }
    }

    private var subtleBackground: some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(colors.surfaceSubtle)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(colors.border.opacity(0.55), lineWidth: 0.5)
            }
    }

    private var borderedBackground: some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(colors.border, lineWidth: 1)
            }
    }

    private func surfaceBackground(accentLeading: Bool) -> some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(
                        accentLeading
                            ? LinearGradient(
                                colors: [
                                    palette.primary.opacity(0.22),
                                    colors.border
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    palette.primary.opacity(0.14),
                                    colors.border
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .leading) {
                if accentLeading {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.primary.opacity(0.55))
                        .frame(width: 3)
                        .padding(.vertical, FormaTokens.Spacing.sm)
                        .padding(.leading, 1)
                }
            }
    }
}
