//
//  FormaActionRow.swift
//  Fitness Coach
//
//  Forma — Navigation rows: link accent, inline chevron, or in-card promo.
//

import SwiftUI

struct FormaActionRow<Leading: View>: View {
    enum Style {
        case linkAccent
        case navigation
        case card(
            systemImage: String,
            usesLegalText: Bool = false,
            verticalAlignment: VerticalAlignment = .center
        )
    }

    let title: String
    var subtitle: String?
    var style: Style
    @ViewBuilder var leading: Leading

    init(
        title: String,
        subtitle: String? = nil,
        style: Style,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.leading = leading()
    }

    var body: some View {
        switch style {
        case .linkAccent:
            linkAccentContent
        case .navigation:
            navigationContent
        case .card(let systemImage, let usesLegalText, let verticalAlignment):
            cardContent(
                systemImage: systemImage,
                usesLegalText: usesLegalText,
                verticalAlignment: verticalAlignment
            )
        }
    }

    private var linkAccentContent: some View {
        HStack(spacing: FormaTokens.Spacing.sm) {
            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.accent)

            Spacer(minLength: 0)

            FormaNavigationChevron()
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .contentShape(Rectangle())
    }

    private var navigationContent: some View {
        HStack(alignment: .center, spacing: FormaTokens.Spacing.sm) {
            leading

            Text(title)
                .font(FormaTokens.Typography.sectionSubtitle)
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            FormaNavigationChevron()
        }
        .frame(minHeight: FormaTokens.Layout.minTouchTarget, alignment: .center)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private func cardContent(
        systemImage: String,
        usesLegalText: Bool,
        verticalAlignment: VerticalAlignment
    ) -> some View {
        HStack(
            alignment: verticalAlignment == .center ? .center : .top,
            spacing: FormaTokens.Spacing.sm
        ) {
            Image(systemName: systemImage)
                .font(FormaTokens.Typography.body)
                .foregroundStyle(FormaTokens.Color.accent)

            VStack(alignment: .leading, spacing: FormaTokens.Spacing.xs) {
                Text(title)
                    .font(
                        usesLegalText
                            ? FormaTokens.Typography.sectionSubtitle
                            : FormaTokens.Typography.sectionSubtitle.weight(.semibold)
                    )
                    .foregroundStyle(
                        usesLegalText
                            ? FormaTokens.Color.textLegal
                            : FormaTokens.Color.textPrimary
                    )
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle {
                    Text(subtitle)
                        .font(FormaTokens.Typography.caption)
                        .foregroundStyle(FormaTokens.Color.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            FormaNavigationChevron()
        }
        .frame(
            minHeight: verticalAlignment == .center ? FormaTokens.Layout.minTouchTarget : nil,
            alignment: .center
        )
    }
}

extension FormaActionRow where Leading == EmptyView {
    init(title: String, subtitle: String? = nil, style: Style) {
        self.init(title: title, subtitle: subtitle, style: style) {
            EmptyView()
        }
    }
}

struct FormaNavigationChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(FormaTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(FormaTokens.Color.textTertiary)
            .accessibilityHidden(true)
    }
}

#Preview("Link") {
    FormaActionRow(
        title: "Manage connection",
        style: .linkAccent
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("Card") {
    FormaPlanCard {
        FormaActionRow(
            title: "Update today with Coach",
            subtitle: "Log meals, water, weight, or training.",
            style: .card(systemImage: "bubble.left.and.bubble.right")
        )
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
