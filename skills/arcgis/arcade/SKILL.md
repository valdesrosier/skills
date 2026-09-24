---
name: arcade
description: Author ArcGIS Arcade expressions for the correct profile and target version. Use when the user writes or debugs an Arcade expression for a popup, label, field calculation, or attribute rule, or asks which Arcade functions or globals are available.
---

# Arcade

Arcade is **profile-scoped** and **version-gated**: the same expression is valid in one profile and nonsense in another, and a function that exists at one Arcade version is absent in an earlier one. Resolve both before writing a line.

## Identify the profile first

Each profile exposes different globals and expects a different return type. Writing before the profile is known produces expressions that run in the author's head but fail in the app — a popup expression pasted into an attribute rule references globals that do not exist there.

- **Popup** — `$feature`, `$map`, `$datastore` and related globals; returns text or a dictionary for display.
- **Labeling** — returns the label string for each feature.
- **Field calculation** — returns the value written to the target field.
- **Attribute rules** (calculation, constraint, validation) — edit-context globals such as `$originalFeature`; each rule type expects a different return.

Confirm which profile the expression targets before authoring.

## Pin the Arcade version

Arcade's available functions are version-gated. The Arcade version is pinned by the ArcGIS Maps SDK for JavaScript version, which is pinned by the ArcGIS Enterprise release (or by ArcGIS Online). Resolve the target from the live Esri version matrix — <https://developers.arcgis.com/javascript/latest/version-matrix/> — rather than assuming "latest," which re-verifies against the current published mapping every time.

## Verify every global and function

Before shipping the expression, confirm through `arcgis-docs-lookup` that every global and every function it uses exists **in the target profile at the target Arcade version**. A function added in a later Arcade release silently breaks on an older Enterprise.

## Done when

The profile is identified, the return type matches that profile, and every global and function used is verified available at the target Arcade version.
