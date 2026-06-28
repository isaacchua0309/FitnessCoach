//
//  CoachAttachmentMenu.swift
//  Fitness Coach
//
//  FitPilot AI — Expandable attachment menu for Coach composer.
//

import SwiftUI

enum CoachAttachmentOption: String, Identifiable, CaseIterable {
    case takePhoto
    case choosePhoto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .takePhoto: return "Take Photo"
        case .choosePhoto: return "Choose Photo"
        }
    }

    var symbolName: String {
        switch self {
        case .takePhoto: return "camera"
        case .choosePhoto: return "photo.on.rectangle"
        }
    }
}

struct CoachAttachmentMenu: View {
    @Binding var isPresented: Bool
    let onSelect: (CoachAttachmentOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(CoachAttachmentOption.allCases) { option in
                Button {
                    isPresented = false
                    onSelect(option)
                } label: {
                    HStack(spacing: CoachDesignTokens.Spacing.sm) {
                        Image(systemName: option.symbolName)
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 24)
                        Text(option.title)
                            .font(CoachDesignTokens.Typography.messageBody)
                        Spacer()
                    }
                    .foregroundStyle(CoachDesignTokens.Color.primaryText)
                    .padding(.horizontal, CoachDesignTokens.Spacing.md)
                    .padding(.vertical, CoachDesignTokens.Spacing.sm + 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, CoachDesignTokens.Spacing.xs)
        .background(CoachDesignTokens.Color.elevatedSurface, in: RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CoachDesignTokens.Radius.attachment, style: .continuous)
                .strokeBorder(CoachDesignTokens.Color.composerStroke, lineWidth: 0.5)
        )
    }
}

#Preview {
    CoachAttachmentMenu(isPresented: .constant(true)) { _ in }
        .padding()
        .background(CoachDesignTokens.Color.background)
        .formaThemePreview()
}
