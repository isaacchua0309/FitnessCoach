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

    private static var subtleBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(FormaTokens.Color.surfaceSubtle)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FormaTokens.Color.border.opacity(0.55), lineWidth: 0.5)
            }
    }

    private static var borderedBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(FormaTokens.Color.surface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FormaTokens.Color.border, lineWidth: 1)
            }
    }

    private static func surfaceBackground(accentLeading: Bool) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(FormaTokens.Color.surface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        accentLeading
                            ? LinearGradient(
                                colors: [
                                    FormaTokens.Color.accent.opacity(0.22),
                                    FormaTokens.Color.border
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    FormaTokens.Color.accent.opacity(0.14),
                                    FormaTokens.Color.border
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
                        .fill(FormaTokens.Color.accent.opacity(0.55))
                        .frame(width: 3)
                        .padding(.vertical, FormaTokens.Spacing.sm)
                        .padding(.leading, 1)
                }
            }
    }
}
