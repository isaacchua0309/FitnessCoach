//
//  ChatMessageView.swift
//  Fitness Coach
//
//  FitPilot AI — Renders a single chat message by role.
//

import SwiftUI

struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user:
            bubble(alignment: .trailing)
        case .assistant:
            bubble(alignment: .leading)
        case .system:
            systemMessage
        }
    }

    private func bubble(alignment: HorizontalAlignment) -> some View {
        HStack {
            if alignment == .trailing { Spacer(minLength: 40) }

            Text(message.text)
                .font(.body)
                .foregroundStyle(alignment == .trailing ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    alignment == .trailing ? Color.accentColor : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .frame(maxWidth: .infinity, alignment: alignment == .trailing ? .trailing : .leading)

            if alignment == .leading { Spacer(minLength: 40) }
        }
    }

    private var systemMessage: some View {
        Text(message.text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(CoachPreviewData.messages) { message in
            ChatMessageView(message: message)
        }
    }
    .padding()
}
