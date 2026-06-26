//
//  CoachView.swift
//  Fitness Coach
//
//  FitPilot AI — AI command center for all fitness mutations.
//

import PhotosUI
import SwiftUI

struct CoachView: View {

    @StateObject private var model: CoachModel
    @EnvironmentObject private var authManager: AuthManager
    @FocusState private var isInputFocused: Bool

    @State private var isPhotoPickerPresented = false
    @State private var isCameraPresented = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isRetryingCoachSession = false

    init(model: CoachModel) {
        _model = StateObject(wrappedValue: model)
    }

    private var showEmptyChrome: Bool {
        model.messages.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CoachDesignTokens.Color.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if showEmptyChrome {
                        CoachHeader()
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    CoachConversationView(
                        messages: model.messages,
                        isSending: model.isSending,
                        onDismissKeyboard: {
                            dismissKeyboard()
                        },
                        onStarterTap: { prompt in
                            handleStarterTap(prompt)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    coachErrorBanner

                    if let pending = model.pendingConfirmation {
                        CoachConfirmationBar(
                            confirmation: pending,
                            isConfirming: model.isConfirmingPending,
                            onConfirm: {
                                dismissKeyboard()
                                Task { await model.confirmPendingFromBar() }
                            },
                            onReject: {
                                dismissKeyboard()
                                model.rejectPendingFromBar()
                            },
                            onEdit: pending.supportsEdit ? {
                                dismissKeyboard()
                                model.openFoodEditSheet()
                            } : nil
                        )
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    composerChrome
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .animation(CoachDesignTokens.Motion.standard, value: showEmptyChrome)
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { _, item in
                guard item != nil else { return }
                photoPickerItem = nil
                Task { await model.handlePhotoSelected() }
            }
            .fullScreenCover(isPresented: $isCameraPresented) {
                CoachCameraPicker {
                    Task { await model.handlePhotoSelected() }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $model.isShowingFoodEditSheet) {
                foodEditSheet
            }
        }
    }

    @ViewBuilder
    private var coachErrorBanner: some View {
        if let errorMessage = model.errorMessage {
            CoachErrorView(
                title: model.errorTitle,
                message: errorMessage,
                retryAction: model.showsAuthRetry ? { retryCoachSession() } : nil,
                isRetrying: isRetryingCoachSession,
                onDismiss: {
                    model.clearError()
                }
            )
        }
    }

    private var composerChrome: some View {
        CoachComposer(
            text: $model.inputText,
            isFocused: $isInputFocused,
            isSending: model.isSending,
            onSend: {
                Task {
                    await model.sendCurrentMessage()
                    dismissKeyboard()
                }
            },
            onVoiceTap: {
                // Voice capture placeholder — wired when speech ships.
            },
            onAttachmentSelect: handleAttachmentSelection
        )
        .fixedSize(horizontal: false, vertical: true)
        .background(
            CoachDesignTokens.Color.background
                .shadow(color: .black.opacity(0.28), radius: 12, y: -4)
        )
        .padding(.bottom, CoachDesignTokens.Layout.bottomChromeInset)
    }

    private func handleStarterTap(_ prompt: CoachStarterPrompt) {
        dismissKeyboard()
        switch prompt.behavior {
        case .openPhotoPicker:
            isPhotoPickerPresented = true
        case .prefill:
            Task { await model.applyStarterPrompt(prompt) }
            isInputFocused = true
        case .send:
            Task { await model.applyStarterPrompt(prompt) }
        }
    }

    private func handleAttachmentSelection(_ option: CoachAttachmentOption) {
        switch option {
        case .takePhoto:
            isCameraPresented = true
        case .choosePhoto:
            isPhotoPickerPresented = true
        }
    }

    private func dismissKeyboard() {
        isInputFocused = false
    }

    private func retryCoachSession() {
        guard model.showsAuthRetry, !isRetryingCoachSession else { return }
        isRetryingCoachSession = true
        Task { @MainActor in
            defer { isRetryingCoachSession = false }
            guard case .signedIn = authManager.authState else {
                model.clearError()
                return
            }
            do {
                _ = try await authManager.idToken(forceRefresh: true)
                model.clearError()
            } catch {
                // Keep the session failure UI; AuthGateView handles signed-out routing.
            }
        }
    }

    @ViewBuilder
    private var foodEditSheet: some View {
        if let draft = model.pendingConfirmation?.foodDraft {
            AIFoodConfirmationSheet(
                draft: draft,
                errorMessage: model.foodEditErrorMessage,
                onDone: { formState in
                    model.saveFoodEdit(formState)
                },
                onCancel: {
                    model.dismissFoodEditSheet()
                }
            )
        }
    }
}

#Preview {
    CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
        .environmentObject(AppRefreshCenter())
        .environmentObject(AuthManager())
}
