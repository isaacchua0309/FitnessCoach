# Coach Photo Picker QA Runbook

**Status:** Manual QA  
**Audience:** QA, release engineering, engineers validating Coach meal-photo attach  
**Production path:** `CoachImagePickFlowController` → `CoachInputState.pendingImage` (`CoachPendingImageState`) → send via `CoachInputSendSnapshot`

**Related:**
- [CoachArchitecture.md](./CoachArchitecture.md) — picker and composer wiring
- [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) — broader Coach QA matrix

**Note:** Legacy `CoachPhotoPickerPresentation` / `CoachInputAttachmentState` are not production wiring.

---

## Devices

- Physical iPhone (primary)
- Simulator if available (camera may be limited; library picker still useful)
- At least one device with normal Photos library access
- At least one scenario with limited Photos access if possible (Settings → Privacy → Photos → selected photos only)

### Before you start

| Requirement | Notes |
|-------------|-------|
| Signed-in user | Required for send / AI analysis paths |
| Coach tab reachable | Main tab → Coach |
| Network on (default) | Scenario 13 tests attach offline; use Airplane Mode only for that case |
| DEBUG build for log capture | See [Debug logs to capture](#debug-logs-to-capture) |

### Pass / fail convention

| Result | Meaning |
|--------|---------|
| **PASS** | All expected results; no silent failure |
| **FAIL** | Thumbnail missing without cancel, non-retryable error, crash, or stuck flow |
| **BLOCKED** | Environment cannot run (document reason) |

---

## Required scenarios

### 1. Take Photo

**Steps:**
- Coach → **+** → **Take Photo** → capture image

**Expected:**
- Thumbnail appears inside composer
- Send button enables
- Remove button works
- Send creates image chat bubble

---

### 2. Choose Photo JPEG

**Steps:**
- Coach → **+** → **Choose Photo** → select JPEG

**Expected:**
- Thumbnail appears inside composer
- **"Preparing photo…"** appears briefly if processing takes time
- Send button enables

---

### 3. Choose Photo HEIC

**Steps:**
- Coach → **+** → **Choose Photo** → select HEIC from library

**Expected:**
- Thumbnail appears **or** retryable composer error appears
- No silent failure

---

### 4. Choose Photo large image

**Steps:**
- Coach → **+** → **Choose Photo** → select a large photo (e.g. recent iPhone full-resolution shot)

**Expected:**
- Thumbnail appears after compression **or** retryable error appears
- App does not freeze

---

### 5. Cancel library picker

**Steps:**
- Coach → **+** → **Choose Photo** → dismiss picker without selecting

**Expected:**
- No thumbnail
- No error
- Flow returns idle (can open **+** again)
- User can pick again

---

### 6. Choose Photo from starter chip

**Steps:**
- Empty Coach → starter chip **Photo meal** (or equivalent) → select photo

**Expected:**
- Same as **+** menu **Choose Photo** (scenarios 2–5 behavior)

---

### 7. Camera → remove → library

**Steps:**
- Attach image via **Take Photo**
- Tap remove on composer thumbnail
- **+** → **Choose Photo** → select image

**Expected:**
- Library image attaches after camera image removed

---

### 8. Library → remove → camera

**Steps:**
- Attach image via **Choose Photo**
- Tap remove on composer thumbnail
- **+** → **Take Photo** → capture

**Expected:**
- Camera image attaches after library image removed

---

### 9. Replace camera with library

**Steps:**
- Attach image via **Take Photo**
- Without removing, **+** → **Choose Photo** → select another image

**Expected:**
- Old camera thumbnail remains visible until library replacement succeeds
- **"Preparing photo…"** may show during processing
- New library thumbnail replaces old image on success

---

### 10. Replace library with camera

**Steps:**
- Attach image via **Choose Photo**
- Without removing, **+** → **Take Photo** → capture

**Expected:**
- Same replacement behavior as scenario 9 (old thumbnail preserved during processing, then replaced on success)

---

### 11. Add image, type caption, send

**Steps:**
- Attach image (camera or library)
- Type caption in composer
- Send

**Expected:**
- Chat bubble contains image and caption
- AI meal analysis starts (pending confirmation / analysis UI)

---

### 12. Add image only, send if supported

**Steps:**
- Attach image only (no caption)
- Send

**Expected:**
- Chat bubble contains image
- AI meal analysis starts

---

### 13. Network off after attach

**Steps:**
- Attach image while online
- Enable Airplane Mode (or disable network)
- Send

**Expected:**
- Attaching still works (completed before network off)
- Send failure is recoverable (retry or clear error; no crash)

---

### 14. Switch tabs during library processing

**Steps:**
- Coach → **Choose Photo** → select image
- While **"Preparing photo…"** is visible, switch to another main tab, then return to Coach

**Expected:**
- No crash
- Either image attaches **or** safe retryable error appears (never silent drop)

---

### 15. Theme switching while image attached

**Steps:**
- Attach image so thumbnail is visible in composer
- Change app theme (Settings → appearance / theme)

**Expected:**
- Thumbnail border and remove button remain readable in light and dark themes

---

## Debug logs to capture

Enable on DEBUG builds (Xcode console — filter `CoachPhotoLibraryPick`):

```text
FORMA_COACH_PHOTO_LIBRARY_PICK_DEBUG=1
```

(Set in scheme → Run → Arguments → Environment Variables. Default is on unless `FORMA_COACH_PHOTO_LIBRARY_PICK_DEBUG=0`.)

| Event | When to expect |
|-------|----------------|
| `libraryPickStarted` | User opens Choose Photo |
| `librarySelectionReceived` | Picker returns a selection |
| `librarySelectionAccepted` | Controller claims selection for processing |
| `libraryProcessingStarted` | Pending image enters processing |
| `libraryProcessingSucceeded` | Pipeline staged ready thumbnail |
| `libraryProcessingFailed` | Load/pipeline/attach failure |
| `librarySelectionDroppedUnexpectedState` | Should **not** appear in happy path; investigate if seen with a real selection |

Also useful:
- `libraryPickCancelled` — user dismissed picker without selection
- `libraryProcessingDiscardedStale` — benign race after remove/replace (no user error)

**Privacy:** Logs must not contain image bytes, filenames, asset IDs, or user captions.

---

## Release criteria

- **Choose Photo** succeeds **10/10** on device for JPEG.
- **Choose Photo** succeeds **or** shows retryable error for HEIC / large images.
- **No silent failure** (every failed attach shows thumbnail, preparing state, retryable error, or nothing only after intentional cancel).
- **Camera** still works (scenario 1).
- **Send pipeline** still works (scenarios 11–12).

---

## Quick regression matrix

| # | Scenario | Camera | Library | Remove | Replace | Send |
|---|----------|--------|---------|--------|---------|------|
| 1 | Take Photo | ✓ | | ✓ | | ✓ |
| 2 | JPEG library | | ✓ | | | |
| 3 | HEIC | | ✓ | | | |
| 4 | Large image | | ✓ | | | |
| 5 | Cancel picker | | ✓ | | | |
| 6 | Starter chip | | ✓ | | | |
| 7 | Cam → lib | ✓ | ✓ | ✓ | | |
| 8 | Lib → cam | ✓ | ✓ | ✓ | | |
| 9 | Replace cam→lib | ✓ | ✓ | | ✓ | |
| 10 | Replace lib→cam | ✓ | ✓ | | ✓ | |
| 11 | Caption + send | ✓ | ✓ | | | ✓ |
| 12 | Image-only send | ✓ | ✓ | | | ✓ |
| 13 | Offline send | | ✓ | | | ✓ |
| 14 | Tab switch | | ✓ | | | |
| 15 | Theme | ✓ | ✓ | | | |
