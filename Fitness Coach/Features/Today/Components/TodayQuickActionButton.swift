//
//  TodayQuickActionButton.swift
//  Fitness Coach
//
//  Forma — Floating quick-log menu for Today (above tab bar).
//

import SwiftUI

struct TodayQuickActionButton: View {
    let menuItems: [TodayQuickActionMenuItem]
    let onSelect: (TodayQuickActionKind) -> Void

    var body: some View {
        Menu {
            ForEach(menuItems) { item in
                if item.isEnabled {
                    Button {
                        onSelect(item.kind)
                    } label: {
                        Label {
                            Text(FormaProductCopy.Today.QuickActions.title(for: item.kind))
                        } icon: {
                            Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: item.kind))
                        }
                    }
                } else {
                    Button {} label: {
                        Label {
                            Text(FormaProductCopy.Today.QuickActions.title(for: item.kind))
                        } icon: {
                            Image(systemName: FormaProductCopy.Today.QuickActions.symbolName(for: item.kind))
                        }
                    }
                    .disabled(true)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(FormaTokens.Color.textPrimary)
                .frame(width: FormaTokens.Layout.minTouchTarget + 8, height: FormaTokens.Layout.minTouchTarget + 8)
                .background(FormaTokens.Color.accent, in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .accessibilityLabel(FormaProductCopy.Today.QuickActions.fabAccessibilityLabel)
        .accessibilityHint(FormaProductCopy.Today.QuickActions.fabAccessibilityHint)
    }
}

#Preview {
    ZStack(alignment: .bottomTrailing) {
        FormaTokens.Color.canvas.ignoresSafeArea()
        TodayQuickActionButton(
            menuItems: TodayQuickActionPolicy.menuItems(isScanFoodAvailable: false),
            onSelect: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
