# Browser capture on any supported host

Use this route only when the approved surface is a browser app or the user approved
an independent browser segment. It does not turn a native app into a web app.
The same workflow can run on Windows, Linux, or macOS; verify the installed browser
and recording backend rather than assuming support from the operating system.

## Two legitimate routes

**Visible browser window:** automate actual controls with available browser tools,
and record the dedicated window with the host's approved recorder. This preserves
real browser chrome and the real pointer. Confirm the native recorder excludes
other windows and receives the same geometry/scaling used by the automation.

**Browser-context video:** create a dedicated Playwright context configured for
video before opening its page, using the user's agreed viewport and video size.
This can work headlessly if approved, but does not capture a normal desktop window
or guarantee visible cursor pixels. Check that distinction in the preflight.

Do not enable unsafe remote-debugging exposure or disable browser security. Do not
serialize a signed-in user's cookies/storage state or copy credentials into footage
fixtures without a specific need and approval. An existing authenticated window may
be safer than opening an unapproved new session.

## Recorder lifecycle

Use existing installed tooling and repository patterns. The core Playwright shape,
when that backend is available, is:

```javascript
const context = await browser.newContext({
  viewport: approvedViewport,
  recordVideo: { dir: freshTakeDirectory, size: approvedViewport },
});
const page = await context.newPage();
const video = page.video();
try {
  await page.goto(approvedUrl);
  await verifyActualApplicationReady(page);
  await runApprovedActionsAndLogTheirActualTimes(page);
} finally {
  await context.close();
}
if (!video) throw new Error("The browser context did not create a recording.");
const path = await video.path();
// Decode and inspect this short take before any production run.
```

This is a recipe, not a runnable universal action script. Implement the named checks
and actions against the actual product's observed selectors. Use a fresh directory
per take, retain failures explicitly, and do not deliver merely because `video.path()`
returned a file. Browser context closure finalizes the recording; prematurely copying
an in-progress file can produce an incomplete artifact.

For a real-window recorder, move navigation/loading before recording when the approved
scene starts already ready. For browser-context video, log the start of useful action
after readiness and trim preceding setup as an editorial cut.

## Real actions and smooth motion

Use accessible roles/names or observed selectors, not screenshot guesses. Await each
actual outcome rather than a blind fixed sleep. Scroll the control into view, resolve
its current bounding box, move smoothly, settle, then click. Recheck layout if the
app reflows or opens a panel.

If visible browser cursor rendering is approved, use actual logged coordinates and
timings. For controlled browser motion, interpolate from the tracked pointer position
with the minimum-jerk curve from the recording guide, about 60 updates/second. Start
an untracked cursor off-frame before recording; do not introduce a visible teleport.
Do not claim a synthetic cursor is the operating system pointer.

## Real response replay

The Census demo recorded browser interactions while replaying retained genuine
backend responses for reliable pacing and matching themes. Reuse this method only
if approved and disclosed:

1. Execute the real query and retain only relevant, non-secret inputs/responses.
2. Hash them and identify the exact request endpoint/method/payload and response order.
3. Intercept only that approved endpoint; fail closed on a mismatch or missing fixture.
4. Deliver the genuine recorded payload, including the expected content type and
   streaming/event semantics. Do not invent values, successes, tools, or latency.
5. Compare rendered content against the retained response and across requested themes.

Never use blanket request interception with success-shaped fallback data. An
unmatched request should stop the take, not silently pass through to a changing live
backend when theme parity depends on replay.

## Final checks

Retain tool trace/source availability where relevant without leaking internal or
forbidden names. Confirm all important text is readable at export scale, zoomed maps
retain attribution, and source drawers do not obscure the narrated selection.
Test the actual generated app independently when that is the story's promise.
Close only the dedicated recording context/window when cleanup is authorized; do
not disturb the user's pre-existing browser session.
