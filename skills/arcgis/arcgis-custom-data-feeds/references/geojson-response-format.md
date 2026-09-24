# GeoJSON Response Format Reference

Every `getData()` call must return a GeoJSON `FeatureCollection` with a `metadata` property attached. This schema is durable; confirm any version-specific option against the live Enterprise SDK CDF guide via `arcgis-docs-lookup`.

## Full response shape

```javascript
{
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [-118.2, 34.0] },
      properties: { id: 1, name: 'Example', category: 'A', value: 42.5 }
    }
    // ...
  ],

  // Required: metadata block
  metadata: {
    idField:        'id',          // REQUIRED — unique numeric property name
    name:           'Layer Name',
    description:    'Optional description shown in the service info page.',
    geometryType:   'Point',       // Point | Polyline | Polygon | MultiPoint
    maxRecordCount: 2000,          // Max features returned per query
    inputCrs:       4326,          // WKID of source data CRS (default: 4326)
    displayField:   'name',        // Field shown in popups by default
    fields: [                      // REQUIRED — always declare explicitly
      { name: 'id',       type: 'integer', alias: 'ID' },
      { name: 'name',     type: 'string',  alias: 'Name',     length: 256 },
      { name: 'category', type: 'string',  alias: 'Category', length: 64 },
      { name: 'value',    type: 'double',  alias: 'Value' }
    ],
    templates:    [],   // Edit widgets; required when editingEnabled: true
    labelingInfo: []    // Label rules
  },

  // Optional: tell the framework which filters you already applied upstream
  filtersApplied: {
    where:             false,
    geometry:          false,
    objectIds:         false,
    resultRecordCount: false,
    resultOffset:      false
  },

  ttl: 30   // Cache TTL in seconds. LRU cache, capacity 500 elements.
}
```

## Field types

Declare a `type` for every field — inference from the first feature produces wrong types. Common types: `integer`, `biginteger`, `double`, `string` (add `length`), `date`, `boolean`. For editable fields, add `editable: true` / `editable: false` and `length` (for strings):

```javascript
{ name: 'name', type: 'string', alias: 'Name', length: 128, editable: true }
```

## Spatial reference

- **Default:** WGS84, WKID 4326. No configuration needed if coordinates are `[lng, lat]` in WGS84.
- **Other CRS:** set `metadata.inputCrs` to the WKID; the framework reprojects automatically.
  - Web Mercator: `inputCrs: 3857` · NAD83: `inputCrs: 4269` · Custom: any WKID recognized by `@esri/proj-codes`.
- Accepted aliases: `inputCrs`, `dataCrs`, `sourceSR`, `crs` — `inputCrs` is canonical.

## Multi-layer response

Return this when `req.params.layer` is `undefined` (a service-level request, not a layer request):

```javascript
return {
  layers: [await this.getPointLayerData(), await this.getPolygonLayerData()],
  tables: [], // non-spatial tables, if any
  metadata: {
    name: "My Multi-Layer Service",
    inputCrs: 4326,
  },
};
```

Each element of `layers` is a full FeatureCollection-with-metadata object. Its index in the array becomes its layer ID (0, 1, …).

## Pass-through — filtersApplied

When your provider translates ArcGIS query params to an upstream API, set `filtersApplied` to `true` for each filter you handled so the framework does not double-apply it:

```javascript
return {
  type: "FeatureCollection",
  features: upstreamFeatures,
  metadata: { idField: "id", maxRecordCount: 2000 },
  filtersApplied: {
    where: true, // You translated the WHERE clause upstream
    resultOffset: true, // You sent offset to the upstream API
    resultRecordCount: true, // You sent limit to the upstream API
  },
};
```

Return-count shortcut — skip building features entirely:

```javascript
if (req.query.returnCountOnly === "true") {
  const total = await upstream.count(where);
  return { count: total };
}
```

## Edit templates

Required when `editingEnabled: true` and you want editing widgets to work in ArcGIS clients:

```javascript
templates: [
  {
    name: "New Feature",
    description: "Add a new feature.",
    drawingTool: "esriFeatureEditToolPoint", // or Polygon, Polyline, etc.
    prototype: {
      attributes: { name: null, category: null, value: null },
    },
  },
];
```
