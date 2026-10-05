# Next Codex Task: Terrain Bridge Contract

Continue the Godot prototype in this repository. Keep the existing two-turn
movement/contact demo and its smoke test working.

## Completed

- Campaign data and placeholder geographic bounds load from `data/campaign.json`.
- Opposing units entering one sector generate a schema-versioned battle payload.
- `scripts/sector_geometry.gd` calculates the center of a uniform WGS84 grid cell.
- `scripts/battle_exporter.gd` writes JSON to `user://battle_exports`.
- The sidebar shows the coordinates and export filename.
- `tests/campaign_smoke.gd` validates the loop and export errors in Godot 4.5.1.

## Next implementation

1. Add a Python CLI under `terrain_bridge/` accepting an existing battle JSON.
2. Validate schema version, coordinate ranges, and requested tactical map size.
   Reject incomplete geographic requests instead of fabricating coordinates.
3. Calculate a 2x2 km tactical bounding box in an appropriate projected CRS,
   transform it back to WGS84, and write a terrain-request manifest. Include the
   projection and source provenance. Do not treat decimal degrees as meters.
4. Keep the bridge usable offline with a checked-in synthetic fixture. Record
   OSM/DEM inputs as pending until actual data has been provided or downloaded.
5. Inspect current CMAutoEditor documentation and its actual CMBS configuration
   before adding adapters. Do not assume an API exists for producing a CMBS
   scenario or importing results.
6. Document an explicit manual terrain-generation workflow, including what the
   user must do in the Windows Combat Mission editor.

## Definition of done

- The existing Godot smoke test passes.
- A real exported JSON file is accepted by the Python CLI.
- Its terrain manifest has validated geographic bounds and metric dimensions.
- Bad coordinates, unsupported schema versions, and missing data fail clearly.
- No placeholder data is described as actual OSM, elevation, or a playable CMBS map.

Later milestones: campaign save/load, unresolved battle locking, manual result
import with persistent losses, and exact metric operational sectors.
