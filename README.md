# Ukraine Wargame

Prototype operational campaign layer intended to use **Combat Mission: Black Sea** as the tactical battle resolver.

## Phase 1 vertical slice

This starter project proves the core campaign loop:

1. Select an operational unit.
2. Order it one sector at a time.
3. Resolve the campaign turn.
4. Detect opposing units occupying the same sector.
5. Write a tactical battle JSON export with geographic coordinates.

The prototype uses a 4x4 grid over a fictional test area in central Ukraine. Formation positions and strengths are demonstration data. It does not represent the current conflict.

## Requirements

- Godot 4.5 or newer (validated with Godot 4.5.1).

## Run

Clone this repository and import its root `project.godot` in Godot. Press **F5** to run.

The prototype is on `phase-1-vertical-slice` until its pull request is merged. Select that branch when cloning or downloading it.

### Controls

- Left-click a unit token to select it.
- Left-click an adjacent sector to issue a movement order.
- Click **RESOLVE TURN** to execute orders simultaneously.
- If Ukrainian and Russian units occupy the same sector, a battle summary and its geographic center appear. The payload is written to `user://battle_exports/<battle_id>.json`.

### Two-turn contact demo

1. Select UKR in A3 and order A2. Select RU in D2 and order C2. Resolve the turn.
2. Select UKR in A2 and order B2. Select RU in C2 and order B2. Resolve again.
3. Contact produces `T003_B2.json`, with center latitude `49.0225` and longitude `31.965`.

`user://` is Godot's per-user data directory. On Windows, exports normally appear in `%APPDATA%\Godot\app_userdata\Ukraine Wargame\battle_exports`. The absolute path is also printed in Godot's Output panel.

### Current limits

- The battle center is the geographic center of its sector, not a detected real contact point. The uniform latitude/longitude grid spans about 20x20 km; `sector_size_km` is nominal, not an exact metric measurement.
- No OSM, elevation, buildings, terrain maps, CMBS scenario files, automatic launch, or result import are generated yet. The JSON is a contract for the future bridge.
- Only the first same-sector opposing pair is exported each turn. Crossing moves and larger battles need later rules.
- Campaign state lives in memory and resets when the application closes. Units can continue moving after contact; battles do not lock turns yet. Personnel and vehicles are carried in the payload, but losses and campaign saving are not implemented.

## Validation

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/campaign_smoke.gd
```

The smoke test exercises click orders, illegal movement, simultaneous movement, contact detection, sector-center orientation, JSON file contents, invalid export filenames, and directory-write failure handling. Test exports use a separate temporary folder and are cleaned up.

## Project layout

- `scripts/main.gd`: campaign interactions, turn resolution, and rendering.
- `scripts/sector_geometry.gd`: conversion from grid coordinates to a WGS84 sector center.
- `scripts/battle_exporter.gd`: JSON file writing and write errors.
- `data/campaign.json`: formations and geographic bounds.
- `docs/BATTLE_EXPORT.md`: export fields and coordinate assumptions.
- `docs/CODEX_NEXT_PROMPT.md`: terrain-bridge milestone.

## Architecture direction

```text
Godot campaign layer
    |
    +-- campaign state / formations / turns
    +-- map + sectors
    +-- movement + supply + fog of war
    +-- battle detection
    |
    +--> battle_payload.json
             |
             v
Python GIS bridge
    +-- OpenStreetMap
    +-- DEM/elevation
    +-- battle bounding box
    +-- CMAutoEditor integration
             |
             v
Combat Mission: Black Sea
             |
             v
battle result import
             |
             v
Godot campaign state
```

## Next milestones

- Replace the abstract grid with a georeferenced map of Ukraine.
- Replace uniform geographic interpolation with a projected metric sector grid.
- Add operational movement costs by road/terrain.
- Add formation composition and persistent losses.
- Add a Python `terrain_bridge` that accepts battle coordinates and prepares OSM/DEM data for CMAutoEditor.
- Add battle-result import.

## Design rule

The campaign sector is **not** the CMBS tactical battlefield. A campaign sector may be 5–10 km across, while a contact inside that sector generates a smaller tactical window such as 2x2 km centered on the engagement location.
