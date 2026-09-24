---
name: demo-director
description: Plan, script, rehearse, record, and finish polished software demonstrations through a short interactive interview and explicit script approval. Use for conference demos, product walkthroughs, narrated screen recordings, demo videos, and recuts. Covers browser and native desktop apps across operating systems, hardware discovery by permission, sleep and lock prevention, smooth cursor motion, trustworthy footage, timing, narration, and final quality checks.
---

# Demo director

Turn a real working product into a clear, compelling demonstration. The payoff is
what the product does, not decorative editing. This skill is platform-neutral.
Never assume the user's OS, computer, recording host, audio choice, or preferred
capture method from previous demos.

Invoke with `/demo-director` or "Use demo-director to plan and record a demo."
For an existing recording, specify a recut; reuse its verified sources and accepted
decisions, but obtain approval of the revised script before another recording.

## Operating contract

- Interview before scripting; obtain approval of the timed script before recording.
- Ask one focused question at a time with `ask_user` when available. Offer useful
  choices; do not dump a questionnaire or repeatedly ask already answered questions.
- Ask the user to provide their hardware/OS **or approve limited read-only
  identification**. Do not run hardware, display, OS, or window discovery before
  that choice. Existing environment metadata is context, not permission to probe.
- The machine running the agent may not be the machine being recorded. Establish
  the actual capture host, app host, local/remote session, and available displays.
- Ask about audio each time. There is **no default**: silent/live presenter,
  recorded voiceover, system audio, or a specified combination.
- Preserve prior versions, source data, personal windows, user-adjusted layout,
  and unsaved work. Recording authorization is not permission to publish, change
  access controls, alter power/security settings, or rewrite the product.
- Use real controls and real outputs. Distinguish live execution, prepared runs,
  replay of captured responses, mockups, shortened processing, and local previews.
- Prefer a few verified scenes to a sprawling feature tour. Never call incomplete,
  blank, frozen, cropped, or technically unverified footage a finished video.

## Workflow and gates

### 1. Discover the brief

Read [the interview guide](references/interview.md). Use what the user already
provided; ask only consequential missing decisions. Hardware discovery permission
is required even when the app URL or a previous recording is supplied.

Resolve: audience and setting, one takeaway, duration, app/scenario, main visual
payoff, source truth, must-show/must-avoid items, audio, style, output variants,
capture host, permissions, and delivery needs. A useful interview usually takes
5-8 focused questions, but do not impose a quota or skip essential uncertainties.
Offer clear proposed defaults for lower-impact editorial choices and let the user
accept them together after the core decisions are settled.

With approval, inspect only relevant product files, visible target surfaces, and
referenced sessions. Research actual capabilities instead of asking the user to
guess them. Never infer the hosting provider, AI backend, authentication,
production readiness, or publishing support from conference branding.

**Gate A:** Summarize the brief, supported claims, unresolved blockers, and chosen
capture approach. Script first even if app access or capture permissions are still
blocked; mark unsupported scenes as provisional rather than inventing capability.

### 2. Write the script for approval

Read [script design](references/script-design.md). Create a versioned Markdown
click script using [the template](templates/click-script.md), plus a structured
scene plan based on [demo-plan.json](templates/demo-plan.json). Save these in the
current demo's artifact folder, not inside the installed skill.

Each scene needs:

| Field | Required content |
|---|---|
| Timing | Start/end time, duration, pauses, and transition |
| Picture | What appears on screen; framing and UI state |
| Action | Exact prompt/click/scroll and expected visible result |
| Narration | Words spoken verbatim; directions kept separate |
| Proof | How the visible result and any capability claim will be checked |

Include the opening context, one coherent task, brief grounding, the strongest
payoff, and a decisive ending. Budget spoken words against speaking time, excluding
deliberate silence. Retain a short final hold. For variants, specify which elements
must be identical and which may differ.

Open the script in an editor canvas if available; otherwise provide its full path.
Ask: **"Approve this version for rehearsal and recording, or revise it?"** Record
the approval against the actual script version/hash. A request to revise the story,
claims, or ending invalidates prior script approval.

**Gate B:** No capture, including rehearsal recordings, before explicit approval.
Read-only feasibility checks are fine within the user's discovery consent.

### 3. Stage and rehearse

Read [recording and platform routing](references/recording.md). Select a supported
backend for the approved host; no OS is the default.

Confirm exact app/window/page, data, permissions, display scaling, theme, layout,
audio route, output path, free space, power/lid situation, and allowed exclusions.
Ask separately before granting permissions, switching themes/resolution, closing
personal windows, changing application code, or temporarily inhibiting sleep.

Run real actions and verify real outcomes. App readiness is not merely an HTTP
200, a count label, or absence of a spinner. For linked views, test both directions,
actual map/object hits, record identity, filters, and source preservation.

Record a **5-10 second preflight clip** after approval. Include movement, one
meaningful interaction, a result, and audio if required. Play it back at the
delivery resolution. Check pointer visibility/smoothness, text legibility,
clipping, UI obstruction, protected black surfaces, permissions, and sound.

**Gate C:** Production starts only when the preflight passes and the user has
authorized temporary keep-awake measures or accepted a manual power plan.
Failing preflight means repair and repeat the short clip, not record a full bad take.
Use bounded repair passes. If a dependency or capture backend remains blocked after
distinct reasonable attempts, preserve the usable work and ask for the specific
user action needed; do not spend an open-ended session repeatedly recording failures.

### 4. Record in bounded takes

- Capture only the approved surface. A native app must not silently become a
  browser recreation; ask before switching surfaces.
- Wait for recorder readiness before actions. Log actual action times against the
  recorder clock; do not assume a scheduled click finished at its nominal time.
- Use measured, current selectors/bounds, minimum-jerk cursor travel, short settling
  pauses, and guarded text entry. Never overwrite unexpected composer text.
- Preserve the agreed layout. A real collapse control is acceptable when approved;
  simulated collapse or narrowing the user's pane is not. Use honest editorial
  reframing if the control does not exist.
- Stop a take on lock, sleep, lost focus, window identity/geometry changes,
  disconnection, wrong data, missing layers, failed actions, audio failure, or
  unexpected personal content. Quarantine partial files; retain evidence.
- Never unlock a machine or disable its security policy. Ask the user to unlock;
  rediscover the target and rerun preflight before resuming.

### 5. Edit and verify

Read [editing and quality](references/editing-quality.md). Use the approved scene
plan, genuine footage, and documented trims/holds. Do not accelerate pointer travel
to fit an overlong story; shorten idle dwell or seek approval to simplify.

Use the platform-independent checker:

```text
python "<skill-dir>/scripts/demo_checks.py" plan "<demo-dir>/demo-plan.json" --approved
python "<skill-dir>/scripts/demo_checks.py" video "<demo-dir>/final.mp4" --plan "<demo-dir>/demo-plan.json"
```

`python` means the installed Python 3 command on the approved host; it may be
`python3` or `py -3`. Resolve it locally, not through a hardcoded executable path.
The checker's scope is technical; visual truth, audio quality, content exclusion,
and legibility also require review.

If the user asks for a stronger recut, redesign the story around a more consequential
visible outcome, not simply more transitions. Reapprove the revised script.

**Gate D:** Deliver only after full decode/format/duration checks, scene-boundary
and legibility review, required audio review, source/claim checks, privacy/name
exclusion checks, and variant parity checks pass. Do not conceal known defects.

### 6. Deliver and clean up

Provide the final video, approved script with timing/narration, and full disk paths.
Open a preview when available. Supply Word, captions, separate clips, or theme
comparison only when requested or agreed.

Retain source hashes, capture/action manifests, evidence, edit timeline, and final
verification bound to the final movie hash. Keep earlier approved versions.
Stop only this job's recorder and temporary sleep-inhibition process; leave user
power/security settings unchanged. Keep preview servers attached, not detached,
unless the user explicitly requests survival beyond the session.

For tested lessons from the two source demos, read
[reference cases](references/reference-cases.md). They are examples, not default
datasets, runtime lengths, hardware, apps, ports, or credentials.

## Optional helpers

- [Host inventory](scripts/host_inventory.py): limited read-only OS/architecture
  report, only with explicit approval; does not enumerate applications or windows.
- [Technical plan/video checks](scripts/demo_checks.py): Python 3 plus existing
  ffmpeg/ffprobe for video checks; platform-independent.
- [Browser capture recipe](references/browser-capture.md): actual browser interaction,
  recorder lifecycle, cursor choices, and verified-response replay on supported hosts.
- [macOS adapter](references/macos-toolkit.md): **optional** native capture/control
  implementation for a user-confirmed macOS host. Never invoke it on other platforms.
- Windows and Linux capture options, inhibitors, and limitations are documented in
  [recording](references/recording.md). Verify the selected backend; do not claim
  untested native automation works simply because browser automation does.
