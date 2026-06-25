//
//  CoachMessageListView.swift
//  Fitness Coach
//
//  FitPilot AI — Scrollable list of chat messages with auto-scroll.
//

import SwiftUI

struct CoachMessageListView: View {
    let messages: [ChatMessage]

    var body: some View {
        if messages.isEmpty {
            CoachEmptyStateView()
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let lastId = messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CoachMessageListView(messages: CoachPreviewData.messages)
}
