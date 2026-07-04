//
//  FormaPlanTokens.swift
//  Fitness Coach
//
//  Forma — Static facade for Edit / Adjust Plan semantic design tokens.
//

import SwiftUI

enum FormaPlanTokens {

    // MARK: - Colors

    /// Semantic color facade for the Edit / Adjust Plan flow.
    ///
    /// Resolves through `FormaThemeAccess.currentPlanColors`, updated at the app root.
    /// In SwiftUI views, prefer `@Environment(\.formaPlanColors)` when possible.
    enum Color {
        @MainActor
        private static var active: FormaPlanColors {
            FormaThemeAccess.currentPlanColors
        }

        @MainActor
        static var planBackground: SwiftUI.Color { active.planBackground }
        @MainActor
        static var planSurface: SwiftUI.Color { active.planSurface }
        @MainActor
        static var planElevatedSurface: SwiftUI.Color { active.planElevatedSurface }
        @MainActor
        static var planPrimaryText: SwiftUI.Color { active.planPrimaryText }
        @MainActor
        static var planSecondaryText: SwiftUI.Color { active.planSecondaryText }
        @MainActor
        static var planMutedText: SwiftUI.Color { active.planMutedText }
        @MainActor
        static var planAccent: SwiftUI.Color { active.planAccent }
        @MainActor
        static var planAccentSoft: SwiftUI.Color { active.planAccentSoft }
        @MainActor
        static var planSuccess: SwiftUI.Color { active.planSuccess }
        @MainActor
        static var planSuccessSoft: SwiftUI.Color { active.planSuccessSoft }
        @MainActor
        static var planSuccessBorder: SwiftUI.Color { active.planSuccessBorder }
        @MainActor
        static var planWarning: SwiftUI.Color { active.planWarning }
        @MainActor
        static var planWarningSoft: SwiftUI.Color { active.planWarningSoft }
        @MainActor
        static var planWarningBorder: SwiftUI.Color { active.planWarningBorder }
        @MainActor
        static var planDanger: SwiftUI.Color { active.planDanger }
        @MainActor
        static var planDivider: SwiftUI.Color { active.planDivider }
        @MainActor
        static var planInputBackground: SwiftUI.Color { active.planInputBackground }
        @MainActor
        static var planInputBorder: SwiftUI.Color { active.planInputBorder }
        @MainActor
        static var planCardBorder: SwiftUI.Color { active.planCardBorder }
        @MainActor
        static var planSubtleCardBorder: SwiftUI.Color { active.planSubtleCardBorder }
        @MainActor
        static var planSelectedBorder: SwiftUI.Color { active.planSelectedBorder }
        @MainActor
        static var planAccentBorder: SwiftUI.Color { active.planAccentBorder }
        @MainActor
        static var planAccentHighlight: SwiftUI.Color { active.planAccentHighlight }
        @MainActor
        static var planDisabledAction: SwiftUI.Color { active.planDisabledAction }
        @MainActor
        static var planUpToDateBackground: SwiftUI.Color { active.planUpToDateBackground }
        @MainActor
        static var planProgressTrack: SwiftUI.Color { active.planProgressTrack }
        @MainActor
        static var planProgressFill: SwiftUI.Color { active.planProgressFill }
        @MainActor
        static var planSelectedCardBackground: SwiftUI.Color { active.planSelectedCardBackground }
        @MainActor
        static var planUnselectedCardBackground: SwiftUI.Color { active.planUnselectedCardBackground }

        /// Prominent button fill — uses theme gradient anchor for CTA consistency.
        @MainActor
        static var planAccentButton: SwiftUI.Color {
            FormaThemeAccess.currentThemePalette.primaryButtonBackground
        }
    }
}

// MARK: - Plan card chrome (Edit Plan flow)

enum PlanEditCardChrome {

    static let cornerRadius = FormaTokens.Radius.compact

    @ViewBuilder
    static func background() -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(FormaPlanTokens.Color.planSurface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                FormaPlanTokens.Color.planAccentHighlight,
                                FormaPlanTokens.Color.planCardBorder
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
    }
}

struct PlanEditCard<Content: View>: View {
    var compact: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, compact ? FormaTokens.Spacing.sm : FormaTokens.Spacing.md)
            .padding(.vertical, compact ? FormaTokens.Spacing.xs : FormaTokens.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PlanEditCardChrome.background())
    }
}
