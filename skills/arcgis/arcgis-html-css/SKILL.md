---
name: arcgis-html-css
description: Write or repair paste-ready HTML and CSS for ArcGIS Online Hub text cards and Map Viewer popups. Use when ordinary web markup is stripped, rejected, or rendered differently in either editor.
---

# ArcGIS HTML and CSS

ArcGIS Online sanitizes authored markup. Valid browser HTML and CSS can still be removed or changed when saved, and the two supported editors do not share one compatibility contract. Select the constrained-markup profile before writing.

## Identify the profile first

Ask when the target is not explicit. Never guess between:

- **Hub text card** — the HTML source editor in an ArcGIS Online Hub text card. Read [references/hub-text-card.md](references/hub-text-card.md).
- **Map Viewer popup** — the HTML/CSS editor for text content in an ArcGIS Online Map Viewer popup. Read [references/map-viewer-popup.md](references/map-viewer-popup.md).

Do not apply these profiles to ArcGIS Enterprise Sites, Experience Builder, embeds, iframes, standalone web pages, or ArcGIS Maps SDK for JavaScript applications.

Popup Arcade is a separate authoring environment. Do not generate or combine Arcade when the requested output is popup HTML/CSS.

## Produce a fragment

Return markup that can be pasted directly into the selected editor. Do not emit `<html>`, `<head>`, external stylesheets, build tooling, JavaScript, or a standalone application.

For new content:

1. Confirm the content, links, images, field placeholders, and visual intent.
2. Use only elements, attributes, URL protocols, and inline CSS allowed by the selected profile.
3. Prefer simple semantic HTML. In Hub only, use a supported Calcite component when it is the clearest compatible and accessible solution.
4. Keep layouts usable at narrow popup widths and mobile Hub widths.

For repair or conversion:

1. Identify what the sanitizer or renderer will reject or alter.
2. Preserve meaningful content, links, images, hierarchy, and field placeholders before visual fidelity.
3. Replace unsupported constructs with the closest compatible alternative.
4. Never silently remove content. List material visual or behavioral compromises after the fragment.
5. Say plainly when the request requires unsupported scripting or interactivity.

## Make accessibility a completion condition

- Use semantic structure where the profile supports it.
- Preserve a logical heading order.
- Give images meaningful alternative text unless they are decorative.
- Use meaningful link text.
- Do not communicate meaning through color alone.
- Check text and interactive-state contrast when choosing colors.
- Avoid fixed dimensions that clip or overflow at narrow widths.

Repair clear accessibility defects unless that would materially change the requested content; report the conflict when it would.

## Validate proportionally

For straightforward fragments, validate every element, attribute, URL protocol, and inline CSS property against the selected profile reference. Review accessibility and narrow-width behavior.

For intricate layouts or behavior not settled by the reference, validate in the live editor when access is available: paste, save, reopen, inspect the persisted markup, and test the rendered result at narrow and wide widths. Label the result accurately as either **allowlist-validated** or **live-editor validated**; never claim ArcGIS preserved markup unchanged without testing it.

Treat first-party Esri documentation as authoritative. A dated observed rule may fill a documentation gap, but label it as observed rather than guaranteed. When neither source supports a construct, use a conservative alternative.

## Done when

The profile is explicit, the output is a paste-ready fragment, every construct is supported by that profile, accessibility checks pass, compromises are disclosed, and the validation level is stated.
