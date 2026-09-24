# Skills

Terminology for this repo's skill collection. The terms below apply to the ArcGIS-specific skills. Skill-system terms (model-invoked, user-invoked, context pointer, leading word, etc.) follow Matt Pocock's skill-authoring system and are not restated here.

## Language

**Version anchor**:
The live Esri source that owns a given stack's version relationships, which every version-needing skill points at rather than restating. The anchor is per-stack, not one global source: the ArcGIS Maps SDK for JavaScript version-matrix is the anchor shared by the JS-family skills (arcade, js-sdk, exb-widget) — mapping an ArcGIS Enterprise release to its JS SDK, Calcite, and Arcade versions — while Custom Data Feeds points at the ArcGIS Enterprise SDK CDF guide, a separate release train.
_Avoid_: version table, version map, version matrix (when referring to a canonical live source); "shared version anchor" (implies one global anchor — it is per-stack)

**Destructive operation guard**:
The policy each data-touching skill embeds and must satisfy before emitting code that irreversibly changes real data — whether ArcGIS-hosted data or a Custom Data Feeds provider's upstream store — name the target, show what it is, confirm it is not production, prefer a dry-run, never emit blind. Scoped to data operations only, not credentials or org hygiene.
_Avoid_: safety check, confirmation prompt (when referring to this specific policy)

**Custom Data Feed (CDF)**:
A Node.js provider — running on Koop.js inside the ArcGIS Enterprise SDK runtime — that pulls from an external source and exposes it as an ArcGIS Feature Service. Server-side extension development, distinct from the client/authoring surfaces the other skills cover. The provider's own backend (a database, an external API) is its _upstream store_; deployment/registration on ArcGIS Server is out of scope for the skill.
_Avoid_: connector, integration, data pipeline (those are the Python-side ETL sense, not the CDF provider)

**Constrained-markup profile**:
An ArcGIS authoring surface with its own supported HTML elements, attributes, and CSS behavior. The initial profiles are the ArcGIS Online Hub text card HTML source editor and the Map Viewer popup HTML/CSS environment; the separate popup Arcade environment is not part of the latter.
_Avoid_: HTML flavor, HTML mode, generic HTML/CSS
