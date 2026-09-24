# ArcGIS Online Map Viewer popup HTML/CSS

Use this profile only for HTML/CSS pasted into text content in an ArcGIS Online Map Viewer popup. Popup Arcade is a separate editor and is out of scope.

## Owning sources

- The [Web Map Specification `popupInfo` reference](https://developers.arcgis.com/web-map-specification/objects/popupInfo/) states that popup descriptions accept a basic HTML subset and points to ArcGIS Online's supported HTML rules.
- [Supported HTML](https://doc.arcgis.com/en/arcgis-online/reference/supported-html.htm) owns the ArcGIS Online sanitizer's current element, attribute, URL protocol, and CSS property allowlists.
- The [popup text element reference](https://developers.arcgis.com/web-map-specification/objects/popupElement_text/) defines text popup content.

The sanitizer page is a live ArcGIS Online source. Recheck its tables before using an uncommon construct; do not assume browser support implies popup support.

## Documented rules

- Use a fragment, not a complete HTML document.
- CSS is inline only, in an allowed element's `style` attribute. Do not emit `<style>`, classes that depend on external CSS, or external stylesheets.
- Elements and attributes absent from the live allowlist are filtered out.
- `href` and `src` allow only `https`, `tel`, and `mailto` protocols. UNC links are unsupported.
- Links always open in a new browser tab. Make their destination or behavior clear from the text.
- ArcGIS automatically closes unclosed allowed tags.
- Literal `<`, `>`, `&`, and `"` outside legal tags must be entity-escaped.

## Element and attribute baseline

The current documented allowlist includes:

- `a[href, style]`, `abbr[title]`
- `article[style]`, `aside[style]`, `blockquote[style]`, `code[style]`, `del[style]`
- `div[style, align, aria-label, aria-hidden]`, `span[style, aria-label, aria-hidden]`
- `header[style]`, `footer[style]`, `main[style]`, `nav[style]`, `section[style]`
- `h1` through `h6[style]`, `p[style]`, `pre[style]`
- `b`, `strong`, `i`, `em`, `u`, `br`, `hr`, `ul`, `ol`, `li`, `tbody`
- `dd[style]`, `dl[style]`, `dt[style]`, `mark[style]`, `sub[style]`, `sup[style]`, `time[style]`
- `details[style, open]`, `summary[style]`
- `figure[style]`, `figcaption[style]`
- `font[size, color, style]`
- `img[src, width, height, border, alt, style]`
- `table[width, height, cellpadding, cellspacing, border, style]`
- `tr[height, valign, align, style]`
- `td` and `th[height, width, valign, align, colspan, rowspan, nowrap, style]`
- `audio[autoplay, controls, loop, muted, preload]`
- `video[autoplay, controls, height, loop, muted, poster, preload, width]`
- `source[media, src, type]`

Recheck the owning source for changes and exact table syntax. Use semantic elements over `font`, presentational attributes, or layout tables even when those older constructs remain accepted.

## CSS baseline

The live source allows inline properties in these families: background, border, box, break, display, flex, font, grid, justify, list, margin, padding, text, and word. It also lists alignment, dimensions and min/max dimensions, color, float/clear, gap, letter and line spacing, and overflow properties.

Validate every property against the live CSS table. Do not infer support for position, inset, transform, transition, animation, opacity, cursor, object fitting, media queries, custom properties, pseudo-classes, or pseudo-elements; these are not in the documented allowlist as of 2026-08-19.

Even when grid or flex properties are admitted by the sanitizer, keep popup layouts simple and wrapping. Popup containers are narrow and vary by consuming application.

## Field placeholders

Preserve field placeholders exactly as supplied. A placeholder is content interpolation, not permission to create an Arcade expression. If the requested value requires computation or conditional logic, explain that it cannot be produced by this HTML/CSS fragment.

## Repair signals

- Styling disappears: move supported declarations into inline `style` attributes and remove unsupported properties.
- A link or image disappears: use an allowed attribute and an `https`, `tel`, or `mailto` URL as appropriate.
- Content flattens: replace unsupported containers with allowed semantic elements or `div`/`span`.
- Layout clips: remove fixed widths, allow wrapping, and constrain media with supported percentage width and `max-width`.

## Evidence labels

Rules above are **documented** unless explicitly marked otherwise. Record any live-editor-only finding as `Observed YYYY-MM-DD` with the exact input, persisted output, and tested context before relying on it.
