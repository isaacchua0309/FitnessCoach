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
    @FocusState private var isInputFocused: Bool

    init(model: CoachModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CoachMessageListView(messages: model.messages) {
                    dismissKeyboard()
                }

                if model.isSending {
                    CoachTypingIndicatorView()
                }

                if let errorMessage = model.errorMessage {
                    CoachErrorView(message: errorMessage) {
                        model.clearError()
                    }
                }

                if let draft = model.foodConfirmationState.pendingDraft,
                   !model.isShowingFoodConfirmationSheet {
                    AIFoodConfirmationCard(draft: draft) {
                        dismissKeyboard()
                        model.openFoodConfirmationSheet()
                    }
                }

                Divider()

                QuickActionChips(isDisabled: model.isSending) { action in
                    dismissKeyboard()
                    Task { await model.tapQuickAction(action) }
                }

                CoachInputBar(
                    text: $model.inputText,
                    isFocused: $isInputFocused,
                    isSending: model.isSending,
                    onSend: {
                        Task {
                            await model.sendCurrentMessage()
                            dismissKeyboard()
                        }
                    }
                )
            }
            .navigationTitle("Coach")
            .sheet(isPresented: $model.isShowingFoodConfirmationSheet) {
                foodConfirmationSheet
            }
        }
    }

    private func dismissKeyboard() {
        isInputFocused = false
    }

    @ViewBuilder
    private var foodConfirmationSheet: some View {
        if let draft = model.foodConfirmationState.pendingDraft {
            AIFoodConfirmationSheet(
                draft: draft,
                errorMessage: model.foodConfirmationErrorMessage,
                onConfirm: { formState in
                    await model.confirmAIFoodEstimate(formState)
                },
                onReject: {
                    model.rejectAIFoodEstimate()
                },
                onCancel: {
                    model.dismissFoodConfirmationSheet()
                }
            )
        }
    }
}

#Preview {
    CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
}
