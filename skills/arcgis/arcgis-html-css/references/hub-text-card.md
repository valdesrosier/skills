# ArcGIS Online Hub text card

Use this profile only for the `</> Edit in HTML` source editor of an ArcGIS Online Hub text card.

## Owning sources

- [Add text and images](https://doc.arcgis.com/en/hub/sites/add-text-and-images.htm) owns the text-card element and attribute allowlists, supported Calcite list, link behavior, and script restriction.
- [Customize sites with HTML and CSS](https://doc.arcgis.com/en/hub/sites/customize-html-css.htm) owns Hub custom-code placement and sanitizer behavior.

These are live ArcGIS Online pages. Recheck them before relying on an uncommon element, attribute, CSS construct, or Calcite component; do not treat this file as a frozen version matrix.

## Documented rules

- Paste a fragment into a Text card's HTML source editor, not a complete document.
- Hub scans HTML and CSS for unsupported tags. Unsupported code can appear as raw text rather than render.
- Embedded JavaScript is not supported; `<script>` tags are ignored. Do not use event-handler attributes or `javascript:` URLs as substitutes.
- All supported HTML elements accept `class` and `style`. Element-specific attributes are limited to the allowlist in the owning source.
- Relative links such as `/pages/target-page` avoid a full page refresh within a Hub site.
- A link may use `target="_blank"`, but warn the reader in the link text or nearby copy before opening a new tab.
- If Hub inserts `ADDSTYLE`, it sanitized code near that location. Hub's guidance says to consolidate multiple style tags into one.

Prefer semantic HTML and inline styles for simple fragments. Use one `<style>` block only when reusable classes or state selectors materially simplify the fragment, then live-editor validate it. Never emit external stylesheets.

## Practical safe baseline

Prefer these common documented elements unless the design needs another element from the live allowlist:

- Structure: `article`, `section`, `header`, `footer`, `main`, `nav`, `div`, `p`, `h1` through `h6`, `hr`, `br`
- Text: `strong`, `b`, `em`, `i`, `u`, `mark`, `small`, `sub`, `sup`, `blockquote`, `code`, `pre`
- Lists: `ul`, `ol`, `li`, `dl`, `dt`, `dd`
- Links and media: `a`, `img`, `audio`, `video`, `source`, `figure`, `figcaption`
- Disclosure and data: `details`, `summary`, `table`, `caption`, `thead`, `tbody`, `tfoot`, `tr`, `th`, `td`

Do not infer that every standard attribute is supported because an element is supported. Check the source allowlist. In particular, preserve `alt` on informative images, use table headers for tabular data, and avoid deprecated elements even when the sanitizer currently admits them.

## Calcite components

Hub documents this Text card subset:

`calcite-action`, `calcite-accordion`, `calcite-accordion-item`, `calcite-avatar`, `calcite-block`, `calcite-button`, `calcite-card`, `calcite-chip`, `calcite-dialog`, `calcite-dropdown-group`, `calcite-dropdown-item`, `calcite-fab`, `calcite-flow`, `calcite-icon`, `calcite-link`, `calcite-panel`, `calcite-rating`, `calcite-split-button`, `calcite-stepper`, `calcite-stepper-item`, `calcite-tab`, `calcite-tab-nav`, `calcite-tab-title`, `calcite-tabs`, `calcite-tile`, and `calcite-tooltip`.

Use a component only when it is a clearer compatible and accessible solution than ordinary HTML. Verify its current attributes and composition in the [Calcite component reference](https://developers.arcgis.com/calcite-design-system/components/) and live-editor validate interactive compositions. Do not use Calcite components outside this list.

## Repair signals

- Raw code in the rendered card: an unsupported tag survived as text; replace it with an allowed semantic element.
- `ADDSTYLE` in persisted markup: simplify the nearby CSS and consolidate style blocks.
- Missing behavior: remove the script dependency or use a supported native HTML or Calcite interaction.
- Layout works only at one width: replace fixed widths with percentages, wrapping flex/grid tracks, and `max-width` where supported; then test mobile width.

## Evidence labels

Rules above are **documented** unless explicitly marked otherwise. Record any live-editor-only finding as `Observed YYYY-MM-DD` with the exact input, persisted output, and tested context before relying on it.
