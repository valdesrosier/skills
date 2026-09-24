# Complete Editable Provider — database backend

Illustrative, **targeting ArcGIS Enterprise 11.5+ / 12.0**. Confirm any version-specific detail against the live [Enterprise SDK CDF guide](https://developers.arcgis.com/enterprise-sdk/guide/custom-data-feeds/) via `arcgis-docs-lookup` before building against a different release. An editable provider over a MongoDB collection, demonstrating `editData()`, `authorize()`, and `getMetadata()`.

> Editing writes to the **upstream store**. Before generating `editData` update/delete logic, run it through the destructive-operation guard in the skill: name the target store, show what it affects, confirm it is not production, prefer a read/count-first form, and never emit blind.

## cdconfig.json

```json
{
  "name": "fires-provider",
  "arcgisVersion": "12.0.0",
  "parentServiceType": "FeatureServer",
  "customdataRuntimeVersion": "1",
  "type": "provider",
  "editingEnabled": true,
  "properties": {
    "serviceParameters": [
      {
        "label": "Database Name",
        "key": "dataBaseName",
        "description": "MongoDB database name."
      },
      {
        "label": "Collection Name",
        "key": "collectionName",
        "description": "MongoDB collection name."
      }
    ]
  }
}
```

`editingEnabled: true` activates `editData()` (11.4+).

## src/mongodb-config.json ← add to .gitignore

```json
{
  "connectString": "mongodb://127.0.0.1:27017",
  "allowedEditors": ["fireops_user1", "fireops_user2"]
}
```

## src/index.js

```javascript
module.exports = {
  type: require("../cdconfig.json").type,
  name: require("../cdconfig.json").name,
  version: require("../package.json").version,
  Model: require("./model"),
};
```

## src/model.js

```javascript
const { MongoClient } = require("mongodb");
const cfg = require("./mongodb-config.json"); // gitignored

const client = new MongoClient(cfg.connectString);

class Model {
  #logger;
  constructor({ logger }) {
    this.#logger = logger;
  }

  async #collection(req) {
    await client.connect();
    return client
      .db(req.params.dataBaseName)
      .collection(req.params.collectionName);
  }

  // 12.0+: lets the framework reproject edit geometries without manual proj4
  async getMetadata() {
    return { idField: "alternateID", inputCrs: 4326 };
  }

  // Throw to reject the request before it reaches getData/editData
  async authorize(req) {
    if (!cfg.allowedEditors.includes(req._user?.username)) {
      const err = new Error("Unauthorized");
      err.code = 403;
      throw err;
    }
  }

  async getData(req) {
    const col = await this.#collection(req);
    const docs = await col.find({}).toArray();

    const features = docs.map((doc) => ({
      type: "Feature",
      geometry: doc.geometry,
      properties: {
        alternateID: doc.alternateID,
        fireId: doc.fireId,
        fireName: doc.fireName,
        fireType: doc.fireType,
        acres: doc.acres,
      },
    }));

    return {
      type: "FeatureCollection",
      features,
      metadata: {
        idField: "alternateID",
        name: "Active Fires",
        geometryType: "Point",
        maxRecordCount: 10000,
        fields: [
          {
            name: "alternateID",
            type: "biginteger",
            alias: "Alternate ID",
            editable: false,
          },
          {
            name: "fireId",
            type: "string",
            alias: "Fire ID",
            length: 64,
            editable: true,
          },
          {
            name: "fireName",
            type: "string",
            alias: "Fire Name",
            length: 128,
            editable: true,
          },
          {
            name: "fireType",
            type: "string",
            alias: "Fire Type",
            length: 64,
            editable: true,
          },
          { name: "acres", type: "double", alias: "Acres", editable: true },
        ],
        templates: [
          {
            name: "New Fire",
            description: "Add a fire.",
            drawingTool: "esriFeatureEditToolPoint",
            prototype: {
              attributes: {
                fireId: null,
                fireName: null,
                fireType: null,
                acres: null,
              },
            },
          },
        ],
      },
    };
  }

  // edits: { adds:[feature], updates:[feature+OBJECTID], deletes:[oid] }
  // The framework does NOT enforce rollbackOnFailure — handle atomicity yourself.
  async editData(req, edits) {
    const col = await this.#collection(req);

    const addResults = [];
    for (const f of edits.adds ?? []) {
      try {
        const r = await col.insertOne({
          geometry: f.geometry,
          ...f.attributes,
        });
        addResults.push({ objectId: r.insertedId, success: true });
      } catch (e) {
        addResults.push({
          objectId: -1,
          success: false,
          error: { code: 1017, description: e.message },
        });
      }
    }

    const updateResults = [];
    for (const f of edits.updates ?? []) {
      try {
        await col.updateOne(
          { alternateID: f.attributes.alternateID },
          { $set: { geometry: f.geometry, ...f.attributes } },
        );
        updateResults.push({
          objectId: f.attributes.alternateID,
          success: true,
        });
      } catch (e) {
        updateResults.push({
          objectId: f.attributes.alternateID,
          success: false,
          error: { code: 1019, description: e.message },
        });
      }
    }

    const deleteResults = [];
    for (const oid of edits.deletes ?? []) {
      try {
        await col.deleteOne({ alternateID: oid });
        deleteResults.push({ objectId: oid, success: true });
      } catch (e) {
        deleteResults.push({
          objectId: oid,
          success: false,
          error: { code: 1018, description: e.message },
        });
      }
    }

    return { addResults, updateResults, deleteResults };
  }
}

module.exports = Model;
```

## Notes

- `idField` (`alternateID`) references a real field — editable providers do not support auto-generated OIDs.
- Error codes: `1017` insert, `1018` delete, `1019` update.
- `authorize()` gates every request; `req._user` requires `forwardUserIdentity: true` on the service.
- Install `mongodb` at the provider level.
