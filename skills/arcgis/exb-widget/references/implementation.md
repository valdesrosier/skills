# Implementation Guidance

Read only the surface relevant to the widget change, after the target and toolchain gates in the parent skill. Verify API names, imports, and lifecycle behavior against the selected installation's Jimu and SDK types before adapting examples from newer releases.

## Optional Esri companion

Use Esri's `arcgis-exb-widget-dev` as an implementation companion, not a replacement for the local targeting and deployment gates. The reviewed baseline is [Esri/arcgis-experience-builder-sdk-resources at `0ca4c7af1762ad80e0bf02f8b903ea50cc1fc788`](https://github.com/Esri/arcgis-experience-builder-sdk-resources/tree/0ca4c7af1762ad80e0bf02f8b903ea50cc1fc788/skills/arcgis-exb-widget-dev), inspected on 2026-09-16.

For companion guidance, read its [workflow](https://raw.githubusercontent.com/Esri/arcgis-experience-builder-sdk-resources/0ca4c7af1762ad80e0bf02f8b903ea50cc1fc788/skills/arcgis-exb-widget-dev/references/widget-workflow.md), then use its [implementation-surface index](https://raw.githubusercontent.com/Esri/arcgis-experience-builder-sdk-resources/0ca4c7af1762ad80e0bf02f8b903ea50cc1fc788/skills/arcgis-exb-widget-dev/references/implementation-surfaces.md) to open only the relevant references at the same commit. If a separately installed copy differs, inspect its provenance and review the relevant changes before adopting them. Leave installed third-party files unchanged; adapt verified examples only in the user's widget.

Apply these review findings when using that baseline:

- Add the required widget `type` missing from its skeleton; derive `exbVersion` from the verified target rather than copying the sample value.
- Resolve runtime import conflicts using installed exports and runtime safety. Keep builder-only imports out of runtime; a `MessageType` enum used as a value needs a value import, not `import type`.
- Select the saved-config version manager from official guidance for the chosen release; reconcile the companion's differing base/widget-manager recommendations.
- Keep source-checkout translation registration separate from Developer Edition locale handling. Preserve framework keys such as `_widgetLabel` and namespace new widget-specific strings.
- Verify modern map components, cache/restore hooks, and theme APIs in local types. Keep transient map/view objects out of serialized app configuration and clean them up on view changes/unmount.

When updating the companion baseline, deliberately review the changed surfaces and record the new commit and verification evidence. Installation alone does not validate snippets or establish support for older releases.

## Standalone routes

Use the installed framework types, neighboring widgets/tests, and these official sources whether or not the companion is present. Use `arcgis-docs-lookup` when available for source/version verification; otherwise perform the same checks directly. Live guides do not establish API availability at an older target release.

| Changed surface | Official starting point | Verify in the widget |
| --- | --- | --- |
| Runtime/settings and manifest | [Widget implementation](https://developers.arcgis.com/experience-builder/guide/extend-base-widget/) and [manifest](https://developers.arcgis.com/experience-builder/guide/widget-manifest/) | Runtime/builder separation, immutable settings updates, required dependencies |
| Data sources | [Use data sources](https://developers.arcgis.com/experience-builder/guide/use-data-source-in-widget/) | Persisted selections/fields, query versus loaded records, empty/error/output readiness |
| Maps and layers | [Use MapView and SceneView](https://developers.arcgis.com/experience-builder/guide/use-mapview-sceneview-in-a-widget/) | Readiness, view replacement, handle cleanup, stale callbacks |
| Messages/actions | [Widget communication](https://developers.arcgis.com/experience-builder/guide/widget-communication/) | Manifest declarations, payloads, support/execution and repeated invocation |
| Saved configuration | [Backward compatibility](https://developers.arcgis.com/experience-builder/guide/make-widgets-backward-compatible/) | Release-appropriate version manager or justified fallback, old saved-app upgrade |
| Localization | [Multi-language support](https://developers.arcgis.com/experience-builder/guide/multi-language-support/) | Locale files, keys, declared locales and correct checkout-specific registration |
| Tests | [Unit testing](https://developers.arcgis.com/experience-builder/guide/unit-testing/) | Existing Jest/Testing Library/Jimu helpers, behavior assertions and deterministic boundary mocks |

When a source or target installation is inaccessible, identify the blocked API check rather than substituting an unverified newer example.