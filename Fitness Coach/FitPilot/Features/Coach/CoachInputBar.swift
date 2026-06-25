//
//  CoachInputBar.swift
//  Fitness Coach
//
//  FitPilot AI — Text input and send button for the Coach screen.
//
//  The input bar is dumb: it receives a binding and closures and does not own
//  the model, call services, or parse commands.
//

import SwiftUI

struct CoachInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void

    private var canSend: Bool {
        !isSending && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            TextField("Message Coach", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .submitLabel(.send)
                .onSubmit {
                    if canSend { onSend() }
                }

            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    CoachInputBar(text: .constant("status"), isSending: false) {}
}
