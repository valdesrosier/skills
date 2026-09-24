---
name: exb-widget
description: Build ArcGIS Experience Builder Developer Edition custom widgets at the correct compile version. Use when the user develops, builds, or registers an ExB custom widget, edits its manifest.json, or targets specific ArcGIS Enterprise versions with a widget.
---

# Experience Builder Custom Widget

Developer Edition custom widget work. Establish the deployment target and **compile version** before writing widget code; validate behavior in the runtime that will actually load it.

## Establish the target before code

1. Inspect the workspace and existing widget. Establish whether this is a new widget or a change, its required behavior, data/map inputs, intended audience, and deployment target. Ask only for consequential information not already supplied.
2. Distinguish a **local Developer Edition widget**, an **externally hosted full experience**, and a **widget registered in Enterprise**. A Developer Edition app consuming Enterprise data does not inherit the portal-widget compile constraint. Custom widgets cannot be installed into the ArcGIS Online builder; an externally hosted Developer Edition app using Online content is a different target. Verify against [widget and theme deployment](https://developers.arcgis.com/experience-builder/guide/widget-theme-deployment/).
3. Read `client/package.json` for the installed ExB version and inspect the extension layout. Confirm Developer Edition versus an Esri source checkout before following placement or registration instructions. If the installation is unavailable, ask for its version and relevant files; mark the environment gate unresolved rather than guessing.
4. For an **Enterprise-registered widget**, record every promised Enterprise target and resolve its matching Developer Edition via [VERSIONS.md](./VERSIONS.md). Use the same JS SDK version as each portal target. A single artifact starting from the oldest target's matching edition is only a candidate support policy, not a forward-compatibility guarantee: test every promised target. Use target-specific builds or narrow the support range when necessary.
5. For local development or an externally hosted experience, pin the Developer Edition runtime and verify the connected Online/Enterprise services it uses. Record the selected runtime, target(s), source URLs, verification date, and any unresolved pairings before implementation.

`exbVersion` declares framework compatibility; lowering it does not backport APIs, dependencies, or compiled code. The [WidgetManifest reference](https://developers.arcgis.com/experience-builder/api-reference/jimu-core/WidgetManifest/) described its check as not currently enforced when verified on 2026-09-24. Recheck that status for the task; neither the field nor successful compilation proves runtime compatibility.

## Verify the exact-release toolchain

Before dependency installation or startup, use [VERSIONS.md](./VERSIONS.md) to resolve the required Node range, recommended Node version, and npm/pnpm installation choice for the exact release. Compare these with installed tools and the client/server package metadata and lockfiles. Resolve mismatches before running commands; distinguish dependency installation from script execution.

## Implement the smallest affected contract

- **New widget:** establish manifest, runtime, and only the settings/configuration surfaces the behavior needs. Follow a neighboring widget in the verified workspace.
- **Existing widget:** inspect its runtime, settings, configuration, and neighboring tests before editing. Preserve public configuration and framework conventions.
- **Impact:** for a local behavior change, test that behavior; for settings/data/map/action changes, test the affected contracts; for saved-schema or runtime upgrades, include migration and target-runtime checks. Expand validation with impact, not unrelated refactoring.

When implementation guidance is needed, read [Implementation guidance](./references/implementation.md) for the relevant surface. Apply this skill's environment gate first, then the selected implementation guidance, then the validation below. An optional companion does not choose the target runtime or replace these gates.

## Keep the manifest invariants

Follow the [manifest authoring checklist](https://developers.arcgis.com/experience-builder/guide/widget-manifest/): `name`, `type`, `version`, `exbVersion`, and `translatedLocales`. Verify the widget type, version values, declared dependencies/actions, and locale files against the selected release. `name` must be unique and exactly match the widget folder. The authoring checklist and optional properties in TypeScript declarations are distinct checks; validate both.

## Build the intended artifact

- **Dev loop:** resolve startup scripts for the client and server from the installation. Verify extension discovery and reload behavior; restart the client when required for new files or folders.
- **Full experience:** follow [experience deployment](https://developers.arcgis.com/experience-builder/guide/experience-deployment/) to publish/download and host the whole app. A compiled widget directory is not a full-experience export.
- **Compiled widget:** inspect the installation's build scripts and referenced build configuration, run the applicable production build, and verify the actual output. Preserve dynamically imported `widgets/chunks` and required shared-code/chunks in their expected relative layout. Resolve historical command/output differences using [VERSIONS.md](./VERSIONS.md); do not infer the output directory from a script name alone.

## Deploy an Enterprise-registered widget

Only for this target, open **Add custom widgets** for the exact Enterprise release on `doc.arcgis.com`; [12.1](https://doc.arcgis.com/en/experience-builder/12.1/configure-widgets/add-custom-widgets.htm) is an example, not a default target. Resolve and verify the target-version URL before applying the procedure.

1. Confirm an anonymously accessible widget host with HTTPS and a valid certificate. Allow the portal origin through CORS on the **widget-hosting server**. Verify `.json` is served as `application/json` rather than an HTML login/error page.
2. Deploy the compiled widget, dynamic chunks, shared code, locale files, and other required assets with their expected paths. Fetch the manifest and dependent assets, then check browser loading from the portal origin; HTTP success alone is insufficient.
3. Have a portal administrator register each widget's manifest URL and share the item with the agreed audience. Extension/source-checkout registration is not portal registration. Confirm same-organization constraints and intended authenticated/anonymous app access separately from anonymous code hosting. Obtain authorization before changing hosting, registration, or sharing.
4. Smoke-test the widget in every promised target portal, under the intended audience's access. Verify hosted updates and cache behavior when replacing an existing deployment.

## Validate changed behavior

Resolve and run the installation's applicable typecheck, build, and focused test scripts; verify they include the affected widget. Use its existing test helpers, with [official unit-testing guidance](https://developers.arcgis.com/experience-builder/guide/unit-testing/) as the standalone fallback.

- Exercise configured, unconfigured, loading, empty, and error states relevant to the change, including settings persistence and affected data/action contracts.
- For map widgets, exercise view changes and unmounts; confirm watchers, highlights, graphics, temporary layers, and stale asynchronous callbacks are cleaned up.
- For persisted schema changes, test an existing saved configuration through the upgrade path. Select the release-appropriate version manager from the [compatibility guide](https://developers.arcgis.com/experience-builder/guide/make-widgets-backward-compatible/) and installed types. Saved-config migration is distinct from cross-runtime compatibility.
- Check changed UI for keyboard access, accessible labels, localization, and narrow layouts. Verify the built artifact in its chosen delivery environment, not only the development server.

## Done when

Report the deployment mode, verified version/toolchain evidence, changed contracts, artifact location, and results of the applicable build/test/runtime/deployment checks. Every promised runtime has supporting test evidence. Explicitly list unavailable checks and blocked prerequisites; a passing typecheck or build alone is not a compatibility or deployment claim.
