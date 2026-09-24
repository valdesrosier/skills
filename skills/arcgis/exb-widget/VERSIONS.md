# Experience Builder Versions

Use live anchors for the exact release. Record source URLs and verification date with the task's environment decision; this file is a lookup procedure, not a cached support table.

## Runtime pairing

1. Read [About release versions](https://developers.arcgis.com/experience-builder/guide/release-versions/) for the selected Developer Edition's bundled JS SDK and any explicitly listed Enterprise pairing.
2. For an Enterprise-registered widget, cross-check every target against the [JS SDK version matrix](https://developers.arcgis.com/javascript/latest/version-matrix/). Apply Esri's same-JS-SDK selection rule; distinguish an explicit pairing from an inference when a table cell is blank. Resolve conflicting evidence before claiming support.
3. For a Developer Edition app that only consumes Enterprise data, verify the connected service requirements separately; that connection does not make the portal's builder the widget runtime.

## Node and package manager

1. Use the exact release's row and applicable notes in **About release versions**, plus its release notes, to distinguish the required/supported Node range from the recommended Node version. A newer, more specific requirement overrides overlapping historical notes; do not extrapolate an old range indefinitely.
2. Read the client/server sections of the [installation guide](https://developers.arcgis.com/experience-builder/guide/install-guide/) to select npm or pnpm and the required installation command. Resolve any recommended package-manager version for this release from the release table.
3. Compare with local Node/package-manager versions, `engines`, `packageManager`, scripts, and lockfiles where present. Investigate disagreements before installation. An installation-tool change does not imply that every startup/build script must use a different runner.

## Build commands and output

Read the installation's scripts and referenced build configuration, then verify the generated files. Widget compilation, whole-experience download, and portal registration are different operations.

**Historical discrepancy:** earlier local guidance placed the `build:prod` / `dist-prod` to `build:for-download` / `dist-download` transition at 1.17. The [Enterprise 12.0](https://doc.arcgis.com/en/experience-builder/12.0/configure-widgets/add-custom-widgets.htm) and [12.1](https://doc.arcgis.com/en/experience-builder/12.1/configure-widgets/add-custom-widgets.htm) hosting docs, checked 2026-09-24, instead say **1.17 and earlier** use the old command/output. Treat the precise cutoff as disputed until checked in the actual installation; neither a cached cutoff nor a script name establishes the output path.
