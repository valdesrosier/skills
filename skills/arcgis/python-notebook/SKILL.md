---
name: python-notebook
description: Write and run ArcGIS API for Python code in ArcGIS Notebooks or a local environment. Use when the user works with the arcgis package, a hosted ArcGIS Notebook runtime, ArcPy in a notebook, or deletes or overwrites hosted data from Python.
---

# ArcGIS API for Python & ArcGIS Notebooks

## Determine the runtime target first

The runtime pins the library versions — you do not choose them independently. Establish which target applies before importing anything, because the rules diverge from here:

- **Hosted ArcGIS Notebooks** (Enterprise or Online)
- **Local / conda / pip** environment

## Hosted notebooks: check the runtime manifest

Hosted runtimes are versioned to match the Notebook Server version (e.g. "ArcGIS Notebook Server Standard 12.0"). Two runtimes ship as container images:

- **Standard**
- **Advanced** — everything in Standard **plus ArcPy**.

ArcPy is Advanced-only: a notebook switched to Standard errors on any ArcPy cell. Authoring with each runtime is gated by a separate portal privilege. Check the runtime manifest for the target version before importing — do not assume a library is present, and do not pip-install around the runtime.

## Changing the runtime can break working code

Precedent: arcgis 2.4.0 introduced a new map widget for Jupyter Notebook 7 / JupyterLab 4, and code written against the old widget requires migration; staying on arcgis 2.3.1 keeps Jupyter Notebook 6. Flag this risk before switching a notebook's runtime, and confirm the current behavior against the release notes for the versions in play.

## Local installs: pin Python to the library

arcgis 2.4.2+ requires Python 3.10.x–3.13.x. Verify the exact range against the system-requirements page for the version in use rather than assuming.

## Watch deprecated modules

GeoAnalytics Server's final release was Enterprise 11.3; `arcgis.geoanalytics` is supported via the built-in Python API only through 11.3 and earlier. Do not target it on newer releases.

## Auth: match the environment, never inline credentials

- Inside a hosted notebook, authenticate with `GIS("home")`.
- Elsewhere, use explicit credential auth — but never write credentials inline; source them from the environment or a prompt.

## Guard destructive operations

Before generating any code that calls `truncate`, `delete`, `delete_features`, `overwrite`, or removes an item or layer, stop and satisfy every point in order. This covers irreversible data operations only, not credentials or org hygiene.

1. **Name the target.** State the org and the exact item or layer id the call targets. An unnamed target is a stop.
2. **Show what it is.** Display the target's title, type, and feature count so the user sees what they are about to lose.
3. **Confirm it is not production.** Say so explicitly and get the user's confirmation before proceeding.
4. **Prefer the reversible form first.** Offer a query-first / count-first or dry-run form so the blast radius is known before the destructive call runs.
5. **Never emit blind.** Withhold the destructive call until 1–4 are satisfied and the user confirms — even when the user sounds confident.

## Done when

The runtime target is identified; libraries are confirmed present in that runtime (or Python is pinned for a local install); auth matches the environment with no inline credentials; and any destructive call has passed through the guard.
