//
//  FormaContextLoopIntegration.swift
//  Fitness Coach
//
//  Forma — Debug-only ContextLoopSDK host integration for founder dogfooding.
//

#if DEBUG
import Combine
import ContextLoopSDK
import Foundation
import Network
import SwiftUI

// MARK: - Shared host state

@MainActor
enum FormaContextLoopIntegration {
    static let sharedHost = AlphaHostController()
    static let sharedProviderState = FormaContextLoopProviderState()

    private static var didBootstrap = false

    /// Call once from app launch (Debug only).
    static func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        sharedHost.registerProvider(FormaSafeContextProvider(state: sharedProviderState))
        sharedProviderState.networkMonitor.start()

        ContextLoopRings.shared.addBreadcrumb(Breadcrumb(name: "forma.app_launched"))
        ContextLoopRings.shared.addLog(
            CuratedLogEntry(level: "info", message: "Forma ContextLoop bootstrap")
        )
        noteInvokedBreadcrumb(name: "forma.contextloop_bootstrapped")
    }

    static func noteInvokedBreadcrumb(name: String, metadata: [String: String] = [:]) {
        ContextLoopRings.shared.addBreadcrumb(Breadcrumb(name: name, metadata: metadata))
    }

    static func noteLog(level: String, message: String) {
        // Strip obvious secrets before curated log append (SDK also redacts on submit).
        let safe = message
            .replacingOccurrences(of: #"(?i)bearer\s+\S+"#, with: "bearer [redacted]", options: .regularExpression)
        ContextLoopRings.shared.addLog(CuratedLogEntry(level: level, message: safe))
    }

    static func recordTabChanged(_ tab: String) {
        sharedProviderState.selectedTab = tab
        sharedProviderState.currentScreen = tab
        noteInvokedBreadcrumb(name: "forma.main_tab_changed", metadata: ["tab": tab])
    }

    static func recordScreen(_ screen: String) {
        sharedProviderState.currentScreen = screen
        noteInvokedBreadcrumb(name: "forma.screen_opened", metadata: ["screen": screen])
    }

    static func recordAuth(isAuthenticated: Bool) {
        sharedProviderState.isAuthenticated = isAuthenticated
    }

    static func recordActivePlan(_ hasPlan: Bool) {
        sharedProviderState.hasActivePlan = hasPlan
    }

    static func recordTheme(_ theme: String) {
        sharedProviderState.theme = theme
    }

    static func recordRequest(started endpoint: String) {
        noteInvokedBreadcrumb(name: "forma.request_started", metadata: ["endpoint": endpoint])
        noteLog(level: "info", message: "request started \(endpoint)")
    }

    static func recordRequest(completed endpoint: String) {
        noteInvokedBreadcrumb(name: "forma.request_completed", metadata: ["endpoint": endpoint])
    }

    static func recordRequest(failed endpoint: String, code: String) {
        noteInvokedBreadcrumb(
            name: "forma.request_failed",
            metadata: ["endpoint": endpoint, "code": code]
        )
        noteLog(level: "error", message: "request failed \(endpoint) code=\(code)")
    }

    static func recordContextLoopInvoked() {
        noteInvokedBreadcrumb(name: "forma.contextloop_invoked")
    }
}

// MARK: - Safe context

@MainActor
final class FormaContextLoopProviderState: ObservableObject {
    var currentScreen: String = "unknown"
    var selectedTab: String = "today"
    var isAuthenticated: Bool = false
    var hasActivePlan: Bool = false
    var theme: String = "unknown"
    let networkMonitor = FormaNetworkAvailabilityMonitor()

    var networkAvailability: String { networkMonitor.status }
}

struct FormaSafeContextProvider: ContextProviding {
    let key = "forma.app"
    let state: FormaContextLoopProviderState

    @MainActor
    init(state: FormaContextLoopProviderState) {
        self.state = state
    }

    func collect() async throws -> ContextValue {
        await MainActor.run {
            let payload: [String: String] = [
                "currentScreen": state.currentScreen,
                "selectedTab": state.selectedTab,
                "authenticated": state.isAuthenticated ? "true" : "false",
                "activePlan": state.hasActivePlan ? "true" : "false",
                "theme": state.theme,
                "network": state.networkAvailability
            ]
            // Explicitly omit tokens, prompts, email, HealthKit, photos, journal text.
            let data = try! JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            let json = String(data: data, encoding: .utf8) ?? "{}"
            return ContextValue(key: key, json: json)
        }
    }
}

/// Lightweight connectivity label for safe context only (not a product networking stack).
@MainActor
final class FormaNetworkAvailabilityMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "forma.contextloop.network")
    private(set) var status: String = "unknown"

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            let label: String
            switch path.status {
            case .satisfied:
                label = path.isExpensive ? "satisfied_expensive" : "satisfied"
            case .unsatisfied:
                label = "unsatisfied"
            case .requiresConnection:
                label = "requires_connection"
            @unknown default:
                label = "unknown"
            }
            Task { @MainActor in
                self?.status = label
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - Report UI

struct FormaContextLoopReportView: View {
    @ObservedObject private var host = FormaContextLoopIntegration.sharedHost
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            Section("Status") {
                Text(host.status)
                    .accessibilityIdentifier("formaContextLoopStatus")
                if let rejection = host.lastRejectionReason {
                    Text(rejection)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .accessibilityIdentifier("formaContextLoopRejection")
                }
            }

            Section("Build identity") {
                let identity = BuildIdentity.current()
                LabeledContent("Version", value: identity.appVersion ?? "missing")
                LabeledContent("Build", value: identity.buildNumber ?? "missing")
                LabeledContent("Environment", value: identity.environmentName ?? "missing")
                LabeledContent("Git SHA", value: identity.gitCommitSHA ?? "missing")
                if !identity.missingFields.isEmpty {
                    Text("Missing: \(identity.missingFields.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                NavigationLink("Alpha backend configuration") {
                    AlphaConfigView(store: host.configStore)
                }
                .accessibilityIdentifier("formaContextLoopConfigLink")
            }

            Section {
                Button("Report with ContextLoop") {
                    Task {
                        FormaContextLoopIntegration.recordTheme(themeManager.preferences.palette.persistenceRawValue)
                        FormaContextLoopIntegration.recordContextLoopInvoked()
                        await host.invoke()
                    }
                }
                .accessibilityIdentifier("formaContextLoopReportButton")

                Button("Cancel / dismiss ContextLoop UI") {
                    host.cancelPresentation()
                }
                .accessibilityIdentifier("formaContextLoopCancelButton")
            } footer: {
                Text("Debug/internal only. Submits to your Mac local alpha API. Never includes tokens, HealthKit values, photos, or journal text.")
            }
        }
        .navigationTitle("ContextLoop")
        .alphaHostSheets(
            controller: host,
            reportTitle: "Forma bug report",
            expected: "Forma behaves correctly",
            steps: [
                "Open Forma Debug build",
                "Reproduce the bug",
                "Settings → Developer → Report with ContextLoop"
            ],
            defaultDescription: ""
        )
        .onAppear {
            FormaContextLoopIntegration.bootstrap()
            FormaContextLoopIntegration.recordTheme(themeManager.preferences.palette.persistenceRawValue)
            FormaContextLoopIntegration.recordScreen("settings.contextloop")
        }
    }
}

#endif
