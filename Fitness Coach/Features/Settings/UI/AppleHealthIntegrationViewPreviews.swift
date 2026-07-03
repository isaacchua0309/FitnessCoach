//
//  AppleHealthIntegrationViewPreviews.swift
//  Fitness Coach
//
//  Forma — Apple Health settings previews.
//

import SwiftUI

#if DEBUG
private struct AppleHealthIntegrationPreviewHost: View {
    let integrationState: TrainingIntegrationState
    let lastSyncedAt: Date?

    @StateObject private var store: TrainingInsightsStore

    init(integrationState: TrainingIntegrationState, lastSyncedAt: Date?) {
        self.integrationState = integrationState
        self.lastSyncedAt = lastSyncedAt
        let store = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: integrationState)
        )
        store.configureLastSyncedAtForPreview(lastSyncedAt)
        _store = StateObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            AppleHealthIntegrationView(insightsStore: store)
        }
        .formaThemePreview()
    }
}

#Preview("Apple Health — Connected") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .connected,
        lastSyncedAt: Date()
    )
}

#Preview("Apple Health — Disconnected") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .notConnected,
        lastSyncedAt: nil
    )
}

#Preview("Apple Health — Permission Needed") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .denied,
        lastSyncedAt: nil
    )
}
#endif
