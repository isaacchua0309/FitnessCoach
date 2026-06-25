//
//  CoachView.swift
//  Fitness Coach
//
//  FitPilot AI — Coach chat shell screen.
//
//  CoachView only renders state and forwards user actions to CoachModel. It
//  does not access SwiftData, call services directly, parse commands, calculate
//  macros, or call AI.
//

import SwiftUI

struct CoachView: View {

    @StateObject private var model: CoachModel

    init(model: CoachModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CoachMessageListView(messages: model.messages)

                if model.isSending {
                    CoachTypingIndicatorView()
                }

                if let errorMessage = model.errorMessage {
                    CoachErrorView(message: errorMessage) {
                        model.clearError()
                    }
                }

                Divider()

                QuickActionChips(isDisabled: model.isSending) { action in
                    Task { await model.tapQuickAction(action) }
                }

                CoachInputBar(
                    text: $model.inputText,
                    isSending: model.isSending,
                    onSend: { Task { await model.sendCurrentMessage() } }
                )
            }
            .navigationTitle("Coach")
        }
    }
}

#Preview {
    CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
}
