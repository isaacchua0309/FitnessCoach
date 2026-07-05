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

    @Environment(\.theme) private var theme
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let _ = themeManager.themeRevision
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
            .fill(theme.accentSoftBackground)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(theme.inputBorder.opacity(0.55), lineWidth: 0.5)
            }
    }

    private var borderedBackground: some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(theme.inputBorder, lineWidth: 1)
            }
    }

    private func surfaceBackground(accentLeading: Bool) -> some View {
        RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
            .fill(theme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: FormaCardChrome.cornerRadius, style: .continuous)
                    .stroke(
                        accentLeading
                            ? LinearGradient(
                                colors: [
                                    theme.accent.opacity(0.22),
                                    theme.inputBorder
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    theme.accent.opacity(0.14),
                                    theme.inputBorder
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
                        .fill(theme.accentLine)
                        .frame(width: 3)
                        .padding(.vertical, FormaTokens.Spacing.sm)
                        .padding(.leading, 1)
                }
            }
    }
}
