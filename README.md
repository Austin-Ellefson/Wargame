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

Download **[`codex/playback-single-step`](https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/playback-single-step)** for the latest candidate descendant. It includes repeat battles and restart, firing/report feedback, limited visibility and delayed reports, infantry movement/fire/posture orders, fatigue and morale, low-poly animated soldier figures, nearby-cover reactions and smooth label/cue zoom. The planning terrain LOS/range tool compares the actual squad position with its hypothetical final queued waypoint; during execution the camera can follow the selected squad, pause battle time, or deliberately advance one simulated second while paused. These presentation tools do not change orders or reveal hidden enemies. Fresh battles remain v25; existing pending saves receive them without a rules migration.

The original milestone remains preserved on `codex/completed-battle-report`. The stacked PRs remain unmerged. Import `project.godot`, then press **F5**; start a fresh integrated demo to use the latest rules. Existing pending battles keep their saved rules.

### Try the integrated battle

Click **PLAY INTEGRATED DEMO** in a new campaign. It executes the documented two-turn contact and opens `T003_B2` on a synthetic 512 x 512 m map.

- You command the blue detachment: up to four nine-person squads. Red follows objective routes and stops to engage its own locally visible firing contacts.
- Middle-drag to pan, Shift + middle-drag to rotate, and use the wheel to zoom. **RESET CAMERA** restores the overview.
- During execution, **FOLLOW S#** keeps the camera centered on the selected living blue squad's actual position. Wheel zoom remains available. Pan, rotate, change selection, INSPECT, RESET, elimination, completion or reopening disengages follow instead of transferring it silently.
- During execution, **PAUSE PLAYBACK** freezes battle ticks, partial playback time, shot/tracer lifetime, recoil and movement animation. Pan, orbit, zoom, speed selection and FOLLOW remain usable. While paused, **STEP +1s** executes one normal battle tick, shows its real shots and feedback, then remains paused; the frozen partial second is preserved for **RESUME PLAYBACK**. These controls are separate from the saved 15/30/60-second movement-order pause and reset on planning, completion or reopening. STEP deliberately advances authority; it is not replay or rewind.
- Select a blue squad and **MOVE**, **QUICK** or **HUNT**, then right-click ground to replace its routed movement order. **Shift + right-click** appends a waypoint in the existing route mode. **HOLD POSITION** clears the route.
- **AUTO / HOLD FIRE** controls firing, including return fire. **Shift + left-click** a contact to prefer it only when the selected squad can locally engage it; **CLEAR TARGET** returns to nearest eligible targets.
- With a queued route, **PAUSE** cycles 0/15/30/60 simulated seconds before moving; firing continues. Remaining waits and routes survive restart. HUNT also pauses on local contacts or pressure.
- **STAND / CROUCH / PRONE** changes posture while planning. Lower posture slows movement, reduces observation range and exposure, and may lose terrain sight. Posture persists on restart. Broken squads stand for withdrawal.
- **CHECK TERRAIN LOS**, then left-click ground, shows horizontal range and terrain CLEAR/BLOCKED from the selected squad's posture to a point 0.30 m above ground. Posture changes recalculate it; right-click, Escape or the button cancels without moving. This is terrain only, not enemy detection, fire permission or hit chance; the colored line does not mark the first obstruction.
- With a queued route, click **ORIGIN: CURRENT POSITION — SWITCH** inside the probe panel to measure from the **HYPOTHETICAL** final waypoint instead. Its coordinates and assumed current posture are shown; switch back to compare. Changing the route updates the origin; HOLD removes the measurement. This predicts neither arrival nor future spotting/fire.
- Fresh battles use **RIFLE** squads S1/S3 (one round/person every 3 seconds) and **SUPPORT** squads S2/S4 (two rounds/person every 2 seconds). Support volleys spend finite ammunition faster and apply more suppression; these are abstract squad profiles. Older pending battles retain their saved rules.
- Click **EXECUTE 60 SECONDS**. Both sides move and fire simultaneously. Playback defaults to 4x; the compact execution row cycles 4x/8x/1x, pauses/resumes viewing, and enables one-second stepping only while paused.
- New or replaced movement routes wait **five executed seconds** before motion. Fire and spotting continue. Appending keeps the current response; **HOLD POSITION** cancels it. Manual PAUSE counts concurrently; automatic withdrawal bypasses response.
- Click **INSPECT SQUAD** to see individual soldier figures, helmets, rifles and standing/crouched/prone poses. Friendly losses become grey fallen figures. **RESET CAMERA** restores the overview. Figures walk/crouch/crawl after actual movement and recoil/flash on witnessed shots. These display rigs do not add individual soldier AI.
- Fresh battles show the selected squad’s own contacts. After sight is lost, **? LOCAL Ns** shows its last observation; **? REPORT Ns** arrives after the five-second report delay. The newest observation wins, with local sight winning ties. Both retain captured position/time and grant no firing permission. Start a fresh **PLAY INTEGRATED DEMO** for v25; existing saves retain their rules.
- During planning, select a squad, click **FACE**, then left-click ground. **ARC OFF / 90° / 180°** restricts fire around that bearing; enemies outside it remain visible but receive no fire, including return fire. Right-click cancels FACE; clearing ARC restores unrestricted local fire. Facing/arc orders survive Save/Load.
- **AREA FIRE**, then left-click reachable ground to spend real rounds suppressing a16m area. **CLEAR FIRE** cancels it; HOLD FIRE pauses it. Hidden enemies stay concealed and receive no fabricated hit/casualty report. This first area-fire increment applies suppression only.
- Red squads crouch/go prone under suppression and rise after it fades; blue posture stays manual. After six seconds of sustained pressure, exposed red squads can seek nearby woods while retaining their original route. They hold the selected cover until pressure fades, then rejoin that route. Pinning and morale withdrawal still take priority; new cover goals stay at least 12 m from living friendly squads and reserved cover destinations. Usable cover blocked by friendlies is retried every 12 executed seconds while pressure stays at least 30%, retaining the original orders. No hidden attacker knowledge enters selection.
- New contacts require **three consecutive simulated seconds of local sight**. Losing sight resets acquisition. Shared or last-seen contacts alone do not permit a squad to fire; pause and playback speed do not earn observation time.
- Capture the gold objective. Fire is automatic within 230 m with line of sight; woods reduce hit probability. Suppression slows movement, pins heavily pressured squads and reduces firing effectiveness. Live enemy contacts reveal no exact strength; amber last-seen markers remain at observed positions without tracking hidden movement.
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
- Native battles currently use synthetic terrain and abstract infantry combat. OSM/DEM import, vehicles, detailed ballistics and deeper force behavior are later work. Windows validation and Combat Mission fidelity remain unverified.
- World labels and shot cues now scale continuously between close and overview sizes. Labels can still overlap in dense groups, and decorative terrain/HUD can obscure figures; this does not add per-label collision avoidance.
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
