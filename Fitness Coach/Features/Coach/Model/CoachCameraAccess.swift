//
//  CoachCameraAccess.swift
//  Fitness Coach
//
//  Forma — Camera availability and permission checks before meal photo capture.
//

import AVFoundation
import UIKit

enum CoachCameraAccess {

    static var isHardwareAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    static func resolveForCapture() async -> Result<Void, CoachMealPhotoError> {
        guard isHardwareAvailable else {
            return .failure(.cameraUnavailable)
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .success(())
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .success(()) : .failure(.cameraPermissionDenied)
        case .denied, .restricted:
            return .failure(.cameraPermissionDenied)
        @unknown default:
            return .failure(.cameraPermissionDenied)
        }
    }
}
