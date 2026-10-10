# Campaign saves, version 2

Use **SAVE** and **LOAD** beside Resolve Turn. There is one slot. Save replaces the previous slot; Load replaces unsaved progress. Native contact, execution start, completed intervals and result application autosave. Normal game-window close requests a save. Forcing the process to stop can lose work since the last checkpoint. On startup the initial fictional scenario opens; click Load to resume a saved campaign.

The save is `user://saves/campaign.json`, normally `%APPDATA%\Godot\app_userdata\Ukraine Wargame\saves\campaign.json` on Windows. Battle exports remain separate files in `battle_exports`.

Saved state includes turn, the complete formation roster and force counts, positions, pending movement orders, selection, the current battle payload/export path, native squad state and paths, execution timing, objective scores, contact origins, resolved battle IDs and the last result. A SHA-256 hash of the initial scenario ties the slot to that scenario. Changing scenario data requires a new save. Version 1 slots migrate to version 2: an unresolved legacy contact starts a fresh native battle with the saved forces, and queued campaign orders/selection for that contact clear to enforce the lock. Version 2 pending contacts require a valid tactical state.

Loads validate the entire snapshot before applying it. Unsupported versions, different scenarios, invalid formations/counts/sectors, fractional turns, illegal orders, and inconsistent battle payloads are rejected. A failed load leaves campaign state unchanged. The current battle is checked against the existing live export builder. An export path is a recorded location, not proof that the external file still exists; loading does not regenerate or validate terrain or a CMBS scenario.

Saving writes and flushes a temporary sibling file, then renames it over the slot. Open/write/rename failures are reported and the prior save is retained. This reduces partial-write risk; it is not a backup system or a guarantee against power loss or filesystem failure. Linux replacement behavior is tested; Windows remains a manual check.

A pending battle locks campaign movement and turn resolution. Only a matching finished native simulation can resolve it. Result application and saving form one transaction: on a write failure, force changes and resolution history roll back. Duplicate results remain rejected after restart. Formation personnel changes only by deployed detachment losses; vehicles remain in reserve.

## Verification

```bash
python tests/run_godot_checks.py --godot godot
python -m pytest -q tests/test_terrain_bridge.py
```

The save/load smoke uses temporary user-data folders and checks the actual Save/Load controls, restart restoration, orders and force counts, contact persistence, invalid inputs, and retention of existing saves after write failure. It cleans up its outputs.
