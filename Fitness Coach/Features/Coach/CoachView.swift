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
    @StateObject private var speechService = CoachSpeechRecognizerService()
    @StateObject private var imagePickFlow = CoachImagePickFlowController()
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var refreshCenter: AppRefreshCenter
    @FocusState private var isInputFocused: Bool

    /// False when another tab is selected in `MainTabView` (TabView keeps the view mounted).
    var isActive: Bool = true

    @State private var photoPickerItem: PhotosPickerItem?
    @State private var isRetryingCoachSession = false

    init(model: CoachModel, isActive: Bool = true) {
        _model = StateObject(wrappedValue: model)
        self.isActive = isActive
    }

    private var showEmptyChrome: Bool {
        model.messages.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showEmptyChrome {
                    CoachHeader()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                CoachConversationView(
                    messages: model.messages,
                    isSending: model.isSending,
                    todayContext: model.todayContext,
                    launchPresentation: model.activeLaunchPresentation,
                    starterPrompts: model.starterPromptSpecs,
                    pendingConfirmation: model.pendingConfirmation,
                    isInputFocused: isInputFocused,
                    onDismissKeyboard: {
                        dismissKeyboard()
                    },
                    onLaunchChipTap: { chip in
                        handleLaunchChip(chip)
                    },
                    onStarterTap: { prompt in
                        handleStarterTap(prompt)
                    },
                    onRetryMealPhotoAnalysis: { userMessageID in
                        Task { await model.retryMealPhotoAnalysis(for: userMessageID) }
                    },
                    onNutritionAction: { action in
                        Task { await model.handleNutritionEstimateAction(action) }
                    },
                    bottomAccessory: {
                        VStack(spacing: 0) {
                            coachErrorBanner
                            bottomAccessoryStack
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: model.requestsComposerFocus) { _, shouldFocus in
                    if shouldFocus {
                        focusComposerIfRequested()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                CoachCanvasBackground()
                    .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                model.refreshTodayContext()
            }
            .onAppear {
                model.refreshTodayContext()
            }
            .onDisappear {
                speechService.stopRecording()
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    speechService.stopRecording()
                    imagePickFlow.dismissPresentedPickers()
                    model.handleCoachBecameInactive()
                } else {
                    focusComposerIfRequested()
                    presentCameraIfRequested()
                }
            }
            .onChange(of: model.requestsComposerFocus) { _, shouldFocus in
                if shouldFocus {
                    focusComposerIfRequested()
                }
            }
            .onChange(of: model.requestsCameraPresentation) { _, shouldPresent in
                if shouldPresent {
                    presentCameraIfRequested()
                }
            }
            .onChange(of: model.isSending) { _, isSending in
                if isSending {
                    speechService.stopRecording()
                }
            }
            .onChange(of: refreshCenter.refreshToken) { _, _ in
                model.refreshTodayContext()
            }
            .animation(CoachDesignTokens.Motion.standard, value: showEmptyChrome)
            .photosPicker(
                isPresented: $imagePickFlow.isPhotoPickerPresented,
                selection: $photoPickerItem,
                matching: .images
            )
            .onChange(of: imagePickFlow.isPhotoPickerPresented) { _, isPresented in
                if !isPresented {
                    imagePickFlow.handlePhotoLibraryPickerDismissed()
                }
            }
            .onChange(of: photoPickerItem) { _, item in
                guard let item else { return }
                photoPickerItem = nil
                imagePickFlow.markLibrarySelectionReceived()
                Task {
                    await imagePickFlow.handlePhotoLibrarySelection(item, model: model)
                }
            }
            .fullScreenCover(
                isPresented: $imagePickFlow.isCameraPresented,
                onDismiss: {
                    imagePickFlow.handleCameraPickerDismissedWithoutResult()
                }
            ) {
                CoachCameraPicker { result in
                    Task {
                        await imagePickFlow.handleCameraResult(result, model: model)
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $model.isShowingFoodEditSheet) {
                foodEditSheet
            }
            .formaThemeReactive()
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

    private var bottomAccessoryStack: some View {
        CoachBottomAccessoryStack(
            pendingConfirmation: model.pendingConfirmation,
            isConfirmingPending: model.isConfirmingPending,
            onConfirmPending: {
                dismissKeyboard()
                Task { await model.confirmPendingFromBar() }
            },
            onRejectPending: {
                dismissKeyboard()
                model.rejectPendingFromBar()
            },
            onEditPending: model.pendingConfirmation?.supportsEdit == true ? {
                handlePendingEditTap()
            } : nil,
            onRetryPhotoAnalysis: model.pendingConfirmation?.supportsPhotoRetry == true ? {
                dismissKeyboard()
                guard let userMessageID = model.pendingConfirmation?.relatedPhotoUserMessageID else { return }
                Task { await model.retryMealPhotoAnalysis(for: userMessageID) }
            } : nil,
            text: Binding(
                get: { model.inputState.text },
                set: { newValue in
                    let previousValue = model.inputState.text
                    if speechService.isRecording,
                       !speechService.isApplyingTranscriptUpdate,
                       newValue != previousValue {
                        speechService.userDidEditInput()
                    }
                    model.inputText = newValue
                }
            ),
            pendingImage: model.inputState.pendingImage,
            attachmentError: model.inputState.imageErrorMessage,
            showsImageErrorRetry: model.inputState.imageErrorSupportsRetry,
            speechError: speechService.errorMessage,
            isListening: speechService.isRecording,
            isVoiceInputBusy: speechService.isVoiceInputBusy,
            canPickAttachment: model.inputState.canStartImageSelection && imagePickFlow.allowsAttachmentPick,
            isProcessingImage: imagePickFlow.isProcessingImage,
            textFieldPlaceholder: model.photoClarificationComposerPlaceholder
                ?? FormaProductCopy.Coach.composerPlaceholder,
            isFocused: $isInputFocused,
            isSending: model.isSending,
            onSend: {
                speechService.stopRecording()
                model.noteComposerInteraction()
                Task {
                    await model.sendCurrentMessage()
                    dismissKeyboard()
                }
            },
            onVoiceTap: {
                model.noteComposerInteraction()
                handleVoiceTap()
            },
            onAttachmentSelect: { option in
                model.noteComposerInteraction()
                handleAttachmentSelection(option)
            },
            onRemoveAttachment: {
                model.removeStagedMealPhoto()
                imagePickFlow.handleAttachmentRemoved()
            },
            onRetryImageSelection: {
                Task {
                    await imagePickFlow.retryFailedImageSelection(model: model)
                }
            }
        )
    }

    private func handlePendingEditTap() {
        if isInputFocused {
            // Compact mode: keep the composer focused for clarification typing.
            isInputFocused = true
            return
        }
        dismissKeyboard()
        model.openFoodEditSheet()
    }

    private func handleLaunchChip(_ chip: CoachLaunchChip) {
        dismissKeyboard()
        speechService.stopRecording()
        model.consumeLaunchPresentation()

        switch chip {
        case .takePhoto:
            handleAttachmentSelection(.takePhoto)
        case .describeMeal:
            isInputFocused = true
        case .useVoice:
            handleVoiceTap()
        case .addWater(let amountMl):
            Task {
                await model.send(CoachLaunchPresentationBuilder.waterLogCommand(amountMl: amountMl))
            }
        }
    }

    private func handleStarterTap(_ prompt: CoachStarterPromptSpec) {
        dismissKeyboard()
        speechService.stopRecording()
        switch prompt.behavior {
        case .openPhotoPicker:
            _ = imagePickFlow.beginPhotoLibraryPick(model: model)
        case .prefill:
            Task { await model.applyStarterPromptSpec(prompt) }
            isInputFocused = true
        case .send:
            Task { await model.applyStarterPromptSpec(prompt) }
        }
    }

    private func handleAttachmentSelection(_ option: CoachAttachmentOption) {
        speechService.stopRecording()
        switch option {
        case .takePhoto:
            Task {
                await imagePickFlow.beginCameraPick(model: model)
            }
        case .choosePhoto:
            _ = imagePickFlow.beginPhotoLibraryPick(model: model)
        }
    }

    private func dismissKeyboard() {
        isInputFocused = false
    }

    private func focusComposerIfRequested() {
        guard isActive, model.requestsComposerFocus else { return }
        isInputFocused = true
        model.consumeComposerFocusRequest()
    }

    private func presentCameraIfRequested() {
        guard isActive, model.requestsCameraPresentation else { return }
        model.consumeCameraPresentationRequest()
        handleAttachmentSelection(.takePhoto)
    }

    private func handleVoiceTap() {
        guard !speechService.isVoiceInputBusy || speechService.isRecording else { return }

        dismissKeyboard()
        Task {
            await speechService.toggleRecording(currentText: model.inputState.text) { transcript in
                model.inputText = transcript
            }
        }
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

private struct CoachCanvasBackground: View {
    @Environment(\.formaColors) private var colors

    var body: some View {
        colors.canvas
    }
}

#Preview {
    CoachView(model: try! AppContainer(inMemory: true).makeCoachModel())
        .environmentObject(AppRefreshCenter())
        .environmentObject(AuthManager())
        .formaThemePreview()
}
