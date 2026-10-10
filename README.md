# Ukraine Wargame

Operational campaign prototype with an **integrated 3D WEGO infantry battle** built in Godot. Contact launches the battle directly; its results update the campaign without external editor steps.

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

Download **`codex/integrated-tactical-battle`** for this build. It includes the save/load and terrain-bridge branches; the stacked PRs are still unmerged. Import its `project.godot`, then press **F5**.

### Try the integrated battle

Click **PLAY INTEGRATED DEMO** in a new campaign. It executes the documented two-turn contact and opens `T003_B2` on a synthetic 512 x 512 m map.

- You command the blue detachment: up to four nine-person squads. Red is a scripted opponent.
- Select a blue squad in the map or side panel; right-click ground to order movement. Orders route around buildings. **HOLD POSITION** clears an order.
- Click **EXECUTE 60 SECONDS**. Both sides move and fire simultaneously. Playback defaults to 4x and can switch to 8x.
- Capture the gold objective. Fire is automatic within 230 m with line of sight; woods reduce hit probability. Suppression slows movement and reduces firing effectiveness.
- **SAVE & CAMPAIGN** preserves an unfinished battle and its campaign lock. **OPEN TACTICAL BATTLE** resumes it.
- A battle ends on detachment elimination or after six intervals. Click **APPLY & CAMPAIGN** to apply the result and save. Vehicles stay in reserve; losses affect only the infantry actually deployed.
- On restart, click **LOAD** to restore your save before starting another demo.

See [native battle behavior and limits](docs/NATIVE_TACTICAL.md).

### Campaign controls

- Left-click a unit token to select it.
- Left-click an adjacent sector to issue a movement order.
- Click **RESOLVE TURN** to execute orders simultaneously.
- Click **SAVE** to write the current campaign to one save slot; click **LOAD** to restore it, including after restarting. Loading deliberately replaces unsaved progress.
- Saves use `user://saves/campaign.json`; see [save/load behavior](docs/CAMPAIGN_SAVES.md).
- If Ukrainian and Russian units occupy the same sector, a battle summary and its geographic center appear. The payload is written to `user://battle_exports/<battle_id>.json`.

### Two-turn contact demo

1. Select UKR in A3 and order A2. Select RU in D2 and order C2. Resolve the turn.
2. Select UKR in A2 and order B2. Select RU in C2 and order B2. Resolve again.
3. Contact produces `T003_B2.json`, with center latitude `49.0225` and longitude `31.965`.

`user://` is Godot's per-user data directory. On Windows, exports normally appear in `%APPDATA%\Godot\app_userdata\Ukraine Wargame\battle_exports`. The absolute path is also printed in Godot's Output panel.

### Current limits

- The battle center is the geographic center of its sector, not a detected real contact point. The uniform latitude/longitude grid spans about 20x20 km; `sector_size_km` is nominal, not an exact metric measurement.
- The Python terrain bridge can prepare real OSM features, a projected elevation grid, and a CMAutoEditor elevation CSV. It does not create a CMBS scenario, launch the game, or import battle results.
- Only the first same-sector opposing pair starts a battle. Crossing moves and larger battles need later rules.
- Native battles currently use synthetic terrain and abstract infantry combat. OSM/DEM import, vehicles, fog of war, detailed ballistics and realistic force behavior are later work.
- Contact, tactical interval boundaries and applied results autosave. Startup still opens the initial scenario until **LOAD**. An unfinished battle locks campaign turns and movement.

## Validation

```bash
python tests/run_godot_checks.py --godot godot
python -m pytest -q tests/test_terrain_bridge.py
```

Checks cover campaign orders/exports, save validation, native combat, deterministic restart, actual mouse orders, navigation/LOS, locks, once-only results and failed-save rollback. GitHub Actions also renders the 3D view and captures a preview. Checks use temporary user-data folders.

## Optional legacy GIS / CMBS preparation

On Windows, install Python 3.11 or 3.12, run `setup_terrain_bridge.cmd`, then run
`run_terrain_bridge.cmd`. Choose **F** to fetch public OSM and elevation data for
the latest Godot battle export. Open `terrain_output/<battle_id>/preview.html`
and follow that folder's `CMAUTOEDITOR.md` to place terrain through the CMBS editor.

See [the terrain bridge guide](terrain_bridge/README.md) for offline planning,
local DEMs, the CLI, accuracy limits, and the manual editor handoff.

## Project layout

- `scripts/main.gd`: campaign interactions, turn resolution, and rendering.
- `scripts/sector_geometry.gd`: conversion from grid coordinates to a WGS84 sector center.
- `scripts/battle_exporter.gd`: JSON file writing and write errors.
- `data/campaign.json`: formations and geographic bounds.
- `docs/BATTLE_EXPORT.md`: export fields and coordinate assumptions.
- `scripts/tactical_battle.gd`: deterministic infantry simulation and validated saved state.
- `scripts/tactical_view.gd`: 3D battlefield, squad input and playback controls.
- `docs/NATIVE_TACTICAL.md`: complete native game loop, rules and limitations.
- `docs/CODEX_NEXT_PROMPT.md`: next native tactical improvements.
- `terrain_bridge/`: validated GIS requests, public-source fetching, elevation CSV, and previews.

## Architecture direction

The campaign launches a native tactical scene in the same Godot process. The simulation returns a validated result, the campaign applies losses once and saves, and operational play resumes. The standalone GIS bridge and CMBS tools remain optional.

Next milestones are tactical usability, stronger infantry behavior, native GIS terrain, and vehicles. See [the development queue](docs/AUTONOMOUS_DEVELOPMENT.md).

## Design rule

Campaign sectors and tactical battlefields are separate. The native first slice uses a 512 m test map; the optional GIS export still requests a 2 km window around the placeholder sector center.
