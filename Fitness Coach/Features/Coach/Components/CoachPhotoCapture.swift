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
    let onResult: (Result<Data, CoachMealPhotoError>) -> Void

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
        let onResult: (Result<Data, CoachMealPhotoError>) -> Void
        let dismiss: DismissAction

        init(onResult: @escaping (Result<Data, CoachMealPhotoError>) -> Void, dismiss: DismissAction) {
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
            switch CoachMealPhotoPipeline.prepareJPEG(from: image) {
            case .success(let data):
                onResult(.success(data))
            case .failure(let error):
                onResult(.failure(error))
            }
        }
    }
}

private extension CoachMealPhotoPipeline {
    static func prepareJPEG(from image: UIImage) -> Result<Data, CoachMealPhotoError> {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            return .failure(.loadFailed)
        }
        return prepareJPEG(from: data)
    }
}
