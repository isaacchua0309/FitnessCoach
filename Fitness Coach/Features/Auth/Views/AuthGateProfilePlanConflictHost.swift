//
//  AuthGateProfilePlanConflictHost.swift
//  Fitness Coach
//
//  Hosts profile plan conflict resolution inside the auth gate shell.
//

import SwiftUI

struct AuthGateProfilePlanConflictHost: View {
    @ObservedObject var coordinator: AuthGateCoordinator

    var body: some View {
        if let cloudDocument = coordinator.conflictCloudDocument,
           let localProfile = try? coordinator.container.userProfileService.getCurrentProfile() {
            let summary = ProfilePlanConflictSummaryBuilder.build(
                localProfile: localProfile,
                cloudDocument: cloudDocument
            )
            ProfilePlanConflictView(
                summary: summary,
                isResolving: coordinator.isResolvingProfileConflict,
                onRestoreExisting: coordinator.restoreExistingPlanAfterConflict,
                onUseDevicePlan: coordinator.beginUseDevicePlanAfterConflict
            )
        } else {
            LaunchLoadingView()
        }
    }
}
