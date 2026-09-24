# Skills

A collection of agent skills for GitHub Copilot, Claude, Codex, and other skill-aware coding assistants, organized into **generic skills** for cross-stack workflows and **ArcGIS-specific skills** for the Esri developer ecosystem.

The skills are designed to **compose with [Matt Pocock's skills](https://github.com/mattpocock/skills)**, but work without his collection installed.

## The skills

### Generic skills

[`skills/generic/`](skills/generic/) is the home for reusable workflows that are not tied to a particular platform or vendor.

| Skill                                                            | What it does                                                                                                                                                             |
| ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [chronicle-protocol](skills/generic/chronicle-protocol/SKILL.md) | Saves a factual project checkpoint when you say "Chronicle" and guides resuming from it in a fresh session, with a plain-chat fallback when file writing is unavailable. |
| [demo-director](skills/generic/demo-director/SKILL.md)           | Plans, scripts, rehearses, records, and finishes software demos across browser and desktop apps, with explicit script approval and final quality checks.                 |

For general-purpose workflows such as code review, debugging, research, and test-driven development, see [Matt Pocock's collection](#recommended-pair-with-matt-pococks-skills). Those are separate dependencies, not skills redistributed by this repo.

### ArcGIS-specific skills

[`skills/arcgis/`](skills/arcgis/) contains the Esri / ArcGIS skills:

| Skill                                                                       | What it does                                                                                                                              |
| --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| [arcgis-docs-lookup](skills/arcgis/arcgis-docs-lookup/SKILL.md)             | Routes documentation questions to authoritative Esri sources, scopes Enterprise URLs by version, and supports deep research.              |
| [arcade](skills/arcgis/arcade/SKILL.md)                                     | Authors Arcade expressions for the correct profile and verifies globals and functions at the target version.                              |
| [arcgis-html-css](skills/arcgis/arcgis-html-css/SKILL.md)                   | Writes and repairs HTML/CSS for ArcGIS Online Hub text cards and Map Viewer popups using each surface's sanitizer rules.                  |
| [js-sdk](skills/arcgis/js-sdk/SKILL.md)                                     | Builds and migrates ArcGIS Maps SDK for JavaScript apps with version-aware API and Calcite choices.                                       |
| [python-notebook](skills/arcgis/python-notebook/SKILL.md)                   | Writes ArcGIS API for Python code for hosted notebooks or local installs, with a guard around destructive data operations.                |
| [exb-widget](skills/arcgis/exb-widget/SKILL.md)                             | Builds Experience Builder widgets with target-specific version/tooling gates, implementation guidance, and runtime/deployment checks.    |
| [arcgis-custom-data-feeds](skills/arcgis/arcgis-custom-data-feeds/SKILL.md) | Builds version-aware Node.js/Koop providers that expose external systems as ArcGIS Feature Services, with a guard around upstream writes. |

`python-notebook`, `js-sdk`, and `arcgis-custom-data-feeds` each embed a destructive-operation guard: before any irreversible data call — a hosted-feature delete, or a Custom Data Feeds provider's upstream update/delete — the agent must name the target, show what it is, confirm it isn't production, and prefer a dry-run — so each skill stays self-contained.

## How they work — you don't invoke them

These are **model-invoked** skills. You don't type a command; you just describe your task in plain language and the agent recognizes it and applies the right skill:

```
You: "Help me write a popup Arcade expression that shows parcel area in acres."
        ↓  (matches the arcade skill's description)
Agent: reads arcade/SKILL.md → identifies the profile → pins the version → writes it.
```

Each skill's one-line description stays in the agent's context; when your intent matches, the agent loads that skill's full instructions and follows them. Being explicit about the technology ("an **Experience Builder** widget", "the **ArcGIS Python API**") makes the match near-certain.

For **The Chronicle Protocol**, say "Chronicle this" to request a checkpoint or ask to resume from a Chronicle. The skill is named `chronicle-protocol` to distinguish it from Copilot's session-history tool. Automatic checks at every session start require a pointer in the host's always-loaded project instructions; the skill alone does not install a startup hook.

## Installation

**Via the `skills` CLI** — installs into your project's `.agents/skills/`:

```bash
npx skills@latest add valdesrosier/skills
```

List available skills or install only selected ones:

```bash
npx skills@latest add valdesrosier/skills --list
npx skills@latest add valdesrosier/skills --skill arcade arcgis-docs-lookup
```

**Or copy the folders** — copy individual skill folders from [`skills/generic/`](skills/generic/) or [`skills/arcgis/`](skills/arcgis/) into your project's `.agents/skills/` directory. Copy the skill itself, not the category: `skills/arcgis/arcade/` becomes `.agents/skills/arcade/`. Every skill is self-contained; `arcade` and `js-sdk` verify APIs through `arcgis-docs-lookup`, so include it if you want that step.

Either way, any skill-aware agent (GitHub Copilot, Claude, Codex) picks them up automatically whenever the workspace is open — no per-chat setup.

## Keeping skills up to date

Updates are **pull-based** — there's no background auto-update. The skill files live committed in your project, so refreshing them is a deliberate, reviewable step.

**If you installed via the CLI**, re-run the same command from your project root:

```bash
npx skills@latest add valdesrosier/skills
```

`add` is idempotent and doubles as the updater: it re-fetches the current version, rewrites the files under `.agents/skills/`, and refreshes the per-skill hashes in `skills-lock.json`. Review the diff and commit it like any other dependency bump — the changed hashes tell you exactly which skills moved.

**If you copied the folders by hand**, re-copy the skill folder(s) from [`skills/`](skills/) (or `git pull` if you vendored this repo).

Re-run when a new [release](https://github.com/valdesrosier/skills/releases) is tagged, or fold it into your routine dependency hygiene. Use the same `--skill` selection when refreshing only a subset.

## Recommended: pair with Matt Pocock's skills

These were built to slot into [Matt Pocock's skill system](https://github.com/mattpocock/skills) and follow its conventions (front-loaded descriptions, one trigger per branch, checkable completion criteria, progressive disclosure). Two ways they benefit from his set:

- **During a grill.** Run his `/grill-with-docs` (or `/grilling` + `/domain-modeling`) to stress-test an ArcGIS design decision, and these skills fire automatically on-topic — bringing version discipline and API verification into the interview.
- **Deep research.** `arcgis-docs-lookup` hands heavy investigations to his `research` skill when it's installed, and falls back to inline research when it isn't.

Install his set with:

```bash
npx skills@latest add mattpocock/skills
```

Nothing here edits or depends on his files — the composition is additive.

## Design principles

All categories use focused descriptions, progressive disclosure, and self-contained skill folders. The ArcGIS skills also follow these domain-specific rules:

- **No baked version facts.** Version relationships, build commands, and output paths change across releases. Skills encode the _procedure_ for discovering the target version and point at the live version anchor that owns their stack — the [Esri version matrix](https://developers.arcgis.com/javascript/latest/version-matrix/) for the JS-family skills, the [Enterprise SDK CDF guide](https://developers.arcgis.com/enterprise-sdk/guide/custom-data-feeds/) for Custom Data Feeds — rather than hardcoding a value that will silently go stale. Experience Builder also checks its exact-release documentation and installed build configuration; its historical build cutoff is [disputed](skills/arcgis/exb-widget/VERSIONS.md#build-commands-and-output).
- **A safety guard for destructive data operations.** Before any irreversible data operation — a `truncate` / `delete` / `overwrite` / feature deletion against hosted data, or an editable Custom Data Feeds provider's upstream update/delete — the agent must name the target, show what it is, confirm it isn't production, and prefer a dry-run — pulled deterministically as an explicit step, never left to chance.
- **Never cite retired products.** Documentation lookups route to current sources and explicitly avoid ArcMap, ArcCatalog, and ArcGIS Desktop docs.

The architectural decisions behind these choices are recorded in [`docs/adr/`](docs/adr/), and project terminology in [`CONTEXT.md`](CONTEXT.md).

## Standalone or composed

Every skill is portable — drop a single folder into any skill-aware repo and it works with zero other skills present. Pairing with Matt Pocock's skills is a recommendation, not a requirement.

## Repository layout

Skills are published under [`skills/`](skills/), grouped by category. The `skills` CLI discovers the nested skill folders; category names do not change skill names or invocation.

```text
skills/
        generic/                       # Cross-stack workflows
                chronicle-protocol/
                demo-director/
        arcgis/                        # Esri / ArcGIS workflows
                arcade/
                arcgis-custom-data-feeds/
                arcgis-docs-lookup/
                arcgis-html-css/
                exb-widget/
                js-sdk/
                python-notebook/
```

Each skill lives at `skills/<category>/<skill-name>/SKILL.md`, with any references and agent metadata inside that skill's folder. Add platform-independent skills to `generic/` and Esri-specific skills to `arcgis/`.

These are the canonical sources. For local development, individual skills are also mirrored at `.agents/skills/<skill-name>/`, which is **git-ignored**. That directory additionally holds Matt Pocock's skills as development dependencies; neither those dependencies nor the mirror are redistributed here. Regenerate a mirror by copying the individual skill folder from its category, keeping the installed layout flat.

Each skill is self-contained: the destructive-operation guard is inlined into `js-sdk`, `python-notebook`, and `arcgis-custom-data-feeds` rather than shared, so nothing is lost when the CLI copies a single skill folder.

## License

Add your preferred license (e.g. MIT) as a `LICENSE` file before publishing.
