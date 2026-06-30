#!/usr/bin/env python3
"""Phase 6 symbol renames across the Fitness Coach repo."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path("/workspace")
TARGET_DIRS = [
    ROOT / "Fitness Coach",
    ROOT / "Fitness CoachTests",
    ROOT / "Docs",
    ROOT / "Tools",
]

# (pattern, replacement) — applied in order; use word boundaries via regex groups.
REPLACEMENTS: list[tuple[str, str]] = [
    # FitPilot design system (longest first)
    (r"\bFitPilotPlanDisplayRow\b", "FormaPlanDisplayRow"),
    (r"\bFitPilotSettingsSectionHeader\b", "FormaSettingsSectionHeader"),
    (r"\bFitPilotComingSoonRow\b", "FormaComingSoonRow"),
    (r"\bFitPilotPlanRowDivider\b", "FormaPlanRowDivider"),
    (r"\bFitPilotPlanCard\b", "FormaPlanCard"),
    (r"\bFitPilotScreenStyle\b", "FormaScreenStyle"),
    (r"\bfitPilotSettingsRowChrome\b", "formaSettingsRowChrome"),
    (r"\bfitPilotFormSection\b", "formaFormSection"),
    (r"\bfitPilotFormScreen\b", "formaFormScreen"),
    (r"\bfitPilotScrollBottomInset\b", "formaScrollBottomInset"),
    (r"\bfitPilotGroupedList\b", "formaGroupedList"),
    (r"\bfitPilotScreenBackground\b", "formaScreenBackground"),
    # FitPilot infrastructure
    (r"\bFitPilotModelContainer\b", "FormaModelContainer"),
    (r"\bFitPilotPipelineTracer\b", "FormaPipelineTracer"),
    (r"\bFitPilotAIBackendClient\b", "FormaAIBackendClient"),
    (r"\bFitPilotLegalCopy\b", "FormaLegalCopy"),
    # Plan tab (Profile* UI types only — not user-profile domain types)
    (r"\bProfileDashboardState\b", "PlanDashboardState"),
    (r"\bProfileViewState\b", "PlanViewState"),
    (r"\bProfileFormState\b", "PlanFormState"),
    (r"\bProfilePreviewData\b", "PlanPreviewData"),
    (r"\bProfileEmptyStateView\b", "PlanEmptyStateView"),
    (r"\bProfileFormatter\b", "PlanFormatter"),
    (r"\bmakeProfileModel\b", "makePlanModel"),
    (r"\bProfileModel\b", "PlanModel"),
    (r"\bProfileView\b", "PlanView"),
    # Journey tab (Progress* UI types only)
    (r"\bProgressDashboardState\b", "JourneyDashboardState"),
    (r"\bProgressViewState\b", "JourneyViewState"),
    (r"\bProgressPreviewData\b", "JourneyPreviewData"),
    (r"\bProgressLogSummaryBuilder\b", "JourneyLogSummaryBuilder"),
    (r"\bProgressEmptyStateView\b", "JourneyEmptyStateView"),
    (r"\bProgressRangeSelector\b", "JourneyRangeSelector"),
    (r"\bProgressFormatter\b", "JourneyFormatter"),
    (r"\bmakeProgressModel\b", "makeJourneyModel"),
    (r"\bProgressModel\b", "JourneyModel"),
    (r"\bProgressView\b", "JourneyView"),
]

EXTENSIONS = {".swift", ".md", ".mjs", ".plist", ".example", ".xcscheme"}


def iter_files() -> list[Path]:
    files: list[Path] = []
    for base in TARGET_DIRS:
        if not base.exists():
            continue
        for path in base.rglob("*"):
            if path.is_file() and path.suffix in EXTENSIONS:
                if "phase6-rename.py" in str(path):
                    continue
                files.append(path)
    return files


def main() -> None:
    changed = 0
    for path in iter_files():
        text = path.read_text(encoding="utf-8")
        original = text
        for pattern, repl in REPLACEMENTS:
            text = re.sub(pattern, repl, text)
        if text != original:
            path.write_text(text, encoding="utf-8")
            changed += 1
            print(path.relative_to(ROOT))
    print(f"\nUpdated {changed} files")


if __name__ == "__main__":
    main()
