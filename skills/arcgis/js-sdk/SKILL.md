---
name: js-sdk
description: Build and migrate apps with the ArcGIS Maps SDK for JavaScript at the target ArcGIS Online or Enterprise version. Use when the user works with @arcgis/core, map components, MapView or SceneView, or migrates between 3.x, 4.x, or 5.x.
---

# ArcGIS Maps SDK for JavaScript

## Resolve the target first

Determine whether the app targets **ArcGIS Online** or a **specific ArcGIS Enterprise version**, then resolve the SDK version from the live Esri version matrix — <https://developers.arcgis.com/javascript/latest/version-matrix/> — rather than assuming "latest." The Enterprise release pins the SDK version, which in turn pins Calcite.

## Know the generation boundaries

These are not ordinary version steps — treat them as distinct products where noted:

- **3.x** — retired 2024-07-01. Not a migration target.
- **4.x** — a complete rewrite of 3.x, not an increment. Moving 3.x → 4.x is a rewrite.
- **5.x** — continues 4.x under semantic versioning: minor bumps are backward-compatible, major bumps are breaking.
- Migrating **3.x → 5.x is a rewrite, not an upgrade**.

## Use ES modules or components — the AMD path is dead

4.31 was the last release of the `arcgis-js-api` AMD npm package; its AMD TypeScript declarations and `@arcgis/cli` are retired. Build with `@arcgis/core` ES modules or the components packages. Do not scaffold AMD.

## Prefer components over widgets

Components are the recommended path. If you use widgets, **or** initialize `MapView`/`SceneView` programmatically, you must manually include the core API CSS stylesheet — omitting it renders the view broken.

## Pin Calcite

Pin Calcite to the version the target SDK uses (from the version matrix above), or a greater compatible minor.

## Settle the redirect URL before you choose a dev server

Local sign-in fails for environmental reasons far more often than code reasons, and the dev server is the hardest of those to change late. Redirect URLs are an allowlist stored on the OAuth credential item — only a registered value works, and nothing about the scheme, port, or path is guaranteed. Fix the accepted value first, then pick a server that can serve it.

- **You own the credential item** — register the URL you intend to serve from, under Settings > Application > Redirect URLs on the item page, and serve exactly that.
- **Someone else owns it** (a shared or training `client_id`) — you cannot read the registration from outside the org, but you can **probe** it. Request the authorize endpoint once per candidate: `400` means rejected, `200` means accepted. No credentials needed.

  ```
  https://www.arcgis.com/sharing/oauth2/authorize
    ?client_id=<APP_ID>&response_type=code&redirect_uri=<CANDIDATE>
  ```

  Probe both schemes and the exact port and path you plan to serve. Many orgs register only `https://localhost`, which rejects every `http://` form and every `127.0.0.1` form — and a plain-HTTP dev server (VS Code Live Preview, `http-server`, `python -m http.server`) cannot be retro-fitted with TLS. When only `https` is accepted, serve over HTTPS — Vite with `@vitejs/plugin-basic-ssl` is enough for a CDN-based app with no build step — and tell the user up front that they must click through the self-signed certificate warning once, or it reads as a failure.

Run the redirect in a top-level browsing context. ArcGIS refuses to render its sign-in page in a frame, so in VS Code Simple Browser and other preview panels the sign-in button silently does nothing. Detect `window.top !== window.self` and tell the user to open a real tab.

When both an API key and user authentication are configured, the API key wins — a successful sign-in that still behaves like an anonymous session usually means a stray API key, not a broken flow.

## Destroy credentials only on a user action

`IdentityManager.checkSignInStatus()` rejects on every load with no session — including the load immediately after ArcGIS redirects back with an authorization code. That rejection is a normal state, not an error, so keep its handler to showing the signed-out UI. Calling `destroyCredentials()` there deletes the PKCE state the **return leg** needs (`sessionStorage`, key `esriJSAPIOAuth`, namespaced by page path), and the user signs in successfully only to land back on the sign-in screen, every time. Put `destroyCredentials()` behind an explicit Sign out or Reset button.

On the return leg, read `code`, `error`, and `error_description` from **both** `location.search` and `location.hash` before the SDK consumes them. When they are present but no credential results, show the reason on screen — a silent fall-through to the sign-in screen is indistinguishable from a dead button, and that is what makes this expensive to find. Strip them with `history.replaceState` only after `checkSignInStatus()` settles.

## Verify the signed-in state on the real page

A gate that covers the app until sign-in is the right shape when ArcGIS Online basemaps need a token, because there is nothing to draw before sign-in. Verify it on the real page: a token-free harness — `basemap: "osm"` against a public layer — proves the map, renderer, and legend without credentials and is worth building, but it omits the gate and therefore cannot prove sign-in works. A green harness is not a working app.

When the gate carries an author `display` rule (`display: grid`, `display: flex`), that rule overrides the user-agent `display: none` behind the `hidden` attribute, so `gate.hidden = true` changes nothing and the finished app sits behind the gate. Ship `[hidden] { display: none !important; }`.

## Verify before you propose API

Before proposing any class, method, or property, confirm through `arcgis-docs-lookup` that it exists at the pinned version. When moving between versions, read the breaking-changes guide rather than assuming a method still exists.

## Guard destructive edits

Before emitting any code that deletes or overwrites data — `FeatureLayer.applyEdits` with deletes, `deleteFeatures`, or an editor widget wired to a live layer — stop and satisfy every point in order. This covers irreversible data operations only, not credentials or org hygiene.

1. **Name the target.** State the org/portal and the exact item or layer id the operation hits. An unnamed target is a stop.
2. **Show what it is.** Display the layer's title, type, and feature count so the user sees what they are about to lose.
3. **Confirm it is not production.** Say so explicitly and get the user's confirmation before proceeding.
4. **Prefer the reversible form first.** Offer a read-only query or a count so the blast radius is known before the destructive call runs.
5. **Never emit blind.** Withhold the destructive call until 1–4 are satisfied and the user confirms — even when the user sounds certain.

Enforcement shape for this SDK: check whether the layer URL is hardcoded or config-driven and whether it currently points at production, and place the confirmation in the app flow before the write runs.

## Done when

The target and SDK version are resolved from the matrix; no AMD scaffolding remains; components (or CSS-included widgets) are chosen deliberately; Calcite is pinned to a compatible version; every proposed API is verified at the pinned version; and any destructive edit has passed through the guard. Where the app signs in: the redirect URL was registered or probed rather than assumed, the dev server serves that exact URL, `destroyCredentials()` is reachable only from a user action, and the app was driven through sign-in on the real page and seen in its signed-in state.
