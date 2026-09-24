# Capture routing and safe rehearsal

This workflow is cross-platform. Start with the user's supplied host details or
approved discovery, **not an OS-specific command**. Establish whether the app is
native, browser-based, remote, streamed, or headless. Inspect available capture
tools only after permission. Prefer an already installed, suitable backend.

## Choose and verify a route

| Host/surface | Suitable routes | Must establish before promising automation |
|---|---|---|
| Browser, any supported OS | Existing Playwright/browser tools; browser-context video; approved native window recorder | Correct viewport/context; whether a cursor is actually captured; deterministic app/backend readiness |
| Windows desktop | Existing OBS window capture or Windows Graphics Capture; UI Automation for selectors | Interactive session, exact HWND/process identity, DPI coordinates, protected surfaces, permission, visible pointer |
| macOS desktop | ScreenCaptureKit and Accessibility; optional bundled adapter | Screen Recording/Accessibility consent, exact window identity, unlocked visible session, supported OS/API |
| Linux desktop | Existing OBS/PipeWire/desktop-portal capture; AT-SPI where supported | Wayland vs X11, user-selected portal source, compositor rules, scaling, input-injection permission |
| Remote/virtual/headless | Host-specific recorder or browser-context capture | Where pixels are rendered, whether disconnect blanks/freezes the display, and explicit approval for this surface |

Do not pretend one native-control implementation is portable. The bundled macOS
adapter is optional; Windows and Linux must use a verified available backend or a
clearly reported manual step. Do not switch from a native app to a browser recreation
without approval. Never weaken browser security to enable automation.

For browser-context/window recipes and honest real-response replay, read
[browser capture](browser-capture.md).

Browser-only video often omits the system pointer. Test this in the short preflight.
If it is absent, prefer a real approved window recorder. An editorial cursor derived
from logged browser actions is acceptable only if the user approves that treatment,
it tracks actual controls, and the manifest identifies it as editorial.

## Sleep, locking, lids, and remote sessions

Ask before starting a **temporary, bounded keep-awake process**. Explain that it does
not prevent manual locking, closing a laptop lid, corporate policy enforcement,
remote-session loss, thermal shutdown, or power failure.

Ask laptop users to connect power, keep the lid open unless their supported docked
configuration was verified, and avoid sleeping/locking/switching desktops during the
take. Do not assume closing the lid is safe merely because an external display exists.
Confirm that the agent can finish all takes before the inhibitor expires.

Use an existing platform mechanism when approved:

- **macOS:** `/usr/bin/caffeinate -d -i -t <bounded-seconds>` as an attached process.
  Avoid global `pmset` changes; never alter automatic-lock policies.
- **Windows:** use a small owned, bounded process/thread calling documented
  `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED | ES_DISPLAY_REQUIRED)`.
  Check the API result and clear with `ES_CONTINUOUS` in `finally` on that same
  thread. Do not change `powercfg`, registry, screensaver, or security policy.
- **Linux/systemd desktop:** a scoped
  `systemd-inhibit --what=idle:sleep --mode=block --why="Approved demo recording" <bounded-command>`
  may work. Check permission/support and the active inhibitor; on other desktops use
  their approved inhibitor/portal. Never assume it overrides compositor lock policy.

If an inhibitor is unavailable or refused, say so and use a user-agreed manual plan;
do not silently continue with an alleged guarantee. Do not move the mouse to defeat
idle policy, permanently alter settings, or run detached background work by default.
Track owned process IDs/handles and release them when capture finishes.

On lock or sleep: abort and mark the take invalid, ask the user to unlock/wake, then
rediscover window IDs/selectors/geometry and run another short preflight. Never type
into a lock screen or reuse a stale application-level accessibility proxy as a window.

## Permission and privacy checklist

- Confirm the exact target app/window/tab and permitted account/data.
- Obtain screen/microphone/accessibility permissions through normal OS prompts.
- Capture a window, not the whole desktop, unless the user explicitly needs it.
- Use a dedicated browser window; keep personal tabs, history, notifications,
  password managers, recent documents, tokens, and addresses outside the capture.
- Ask the user to quiet notifications if necessary; do not silently change Focus,
  Do Not Disturb, notification settings, or shared-machine preferences.
- Discover only the named target, not a broad window or process inventory.

## Avoid bad takes

Measure the approved window bounds, resolution, display scaling, panel widths,
theme, and output crop. Preserve user-set layout. Check the effective delivery-scale
text size, not only a high-DPI source screenshot. Retain attribution when reframing.

Use existing liveness/error signals and independently verify meaningful results.
For maps, counts do not prove markers are present. Confirm layer visibility, filters,
object identities, actual hits, and selection details. Watch for UI regeneration
destroying imperatively added layers or dependent widgets.

If an app/backend is unavailable, inspect the specific service and port ownership
before starting another copy. Do not delete/recreate a database, change shared ports,
or stop unrelated processes to force a demo through. Report the dependency blocker
and ask for the minimal permitted intervention.

Cursor movement starts at the actual current position. A useful minimum-jerk curve
is `t*t*t*(10 - 15*t + 6*t*t)`, with about 60 updates/second, 0.35-1.25-second travel,
and a short settle before clicking. Slow deliberate movement should not block real
UI responsiveness. Verify focus, exact target, and bounds before/after motion.
Do not animate from screenshots or stale absolute coordinates.

Capture short, independently named scenes where practical. Refuse overwrite.
Wait for "recording started", then log actual actions. On any failure, stop owned
recording processes, retain a clearly failed partial artifact, and describe the
reason. Do not "repair" a failed result by compositing invented product pixels.

## Audio

Confirm microphone/voiceover/system-audio choices, routing, and permissions per job.
Record a short sample and listen for missing audio, clipping, echo, feedback,
notification sounds, and drift. Silent means no audio stream. A video-only adapter
must not be used to claim a narrated deliverable without a separate approved audio
recording and synchronization step.
