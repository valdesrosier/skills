# Editing, evidence, and acceptance

## Honest production

Keep original capture files immutable. Retain the source-result evidence, retrieval
time, exact input prompts, relevant tool receipts, native action timestamps, and
generation/repair steps. Do not copy whole chat databases or credential-bearing DOM.
Preserve only relevant evidence; redact or omit private information transparently.

For deterministic response replay, capture real responses first; bind them to inputs
and hashes, fail on sequence/input mismatch, and disclose replay. Retained server
responses and live browser interactions are compatible, but are not an unprepared
live backend run. Mock or seed data must be labeled, not passed off as authoritative.

Mark shortened processing at the first cut. A still hold is a genuine frozen frame,
not progress. Local preview is not publication, an authenticated second user, or
proof of configured hosting. Conference sponsorship is not proof of an AI backend.

## Composition

- Cut or zoom only approved genuine pixels. Exclude private chat/window-title areas
  **before** padding or camera transforms so no intermediate frame leaks them.
- Keep camera moves purposeful and brief; avoid rapid reframing during cursor travel.
  Favor complete visible cause and effect over perpetual zooming.
- Retain original source attribution in the frame or carry its actual text in a
  discreet editorial credit. Do not add unverified attribution.
- No fake build animations, decorative code, fabricated activity, unsupported buttons,
  excessive overlays, or typography pasted over important product information.
- Keep the cursor parked away from toolbar hover targets; tooltips can spoil the
  introduction and the final hold. Use a neutral, verified position.
- Use a clean full result at the end and a short still hold. Two seconds worked well
  for the application closer; confirm the timing in each new script.

For H.264 delivery, a common target is 1920x1080, 30fps, yuv420p, faststart MP4, but
confirm aspect ratio, resolution, rate, and audio requirements with this user.
High-resolution source capture allows restrained reframing without inventing pixels.

Native captures may have variable timestamps. Normalize before combining:

```text
settb=AVTB,setpts=PTS-STARTPTS,fps=30,setpts=N/(30*TB),setsar=1
```

Use a **decoded concat filter** with each input's timebase/PTS/SAR normalized, then
normalize the combined timeline. Do not use a concat demuxer across incompatible
native/browser/held clips merely because their filenames all end in `.mp4`.
Include transitions and holds in the exact total frame count.

Inspect ffmpeg capabilities before designing overlays: some installed builds have
no `drawtext`. Use an installed font/image renderer for original transparent text
assets instead of silently dropping captions or installing unrelated tooling.

## Acceptance gates

1. **Technical:** expected stream count, codec/pixel format/resolution/rate/duration,
   exact frame total, faststart when required, and full decode. Use `demo_checks.py`.
2. **Content:** exact prompts; correct identities/values/categories/sources/vintage;
   no missing features/layers; supporting details actually visible when narrated.
3. **Visual:** opening, every transition, every demonstrated state, full-prompt dwell,
   selection/filter cause and effect, sources, last seconds. Inspect at delivery scale.
4. **Exclusion:** scan the whole final film for forbidden names and private/internal
   content. OCR every decoded frame for strict name exclusions where tooling permits;
   bind the scan to the final hash. OCR is fallible, so combine with crop bounds and
   visual inspection. If tooling is unavailable, disclose the limit and manually review
   the complete export rather than claiming an automated full-frame pass.
5. **Audio:** if required, listen to the complete export and check synchronization;
   presence of an audio stream alone is not sufficient.
6. **Variants:** verify identical content/action sequence/timings when promised;
   compare per-theme visible output and response hashes, not just duration.
7. **Ending:** ensure the held input really is static and camera/overlays stop moving.
   H.264 may decode slightly different pixel hashes during a valid still hold; assess
   measured differences plus the fixed source frame, not hash identity alone.

Inspect for black/blank/frozen intervals, but do not automatically reject an intentional
dark theme or approved still hold. Conversely, successful decoding alone does not
prove a meaningful UI was captured.

If the final file changes, invalidate its old audit, recheck the changed export, and
update the evidence hash. Report blockers plainly. Deliver full disk paths alongside
download/preview links because in-app downloads may fail.
