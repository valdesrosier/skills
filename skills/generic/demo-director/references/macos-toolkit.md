# Optional native macOS adapter

**Load only after user identified/approved macOS capture host; not required by the skill.**

The skill is platform-neutral. First ask the user to provide their capture host's hardware/OS or explicitly approve limited read-only identification with a stated scope. Do not automatically detect the OS, inventory hardware, enumerate windows, or infer approval from installed tools, workspace paths or existing system permissions. This adapter is selected only after that intake; it is not a host-identification tool.

`scripts/macos.swift` is an optional, dependency-free, explicitly window-scoped **macOS-only** helper. It does not work on Windows or Linux and is not a prerequisite for the skill's other platform/browser workflows. It is not a general UI automation engine. Once this adapter is selected, build it with Apple's Swift compiler and a **macOS 15+ SDK**, and run on **macOS 15+**:

```sh
swiftc -parse-as-library "/absolute/path/to/demo-director/scripts/macos.swift" \
  -o "/absolute/path/to/demo-native"
"/absolute/path/to/demo-native" --help
"/absolute/path/to/demo-native" --self-test
```

`--help` and `--self-test` do not initialize AppKit, inspect applications or permissions, post input, or start capture. Self-tests cover pure easing, geometry, size limits, lock-state parsing, path parsing and invalid arguments.

## Authorization and discovery

After the user has identified/approved a macOS capture host, obtain explicit authorization for the proposed read-only discovery and **one specific application's window**, its visible content and the intended actions. Host-identification approval does not authorize window inspection or control. An explicit bundle identifier scopes discovery, not permission to interact with every window in that application. Existing macOS privacy permissions are not user approval for this task. This helper never requests permissions, changes preferences, types text, manages sleep, launches applications, or kills other processes.

```sh
"/absolute/path/to/demo-native" list "ALLOWED.BUNDLE.ID"
```

Run `list` only after approval for this scoped window discovery. It reads ScreenCaptureKit window metadata, but emits **only normal windows belonging to the exact supplied bundle**. It does not print other applications, menus or recent documents. Screen Recording permission must already be granted; a failed preflight returns JSON without asking for it. A successful empty `windows` array means no eligible window was found.

After visually confirming the intended window, copy one observed `windows` entry into `/absolute/path/to/window-config.json`. Retain these required fields exactly:

| Field | Source and meaning |
|---|---|
| `pid` | Observed positive process ID |
| `bundle_id` | Exact authorized bundle identifier |
| `window_id` | Observed positive ScreenCaptureKit/CG window ID |
| `window_title` | Exact nonempty title, including case and whitespace |
| `expected_bounds` | Observed `{ "x", "y", "width", "height" }` in global screen **points**, not image pixels |

The extra `on_screen` field from `list` can remain in the config. Configs must be regular JSON files of at most 64 KiB. Paths must be absolute; do not use literal example placeholders or invent a PID, window ID, title, bounds or AX path. Rediscover after navigation changes the title, after moving/resizing the window, or after application restart.

## Read-only inspection

`preflight` and `tree` also require explicit approval for their inspection scope; "read-only" is not an exemption from consent.

```sh
"/absolute/path/to/demo-native" preflight "/absolute/path/to/window-config.json"
"/absolute/path/to/demo-native" tree "/absolute/path/to/window-config.json"
```

Preflight reports `permissions`, `session_lock`, expected and observed `geometry`, viability, and whether the exact window is frontmost. It never activates or raises a window. `recording_viable` means the identity/environment checks passed, **not** that an encoder has been started or an output destination tested. `control_viable` additionally checks event-posting permission; individual controls still need validation. Failures return `status: "failure"`, a stable error code, `viable: false`, and nonzero exit. Unavailable observed geometry is `null`.

**Fail closed:** Screen Recording and Accessibility must already be granted. `CGSessionCopyCurrentDictionary()` must contain an explicit Boolean `CGSSessionScreenIsLocked: false`. Missing, non-Boolean or unreadable lock state is **unknown**, not unlocked. Some macOS environments do not expose that key even on an unlocked desktop: record/control/preflight/tree will refuse there. Do not replace this with a default-unlocked assumption, request permissions automatically, or work around a refusal.

The helper matches AppKit's running bundle/PID, ScreenCaptureKit's exact window ID/title/bundle/PID, Core Graphics identity/geometry, and an `AXWindow` with the same title and bounds. It locks one AX application proxy and one AX window for the invocation. Public AX APIs do not guarantee a window-number attribute: title/geometry mapping must be unique in both SCK and AX, or the helper refuses. Windows must be normal, on screen and explicitly not minimized. Window geometry allows at most **one point** of rounding difference per component; control bounds must remain exactly unchanged.

`tree` traverses only the selected AX window's children. It outputs observed paths such as `w.0.2`, roles, labels, bounds and enabled state. A label is the exact nonempty `AXTitle`, or `AXDescription` only when the title is empty. It never reads AX text values, help text, identifiers, document URLs, the application menu bar or secure-input subtrees. Menu/nested-window subtrees are excluded. Limits: 1,000 nodes, depth 24, 512 children per node and a 15-second traversal budget, plus bounded AX calls/final verification. `truncated: true` means inspection was partial, not permission to guess a missing path. Selected-window labels may still contain sensitive information; handle logs accordingly.

## Pointer movement and clicks

Calling `move` or `click` authorizes **activation of the configured running application and raising of the exact configured window**. No other command does either.

```sh
"/absolute/path/to/demo-native" move "/absolute/path/to/window-config.json" \
  "w.0.2" "EXACT LABEL FROM THE FRESH TREE"
"/absolute/path/to/demo-native" click "/absolute/path/to/window-config.json" \
  "w.0.2" "EXACT LABEL FROM THE FRESH TREE"
```

Replace the illustrative path and label with a freshly observed pair. Supported targets:

| AX role | Move | Click |
|---|---|---|
| `AXButton`, `AXCheckBox`, `AXRadioButton` | Yes | Yes |
| `AXTextField`, `AXTextArea` | Yes | **No** |
| Secure inputs, menus, other roles | No | No |

No arbitrary coordinates, screenshot-derived points, map offsets, keyboard input or AX press-action bypass are accepted. The target center is derived from its live AX bounds. The node must be enabled, larger than one point in both dimensions, entirely inside the selected window and hit-testable. One-pixel/off-screen accessibility sentinel nodes are unusable.

Motion uses the current pointer location, minimum-jerk interpolation and a 60 Hz target cadence, with planned duration clamped to 0.35–1.25 seconds. It posts normal mouse-move events, not a cursor warp. Slow AX checks can reduce cadence; a stall over 250 ms cancels rather than jumping. Held modifier keys/buttons or independent pointer movement also cancel.

Before, during and after motion the helper revalidates permissions, lock state, exact window identity/geometry, foreground PID, **exact focused AX window**, target node/path/title/label/bounds/enabled state and the target hit. System-wide hit testing must prove parent ancestry through the requested control into the originally bound AX window. **PID alone is never enough**: another window belonging to the same application covering the target is rejected.

After motion, SCK identity is refreshed and there is at least a 100 ms guarded settle before a click. Both click events are constructed before posting, then posted as one down/up pair without suspension. Completion means events were posted, **not** that an application action succeeded: `application_effect_verified` is false. Verify the intended effect separately, without broadening scope. Cancellation never rewinds the pointer, because that would send more unrequested input.

## Silent window capture

```sh
"/absolute/path/to/demo-native" record "/absolute/path/to/window-config.json" \
  30 "/absolute/path/to/new-recording.mp4" 1920
```

- Finite requested duration: **1–600 seconds**.
- Optional pixel width: even integer **1280–4096**, default **1920**.
- Aspect-preserving even height: 2–8192 pixels; at most 16,777,216 pixels total.
- Single desktop-independent SCK window; **H.264 MP4, 30 fps, cursor visible, shadows excluded**.
- `capturesAudio = false` and `captureMicrophone = false`; no audio/microphone permissions requested.
- Recording can capture a nonforeground window. It never activates the application. The window must remain on screen, not minimized, with its exact identity/title/geometry unchanged.
- Output parent must exist and be writable. Existing output paths, including dangling symlinks, are refused. Use a new filename and an output directory controlled exclusively by the operator; do not let another process create/replace the path while SCK opens it.
- No preferences, display settings, sleep inhibition, system-wide timeout settings or other processes are changed.

The recording delegate's state is protected by a lock. The first `status: "started", ready: true` event is emitted **only after** SCK acknowledges recording start and guards pass again. Wait for that JSON event before beginning the demonstration. Requested duration is measured after READY; startup and finalization can add time to the recorded file. JSON reports actual recorded duration and bytes, not only the requested interval.

A watchdog rechecks the session, permissions, AppKit/CG/AX/SCK identity, minimized state and geometry roughly every 0.5 seconds while APIs respond, including during startup. SCK discovery has a 2-second bound; AX messages use a 200 ms default timeout **local to this helper process**, including child proxies. Window matching has a one-second budget; AX path/ancestry loops have 250 ms budgets, checked between API calls. Recording delegate failures are checked between watchdog polls. Start/stop callbacks have 5-second deadlines, and delegate start/finalization waits have 8-second deadlines. A slow watchdog can add bounded overrun to the requested capture interval. Guard failures request `stopCapture` explicitly; they never emit success. Any partial output is retained and reported as unfinalized, including when cleanup fails.

`status: "completed"` requires successful stop, recording-finished notification, positive recorded duration/bytes and a nonempty regular output file. This is structural verification, not a claim of visual quality. Inspect the result before delivery. A locked session, TCC revocation, system sleep, an unresponsive application, title change or window closure can produce a failed/partial recording. Do not silently retry capture or grant permissions.

## Results and cancellation

Operational stdout is **JSON Lines**. Help is plain text. Exit codes: `0` successful command, `1` runtime refusal/failure, `2` invalid CLI/config input. Recording events include window identity, output path, dimensions, requested/recorded duration, bytes, codec, audio flags and completion/failure state. Treat only `completed` plus exit `0` as successful capture. Errors before a recorder exists use the normal failure envelope rather than claiming a recording started.

`SIGINT` or `SIGTERM` cancels pointer operations and requests stream stop for capture. Cleanup may take the stop timeout. Never terminate unrelated processes; if cancellation is necessary, address only the helper PID you started. `SIGKILL`, process crashes or machine shutdown cannot guarantee MP4 finalization.

## Safe validation without a live demonstration

Without inspection approval, limit validation to compilation, `--help`, pure `--self-test` checks and deliberately invalid configs rejected before AppKit or live inspection starts. Do not run hardware/OS probes, `list`, a valid-config `preflight`, or `tree` as automatic installation checks. These read-only operations still require explicit approval for their scope. Do **not** use `move`, `click` or `record` for an installation smoke test. Do not approve privacy prompts, activate applications or create a fresh recording merely to validate the build.

The helper deliberately refuses inaccessible/custom-rendered controls, missing exact labels, ambiguous AX window mappings, unknown session lock state and stale observations. It cannot make permission checks and macOS event delivery atomic; concurrent user/UI changes can race the final checks. Keep the desktop stable, do not use it unattended for consequential clicks, and verify effects independently.
