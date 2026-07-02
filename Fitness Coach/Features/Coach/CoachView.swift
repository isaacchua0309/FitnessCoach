//
//  CoachView.swift
//  Fitness Coach
//
//  FitPilot AI — AI command center for all fitness mutations.
//

import PhotosUI
import SwiftUI
import UIKit

struct CoachView: View {

    @StateObject private var model: CoachModel
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @FocusState private var isInputFocused: Bool

    @State private var pickerPresentation = CoachPhotoPickerPresentation.idle
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isRetryingCoachSession = false

    init(model: CoachModel) {
        _model = StateObject(wrappedValue: model)
    }

    private var showEmptyChrome: Bool {
        model.messages.isEmpty
    }

    private var canPresentPhotoPicker: Bool {
        pickerPresentation.canPresentPicker && !model.isShowingFoodEditSheet
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
                        todayContext: model.todayContext,
                        starterPrompts: model.starterPromptSpecs,
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
            .task {
                model.refreshTodayContext()
            }
            .onAppear {
                model.refreshTodayContext()
            }
            .onChange(of: refreshCenter.refreshToken) { _, _ in
                model.refreshTodayContext()
            }
            .onChange(of: pickerPresentation.isSourceDialogPresented) { _, isPresented in
                guard !isPresented else { return }
                let destination = pickerPresentation.finishSourceDialogDismissal()
                presentPicker(for: destination)
            }
            .onChange(of: model.isShowingFoodEditSheet) { _, isPresented in
                guard isPresented else { return }
                dismissPickerPresentation()
            }
            .animation(CoachDesignTokens.Motion.standard, value: showEmptyChrome)
            .photosPicker(
                isPresented: photoLibraryPickerPresented,
                selection: $photoPickerItem,
                matching: .images,
                preferredItemEncoding: .compatible
            )
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                let selectedItem = item
                photoPickerItem = nil
                dismissPickerPresentation()
                Task { @MainActor in
                    await model.importAttachment(from: selectedItem)
                }
            }
            .fullScreenCover(isPresented: cameraPickerPresented) {
                CoachCameraPicker { result in
                    Task { @MainActor in
                        dismissPickerPresentation()
                        await model.importAttachment(
                            from: result,
                            sourceLabel: CoachMealPhotoPipeline.cameraCaptureLabel
                        )
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $model.isShowingFoodEditSheet) {
                foodEditSheet
            }
        }
    }

    private var isAttachmentSourceDialogPresented: Binding<Bool> {
        Binding(
            get: { pickerPresentation.isSourceDialogPresented },
            set: { isPresented in
                if isPresented {
                    _ = pickerPresentation.requestSourceDialogPresentation()
                } else if pickerPresentation.isSourceDialogPresented {
                    pickerPresentation.isSourceDialogPresented = false
                }
            }
        )
    }

    private var photoLibraryPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerPresentation.activePicker == .photoLibrary },
            set: { isPresented in
                if !isPresented {
                    dismissPickerPresentation()
                }
            }
        )
    }

    private var cameraPickerPresented: Binding<Bool> {
        Binding(
            get: { pickerPresentation.activePicker == .camera },
            set: { isPresented in
                if !isPresented {
                    dismissPickerPresentation()
                }
            }
        )
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
            isAttachmentSourceDialogPresented: isAttachmentSourceDialogPresented,
            attachmentState: model.inputAttachmentState,
            isFocused: $isInputFocused,
            isSending: model.isSending,
            canPresentPhotoPicker: canPresentPhotoPicker,
            onSend: {
                Task {
                    await model.sendCurrentMessage()
                    dismissKeyboard()
                }
            },
            onVoiceTap: {},
            onAttachmentOptionSelected: handleAttachmentOptionSelected,
            onRemoveAttachment: {
                model.removeInputAttachment()
            },
            onRetryAttachment: {
                model.dismissAttachmentImportError()
                _ = pickerPresentation.requestSourceDialogPresentation()
            }
        )
        .fixedSize(horizontal: false, vertical: true)
        .background(
            CoachDesignTokens.Color.background
                .shadow(color: FormaTokens.Color.shadow, radius: 12, y: -4)
        )
        .padding(.bottom, CoachDesignTokens.Layout.bottomChromeInset)
    }

    private func handleStarterTap(_ prompt: CoachStarterPromptSpec) {
        dismissKeyboard()
        switch prompt.behavior {
        case .openPhotoPicker:
            queuePhotoLibraryPicker()
        case .prefill:
            Task { await model.applyStarterPromptSpec(prompt) }
            isInputFocused = true
        case .send:
            Task { await model.applyStarterPromptSpec(prompt) }
        }
    }

    private func handleAttachmentOptionSelected(_ destination: CoachPhotoPickerDestination) {
        pickerPresentation.selectAttachmentSource(destination)
    }

    private func presentPicker(for destination: CoachPhotoPickerDestination) {
        guard destination != .none, canPresentPhotoPicker else { return }

        switch destination {
        case .none:
            break
        case .photoLibrary:
            _ = pickerPresentation.present(.photoLibrary)
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                Task { @MainActor in
                    await model.importAttachment(from: .failure(.cameraUnavailable))
                }
                return
            }
            _ = pickerPresentation.present(.camera)
        }
    }

    private func queuePhotoLibraryPicker() {
        guard canPresentPhotoPicker else { return }
        if pickerPresentation.isSourceDialogPresented {
            pickerPresentation.pendingDestination = .photoLibrary
            pickerPresentation.isSourceDialogPresented = false
        } else {
            _ = pickerPresentation.requestPhotoLibraryPicker()
        }
    }

    private func dismissPickerPresentation() {
        pickerPresentation.dismissForBlockingSheet()
        photoPickerItem = nil
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
        .formaThemePreview()
}
