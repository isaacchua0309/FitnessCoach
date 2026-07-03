//
//  SettingsSupportMailComposer.swift
//  Fitness Coach
//
//  Forma — Native mail composer with mailto fallback support.
//

import SwiftUI

#if canImport(MessageUI)
import MessageUI
#endif

enum SettingsSupportMailComposerCapability {

    static var canSendMail: Bool {
        #if canImport(MessageUI)
        return MFMailComposeViewController.canSendMail()
        #else
        return false
        #endif
    }
}

#if canImport(MessageUI)
struct SettingsSupportMailComposer: UIViewControllerRepresentable {
    let topic: SettingsSupportMailTopic
    let supportEmail: String
    let diagnostics: SettingsSupportDiagnostics
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([supportEmail])
        composer.setSubject(SettingsSupportMailContent.subject(for: topic))
        composer.setMessageBody(
            SettingsSupportMailContent.messageBody(for: topic, diagnostics: diagnostics),
            isHTML: false
        )
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish()
        }
    }
}
#endif
