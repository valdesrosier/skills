# Provider Patterns

Two shapes cover almost every `getData()` implementation. Pick based on whether the upstream system can filter, and how large the dataset is.

## Full-fetch pattern

Pull the entire dataset on every query. The CDF framework's built-in `winnow` module handles all filtering (WHERE, geometry, pagination) in memory. Best for small datasets (< ~10k features) or upstream APIs with no query support.

```javascript
async getData(req) {
  const response = await fetch('https://api.example.com/all-data');
  if (!response.ok) throw new Error(`Upstream error: ${response.status}`);
  const data = await response.json();

  return {
    type: 'FeatureCollection',
    features: data.items.map(item => ({
      type: 'Feature',
      geometry: { type: 'Point', coordinates: [item.lng, item.lat] },
      properties: { id: item.id, name: item.name }
    })),
    metadata: {
      idField: 'id',
      maxRecordCount: 5000,
      fields: [
        { name: 'id',   type: 'integer', alias: 'ID' },
        { name: 'name', type: 'string',  alias: 'Name', length: 256 }
      ]
    },
    ttl: 300  // cache 5 minutes; winnow re-filters per query from cache
  };
}
```

## Pass-through pattern

Translate ArcGIS query params to the upstream API, then declare which filters you handled so the framework does not double-apply them. Best for large datasets where the upstream system can query.

```javascript
async getData(req) {
  const where  = req.query.where             || '1=1';
  const offset = req.query.resultOffset      || 0;
  const limit  = req.query.resultRecordCount || 2000;
  const city   = req.params.city;

  // Return a count shortcut when the client only needs a count
  if (req.query.returnCountOnly === 'true') {
    const total = await fetchCount(city, where);
    return { count: total };
  }

  const raw = await fetch(
    `https://api.example.com/query?city=${city}` +
    `&filter=${encodeURIComponent(where)}&offset=${offset}&limit=${limit}`
  );
  const data = await raw.json();

  return {
    type: 'FeatureCollection',
    features: data.results.map(toFeature),
    metadata: { idField: 'id', maxRecordCount: 2000 },
    filtersApplied: {
      where:             true,
      resultOffset:      true,
      resultRecordCount: true
    }
  };
}
```

## Upstream authentication

Never hardcode upstream credentials. Read them from a gitignored local config (`require('./my-provider-config.json')` on 12.0+, the `config` module on 11.x) or the environment, and attach them per request:

```javascript
const cfg = require("./my-provider-config.json"); // gitignored
const raw = await fetch(url, {
  headers: { Authorization: `Bearer ${cfg.apiKey}` },
});
```

## Multi-layer routing

When a service exposes several layers, branch on `req.params.layer`. Return the multi-layer envelope (see the GeoJSON response reference) when it is `undefined`, and a single FeatureCollection when it names a layer.

```javascript
async getData(req) {
  if (req.params.layer === undefined) return this.getServiceInfo();
  return req.params.layer === '0' ? this.getPoints() : this.getPolygons();
}
```

## Error handling

Throw on upstream failure so the framework returns a proper error rather than an empty layer. Attach a numeric `code` to control the HTTP status:

```javascript
if (!response.ok) {
  const err = new Error(`Upstream error: ${response.status}`);
  err.code = response.status >= 500 ? 502 : 400;
  throw err;
}
```

## Pagination for large upstream datasets (full-fetch, multiple pages)

When full-fetch spans multiple upstream pages, loop until exhausted before returning — winnow filters the assembled set:

```javascript
let page = 0,
  all = [];
while (true) {
  const res = await fetch(`https://api.example.com/data?page=${page}`);
  const body = await res.json();
  all = all.concat(body.items);
  if (!body.hasMore) break;
  page += 1;
}
```
