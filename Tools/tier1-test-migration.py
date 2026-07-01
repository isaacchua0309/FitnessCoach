#!/usr/bin/env python3
"""Update OnboardingModel test initializers for Tier 1 API."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

REPLACEMENTS = [
    (
        "OnboardingModel(\n            userProfileService:",
        "OnboardingModel(\n            actionCenter: container.actionCenter,\n            userProfileReader:",
    ),
    (
        "OnboardingModel(\n        userProfileService:",
        "OnboardingModel(\n        actionCenter: container.actionCenter,\n        userProfileReader:",
    ),
    (
        "return OnboardingModel(\n            userProfileService:",
        "return OnboardingModel(\n            actionCenter: container.actionCenter,\n            userProfileReader:",
    ),
    (
        "return OnboardingModel(\n        userProfileService:",
        "return OnboardingModel(\n        actionCenter: container.actionCenter,\n        userProfileReader:",
    ),
    (
        "let model = OnboardingModel(\n            userProfileService:",
        "let model = OnboardingModel(\n            actionCenter: container.actionCenter,\n            userProfileReader:",
    ),
    (
        "let model = OnboardingModel(\n        userProfileService:",
        "let model = OnboardingModel(\n        actionCenter: container.actionCenter,\n        userProfileReader:",
    ),
]

# Patterns where container variable isn't named container
SPECIAL = [
    (
        "OnboardingModel(\n            userProfileService: container.userProfileService,",
        "OnboardingModel(\n            actionCenter: container.actionCenter,\n            userProfileReader: container.userProfileService,",
    ),
]

changed = 0
for path in (ROOT / "Fitness CoachTests").rglob("*.swift"):
    text = path.read_text()
    original = text
    for old, new in REPLACEMENTS + SPECIAL:
        text = text.replace(old, new)
    # Fix cases that used userProfileService: without container prefix in helper
    text = text.replace(
        "userProfileReader: container.userProfileService,",
        "userProfileReader: container.userProfileService,"
    )
    if text != original:
        path.write_text(text)
        changed += 1
        print(path.relative_to(ROOT))

print(f"updated {changed} test files")
