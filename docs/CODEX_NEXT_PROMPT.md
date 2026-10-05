# Next Codex Task: Validate the Windows CMBS Terrain Handoff

## Completed

- Godot movement/contact detection and geographic battle JSON exports.
- A Python terrain bridge with schema validation and a projected 8 m UTM grid.
- Offline footprints/manifests with explicit pending-source statuses.
- Public OSM feature and Copernicus GLO-30 fetching, or local source files.
- Verified HTTPS fallback and tile caching when GDAL streaming cannot connect.
- Correct southwest-origin elevation CSVs, original-altitude GeoTIFFs, and previews.
- A Windows setup and run launcher, plus generated CMAutoEditor instructions.
- 26 GIS tests and the Godot smoke test passed at the terrain-bridge milestone.
- An actual Godot export produced a live 2x2 km package with 62,500 elevation
  cells, complete DEM coverage, and real OSM data. This was a data-preparation
  check, not a completed CMBS map.

## Next validation

1. Have the user run the Windows terrain bridge on their PC and inspect its
   preview. Work from their output and errors; do not assume local CMBS control
   or installed editor binaries are available to Codex.
2. Confirm the user's CMAutoEditor binary exposes the inspected flags and has
   the Black Sea profile/configuration. Follow its installation/screen guidance.
3. Run its OSM converter with the package's exact projected bounds. Check
   terrain CSV extent against the 250x250 elevation CSV, including orientation.
4. Guide the user through the elevation and surface passes in a new CMBS map.
   Compare hills, roads, river crossings, building placement, and map dimensions
   against the preview. Record version-specific problems and manual corrections.
5. Keep forces, objectives, and time/weather manual until a real supported
   scenario-generation interface has been verified.

## Follow-on campaign milestone

Add campaign save/load, a pending-battle lock, and a manual battle-result form
with validated losses and persistent formation updates. Do not discard an
unresolved battle, apply a result twice, or silently reload initial forces.
Keep fictional campaign data separate from real-time operational information.

## Validation to preserve

```bash
python -m pytest -q tests/test_terrain_bridge.py
godot --headless --path . --script res://tests/campaign_smoke.gd
```

See `terrain_bridge/README.md`, `docs/BATTLE_EXPORT.md`, and each prepared
package's `CMAUTOEDITOR.md` for the existing contracts and limitations.
