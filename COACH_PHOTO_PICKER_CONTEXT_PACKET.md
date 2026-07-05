# Coach Photo Picker Context Packet

> **Audit scope:** Static code review only. No code was modified. No runtime reproduction was performed in this session.
>
> **Labels used throughout:**
> - **Confirmed in code** — directly evidenced in source
> - **Likely but unconfirmed** — strong inference from architecture; needs device/simulator verification
> - **Unknown / needs runtime verification** — cannot be determined from code alone

---

## 1. Executive Summary

### What the Coach image input flow appears to support

**Confirmed in code:** Coach supports attaching a single meal photo to the composer via two entry paths:

1. **Take Photo** — `UIImagePickerController` camera (`CoachCameraPicker`) presented as `fullScreenCover`
2. **Choose Photo** — SwiftUI `PhotosPicker` presented via `.photosPicker(isPresented:selection:matching:)`

Both paths funnel through `CoachImagePickFlowController` → `CoachImagePipeline` → `CoachInputCoordinator` / `CoachPendingImageState` → `CoachComposer` preview → `CoachPhotoFlowCoordinator.sendMealPhoto` → AI analysis via base64 JPEG payload.

Additional entry points:
- **+ button** → `CoachAttachmentMenu` (Take Photo / Choose Photo)
- **Launch chip** `"Take photo"` → camera only
- **Starter chip** `"Photo meal"` → photo library only
- **Today → Scan Food** → opens Coach tab and auto-presents camera

### Why "Take Photo" works but "Choose Photo" may fail

**Confirmed in code:** Camera and library use **different picker technologies and different callback wiring**:

| Aspect | Camera | Library |
|--------|--------|---------|
| Picker | `UIImagePickerController` via `CoachCameraPicker` | SwiftUI `PhotosPicker` |
| Callback | Synchronous `UIImage` from UIKit delegate | Async `PhotosPickerItem` → `loadTransferable` → `Data` → `UIImage` |
| Pre-permission | Explicit `CoachCameraAccess` / AVFoundation | None (system PHPicker) |
| Dismiss race guard | `cameraDeliveredResult` flag | `librarySelectionReceived` flag |

**Likely but unconfirmed (highest-confidence hypothesis):** The library path has a **state-binding / race-condition bug** between picker dismissal and selection handling. `handlePhotoLibrarySelection` can be silently dropped when:

1. `isPhotoPickerPresented` becomes `false` **before** `photoPickerItem` onChange sets `librarySelectionReceived`, resetting flow state to `.idle`; or
2. `handlePhotoLibrarySelection` clears `librarySelectionReceived` at its entry (line 85) **before** transitioning to `.processingImage`, allowing `handlePhotoLibraryPickerDismissed` to reset state to `.idle` while still in `.pickerPresented(.library)`.

In both cases, the guard at the top of `handlePhotoLibrarySelection` fails silently:

```swift
guard case .pickerPresented(.library) = state else { return }
```

No composer error, no chat bubble, no log in Release builds — matching a user report of "selection does nothing."

Camera avoids this because `handleCameraResult` sets `cameraDeliveredResult = true` immediately and transitions state before async pipeline work.

### Bug classification

| Layer | Assessment |
|-------|------------|
| Picker-level | **Likely but unconfirmed** — `PhotosPicker` presents; selection callback ordering is suspect |
| Permissions-level | **Unlikely primary cause** — `NSPhotoLibraryUsageDescription` exists; PHPicker typically needs no full-library permission |
| State-binding-level | **Likely but unconfirmed** — strongest hypothesis; dismiss/selection race in `CoachImagePickFlowController` |
| Image-processing-level | **Unlikely primary cause** — pipeline tests pass for library-sourced images when data reaches pipeline |
| Composer-rendering-level | **Unlikely primary cause** — preview binds to `pendingImage.isReady`; camera uses same path |
| Send-pipeline-level | **Not implicated for attach failure** — send only runs after `pendingImage` is ready |

### Does photo library selection reach the app at all?

**Unknown / needs runtime verification.** Code is wired to receive `PhotosPickerItem` via `CoachView.photoPickerItem` onChange. Whether that fires reliably on device after user taps a photo is not verifiable statically.

**Likely but unconfirmed:** Picker opens (user can browse library) but selection is dropped before `beginPendingImageProcessing` due to state race.

### Do library and camera images use the same state path?

**Confirmed in code:** Yes, after selection. Both write to:
- `CoachInputState.pendingImage` (`CoachPendingImageState`)
- `CoachPendingImageLocalSourceStore` (original `UIImage` for retry)
- `CoachImagePipeline.processImportedImage` / `importFromCamera`
- `CoachInputCoordinator.stagePipelineProcessedPhoto`

### Is this safe to ship?

**Confirmed in code + user report:** **No.** If library selection fails to attach (as reported), users cannot add existing meal photos — a core Coach workflow. Camera-only workaround exists but is insufficient for users who already have photos.

---

## 2. User-Facing Flow

### Intended flow

1. User taps **+** in Coach input bar
2. User chooses **Take Photo** or **Choose Photo**
3. Camera / photo library opens
4. User captures or selects image
5. Image thumbnail appears inside Coach text box / composer
6. User can remove the image (X button)
7. User can send message with image (and optional caption)
8. Message appears in chat with image attachment
9. AI receives image for meal analysis
10. Pending image state clears after send or cancel

### Implementation comparison

| Step | Intended | Current implementation | Gap |
|------|----------|------------------------|-----|
| 1. Tap + | Expand attachment menu | `CoachComposer.attachmentButton` toggles `isAttachmentMenuPresented` | **Confirmed** — wired |
| 2. Choose option | Take Photo / Choose Photo | `CoachAttachmentMenu` → `onAttachmentSelect` → `CoachView.handleAttachmentSelection` | **Confirmed** — wired |
| 3. Picker opens | Camera or library | Camera: `fullScreenCover`; Library: `.photosPicker` | **Confirmed** — wired |
| 4. Select image | User picks photo | Camera: delegate → `handleCameraResult`; Library: `photoPickerItem` onChange → `handlePhotoLibrarySelection` | **Likely gap** — library callback may not complete |
| 5. Thumbnail in composer | Preview in capsule | `CoachComposer.attachmentPreviewStrip` when `pendingImage.isReady` | **Confirmed** — works if state reaches `.ready` |
| 6. Remove | X clears attachment | `removeStagedMealPhoto` + `imagePickFlow.handleAttachmentRemoved` | **Confirmed** |
| 7. Send | Arrow-up enabled | `canSend` when text or ready image; `sendCurrentMessage` | **Confirmed** |
| 8. Chat bubble | Photo message in thread | `CoachPhotoFlowCoordinator.appendUserMealPhotoMessage` | **Confirmed** |
| 9. AI analysis | Vision request | `CoachMealImageAIRequestBuilder` → base64 JPEG | **Confirmed** |
| 10. Clear pending | After send | `takeSendSnapshot` clears composer | **Confirmed** |

**During processing:** Composer shows `"Preparing photo…"` when `isProcessingImage` is true (`CoachImagePickFlowController.state == .processingImage`).

---

## 3. Current UI Entry Points

### Primary production path

All live image-pick UI funnels through **`CoachView`** with one `CoachImagePickFlowController` and one `CoachInputState.pendingImage` slot.

| File | Component / Symbol | Role |
|------|-------------------|------|
| `Fitness Coach/Features/Coach/CoachView.swift` | `CoachView` | Root wiring: `.photosPicker`, `.fullScreenCover`, handlers |
| `Fitness Coach/Features/Coach/Components/CoachComposer.swift` | `CoachComposer` | + button, preview strip, send/voice |
| `Fitness Coach/Features/Coach/Components/CoachAttachmentMenu.swift` | `CoachAttachmentMenu`, `CoachAttachmentOption` | Take Photo / Choose Photo menu |
| `Fitness Coach/Features/Coach/Components/CoachBottomAccessoryStack.swift` | `CoachBottomAccessoryStack` | Stacks confirmation bar + composer |
| `Fitness Coach/Features/Coach/Components/CoachLaunchChips.swift` | `CoachLaunchChips`, `CoachLaunchChip.takePhoto` | Empty-state launch chip (camera) |
| `Fitness Coach/Features/Coach/Components/CoachStarterChips.swift` | `CoachStarterChips`, `.mealPhoto` | Starter chip (library via `.openPhotoPicker`) |
| `Fitness Coach/Features/Coach/Components/CoachEmptyState.swift` | `CoachEmptyState` | Hosts launch/starter chips |
| `Fitness Coach/App/MainTabView.swift` | `MainTabView` | Hosts `CoachView(model:isActive:)` |

### Button → action mapping

| UI control | Handler | Camera | Library |
|------------|---------|--------|---------|
| + → Take Photo | `handleAttachmentSelection(.takePhoto)` → `beginCameraPick` | ✓ | |
| + → Choose Photo | `handleAttachmentSelection(.choosePhoto)` → `beginPhotoLibraryPick` | | ✓ |
| Launch chip "Take photo" | `handleLaunchChip(.takePhoto)` | ✓ | |
| Starter chip "Photo meal" | `handleStarterTap(.openPhotoPicker)` → `beginPhotoLibraryPick` | | ✓ |
| Today Scan Food | `TodayActionCoordinator` → `analyzePhotoMeal(openCameraImmediately: true)` | ✓ (auto) | |

### State flags

**Confirmed in code:** No `showCamera` / `showPhotoPicker` symbols. Production uses:

- `CoachImagePickFlowController.isCameraPresented`
- `CoachImagePickFlowController.isPhotoPickerPresented`
- `CoachComposer.isAttachmentMenuPresented` (local + menu expansion)
- `CoachModel.requestsCameraPresentation` (deep-link auto-open)

### Shared state?

**Confirmed in code:** Yes. `CoachImagePickFlowController` (picker presentation + flow state machine) and `CoachModel.inputState.pendingImage` are shared across all entry points.

### Reachability / disable conditions

**+ button disabled when** (`CoachComposer.attachmentButton`):
```swift
.disabled(isSending || !canPickAttachment || isListening || isProcessingImage)
```

`canPickAttachment` = `model.inputState.canStartImageSelection && imagePickFlow.allowsAttachmentPick`

- `canStartImageSelection` = `!isSending && !isImageProcessing` (pending image processing blocks new picks)
- `allowsAttachmentPick` = `!state.isBusy` (picker presented / permission request / processing blocks)

**Confirmed:** + stays enabled when a **ready** image is already attached (replacement allowed at model level).

**Confirmed:** `CoachAttachmentMenu` buttons have no extra disable logic — always tappable when visible.

### Legacy / unused UI (not in production path)

| File | Symbol | Status |
|------|--------|--------|
| `Fitness Coach/Features/Coach/Model/CoachPhotoPickerPresentation.swift` | `CoachPhotoPickerPresentation` | Test-only; not wired to `CoachView` |
| `Fitness Coach/Features/Coach/Components/CoachInputAttachmentPreview.swift` | `CoachInputAttachmentPreview` | Preview-only |
| `Fitness Coach/Features/Coach/Model/CoachInputAttachment.swift` | `CoachInputAttachment`, `CoachInputAttachmentState` | Legacy; superseded by `CoachPendingImageState` |

---

## 4. Picker Implementation

### Technology summary

| Picker | File | Technology | Source | Selection binding |
|--------|------|------------|--------|-------------------|
| Camera | `Fitness Coach/Features/Coach/Components/CoachPhotoCapture.swift` | `CoachCameraPicker` (`UIViewControllerRepresentable`) | `.camera` | UIKit delegate → `Result<UIImage, CoachMealPhotoError>` |
| Library | `Fitness Coach/Features/Coach/CoachView.swift` | SwiftUI `PhotosPicker` | Photo library (PHPicker under hood) | `@State photoPickerItem: PhotosPickerItem?` |

**Confirmed:** No direct `PHPickerViewController`, no `UIImagePickerController` with `.photoLibrary`, no custom `ImagePicker` class.

### Camera picker detail

**File:** `Fitness Coach/Features/Coach/Components/CoachPhotoCapture.swift`

```swift
struct CoachCameraPicker: UIViewControllerRepresentable {
    // sourceType = .camera
    // allowsEditing = false
    // Coordinator: imagePickerControllerDidCancel / didFinishPickingMediaWithInfo
}
```

| Property | Value |
|----------|-------|
| Presentation | `.fullScreenCover(isPresented: $imagePickFlow.isCameraPresented)` |
| Callback | `onResult: (Result<UIImage, CoachMealPhotoError>) -> Void` |
| Dismiss | Coordinator calls `dismiss()`; `onDismiss` → `handleCameraPickerDismissedWithoutResult` |
| Pre-check | `CoachCameraAccess.resolveForCapture()` (AVFoundation video permission) |
| Errors | `.userCancelled`, `.noImage`, `.cameraUnavailable`, `.cameraPermissionDenied` |

### Library picker detail

**File:** `Fitness Coach/Features/Coach/CoachView.swift`

```swift
.photosPicker(
    isPresented: $imagePickFlow.isPhotoPickerPresented,
    selection: $photoPickerItem,
    matching: .images
)
.onChange(of: photoPickerItem) { _, item in
    guard let item else { return }
    photoPickerItem = nil
    imagePickFlow.markLibrarySelectionReceived()
    Task { await imagePickFlow.handlePhotoLibrarySelection(item, model: model) }
}
.onChange(of: imagePickFlow.isPhotoPickerPresented) { _, isPresented in
    if !isPresented { imagePickFlow.handlePhotoLibraryPickerDismissed() }
}
```

| Property | Value |
|----------|-------|
| Transferable | `CoachPhotoPickerTransfer` (`DataRepresentation` for `.image` and `.jpeg`) |
| Load path | `CoachImagePipeline.loadImageFromPhotoLibrary` |
| Dismiss guard | `librarySelectionReceived` flag |
| Errors | `.noImage`, `.loadFailed` → composer error with retry |

### Side-by-side: working camera vs broken library

| Dimension | Camera | Library |
|-----------|--------|---------|
| Entry | `beginCameraPick` (async, permission first) | `beginPhotoLibraryPick` (sync) |
| Presentation modifier | `fullScreenCover` | `.photosPicker` |
| Result type | `UIImage` immediate | `PhotosPickerItem` → async `Data` |
| State before processing | `.pickerPresented(.camera)` | `.pickerPresented(.library)` |
| Processing trigger | `handleCameraResult` on MainActor | `Task { await handlePhotoLibrarySelection }` |
| Race guard | `cameraDeliveredResult` | `librarySelectionReceived` (cleared early — see §12) |
| Cancel handling | `.userCancelled` → `revertPendingImageProcessingCancel` | Dismiss without selection → `handlePhotoLibraryPickerDismissed` → `.idle` |
| Permission | `NSCameraUsageDescription` + AVFoundation | `NSPhotoLibraryUsageDescription` present; no `PHPhotoLibrary` API calls |

---

## 5. Permission / Info.plist Audit

### Info.plist keys

**Confirmed in code** (`Fitness Coach.xcodeproj/project.pbxproj`, Debug + Release app target):

| Key | Value | Present |
|-----|-------|---------|
| `NSCameraUsageDescription` | `"Forma uses your camera so you can attach meal photos to Coach conversations."` | ✓ |
| `NSPhotoLibraryUsageDescription` | `"Forma uses your photo library so you can attach meal photos to Coach conversations."` | ✓ |
| `NSPhotoLibraryAddUsageDescription` | — | ✗ (not needed; no save-to-library flow) |

App uses `GENERATE_INFOPLIST_FILE = YES`; no standalone Info.plist for these keys.

### Runtime permission handling

| Source | Handling |
|--------|----------|
| Camera | **Confirmed** — `CoachCameraAccess.resolveForCapture()` requests `AVCaptureDevice` video access before presenting picker |
| Photo library | **Confirmed** — no manual `PHPhotoLibrary` authorization; relies on system `PhotosPicker` / PHPicker |

### PHPicker permission requirements

**Likely but unconfirmed:** `PhotosPicker` uses PHPicker, which does **not** require full photo library access. `NSPhotoLibraryUsageDescription` may not even be prompted for PHPicker-only flows on modern iOS. Missing permission string is **unlikely** to cause silent attach failure.

### Limited / denied library permission

**Unknown / needs runtime verification.** No explicit limited-library handling in app code. PHPicker should still return selected items regardless of limited access.

### Failure mode if permission denied

**Confirmed:** Camera denial surfaces user-facing copy via `CoachResponseBuilder.mealPhotoError(.cameraPermissionDenied)` in chat. Library path has no equivalent manual check — failures would surface as `.loadFailed` / `.noImage` in composer **if** selection reaches pipeline.

---

## 6. Image Selection Callback Path

### Library path (intended)

```
User selects in PhotosPicker
  → SwiftUI sets photoPickerItem (CoachView @State)
  → onChange(photoPickerItem)
      → photoPickerItem = nil
      → markLibrarySelectionReceived()
      → Task { handlePhotoLibrarySelection(item, model) }
  → handlePhotoLibrarySelection (@MainActor)
      → guard state == .pickerPresented(.library)    ← SILENT EXIT IF FAILS
      → isPhotoPickerPresented = false
      → state = .processingImage(.library)
      → model.beginPendingImageProcessing(source: .library)
      → CoachImagePipeline.loadImageFromPhotoLibrary(item)
          → item.loadTransferable(CoachPhotoPickerTransfer) or Data.self
          → UIImage(data: rawData)
      → model.storePendingImageLocalSource(image)
      → model.attachPendingImageLocalReference(localReferenceID)
      → CoachImagePipeline.processImportedImage(...)
      → model.stagePipelineProcessedPhoto(...)
      → pendingImage.status = .ready
  → CoachComposer shows thumbnail (pendingImage.isReady)
```

### Camera path (reference)

```
User captures in UIImagePickerController
  → Coordinator didFinishPickingMediaWithInfo
      → UIImage from .originalImage
      → dismiss()
      → onResult(.success(image))
  → Task { handleCameraResult(result, model) }
      → cameraDeliveredResult = true
      → isCameraPresented = false
      → state = .processingImage(.camera)
      → model.beginPendingImageProcessing(source: .camera)
      → store local source + processImportedImage / importFromCamera
      → stagePipelineProcessedPhoto
      → pendingImage.status = .ready
```

### Where library path may diverge (before pipeline)

**Likely but unconfirmed:**

1. `onChange(photoPickerItem)` never fires → selection never starts
2. `handlePhotoLibrarySelection` guard fails (`state != .pickerPresented(.library)`) → **silent return, no error**
3. `beginPhotoLibraryPick` returns `false` (flow busy) → **silent, no user feedback** (return value discarded)
4. `beginPendingImageProcessing` returns `false` but processing continues unchecked → `shouldAcceptImportSuccess` fails later → **silent discard in `completeImport`**

Steps 2 and 4 produce **no thumbnail, no error message** — consistent with reported bug.

---

## 7. Camera Flow Comparison

| Step | Take Photo | Choose Photo | Same path? | Notes |
|------|------------|--------------|------------|-------|
| Button tap | `handleAttachmentSelection(.takePhoto)` | `handleAttachmentSelection(.choosePhoto)` | Partial | Camera uses `Task { await beginCameraPick }`; library calls `beginPhotoLibraryPick` synchronously |
| Picker opens | `isCameraPresented = true` after permission | `isPhotoPickerPresented = true` | No | Different presentation APIs |
| Image callback fires | UIKit delegate → immediate `UIImage` | `onChange(photoPickerItem)` → async Task | No | Library depends on SwiftUI binding + Task scheduling |
| Image converts | `UIImage` direct | `PhotosPickerItem` → `Data` → `UIImage` | Partial | Converges at `processImportedImage` |
| Attachment state updates | `beginPendingImageProcessing(.camera)` | `beginPendingImageProcessing(.library)` | **Yes** | Same `CoachPendingImageState` |
| Thumbnail appears | `pendingImage.isReady` → `attachmentPreviewStrip` | Same | **Yes** | Same composer binding |
| Send payload includes image | `pendingImage.uploadData` in snapshot | Same | **Yes** | Same `CoachMealPhotoSendPayload` |

### Camera-specific success factors

**Confirmed in code:**
- `cameraDeliveredResult` prevents dismiss handler from resetting state after capture
- `handleCameraResult` transitions to `.processingImage` before async pipeline
- Permission failure surfaces explicit error (chat bubble)

### Library-specific risk factors

**Likely but unconfirmed:**
- `librarySelectionReceived` cleared at start of `handlePhotoLibrarySelection` (line 85) before state transition (line 89)
- `handlePhotoLibrarySelection` scheduled in unstructured `Task` — may yield, allowing dismiss `onChange` to interleave
- No test calls `handlePhotoLibrarySelection` with real `PhotosPickerItem` end-to-end

---

## 8. Composer / Text Box State

### State model

**File:** `Fitness Coach/Features/Coach/Model/CoachInputState.swift`

| Field | Type | Purpose |
|-------|------|---------|
| `text` | `String` | Composer text draft |
| `pendingImage` | `CoachPendingImageState?` | Single optional staged photo |
| `imageError` | `CoachMealPhotoError?` | Composer-level selection error |
| `isSending` | `Bool` | Send in progress |

**File:** `Fitness Coach/Features/Coach/Model/CoachPendingImageState.swift`

| Field | Purpose |
|-------|---------|
| `thumbnail` | `Data` — UI preview (240px JPEG) |
| `uploadData` | `Data` — pipeline-compressed JPEG for send/AI |
| `status` | `.processing` / `.ready` / `.failed` |
| `source` | `.camera` / `.library` |
| `localReferenceID` | Key into `CoachPendingImageLocalSourceStore` |

### Single-image rule

**Confirmed in code:** One `pendingImage` slot (not an array). Replacing:
- `beginProcessingNewSelection` preserves existing ready image in `.processing` until replacement succeeds
- + button **not** disabled when ready image exists

### Remove path

**Confirmed:** `removeStagedMealPhoto()` clears `pendingImage` + local source store; `imagePickFlow.handleAttachmentRemoved()` resets flow to `.idle`.

### Camera vs library same property?

**Confirmed:** Both write to `CoachInputState.pendingImage` via `CoachInputCoordinator`.

### Storage types

**Confirmed:** Pipeline output stored as `Data` (JPEG thumbnail + upload bytes). Original `UIImage` held in memory-only `CoachPendingImageLocalSourceStore` for retry.

---

## 9. Message Model / Attachment Model

### Transcript model

**File:** `Fitness Coach/Domain/Models/ChatMessageImageAttachment.swift`

```swift
struct ChatMessageImageAttachment {
    var kind: ChatMessageAttachmentKind  // .mealPhoto
    var imageJPEG: Data
    var thumbnailJPEG: Data
    var source: CoachInputAttachmentSource?
}
```

**File:** `Fitness Coach/Domain/Models/ChatMessage.swift`
- `ChatMessage.userMealPhoto(caption:attachment:)`
- `mealPhotoJPEG`, `hasMealPhotoAttachment`, `imageAttachment`

### Composer vs transcript

| Layer | Type | When created |
|-------|------|--------------|
| Composer staging | `CoachPendingImageState` | On successful pipeline processing |
| Transcript | `ChatMessageImageAttachment` | On send via `CoachPhotoFlowCoordinator.appendUserMealPhotoMessage` |

### Local file URLs

**Confirmed:** Not required. Camera delivers `UIImage`; library delivers `Data` → `UIImage`. No file URL dependency.

### HEIC / format handling

**Confirmed:** `CoachPhotoPickerTransfer` accepts `.image` and `.jpeg` UTTypes. `loadImageFromPhotoLibrary` decodes via `UIImage(data:)`, then pipeline re-encodes as JPEG. No explicit HEIC UTType, but `.image` is generic.

**Likely but unconfirmed:** Some HEIC assets might fail `loadTransferable` — would surface `.loadFailed` with composer retry, **not** silent failure.

### Size limits

**Confirmed** (`CoachImageUploadConfig.default`):
- `maxUploadBytes`: 500,000
- Compression ladder: 1280px → 1024px, quality 0.8 → 0.6
- Thumbnail max edge: 240px

---

## 10. Image Processing Pipeline

### Pipeline steps

**Files:**
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipelineEncoding.swift`
- `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+ImportedImageProcessing.swift`

1. `normalizeOrientation` — redraw upright, strip EXIF
2. `encodeThumbnail` — max 240px edge
3. `encodeUploadPayload` — resize + JPEG compression ladder, max 500KB
4. `processAsync` — runs on `Task.detached` (off main thread)

### Threading

**Confirmed:**
- `CoachImagePickFlowController` is `@MainActor`
- State updates via `CoachInputCoordinator.commitState` on MainActor
- Pipeline processing is async; results applied back on MainActor

### Library-specific async loading

```swift
// CoachImagePipeline+ImportedImageProcessing.swift
if let transfer = try await item.loadTransferable(type: CoachPhotoPickerTransfer.self) { ... }
else if let data = try await item.loadTransferable(type: Data.self) { ... }
else { return .failure(.noImage) }
```

**Confirmed:** Properly awaited. Failures return `CoachMealPhotoError` and call `handleFailure` → composer error (if import was active).

### Error logging

**Confirmed:** `CoachImageProcessingLogger.logSelectionFailure` — **DEBUG only** (`#if DEBUG`). Release builds have no persistent log for silent guard failures.

---

## 11. Sending Pipeline

### Send flow

```
CoachComposer.onSend
  → CoachModel.sendCurrentMessage()
  → inputCoordinator.takeSendSnapshot()  // clears composer
  → CoachSendFlowCoordinator.sendCurrentMessage(snapshot:)
  → branches on CoachMealPhotoSendPayload:
      .textOnly → text AI routing
      .imageOnly / .textAndImage → photoFlowCoordinator.sendMealPhoto(...)
```

### Image encoding for AI

**Files:**
- `Fitness Coach/Application/UseCases/Coach/CoachMealImageUploadAttachment.swift`
- `Fitness Coach/Application/UseCases/Coach/CoachMealImageAIRequestBuilder.swift`
- `Fitness Coach/Infrastructure/AI/AIContracts.swift` (`AIMealImagePayload.base64`)

**Confirmed:** Camera and library use identical `pendingImage.uploadData` (pipeline JPEG). No separate encoding path.

### Upload vs inline

**Confirmed:** Images sent as **base64 in JSON** to Firebase AI gateway (`FormaAIBackendClient.analyzeMealImage`). No Firebase Storage upload in this path.

### Failed send behavior

**Confirmed:** `takeSendSnapshot` clears composer before send. If send aborts before user message creation, `restoreComposer(from:)` can restore snapshot (coordinator-level).

**Not implicated** for attach-to-composer failure (occurs before send).

---

## 12. State Reset / Race Conditions

### Documented race: library dismiss vs selection

**Likely but unconfirmed — highest priority:**

`CoachImagePickFlowController.handlePhotoLibraryPickerDismissed`:
```swift
guard case .pickerPresented(.library) = state else { return }
if librarySelectionReceived { librarySelectionReceived = false; return }
state = .idle  // resets flow
```

`handlePhotoLibrarySelection` entry:
```swift
librarySelectionReceived = false  // clears protection flag FIRST
guard case .pickerPresented(.library) = state else { return }  // silent exit
```

**Failure scenario A** (dismiss before selection onChange):
1. User selects photo → picker dismisses → `isPhotoPickerPresented = false`
2. `handlePhotoLibraryPickerDismissed` runs with `librarySelectionReceived == false` → `state = .idle`
3. `photoPickerItem` onChange fires → Task starts `handlePhotoLibrarySelection`
4. Guard fails → **silent drop**

**Failure scenario B** (dismiss during handlePhotoLibrarySelection start):
1. `photoPickerItem` onChange sets `librarySelectionReceived = true`, starts Task
2. Task runs: clears `librarySelectionReceived` (line 85)
3. Before line 89 (`state = .processingImage`), `isPhotoPickerPresented` onChange fires
4. Dismiss handler: flag false, state still `.pickerPresented(.library)` → `state = .idle`
5. Guard on line 86 fails → **silent drop**

**Evidence:** Test `testLibraryDismissWithPendingSelectionDoesNotCancelPickerState` only covers flag-set-before-dismiss manually — does **not** cover scenario B or dismiss-before-onChange.

### Camera race (working reference)

**Confirmed:** `cameraDeliveredResult = true` set at start of `handleCameraResult` with `defer` reset. Dismiss handler checks flag and no-ops. Test: `testCameraDismissAfterDeliveredResultDoesNotDropCapture`.

### Other race conditions

| Risk | Evidence | Confidence |
|------|----------|------------|
| Same Boolean for camera + library | Separate `isCameraPresented` / `isPhotoPickerPresented` | Low — not an issue |
| `confirmationDialog` dismissed before picker | Uses inline menu, not confirmationDialog | Low |
| `PhotosPickerItem` reset before data loads | `photoPickerItem = nil` immediately in onChange; item captured in Task closure | Low — item is captured |
| Task cancelled on view disappear | Unstructured Task, no cancellation handle | Medium — tab switch during load |
| `@State` vs `@ObservedObject` mismatch | `CoachModel.inputState` is `@Published`; `imagePickFlow` is `@StateObject` | Low |
| Composer recreated after selection | `CoachView` stable in TabView | Unknown |
| `beginPhotoLibraryPick` return ignored | `_ = imagePickFlow.beginPhotoLibraryPick(...)` | Medium — silent when busy |
| `completeImport` stale guard | `shouldAcceptImportSuccess` fails silently | Medium — after remove during processing |

### `handlePhotoLibrarySelection` also sets `isPhotoPickerPresented = false`

**Confirmed:** Line 88 may re-trigger dismiss onChange, but by then state should be `.processingImage` so dismiss handler's guard (`pickerPresented(.library)`) fails — safe **if** state transitioned first. Current code transitions on line 89 **after** clearing flag on line 85 — window for scenario B.

---

## 13. Platform / Version Compatibility

| Setting | Value | Source |
|---------|-------|--------|
| `IPHONEOS_DEPLOYMENT_TARGET` | **26.0** | `project.pbxproj` |
| `PhotosPicker` availability | Available (iOS 16+) | Deployment target far exceeds |
| UIKit camera fallback | N/A — camera is UIKit | |
| Availability guards | None found for pickers | |

**Unknown / needs runtime verification:** Simulator vs device behavior for `PhotosPicker` selection ordering. iOS 18+ may differ in onChange ordering.

**Likely but unconfirmed:** Bug may be more reproducible on certain iOS versions where picker dismiss fires before selection binding update.

---

## 14. Error Handling and Logging

### User-facing errors

| Condition | User sees | Location |
|-----------|-----------|----------|
| Camera permission denied | Chat message | `appendMealPhotoSelectionFailure` (non-retry errors) |
| Camera unavailable | Chat message | Same |
| Load / encode / no image | Composer error + Retry button | `inputState.imageErrorMessage` |
| Picker cancelled (camera) | Nothing | `.userCancelled` reverts processing |
| Library dismiss without selection | Nothing | State → `.idle` |
| **Silent guard failure in `handlePhotoLibrarySelection`** | **Nothing** | No error path |
| `beginPhotoLibraryPick` returns false | **Nothing** | Return value discarded |
| Send / AI failure | Chat failure message + retry | `CoachMessageView` / `CoachConfirmationBar` |

### Developer logs

| Logger | When | Release? |
|--------|------|----------|
| `CoachImageProcessingLogger` | Pipeline success/failure, selection failure | **DEBUG only** |
| `CoachImageAnalysisDebugLogger` | Analysis errors | DEBUG |
| `FormaPipelineTracer` | Image processing events | DEBUG |

**Confirmed:** Silent library attach failure leaves **no Release-visible log**.

### Loading state

**Confirmed:** `"Preparing photo…"` shown when `imagePickFlow.isProcessingImage`. If selection is silently dropped, loading state never appears.

---

## 15. Theme / UI Consistency

**Assessment:** Not relevant to attach failure. Preview and picker chrome use `CoachDesignTokens` consistently.

**Confirmed (for completeness):**
- Thumbnail: `CoachMealPhotoThumbnailView` with `composerAttachmentSize` / `composerAttachmentCornerRadius`
- Remove button: `CoachComposerAttachmentRemoveButton` (circle X, elevated surface)
- Dark mode: theme tokens via `CoachDesignTokens` / `FormaTokens`
- Processing copy: `FormaProductCopy.Coach.composerImageProcessing` = `"Preparing photo…"`

---

## 16. Suspected Root Causes

### 1. Library picker dismiss/selection race drops callback (HIGHEST)

| | |
|---|---|
| **Evidence** | `librarySelectionReceived` cleared at line 85 before state transition; `handlePhotoLibraryPickerDismissed` resets to `.idle` when flag false; guard in `handlePhotoLibrarySelection` returns silently |
| **Confidence** | **High (code logic); needs runtime confirmation** |
| **Verify** | Breakpoint in `handlePhotoLibrarySelection` guard; log `state` on dismiss onChange; test dismiss-before-selection ordering |

### 2. `photoPickerItem` onChange never fires

| | |
|---|---|
| **Evidence** | SwiftUI `PhotosPicker` binding issues reported in community; no app-level fallback |
| **Confidence** | Medium |
| **Verify** | Log in `onChange(of: photoPickerItem)` on device |

### 3. `beginPhotoLibraryPick` silently fails (flow busy)

| | |
|---|---|
| **Evidence** | Return value discarded; `state != .idle` or `!requestPhotoPick()` returns false with no UI |
| **Confidence** | Low-Medium (would also block re-tap) |
| **Verify** | Log return value; check `flow.state` after Choose Photo tap |

### 4. `loadTransferable` fails for HEIC/large assets

| | |
|---|---|
| **Evidence** | `CoachPhotoPickerTransfer` only `.image`/`.jpeg`; no explicit HEIC |
| **Confidence** | Low for silent failure (would show composer error) |
| **Verify** | Select HEIC on device; check for composer error row |

### 5. `completeImport` / `shouldAcceptImportSuccess` silent discard

| | |
|---|---|
| **Evidence** | `localReferenceID` mismatch or no active import → `state = .idle` return |
| **Confidence** | Medium for edge cases (remove during processing) |
| **Verify** | Breakpoint in `completeImport` success guard |

### 6. Missing photo library permission

| | |
|---|---|
| **Evidence** | Key exists in pbxproj |
| **Confidence** | Low |
| **Verify** | Check Settings → Forma → Photos |

### 7. Legacy dead code confusion

| | |
|---|---|
| **Evidence** | `CoachPhotoPickerPresentation`, `CoachInputAttachmentState` exist but unused in production |
| **Confidence** | Low for runtime bug (could cause fix-in-wrong-place) |
| **Verify** | Ensure fixes target `CoachImagePickFlowController` path |

### 8. Tab inactive / view lifecycle

| | |
|---|---|
| **Evidence** | `CoachView.isActive` stops speech on tab change; no explicit image flow reset |
| **Confidence** | Low |
| **Verify** | Reproduce on scenario 11 (switch tabs during pick) |

---

## 17. Files Involved

| Area | File | Relevant symbols | Notes |
|------|------|------------------|-------|
| Coach UI root | `Fitness Coach/Features/Coach/CoachView.swift` | `photoPickerItem`, `handleAttachmentSelection`, `.photosPicker`, `.fullScreenCover` | **Primary wiring** |
| Input composer | `Fitness Coach/Features/Coach/Components/CoachComposer.swift` | `attachmentButton`, `attachmentPreviewStrip`, `canSend` | Preview when `pendingImage.isReady` |
| Attachment menu | `Fitness Coach/Features/Coach/Components/CoachAttachmentMenu.swift` | `CoachAttachmentOption`, `CoachAttachmentMenu` | Take/Choose buttons |
| Bottom stack | `Fitness Coach/Features/Coach/Components/CoachBottomAccessoryStack.swift` | Pass-through to composer | |
| Camera picker | `Fitness Coach/Features/Coach/Components/CoachPhotoCapture.swift` | `CoachCameraPicker` | UIImagePickerController .camera |
| Flow controller | `Fitness Coach/Features/Coach/Model/CoachImagePickFlowController.swift` | `beginPhotoLibraryPick`, `handlePhotoLibrarySelection`, `handlePhotoLibraryPickerDismissed` | **Likely bug location** |
| Flow state | `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePickFlowState.swift` | `CoachImagePickFlowState` | State machine |
| Camera access | `Fitness Coach/Features/Coach/Model/CoachCameraAccess.swift` | `resolveForCapture` | Pre-camera permission |
| Photo transferable | `Fitness Coach/Features/Coach/Model/CoachPhotoPickerTransfer.swift` | `CoachPhotoPickerTransfer` | PhotosPicker import |
| Image pipeline | `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+ImportedImageProcessing.swift` | `loadImageFromPhotoLibrary`, `processImportedImage` | Shared processing |
| Image pipeline | `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+Camera.swift` | `importFromCamera` | Camera entry |
| Image pipeline | `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImagePipeline+PhotoLibrary.swift` | `importFromPhotoLibrary` | Unused directly by flow controller |
| Composer state | `Fitness Coach/Features/Coach/Model/CoachInputState.swift` | `pendingImage`, `canStartImageSelection`, `takeSendSnapshot` | |
| Pending image | `Fitness Coach/Features/Coach/Model/CoachPendingImageState.swift` | `CoachPendingImageState`, `CoachInputAttachmentSource` | |
| Input coordinator | `Fitness Coach/Features/Coach/Model/CoachInputCoordinator.swift` | `stagePipelineProcessedPhoto`, `beginPendingImageProcessing` | |
| View model | `Fitness Coach/Features/Coach/Model/CoachModel.swift` | `inputState`, `sendCurrentMessage`, photo delegates | |
| Local image store | `Fitness Coach/Features/Coach/Model/CoachPendingImageLocalSourceStore.swift` | In-memory UIImage store | Retry support |
| Errors | `Fitness Coach/Features/Coach/Model/CoachMealPhotoError.swift` | `CoachMealPhotoError` | |
| Thumbnail UI | `Fitness Coach/Features/Coach/Components/CoachMealPhotoThumbnail.swift` | `CoachMealPhotoThumbnailView` | |
| Chat photo UI | `Fitness Coach/Features/Coach/Components/CoachChatPhotoMessageView.swift` | Sent message rendering | |
| Message model | `Fitness Coach/Domain/Models/ChatMessageImageAttachment.swift` | `ChatMessageImageAttachment` | Transcript |
| Message model | `Fitness Coach/Domain/Models/ChatMessage.swift` | `userMealPhoto`, `mealPhotoJPEG` | |
| Send flow | `Fitness Coach/Features/Coach/Model/CoachSendFlowCoordinator.swift` | `sendCurrentMessage` | Routes text vs image |
| Photo send | `Fitness Coach/Features/Coach/Model/CoachPhotoFlowCoordinator.swift` | `sendMealPhoto` | Creates user message + analysis |
| AI payload | `Fitness Coach/Application/UseCases/Coach/CoachMealImageAIRequestBuilder.swift` | `buildAnalysisRequest` | base64 encoding |
| AI service | `Fitness Coach/Application/Services/AIService.swift` | `analyzeMealImage` | |
| Backend | `Fitness Coach/Infrastructure/AI/FormaAIBackendClient.swift` | HTTP gateway | |
| Upload config | `Fitness Coach/Features/Coach/Model/ImagePipeline/CoachImageUploadConfig.swift` | Size/quality limits | |
| Logging | `Fitness Coach/Infrastructure/Diagnostics/CoachImageProcessingLogger.swift` | DEBUG analytics | |
| Copy | `Fitness Coach/Domain/Copy/FormaProductCopy+Coach.swift` | `composerImageProcessing`, `mealPhotoPreparationFailed` | |
| Error copy | `Fitness Coach/Application/StateBuilders/Coach/CoachResponseBuilder.swift` | `mealPhotoError` | |
| Project settings | `Fitness Coach.xcodeproj/project.pbxproj` | Permission strings, deployment target | |
| Legacy (unused) | `Fitness Coach/Features/Coach/Model/CoachPhotoPickerPresentation.swift` | Alternate state machine | Tests only |
| Legacy (unused) | `Fitness Coach/Features/Coach/Model/CoachInputAttachment.swift` | Old attachment model | Superseded |
| Tab host | `Fitness Coach/App/MainTabView.swift` | `CoachView` host | |
| Deep link | `Fitness Coach/Features/Today/Model/TodayActionCoordinator.swift` | `.scanFood` → camera | |

---

## 18. Existing Tests

### Coverage that exists

| Test file | What it covers | Uses real picker? |
|-----------|----------------|-------------------|
| `CoachImagePickFlowTests.swift` | Camera flow, dismiss races, library dismiss flags | No — calls handlers directly |
| `CoachImagePickFlowQATests.swift` | Stale import, remove/replace, send matrix, large images | No |
| `CoachImagePickFlowRetryTests.swift` | Composer retry after failure | Camera only |
| `CoachPhotoLibraryPipelineTests.swift` | Pipeline staging for library source | No — direct `stagePipelineProcessedPhoto` |
| `CoachImageWorkflowE2ETests.swift` | Library/camera staging via test harness | No — `stageTestMealPhoto` bypasses picker |
| `CoachImageWorkflowHardeningTests.swift` | Double-send, auth failure | Harness |
| `CoachManualImageQAExecutionTests.swift` | 22-step checklist programmatically | No — harness simulates library |
| `CoachPendingImageStateTests.swift` | Pending image lifecycle | Unit |
| `CoachInputStateTests.swift` | `canSend`, snapshot | Unit |
| `CoachImagePipelineTests.swift` | Compression, resize | Unit |
| `CoachMealPhotoAnalysisTests.swift` | Send + AI analysis | Harness |
| `CoachMealImageAIRequestBuilderTests.swift` | AI payload | Unit |

### Stale / broken tests (reference removed APIs)

| Test file | Issue |
|-----------|-------|
| `CoachPhotoLibraryImportTests.swift` | Calls `model.importAttachment`, `inputAttachmentState` — **removed from CoachModel** |
| `CoachInputAttachmentStateTests.swift` | Same legacy API |
| `CoachMessageAttachmentSendTests.swift` | Same legacy API |
| `CoachAttachmentFlowStateTests.swift` | Mix of `CoachPhotoPickerPresentation` + legacy APIs |

### Missing coverage (would catch this bug)

1. **Integration test calling `handlePhotoLibrarySelection` with mock `PhotosPickerItem`**
2. **Race test: dismiss onChange before/after `markLibrarySelectionReceived`**
3. **Race test: dismiss onChange between lines 85–89 of `handlePhotoLibrarySelection`**
4. **UI test: tap Choose Photo → select → assert thumbnail appears**
5. **Test that `photoPickerItem` onChange fires in host view hierarchy**

**Confirmed:** Current tests would **not** catch the dismiss/selection race because they bypass `PhotosPicker` and `handlePhotoLibrarySelection` guard paths.

---

## 19. Runtime Reproduction Checklist

| # | Scenario | Expected | Current likely behavior | Logs to capture |
|---|----------|----------|-------------------------|-----------------|
| 1 | + → Take Photo → capture | Thumbnail in composer | **Works** (per report) | Camera permission status |
| 2 | + → Choose Photo → JPEG | Thumbnail in composer | **Fails** — no thumbnail | `photoPickerItem` onChange; `handlePhotoLibrarySelection` entry; `flow.state` |
| 3 | + → Choose Photo → HEIC | Thumbnail or error + retry | **Unknown** — error if load fails | `loadTransferable` result |
| 4 | + → Choose Photo → large image | Thumbnail or error | **Unknown** — pipeline handles large in tests | Processing duration; byte size |
| 5 | Limited library permission | Picker works, selection attaches | **Unknown** | Photos authorization status |
| 6 | Denied library permission | Picker or error | **Unknown** — PHPicker may still work | Settings state |
| 7 | Choose Photo → cancel | No thumbnail, idle state | **Likely works** | `handlePhotoLibraryPickerDismissed` |
| 8 | Add image → remove | Composer clears | **Likely works** | `pendingImage` nil |
| 9 | Add image → type → send | Chat bubble + analysis | **Works for camera** | AI call count |
| 10 | Image only send | Chat bubble, no caption | **Works when image attached** | |
| 11 | Add image → switch tabs → return | Image preserved or cleared | **Unknown** | `isActive` onChange |
| 12 | Add image → keyboard open | Layout OK | **Unknown** | Visual |
| 13 | Camera → remove → library | Library attaches | **Reproduces bug?** | Flow state sequence |
| 14 | Library → remove → camera | Camera attaches | **Likely works** | |
| 15 | Second image when one attached | Replaces after success | **Unknown on device** | `beginProcessingNewSelection` |

### Debug instrumentation suggestions (for fix phase)

1. Add **Release-safe** breadcrumb when `handlePhotoLibrarySelection` guard fails (include `state` raw value)
2. Log order: `photoPickerItem onChange` vs `isPhotoPickerPresented onChange`
3. Breakpoints: `CoachImagePickFlowController` lines 71–79, 81–90

---

## 20. Recommended Fix Direction

**Do not implement yet.** Recommended architecture:

### Preferred approach: Option 1 + 4 hybrid

**Keep separate camera and library picker adapters, normalize into one attachment state machine.**

Rationale:
- Camera path works; don't replace `UIImagePickerController`
- Library path needs race hardening, not full rewrite
- `CoachPendingImageState` / `CoachInputCoordinator` are already the unified model

### Required end-state architecture

```
┌─────────────────────────────────────────────────────────┐
│              CoachComposer (single preview)              │
│         pendingImage: CoachPendingImageState?            │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│           CoachImagePickFlowController                   │
│   state machine + ONE pendingImageAttachment path        │
└───────┬─────────────────────────────────────┬───────────┘
        │                                     │
┌───────▼──────────┐                 ┌────────▼─────────┐
│ CameraAdapter    │                 │ LibraryAdapter   │
│ CoachCameraPicker│                 │ PhotosPicker     │
│ → UIImage        │                 │ → PhotosPickerItem│
└───────┬──────────┘                 └────────┬─────────┘
        │                                     │
        └──────────────┬──────────────────────┘
                       ▼
            CoachImagePipeline.processImportedImage
                       ▼
            CoachInputCoordinator.stagePipelineProcessedPhoto
```

### Specific fix targets (for implementation phase)

1. **Transition to `.processingImage(.library)` BEFORE clearing `librarySelectionReceived`** (mirror camera's `cameraDeliveredResult` pattern)
2. **Do not reset to `.idle` on dismiss if a selection Task is in flight** — use generation token or `processingImage` guard in dismiss handler
3. **Remove silent guard return** — log + optionally surface error if selection arrives in unexpected state
4. **Check `beginPhotoLibraryPick` return value** — surface feedback if pick blocked
5. **Add integration test** for dismiss/selection ordering
6. **Consider `photoPickerItem` binding on item-based `.photosPicker(item:)` API** if iOS 26 offers more reliable selection callback

### Options comparison

| Option | Pros | Cons |
|--------|------|------|
| 1. Normalize output, keep separate pickers | Minimal change, camera untouched | Still two presentation paths |
| 2. Single ImageAttachmentPicker coordinator | Clean API | Larger refactor |
| 3. PhotosPicker + UIImagePickerController | Current architecture | Doesn't fix race alone |
| 4. Single state machine in composer model | Clear ownership | Already mostly exists in `CoachImagePickFlowController` |

**Safest for this app:** Option 1 — surgical fix to `CoachImagePickFlowController` + `CoachView` onChange ordering, preserving working camera path.

---

## 21. Final Summary

### Highest-confidence root cause

**Likely but unconfirmed:** **State-binding race in the photo library pick flow** — `CoachImagePickFlowController.handlePhotoLibrarySelection` is silently dropped when picker dismissal resets `CoachImagePickFlowState` to `.idle` before or during selection handling, due to fragile `librarySelectionReceived` flag timing. Camera path avoids this with `cameraDeliveredResult`.

### Exact files likely needing modification

1. `Fitness Coach/Features/Coach/Model/CoachImagePickFlowController.swift` — **primary**
2. `Fitness Coach/Features/Coach/CoachView.swift` — onChange ordering / Task structure
3. `Fitness CoachTests/CoachImagePickFlowTests.swift` — add race regression tests
4. Optionally `Fitness Coach/Infrastructure/Diagnostics/CoachImageProcessingLogger.swift` — Release breadcrumbs

### Highest-risk area

Changing dismiss/selection synchronization without breaking:
- Cancel-without-selection (should return to idle cleanly)
- Stale import guards after remove (`shouldAcceptImportSuccess`)
- Working camera path

### Missing runtime information

1. Does `photoPickerItem` onChange fire on user's device?
2. Exact ordering of `isPhotoPickerPresented` vs `photoPickerItem` onChange on their iOS version
3. Whether failure is 100% silent or sometimes shows "Preparing photo…" / error
4. Whether starter chip "Photo meal" (library-only) fails same as + → Choose Photo
5. Simulator vs physical device behavior

### Recommended next step before implementing

1. **Runtime reproduce** on device with breakpoints/logging at:
   - `CoachView` `onChange(photoPickerItem)`
   - `CoachView` `onChange(isPhotoPickerPresented)`
   - `handlePhotoLibrarySelection` entry + guard failure
2. **Confirm hypothesis** — if guard fails with `state == .idle`, proceed with race fix
3. **Add failing unit test** simulating dismiss-before-selection ordering
4. **Implement minimal fix** in `CoachImagePickFlowController` (state transition before flag clear; dismiss handler respects in-flight selection)
5. **Add UI test** for Choose Photo → thumbnail visible
6. **Remove or update stale tests** referencing `importAttachment` / `inputAttachmentState` to prevent future confusion

---

*Generated by static codebase audit. Commit: detached HEAD `d5c88290` / branch `cursor/coach-photo-picker-context-e7c4`. No source code was modified.*
