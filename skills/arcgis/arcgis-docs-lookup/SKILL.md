---
name: arcgis-docs-lookup
description: Look up ArcGIS documentation against authoritative Esri sources and verify an API exists at a pinned version. Use when the user needs an ArcGIS API reference, ArcGIS Pro, Enterprise, or Notebook Server docs, or when another skill must confirm a class, method, global, or function is available at a target version.
---

# ArcGIS Docs Lookup

Answer every ArcGIS question from the first-party source that _owns_ it — never a stale mirror, a wrong-product page, or an unverified forum post.

## Route to the owning source

- **developers.arcgis.com** — ArcGIS Maps SDK for JavaScript, ArcGIS API for Python, the REST API, and Arcade references.
- **developers.arcgis.com/enterprise-sdk** — the ArcGIS Enterprise SDK, including Custom Data Feeds (CDF) provider development. A distinct product area from the developer references above — route CDF and Enterprise SDK questions here.
- **pro.arcgis.com** — ArcGIS Pro, including ArcPy and geoprocessing.
- **enterprise.arcgis.com** — ArcGIS Enterprise, Portal, and Notebook Server administration and runtime docs.

**Never cite ArcMap, ArcCatalog, or ArcGIS Desktop documentation.** It describes a retired product whose APIs have diverged from Pro and Enterprise. If a search returns an ArcMap or ArcGIS Desktop page, discard it and find the Pro or Enterprise equivalent.

## Pin the version

Enterprise docs are version-scoped by URL path (e.g. `.../enterprise/11.2/...`). Pin every Enterprise URL to the target version you are working against — the release the caller named, or the one the user is on. An unversioned or mismatched Enterprise URL is not an acceptable citation.

## Treat Community as a hypothesis, not a source

Esri Community, GeoNet, and Stack Exchange threads are leads to verify, never the citation. Trace every claim back to the owning first-party doc before relying on it.

## When the reference page won't render

The ArcGIS API for Python and REST API references on developers.arcgis.com are client-rendered single-page apps. A plain fetch of one of these pages — even at a precise symbol anchor like `arcgis.gis.toc.html#arcgis.gis.Group.notify` — returns no usable content, because the symbol table is painted by JavaScript the fetch never runs. **This is a tooling failure, not evidence the API is absent.** Never downgrade "I couldn't render the reference" into "there is no such API." Instead, fall back to first-party sources that _are_ machine-readable, in order:

1. **Search the owning source's GitHub repo.** For the Python API, search `Esri/arcgis-python-api` — the guide and sample notebooks, and especially the per-version `release_notes_*` notebooks under `guide/02-api-overview/`, enumerate classes and methods by name with anchor links back to the reference (this is where a symbol like `Group.notify()` surfaces even though its reference page won't render). Search the repo for the exact symbol name.
2. **Introspect the installed package.** When a live environment with the `arcgis` package is available, the package source is what the reference is generated from — read the truth directly with `help(Group.notify)` or `inspect.signature(...)`. Use the `python-notebook` skill to run it. The equivalent for the JS SDK is the `@arcgis/core` TypeScript declarations shipped on npm.

Only after these fallbacks come up empty may you report the symbol as unverified — and say "could not verify," not "does not exist," when a client-rendered page was the only thing blocking you.

## Match the depth to the question

- **Quick existence or signature check** ("does this class/method/global exist at version N") — read the owning reference page directly and answer inline. No file written.
- **Genuine investigation** (a migration surface, a breaking-change sweep, synthesis across many pages) — escalate to the `research` skill if it is available, passing these routing and version rules so the background agent obeys them. If `research` is not installed, do the investigation inline against the same first-party sources.

## Done when

Every claim is backed by a first-party URL on the correct domain, pinned to the target version wherever the docs are version-scoped, and no ArcMap/Desktop page or unverified Community thread remains as a citation. No "this API does not exist" conclusion rests on a reference page that merely failed to render — that path was exhausted through the GitHub-repo and package-introspection fallbacks first.
