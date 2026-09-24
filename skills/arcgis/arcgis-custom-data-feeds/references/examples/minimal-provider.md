# Complete Minimal Provider — read-only

Illustrative, **targeting ArcGIS Enterprise 12.0**. Confirm any version-specific detail against the live [Enterprise SDK CDF guide](https://developers.arcgis.com/enterprise-sdk/guide/custom-data-feeds/) via `arcgis-docs-lookup` before building against a different release. A read-only weather forecast provider using the full-fetch pattern.

## cdconfig.json

```json
{
  "name": "weather-provider",
  "arcgisVersion": "12.0.0",
  "parentServiceType": "FeatureServer",
  "customdataRuntimeVersion": "1",
  "type": "provider",
  "editingEnabled": false,
  "properties": {
    "serviceParameters": [
      { "label": "City", "key": "city", "description": "City to query." }
    ]
  }
}
```

Set `arcgisVersion` to the exact target Enterprise version string. Service parameter values arrive in `req.params.<key>`.

## src/weather-config.json ← add to .gitignore

```json
{ "apiKey": "YOUR_WEATHERAPI_COM_KEY" }
```

## src/index.js

```javascript
const packageInfo = require("../package.json");
const cdconfigInfo = require("../cdconfig.json");

module.exports = {
  type: cdconfigInfo.type,
  name: cdconfigInfo.name,
  version: packageInfo.version,
  Model: require("./model"),
};
```

## src/model.js

```javascript
const cfg = require("./weather-config.json"); // gitignored — never commit real keys

class Model {
  #logger;
  constructor({ logger }) {
    this.#logger = logger;
  }

  async getData(req) {
    const city = req.params.city;
    const raw = await fetch(
      `https://api.weatherapi.com/v1/forecast.json?key=${cfg.apiKey}&q=${city}&days=7`,
    );
    if (!raw.ok) {
      const err = new Error(`Upstream error: ${raw.status}`);
      err.code = raw.status >= 500 ? 502 : 400;
      throw err;
    }
    const data = await raw.json();

    const features = data.forecast.forecastday.map((d, i) => ({
      type: "Feature",
      geometry: {
        type: "Point",
        coordinates: [data.location.lon, data.location.lat],
      },
      properties: {
        id: i,
        date: d.date,
        maxtemp_f: d.day.maxtemp_f,
        mintemp_f: d.day.mintemp_f,
        avgtemp_f: d.day.avgtemp_f,
      },
    }));

    return {
      type: "FeatureCollection",
      features,
      metadata: {
        idField: "id",
        name: `7-Day Forecast — ${data.location.name}, ${data.location.country}`,
        description: "Weather forecast data from WeatherAPI.com",
        geometryType: "Point",
        maxRecordCount: 7,
        fields: [
          { name: "id", type: "integer", alias: "Day Index" },
          { name: "date", type: "string", alias: "Date", length: 16 },
          { name: "maxtemp_f", type: "double", alias: "High Temp (°F)" },
          { name: "mintemp_f", type: "double", alias: "Low Temp (°F)" },
          { name: "avgtemp_f", type: "double", alias: "Avg Temp (°F)" },
        ],
      },
      ttl: 1800,
    };
  }
}

module.exports = Model;
```

## Notes

- All npm packages install at the provider level (`providers/weather-provider/package.json`).
- `getData` is `async` throughout — never mix in a callback form.
- `idField` references a real numeric field (`id`); `fields` is declared explicitly.
