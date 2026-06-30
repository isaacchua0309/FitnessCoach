#!/usr/bin/env python3
"""Phase 7: Replace FormaScreenStyle token references with FormaTokens."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "Fitness Coach"

REPLACEMENTS = [
    ("FormaScreenStyle.horizontalPadding", "FormaTokens.Spacing.pageHorizontal"),
    ("FormaScreenStyle.sectionSpacing", "FormaTokens.Spacing.screenSectionSpacing"),
    ("FormaScreenStyle.rowMinHeight", "FormaTokens.Layout.minTouchTarget"),
    ("FormaScreenStyle.rowVerticalPadding", "FormaTokens.Spacing.settingsRowVertical"),
    ("FormaScreenStyle.cardCornerRadius", "FormaCardChrome.cornerRadius"),
    ("FormaScreenStyle.scrollBottomInset", "FormaTokens.Layout.tabBarScrollPadding"),
    ("FormaScreenStyle.settingsRowInsets", "FormaTokens.Layout.settingsRowInsets"),
    ("FormaScreenStyle.activeRowBackground", "FormaTokens.Color.surface"),
    ("FormaScreenStyle.disabledRowBackground", "FormaTokens.Color.surfaceSubtle"),
]

SKIP_DIRS = {"Legacy"}

changed = 0
for path in ROOT.rglob("*.swift"):
    if any(part in SKIP_DIRS for part in path.parts):
        continue
    text = path.read_text()
    original = text
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    if text != original:
        path.write_text(text)
        changed += 1
        print(f"updated {path.relative_to(ROOT.parent)}")

print(f"done: {changed} files")
