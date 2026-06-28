#!/usr/bin/env python3
"""Regenerate Xcode test plans for Fast-Core, Integration, and Full suites."""

from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = ROOT / "Fitness CoachTests"
OUT_DIR = ROOT / "TestPlans"

TARGET = {
    "containerPath": "container:Fitness Coach.xcodeproj",
    "identifier": "3A0000062FEE000100000001",
    "name": "Fitness CoachTests",
}

# Test classes in these files are routed to the Integration plan.
INTEGRATION_FILES = {
    "AccountProfileMismatchTests.swift",
    "AppleHealthTrainingStrategyTests.swift",
    "AuthProfileRouteSafetyTests.swift",
    "CloudProfileResolutionTests.swift",
    "CloudProfileUploadFailureTests.swift",
    "CloudProfileWriteGuardTests.swift",
    "CoachMealPhotoAnalysisTests.swift",
    "DailyLogServiceTests.swift",
    "ExistingUserSignInTests.swift",
    "FitnessActionCenterTests.swift",
    "JourneyManualQAChecklistTests.swift",
    "NoExistingProfileFoundTests.swift",
    "OnboardingAppleHealthTests.swift",
    "OnboardingAuthFlowTests.swift",
    "OnboardingCloudProfileCompatibilityTests.swift",
    "OnboardingCompletionProfileFlowTests.swift",
    "OnboardingCompletionTests.swift",
    "OnboardingFlowSelectionTests.swift",
    "OnboardingProfilePersistenceSafetyTests.swift",
    "PipelineTracerTests.swift",
    "PlanAdjustPlanEntryTests.swift",
    "PlanAdjustmentTests.swift",
    "PlanAnalyticsTests.swift",
    "PlanEditWizardTests.swift",
    "ProfileBootstrapCoordinatorTests.swift",
    "ProfileBootstrapServiceTests.swift",
    "ProfilePlanConflictFlowTests.swift",
    "ProfileRestoreRoutingTests.swift",
    "ReleaseAIBackendConfigurationTests.swift",
    "SignOutHygieneTests.swift",
    "SignOutRoutingTests.swift",
    "SignInIntentResolutionTests.swift",
    "TodayActionCoordinatorTests.swift",
    "TodayAnalyticsTests.swift",
    "TrainingIntegrationTests.swift",
    "WelcomeOnboardingHandoffTests.swift",
}

COACH_INTEGRATION_METHODS = {
    "testLocalRegressionMessagesSaveToInMemoryStore",
    "testLogFoodWithoutNutritionCallsEstimateFood",
    "testWorkoutLogRedirectsWithoutConfirmationBar",
    "testWorkoutLogConnectedCopyWhenAppleHealthLinked",
    "testUndoWorkoutDoesNotDeleteRecords",
    "testFoodEditUpdatesPendingDraftBeforeLogging",
    "testAIFailureShowsGracefulMessage",
    "testAuthenticationFailureSetsInlineRetryStateNotChatBubble",
}

# AppContainer / full-flow analytics classes in otherwise Fast-Core files.
INTEGRATION_CLASSES = {
    "OnboardingAlmostThereAnalyticsTests",
    "OnboardingFormaProofAnalyticsTests",
    "OnboardingModelAnalyticsTests",
}


def discover_classes() -> dict[str, Path]:
    classes: dict[str, Path] = {}
    for path in sorted(TEST_DIR.glob("*Tests.swift")):
        for match in re.finditer(r"final class (\w+Tests): XCTestCase", path.read_text()):
            classes[match.group(1)] = path
    return classes


def test_methods(path: Path) -> list[str]:
    return re.findall(r"func (test\w+)\(", path.read_text())


def make_plan(selected: list[str] | None, *, parallel: bool) -> dict:
    target_entry: dict = {
        "parallelizable": parallel,
        "target": TARGET,
    }
    if selected is not None:
        target_entry["selectedTests"] = selected

    return {
        "configurations": [
            {
                "id": str(uuid.uuid4()).upper(),
                "name": "Configuration 1",
                "options": {},
            }
        ],
        "defaultOptions": {
            "testTimeoutsEnabled": False,
        },
        "testTargets": [target_entry],
        "version": 1,
    }


def main() -> None:
    classes = discover_classes()
    fast_selected: list[str] = []
    integration_selected: list[str] = []

    coach_path = classes.get("CoachRoutingTests")
    if coach_path:
        for method in test_methods(coach_path):
            entry = f"CoachRoutingTests/{method}"
            if method in COACH_INTEGRATION_METHODS:
                integration_selected.append(entry)
            else:
                fast_selected.append(entry)

    for cls, path in sorted(classes.items()):
        if cls == "CoachRoutingTests":
            continue
        if path.name in INTEGRATION_FILES or cls in INTEGRATION_CLASSES:
            integration_selected.append(cls)
        else:
            fast_selected.append(cls)

    OUT_DIR.mkdir(exist_ok=True)

    plans = {
        "Fast-Core.xctestplan": make_plan(fast_selected, parallel=True),
        "Integration.xctestplan": make_plan(integration_selected, parallel=False),
        "Full.xctestplan": make_plan(None, parallel=True),
    }

    for name, plan in plans.items():
        (OUT_DIR / name).write_text(json.dumps(plan, indent=2) + "\n")

    print(f"Discovered {len(classes)} test classes")
    print(f"Fast-Core: {len(fast_selected)} selections")
    print(f"Integration: {len(integration_selected)} selections")
    print(f"Full: all tests in target")


if __name__ == "__main__":
    main()
