//
//  FormaEmptyStateCard.swift
//  Fitness Coach
//
//  Forma — FormaPlanCard wrapper for FormaInlineEmptyState.
//

import SwiftUI

struct FormaEmptyStateCard<Leading: View>: View {
    var title: String?
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var actionAccessibilityHint: String?
    private let includesLeading: Bool
    @ViewBuilder private var leading: Leading

    init(
        title: String? = nil,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        actionAccessibilityHint: String? = nil
    ) where Leading == EmptyView {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.actionAccessibilityHint = actionAccessibilityHint
        self.includesLeading = false
        self.leading = EmptyView()
    }

    init(
        title: String? = nil,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        actionAccessibilityHint: String? = nil,
        @ViewBuilder leading: () -> Leading
    ) {
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.actionAccessibilityHint = actionAccessibilityHint
        self.includesLeading = true
        self.leading = leading()
    }

    var body: some View {
        FormaPlanCard {
            if includesLeading {
                VStack(alignment: .leading, spacing: FormaTokens.Spacing.sm) {
                    leading
                    inlineEmptyState
                }
            } else {
                inlineEmptyState
            }
        }
    }

    private var inlineEmptyState: some View {
        FormaInlineEmptyState(
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action,
            actionAccessibilityHint: actionAccessibilityHint
        )
    }
}

#Preview("With action") {
    FormaEmptyStateCard(
        title: "No meals yet",
        message: "Log your first meal with Coach.",
        actionTitle: "Log meal",
        action: {}
    )
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}

#Preview("With leading icon") {
    FormaEmptyStateCard(
        title: "No workouts yet",
        message: "Workouts from Apple Health will appear here."
    ) {
        Image(systemName: "heart.text.square")
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(FormaTokens.Color.accent)
    }
    .padding()
    .background(FormaTokens.Color.canvas)
    .formaThemePreview()
}
