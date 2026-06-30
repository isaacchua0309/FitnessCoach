//
//  FormaLegalCopy.swift
//  Fitness Coach
//
//  FitPilot — In-app Terms of Service and Privacy Policy copy.
//
//  IMPORTANT: Generic template aligned to current app behavior. Have a qualified
//  attorney review and customize before App Store release (entity name, contact,
//  jurisdiction, retention periods, and subprocessors).
//

import Foundation

enum FormaLegalCopy {

    static let effectiveDate = FormaProductCopy.Legal.effectiveDate
    static let contactEmail = FormaProductCopy.Legal.supportEmail
    static let operatorName = FormaProductCopy.Legal.productName

    // MARK: - Terms of Service

    static let termsSections: [LegalDocumentSection] = [
        LegalDocumentSection(
            title: "Agreement",
            body: """
            By creating an account or using \(operatorName) (the "App"), you agree to these Terms of Service ("Terms"). If you do not agree, do not use the App.
            """
        ),
        LegalDocumentSection(
            title: "The service",
            body: """
            \(operatorName) is a fitness and nutrition planning tool with an AI-powered Coach feature. The App helps you set targets, log food, water, weight, and training, and receive coaching-style guidance based on information you provide.

            \(operatorName) is for general wellness and fitness support only. It is not a medical device and does not provide medical advice, diagnosis, or treatment.
            """
        ),
        LegalDocumentSection(
            title: "Eligibility",
            body: """
            You must be at least 13 years old (or the minimum age required in your country) to use the App. If you are under 18, you should use the App only with permission from a parent or guardian.

            You are responsible for ensuring that use of the App is appropriate for your health circumstances.
            """
        ),
        LegalDocumentSection(
            title: "Your account",
            body: """
            Sign-in is provided through Google Sign-In and Firebase Authentication. You are responsible for maintaining access to your Google account and for activity that occurs through your \(operatorName) account.

            You agree to provide accurate profile and logging information to the extent you choose to enter it, and to keep your account credentials secure.
            """
        ),
        LegalDocumentSection(
            title: "Health and AI disclaimers",
            body: """
            Always consult a qualified healthcare professional before starting or changing a diet, exercise program, or supplement routine. Do not disregard professional medical advice because of something you read or receive in the App.

            Coach responses are generated with artificial intelligence and may be incomplete, outdated, or inaccurate. You are solely responsible for decisions you make based on App output. \(operatorName) does not guarantee any particular fitness, weight, or health outcome.
            """
        ),
        LegalDocumentSection(
            title: "Acceptable use",
            body: """
            You agree not to misuse the App, including by attempting to access systems without authorization, interfering with the service, reverse engineering the App except where permitted by law, or using the App in violation of applicable law.
            """
        ),
        LegalDocumentSection(
            title: "Your content",
            body: """
            You retain ownership of information you enter into the App, such as logs, messages, and profile details. You grant \(operatorName) a limited license to process that information solely to operate and improve the App and provide Coach features, as described in the Privacy Policy.
            """
        ),
        LegalDocumentSection(
            title: "Intellectual property",
            body: """
            The App, including its design, branding, and software, is owned by \(operatorName) or its licensors and is protected by applicable intellectual property laws. These Terms do not grant you any right to use \(operatorName) trademarks except as necessary to use the App.
            """
        ),
        LegalDocumentSection(
            title: "Termination",
            body: """
            You may stop using the App at any time and may sign out from Account settings. We may suspend or terminate access if you violate these Terms or if we discontinue the service.

            Sections that by their nature should survive termination (including disclaimers and limitations of liability) will survive.
            """
        ),
        LegalDocumentSection(
            title: "Disclaimers",
            body: """
            THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.
            """
        ),
        LegalDocumentSection(
            title: "Limitation of liability",
            body: """
            TO THE MAXIMUM EXTENT PERMITTED BY LAW, \(operatorName.uppercased()) AND ITS AFFILIATES WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS, DATA, OR GOODWILL, ARISING FROM YOUR USE OF THE APP.

            OUR TOTAL LIABILITY FOR ANY CLAIM RELATING TO THE APP WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID US FOR THE APP IN THE TWELVE MONTHS BEFORE THE CLAIM, OR (B) USD $100.
            """
        ),
        LegalDocumentSection(
            title: "Changes",
            body: """
            We may update these Terms from time to time. If we make material changes, we will provide notice within the App or by other reasonable means. Continued use after changes become effective constitutes acceptance of the updated Terms.
            """
        ),
        LegalDocumentSection(
            title: "Contact",
            body: """
            Questions about these Terms: \(contactEmail)

            Effective date: \(effectiveDate)
            """
        )
    ]

    // MARK: - Privacy Policy

    static let privacySections: [LegalDocumentSection] = [
        LegalDocumentSection(
            title: "Overview",
            body: """
            This Privacy Policy explains how \(operatorName) ("we," "us") collects, uses, and shares information when you use the \(operatorName) mobile application.

            We designed \(operatorName) so most fitness and logging data stays on your device. Account sign-in uses Google and Firebase Authentication.
            """
        ),
        LegalDocumentSection(
            title: "Information we collect",
            body: """
            Account information. When you sign in with Google, we receive authentication information from Firebase, which may include your account identifier, display name, and email address as provided by Google.

            Information you provide. You may enter profile and fitness information such as name, age, sex, height, weight, goals, activity level, diet preferences, and daily logs for food, water, weight, and workouts.

            Coach interactions. When you use Coach, the App may send a limited summary of relevant context and recent messages to our AI backend so the Coach can respond. Full chat history and complete database records are not sent by design.

            Technical information. We may collect basic diagnostic or operational data needed to secure and maintain the service (for example, authentication errors or app version), consistent with platform and Firebase defaults.
            """
        ),
        LegalDocumentSection(
            title: "How we use information",
            body: """
            We use information to:

            • authenticate you and keep your session secure
            • generate and display your plan, targets, and progress
            • power Coach features and parse natural-language logging requests
            • maintain, protect, and improve the App
            • respond to support requests and legal obligations
            """
        ),
        LegalDocumentSection(
            title: "Where data is stored",
            body: """
            Most profile, log, and chat data you create in \(operatorName) is stored locally on your device using on-device storage (SwiftData).

            Signing out ends your authenticated session but does not automatically delete on-device fitness data. Deleting the App from your device removes local App data subject to iOS behavior and backups.

            Authentication data is processed by Firebase/Google as part of sign-in. Coach requests that require AI processing are transmitted to our backend over encrypted connections.
            """
        ),
        LegalDocumentSection(
            title: "How we share information",
            body: """
            We do not sell your personal information.

            We share information only with service providers that help us operate the App, such as:

            • Google / Google Sign-In (authentication)
            • Google Firebase (authentication infrastructure)
            • AI infrastructure providers that process Coach requests on our behalf

            These providers process data according to their own terms and policies and only as needed to provide their services to us.

            We may also disclose information if required by law, to protect rights and safety, or in connection with a merger, acquisition, or asset sale.
            """
        ),
        LegalDocumentSection(
            title: "Data retention",
            body: """
            Local App data remains on your device until you delete it, sign out and remove the App, or reset device data.

            Authentication records retained by Firebase/Google are governed by those services' retention practices.

            Backend logs and AI request metadata, if any, are retained only as long as reasonably necessary for security, troubleshooting, and service improvement unless a longer period is required by law.
            """
        ),
        LegalDocumentSection(
            title: "Security",
            body: """
            We use reasonable administrative, technical, and organizational measures designed to protect information. No method of transmission or storage is completely secure, and we cannot guarantee absolute security.
            """
        ),
        LegalDocumentSection(
            title: "Your choices",
            body: """
            • Sign out: Available in Account settings. This ends your authenticated session.
            • Local data: Uninstalling the App removes on-device data subject to platform backup behavior.
            • Access or deletion requests: Contact us at \(contactEmail). We will respond consistent with applicable law.
            """
        ),
        LegalDocumentSection(
            title: "Children's privacy",
            body: """
            The App is not directed to children under 13, and we do not knowingly collect personal information from children under 13. If you believe a child has provided us information, contact us and we will take appropriate steps.
            """
        ),
        LegalDocumentSection(
            title: "International users",
            body: """
            If you use the App from outside the country where we operate, your information may be processed in countries that may have different data protection laws than your own.
            """
        ),
        LegalDocumentSection(
            title: "Changes to this policy",
            body: """
            We may update this Privacy Policy from time to time. We will post the updated policy in the App and update the effective date below. Material changes will be communicated by reasonable means where required.
            """
        ),
        LegalDocumentSection(
            title: "Contact",
            body: """
            Privacy questions: \(contactEmail)

            Effective date: \(effectiveDate)
            """
        )
    ]
}

struct LegalDocumentSection: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
}

enum FormaLegalDocument: String, Identifiable {
    case terms
    case privacyPolicy

    var id: String { rawValue }

    var navigationTitle: String {
        accessibilityTitle
    }

    var sections: [LegalDocumentSection] {
        switch self {
        case .terms:
            return FormaLegalCopy.termsSections
        case .privacyPolicy:
            return FormaLegalCopy.privacySections
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .terms:
            return "Terms of Service"
        case .privacyPolicy:
            return "Privacy Policy"
        }
    }

    var linkTitle: String {
        switch self {
        case .terms:
            return "Terms"
        case .privacyPolicy:
            return "Privacy Policy"
        }
    }

    // TODO: Set published URLs before App Store release to open in Safari instead of the in-app sheet.
    var url: URL? {
        switch self {
        case .terms:
            return FormaLegalURLs.terms
        case .privacyPolicy:
            return FormaLegalURLs.privacyPolicy
        }
    }
}

enum FormaLegalURLs {
    static let terms: URL? = nil
    static let privacyPolicy: URL? = nil
}
