# Battle export, schema version 1

Battle contact writes `user://battle_exports/<battle_id>.json`. The exporter
creates the directory when needed and reports file errors in the Godot console.
Existing files with the same ID are overwritten, including when repeating a demo
after restarting. This is a prototype export, not a CMBS scenario format.

| Field | Meaning |
| --- | --- |
| `schema_version` | Currently `1`. |
| `battle_id` | Resolved campaign turn and sector, such as `T003_B2`. |
| `sector` | Column letter and one-based row number. |
| `turn` | Campaign turn after advancing the resolution. |
| `ukraine`, `russia` | Force snapshots: ID, name, personnel, vehicle counts, morale, supply. |
| `terrain_request.sector_size_km` | Nominal operational sector width. |
| `terrain_request.tactical_map_size_km` | Requested tactical square side length, currently 2 km. |
| `terrain_request.center_lat`, `center_lon` | Sector-center latitude and longitude in decimal degrees. |
| `terrain_request.coordinate_system` | `EPSG:4326` (WGS84 geographic coordinates). |
| `terrain_request.center_method` | `placeholder_sector_center`; no sub-sector contact model yet. |
| `terrain_request.source` | `future_osm_dem_pipeline`; no terrain data has been fetched. |

## Geographic assumptions

The bounds in `campaign.json` define a rectangular fictional test area. X grows
eastward and Y grows southward from its northwest corner. Each coordinate uses
the half-cell offset so the location is inside the sector, rather than on a corner.

For row count R and column count C:

```text
latitude = north + (south - north) * (y + 0.5) / R
longitude = west + (east - west) * (x + 0.5) / C
```

This interpolates geographic coordinates. It does not make exact 5 km sectors,
model the Earth's surface distance, or claim building-scale terrain accuracy.
Malformed bounds and out-of-range cells return no center; a bridge must reject
exports without coordinates. Dateline-crossing campaign bounds are unsupported.

Example terrain request from the B2 demo:

```json
{
  "sector_size_km": 5,
  "tactical_map_size_km": 2,
  "source": "future_osm_dem_pipeline",
  "center_lat": 49.0225,
  "center_lon": 31.965,
  "coordinate_system": "EPSG:4326",
  "center_method": "placeholder_sector_center"
}
```

The Python `terrain_bridge` now validates this request and computes projected
metric bounds before requesting OSM/DEM data and preparing CMAutoEditor inputs.
`source: future_osm_dem_pipeline` remains the campaign's request label, not a
claim that terrain has already been downloaded. The bridge's own manifest is
authoritative for preparation status. See `terrain_bridge/README.md`.
