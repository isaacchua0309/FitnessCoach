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
    let onResult: (Result<UIImage, CoachMealPhotoError>) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onResult: (Result<UIImage, CoachMealPhotoError>) -> Void
        let dismiss: DismissAction

        init(onResult: @escaping (Result<UIImage, CoachMealPhotoError>) -> Void, dismiss: DismissAction) {
            self.onResult = onResult
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
            onResult(.failure(.userCancelled))
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            dismiss()
            guard let image = info[.originalImage] as? UIImage else {
                onResult(.failure(.noImage))
                return
            }
            onResult(.success(image))
        }
    }
}
