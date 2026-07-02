//
//  CoachPhotoCapture.swift
//  Fitness Coach
//
//  FitPilot AI — Camera capture bridge for meal photo analysis.
//

import SwiftUI
import UIKit

struct CoachCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onResult: @MainActor (Result<Data, CoachMealPhotoError>) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return CoachUnavailableCameraViewController {
                context.coordinator.finish(with: .failure(.cameraUnavailable))
            }
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, dismiss: dismiss)
    }

    /// Retained by `UIViewControllerRepresentable` for the picker lifetime.
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onResult: @MainActor (Result<Data, CoachMealPhotoError>) -> Void
        private let dismiss: DismissAction
        private var hasDeliveredResult = false

        init(
            onResult: @escaping @MainActor (Result<Data, CoachMealPhotoError>) -> Void,
            dismiss: DismissAction
        ) {
            self.onResult = onResult
            self.dismiss = dismiss
        }

        @MainActor
        func finish(with result: Result<Data, CoachMealPhotoError>) {
            guard !hasDeliveredResult else { return }
            hasDeliveredResult = true
            onResult(result)
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                finish(with: .failure(.userCancelled))
            }
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                Task { @MainActor in
                    finish(with: .failure(.noImage))
                }
                return
            }

            Task.detached(priority: .userInitiated) { [weak self] in
                let prepared = CoachMealPhotoPipeline.prepareJPEG(from: image)
                await MainActor.run {
                    self?.finish(with: prepared)
                }
            }
        }
    }
}

private final class CoachUnavailableCameraViewController: UIViewController {
    private let onUnavailable: () -> Void
    private var didReportUnavailable = false

    init(onUnavailable: @escaping () -> Void) {
        self.onUnavailable = onUnavailable
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didReportUnavailable else { return }
        didReportUnavailable = true
        onUnavailable()
    }
}
