# Coach Photo Picker — Final Verification Report

**Date:** 2026-07-05  
**Integration branch:** `cursor/coach-photo-picker-qa-runbook-e7c4` (stacked fixes + QA runbook)  
**Manual QA runbook:** [COACH_PHOTO_PICKER_QA_RUNBOOK.md](./COACH_PHOTO_PICKER_QA_RUNBOOK.md)

---

## Root cause

**Confirmed (by code audit + unit tests; device re-verify pending).**

Choose Photo failed because of a **dismiss/selection race** in the library path:

1. `PhotosPicker` dismisses and `isPhotoPickerPresented` becomes `false` before `photoPickerItem` `onChange` runs.
2. `handlePhotoLibraryPickerDismissed()` reset flow state to `.idle` while no selection was marked in-flight.
3. When the selection callback arrived, `handlePhotoLibrarySelection` guarded on `.pickerPresented(.library)` and **returned silently** — no thumbnail, no error.

**Fix:** Pick-generation tokens (`activeLibraryPickID`, `librarySelectionInFlightID`, `awaitingLateSelectionPickID`) plus synchronous claim in `beginPhotoLibrarySelectionHandling()` before async load. Late selections after dismiss are accepted when they match the awaiting generation.

Secondary issues addressed: silent failure paths surfaced retryable composer errors; `CoachView` selection task lifecycle hardened; unified `CoachPendingImageState` for camera and library.

---

## Automated verification

| Check | Environment | Result | Notes |
|-------|-------------|--------|-------|
| Xcode build | Linux agent | **SKIP** | No `xcodebuild` / macOS |
| `build-for-testing` | Linux agent | **SKIP** | Requires macOS + Xcode |
| Coach image picker unit tests | Linux agent | **SKIP** | Blocked by BW-101 (test target SPM) on documented CI setup |
| Full Coach / Fast-Core test plan | Linux agent | **SKIP** | Same |
| UI tests | — | **N/A** | No Coach photo picker UI tests in repo |
| SwiftLint | Repo | **N/A** | Not configured |

**Recommended local command (macOS):**

```bash
DESTINATION='platform=iOS Simulator,name=iPhone 17'
xcodebuild build -scheme "Fitness Coach" -destination "$DESTINATION"
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:Fitness\ CoachTests/CoachPhotoLibrarySelectionControllerTests \
  -only-testing:Fitness\ CoachTests/CoachPhotoLibrarySelectionRaceTests \
  -only-testing:Fitness\ CoachTests/CoachImagePickFlowTests \
  -only-testing:Fitness\ CoachTests/CoachInputStateTests \
  -only-testing:Fitness\ CoachTests/CoachPendingImageStateTests \
  -only-testing:Fitness\ CoachTests/CoachPendingImageAttachmentUnifiedTests \
  -only-testing:Fitness\ CoachTests/CoachMessageAttachmentSendTests \
  -only-testing:Fitness\ CoachTests/CoachImageWorkflowE2ETests \
  -only-testing:Fitness\ CoachTests/CoachImagePickFlowQATests
```

---

## Tests added / updated (photo picker scope)

### New test files

| File | Coverage |
|------|----------|
| `CoachPhotoLibrarySelectionRaceTests.swift` | Dismiss-before-selection, dismiss-during-selection, cancel, stale pick, camera regression |
| `CoachPhotoLibrarySelectionControllerTests.swift` | 10 controller-path scenarios with fake loader (no Photos UI) |
| `CoachPhotoLibrarySelectionTestSupport.swift` | `FakeCoachPhotoLibraryImageLoader`, `simulateCoachViewLibrarySelectionCallback` |
| `CoachPendingImageAttachmentUnifiedTests.swift` | Camera/library parity, remove, replace, failed replacement |
| `CoachPhotoLibraryImageLoading.swift` | Production `live` loader seam |

### Rewritten / cleaned

| File | Change |
|------|--------|
| `CoachMessageAttachmentSendTests.swift` | Uses `stageTestMealPhoto` + `pendingImage` (removed `importAttachment`) |
| `CoachPhotoPickerPresentationTests.swift` | Legacy presentation only; documents non-production wiring |

### Removed (stale APIs)

| File | Reason |
|------|--------|
| `CoachInputAttachmentStateTests.swift` | `importAttachment` / `inputAttachmentState` removed |
| `CoachPhotoLibraryImportTests.swift` | Legacy import + removed `prepareJPEG` |
| `CoachAttachmentFlowStateTests.swift` | Dead import paths + duplicate presentation tests |

### Production path covered by tests

| Concern | Primary tests |
|---------|----------------|
| Picker state machine | `CoachImagePickFlowTests`, `CoachPhotoLibrarySelectionControllerTests`, `CoachPhotoLibrarySelectionRaceTests` |
| Composer `pendingImage` | `CoachInputStateTests`, `CoachPendingImageStateTests`, `CoachPendingImageAttachmentUnifiedTests` |
| Photo send payload | `CoachMessageAttachmentSendTests`, `CoachImageWorkflowE2ETests` |
| Retry / remove | `CoachImagePickFlowRetryTests`, `CoachImagePickFlowQATests`, `CoachMealPhotoRecoveryTests` |

---

## Manual QA result

**Not executed on this agent** (no physical iPhone / macOS simulator in cloud environment).

Use [COACH_PHOTO_PICKER_QA_RUNBOOK.md](./COACH_PHOTO_PICKER_QA_RUNBOOK.md) on device before release. Checklist status until device run:

| Scenario | Status |
|----------|--------|
| Take Photo | Pending device |
| Choose Photo JPEG | Pending device |
| Choose Photo HEIC | Pending device |
| Choose Photo large | Pending device |
| Cancel library picker | Pending device |
| Starter chip Choose Photo | Pending device |
| Camera → remove → library | Pending device |
| Library → remove → camera | Pending device |
| Replace camera ↔ library | Pending device |
| Caption + send / image-only send | Pending device |
| Network off after attach | Pending device |
| Tab switch during processing | Pending device |
| Theme with attached image | Pending device |

---

## Files changed (integration summary)

### Production

| File | Change |
|------|--------|
| `CoachImagePickFlowController.swift` | Race tokens, structured errors, library loader injection |
| `CoachView.swift` | Unified `requestPhotoLibraryPick`, selection task, remove cleanup |
| `CoachInputCoordinator.swift` | `reportComposerImageSelectionError`, local ref cleanup |
| `CoachPendingImageState.swift` | `showsComposerPreview`, `hasValidReadyAttachment` |
| `CoachComposer.swift` | Preview during replacement processing |
| `CoachMealPhotoError.swift` | `.attachFailed` |
| `CoachPhotoLibraryImageLoading.swift` | `live` production adapter |
| `CoachPhotoLibraryPickDebugLogger.swift` | Structured events; opt-in `FORMA_COACH_PHOTO_LIBRARY_PICK_DEBUG=1` |

### Docs

| File | Change |
|------|--------|
| `COACH_PHOTO_PICKER_QA_RUNBOOK.md` | Manual QA (15 scenarios) |
| `COACH_PHOTO_PICKER_FINAL_VERIFICATION.md` | This report |

### Not removed (legacy, still referenced)

- `CoachPhotoPickerPresentation.swift` — tested as legacy; not production wiring
- `CoachInputAttachment.swift` / `CoachInputAttachmentPreview.swift` — preview-only / legacy model

---

## Debug logging cleanup

- **Removed:** UI-layer `logDiagnostic` calls (`CoachView`, `CoachComposer`, `CoachInputCoordinator`) and ad-hoc flow diagnostics (reject/dismiss-skip/entered).
- **Kept:** Privacy-safe structured events in `CoachImagePickFlowController` (`libraryPickStarted`, `librarySelectionReceived`, `librarySelectionAccepted`, `libraryProcessingStarted`, `libraryProcessingSucceeded`, `libraryProcessingFailed`, `librarySelectionDroppedUnexpectedState`, `libraryPickCancelled`, `libraryProcessingDiscardedStale`).
- **Default:** DEBUG logging **off**; enable with `FORMA_COACH_PHOTO_LIBRARY_PICK_DEBUG=1`.

---

## Remaining risks

1. **Device QA not run** — JPEG/HEIC/large-image behavior must be validated on physical iPhone per release criteria.
2. **BW-101 test compile** — `Fitness CoachTests` SPM linkage may block `xcodebuild test` until resolved; app target build may still succeed.
3. **Limited Photos permission** — runbook scenario; not covered by unit tests.
4. **HEIC edge cases** — pipeline converts via `UIImage`; exotic assets may still need device verification.
5. **Legacy types remain** — `CoachPhotoPickerPresentation` / `CoachInputAttachmentState` unused in production; low risk but adds confusion until a future removal pass.

---

## Release recommendation

- **Merge** after macOS `xcodebuild test` passes on picker-related suites and device QA runbook is **10/10 JPEG** with no silent failures.
- **Do not release** on unit tests alone without device Choose Photo verification.
