# Technical Debt Register

**Last updated:** 2026-07-05  
**Purpose:** Track intentional gaps that are not safe to delete or fix in a dead-code pass. Each item has an owner domain, reason, and unblock criteria.

**Related:** [DeadCodeAudit.md](../DeadCodeAudit.md), [BuildWarningsRegister.md](./BuildWarningsRegister.md), [ProjectHygieneRegister.md](./ProjectHygieneRegister.md), [PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md](../Archive/ContextPackets/PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md) §15

---

## How to use

| Status | Meaning |
|--------|---------|
| **Open** | Not started; blocks or defers a ship milestone |
| **Deferred** | Known gap; acceptable for current release with documented workaround |
| **Blocked** | Waiting on external input (legal, ops, design) |

When closing an item, remove the source `TD-*` comment and update this register in the same PR.

---

## P0 — App Store / ship blockers

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-LEGAL-001 | Legal | Hosted Terms & Privacy Policy URLs are `nil` | `FormaLegalCopy.swift` (`FormaLegalURLs`) | Legal pages not published yet | Publish URLs; set `FormaLegalURLs.terms` and `.privacyPolicy` |
| TD-LEGAL-002 | Legal | Legal links open in-app sheet instead of Safari | `FormaLegalCopy.swift` (`FormaLegalDocumentLink.url`) | Depends on TD-LEGAL-001 | Wire published URLs; verify Safari handoff in Settings and sign-in |
| TD-SETTINGS-001 | Settings | Support email may be placeholder | `SettingsSupportConfiguration.swift` | `FormaProductCopy.Legal.supportEmail` needs ops confirmation | Confirm production support inbox; verify `SettingsSupportConfiguration.isConfigured` |

---

## P1 — Feature gaps (intentional stubs)

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-SETTINGS-002 | Settings / Privacy | User data export row gated but not wired | `SettingsExportDataActionHandler.swift`, `SettingsDataExportCapability` | `AccountDataExportService` exists; UI flow not shipped | Implement export presentation + share sheet; enable `SettingsDataExportCapability` |
| TD-DATA-001 | Data | `WeightLogService` has no delete API | `WeightLogService.swift` | Tombstone sync path not implemented | Add delete + mutation tracker wiring per account persistence phase docs |

---

## P2 — Accessibility / theme

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-THEME-001 | Design system | Increased-contrast palette variants not implemented | `ThemeAccessibilityAdaptationPolicy.increasedContrastFollowUp` | `FormaAbTest.Theme.supportsIncreasedContrastPaletteVariants` is false by design | Implement palette branching on `colorSchemeContrast`; flip AB flag |
| TD-THEME-002 | Design system | Reduce-transparency compositing not implemented | `ThemeAccessibilityAdaptationPolicy.reduceTransparencyFollowUp` | `FormaAbTest.Theme.supportsReduceTransparencyCompositing` is false by design | Opaque fallbacks in `ThemeResolver`; flip AB flag |

---

## P3 — Structural / consolidation (not dead code)

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-HI-001 | Health Intelligence | Weekly review presentation duplicated across Journey + HI | `JourneyWeeklyReviewBuilder`, `WeeklyReviewPresentationBuilder` | Distinct product surfaces; consolidation is P1 refactor | Shared weekly UX contract per PRDX P1 |
| TD-HI-002 | Health Intelligence | `*SectionLoader` / HI presentation duplication | Today / Journey / Plan HI loaders + presentation builders | **Mostly closed** — shared `HealthIntelligenceSectionLoaderCore` + `HealthIntelligencePresentationCore`; golden parity gate (`HealthIntelligencePresentationParityTests`) landed; dead Today composition stubs removed | Delete `*CompositionPolicy.swift` files and legacy dashboard sections only when `healthIntelligenceUIEnabled` is permanently on |
| TD-COACH-001 | Coach | `CoachModel` god-file split | `CoachModel.swift` (was ~1,600 LOC) | **Partially closed** — v1 coordinators + `CoachDependencies` extracted; image pick flow and legacy test init remain | Remove legacy init; extract `CoachImagePickFlowController` wiring; close when characterization suite green in CI |
| TD-BACKEND-001 | Backend | Monolithic `functions/src/index.ts` | Firebase Functions | Route modularization deferred | Extract `routes/` per PRDX P1 |

---

## Closed — Coach decomposition v1 (2026-07-05)

| ID | Item | Resolution |
|----|------|------------|
| TD-COACH-001 (core) | Monolithic `CoachModel` (~1,600 LOC) | **Split** into 11 coordinators + `CoachDependencies` assembly. `CoachModel` ~350 LOC orchestration layer. Behavior-neutral per characterization tests. Docs: `Docs/Coach/CoachArchitecture.md`, `CoachModelDecompositionV1.md`. |

---

## Closed — Code Bloat Reduction v2 (2026-07-05)

| ID | Item | Resolution |
|----|------|------------|
| TD-AI-001 | Deprecated `AIContext` transport struct | **Deleted** `Infrastructure/AI/AIContext.swift`. Production Coach path already used `CoachContextPacketV2`. Extracted `TodayAISummary` for nutrition AI summaries. Six test stubs migrated to `CoachContextPacketV2`. |
| TD-COPY-001 | `FormaProductCopy` monolith | **Split** into 9 domain extension files under `Domain/Copy/`. Strings unchanged. Guarded by `FormaProductCopyEquivalenceTests`. |

Partial progress (not closed):

| ID | Item | Status |
|----|------|--------|
| TD-HI-002 | `*SectionLoader` / HI presentation duplication | **Mostly closed** — `HealthIntelligenceSectionLoaderCore` + `HealthIntelligencePresentationCore`; tab builders migrated; golden parity gate added; dead `showsLegacyHealthIntelligenceStack` / `showsLegacyNextBestAction` stubs removed from `TodayReadOnlyCompositionPolicy` |

---

## Migration-only code (do not delete)

These SwiftData entities remain registered for lightweight migration. **Not technical debt** — documented retention.

| Entity | File | Notes |
|--------|------|-------|
| `WeeklyReviewEntity` | `Entities/WeeklyReviewEntity.swift` | V1 → V2 migration only |
| `ChatMessageEntity` | `Entities/ChatMessageEntity.swift` | V1 → V2 migration only |
| `WorkoutEntryEntity` | `Entities/WorkoutEntryEntity.swift` | V2 → V3 migration only |
| `ExerciseSetEntity` | `Entities/ExerciseSetEntity.swift` | V2 → V3 migration only |
| `DebugRecordEntity` | `Entities/DebugRecordEntity.swift` | V1 → V2 migration only |

See `Docs/PersistenceCleanupNotes.md` and entity file headers.

---

## Intentional stubs (keep — not debt)

| Symbol | Location | Purpose |
|--------|----------|---------|
| `NoOp*AnalyticsLogger` | `Infrastructure/Diagnostics/` | Release analytics sink until production backend wired |
| `NoOpCloudUserProfileStore` | `Infrastructure/Cloud/` | In-memory / preview builds |
| `StubTrainingIntegrationProvider` | `TestingSupport/` | Previews and tests |
| `NoOpCoachTimelineRecorder` | Coach platform | Fallback when timeline disabled |
| `LocalNoAPIGuard` | Coach pipeline | Offline / no-API guard responses |
| `MockLLMClient` | AI infrastructure | `AppContainer(inMemory: true)` |
| `HealthIntelligenceSnapshot+Preview` | `Health/Models/` | Tests and Canvas previews |

---

## Stale documentation (updated, not deleted)

| Document | Status | Canonical replacement |
|----------|--------|----------------------|
| `USER_DATA_STORAGE_CONTEXT_PACKET.md` | Stale vs V7+ account persistence | `Docs/Architecture/SourceOfTruthMap.md`, `Docs/AccountPersistence/` — archived at `Docs/Archive/ContextPackets/` |
| `arch.md`, `rules.mdc` | Legacy snapshots | `Docs/Architecture.md` — `arch.md` at `Docs/Archive/SprintReports/` |
| `Docs/Coach/archive/COACH_FULL_CONTEXT_PACKET_PRE_V2_2026-07-04.md` | Intentional archive | `Docs/Coach/COACH_FULL_CONTEXT_PACKET.md` |

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | **Health Intelligence consolidation v2** — TD-HI-002 mostly closed; `HealthIntelligenceSectionLoaderCore`, `TodayHealthIntelligenceSectionLoader`, AppContainer dependency file split |
| 2026-07-05 | **Coach decomposition v1** — TD-COACH-001 partially closed; architecture docs added |
| 2026-07-05 | **Code Bloat Reduction v2 finalized** — closed TD-AI-001, TD-COPY-001; doc archive; fixture consolidation; account-test polling; build/hygiene registers |
| 2026-07-05 | Added links to BuildWarningsRegister + ProjectHygieneRegister |
| 2026-07-05 | Closed TD-AI-001 — deleted `AIContext.swift`; migrated 6 test stubs to `CoachContextPacketV2`; extracted `TodayAISummary` |
| 2026-07-04 | Initial register created during dead-code cleanup pass (Batch 6) |
