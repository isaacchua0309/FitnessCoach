//
//  AdjustPlanHeader.swift
//  Fitness Coach
//
//  Forma — Navigation toolbar chrome for the Adjust Plan flow.
//

import SwiftUI

enum AdjustPlanHeaderLayout {
    static let actionMinWidth: CGFloat = 64
}

struct AdjustPlanHeader: ViewModifier {
    let title: String
    let confirmationTitle: String
    let showsConfirmation: Bool
    let isConfirmationEnabled: Bool
    let isConfirmationLoading: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.formaPlanColors) private var theme

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .tint(theme.accent)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(FormaProductCopy.PlanEditCommon.cancel, action: onCancel)
                        .frame(
                            minWidth: AdjustPlanHeaderLayout.actionMinWidth,
                            alignment: .leading
                        )
                }

                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(FormaTokens.Typography.sectionSubtitle.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if showsConfirmation {
                        Button(action: onConfirm) {
                            Group {
                                if isConfirmationLoading {
                                    SwiftUI.ProgressView()
                                        .tint(theme.accent)
                                } else {
                                    Text(confirmationTitle)
                                }
                            }
                        }
                        .foregroundStyle(confirmActionColor)
                        .disabled(!isConfirmationEnabled || isConfirmationLoading)
                        .frame(
                            minWidth: AdjustPlanHeaderLayout.actionMinWidth,
                            alignment: .trailing
                        )
                    }
                }
            }
    }

    private var confirmActionColor: Color {
        isConfirmationEnabled && !isConfirmationLoading
            ? theme.accent
            : theme.disabledAction
    }
}

extension View {
    func adjustPlanHeader(
        title: String,
        confirmationTitle: String,
        showsConfirmation: Bool,
        isConfirmationEnabled: Bool,
        isConfirmationLoading: Bool,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            AdjustPlanHeader(
                title: title,
                confirmationTitle: confirmationTitle,
                showsConfirmation: showsConfirmation,
                isConfirmationEnabled: isConfirmationEnabled,
                isConfirmationLoading: isConfirmationLoading,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        )
    }
}
