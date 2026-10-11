# Campaign saves, version 2

The suppression-pinning descendant creates tactical rules version 2 engagements
inside the existing campaign schema. Tactical v1 saves remain supported and keep
their original behavior through completion; they are not upgraded on load. New
v2 battles derive pinning from saved morale/suppression, preserving status and
outcomes on restart. No additional squad fields are required. Unknown tactical
rule versions are rejected.

The limited-enemy-visibility descendant creates tactical rules v3 engagements.
Current spotting is derived from saved positions, living observers, terrain and
target cover with no random samples or persistent contact fields. Reload restores
the same sight picture. Existing v1/v2 engagements retain their original rules
and full enemy visibility; campaign schema and completed-result shape remain v2
and v1 respectively. Unknown tactical versions are rejected.

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

## Last-known contacts (tactical v4)

Fresh battles persist `contacts` for UKR and RU, keyed by opposing squad ID. Each
record contains only `position` and integer `seen_at` (elapsed simulation seconds).
Living observers update memory only with current range/LOS observation. Hidden
movement and unobserved death leave it unchanged; reacquisition updates it and
a living observer with range/LOS can confirm an eliminated contact.

During an unresolved battle, amber `? LAST SEEN Ns` markers show lost contacts
at their recorded position. They do not expire, reveal strength, track hidden
units or permit automatic fire without the shooter's own current LOS. Finished
reports hide uncertain markers. Instant side-wide information sharing remains.

Validation rejects friendly/unknown IDs, extra fields, blocked/out-of-map positions,
fractional/future timestamps and missing faction maps. V1/V2/V3 saves retain their
original fields and rules; no silent migration. Campaign schema v2 and battle
result schema v1 remain unchanged. Presentation consumes no simulation RNG.

## Movement modes (tactical v5)

New engagements add `movement_modes`, a dictionary keyed by exactly the IDs
with nonempty queued paths in `orders`. Values are `move`, `quick` or `hunt`.
Validation rejects missing/extra IDs, missing maps, unknown values and empty
mode-associated paths. Movement mode and path are replaced/cleared together.
Pause conditions derive from saved positions, morale/suppression and local LOS;
no transient pause flag or extra RNG is saved. Disk restart preserves both modes
and complete deterministic outcomes. Campaign schema remains v2; result v1 and
legacy export contracts are unchanged. V1/V2/V3/V4 engagements retain original
fields and speed/response rules and cannot accept QUICK/HUNT; no silent upgrade.

## Infantry fire control (tactical v6)

During planning, AUTO or HOLD FIRE changes the selected squad's firing rule.
HOLD FIRE conserves all rounds and also withholds return fire; incoming fire,
spotting and movement continue. AUTO uses the existing local LOS/range rules.
Fire rules freeze during execution and persist across intervals and restart.
New v6 saves add `fire_modes` for every squad ID, with `auto` or `hold` values;
missing/extra IDs and unknown values reject the save. V1-v5 retain their automatic
fire and original fields/rules. Campaign v2 and result v1 are unchanged. Holding
fire does not introduce concealment benefits, weapon classes or ammo resupply.

## Preferred targets (tactical v7)

During planning, Shift-left-click a visible contact to prefer it for the selected
squad, or CLEAR TARGET to return to nearest eligible targeting. Assignment requires
the shooter's current local sight and fire range. A preference is not forced fire:
if unavailable, AUTO chooses another eligible target. HOLD FIRE always overrides.
Focus ready/waiting/none never shows enemy counts or hidden status; an unobserved
death retains the preference like any unavailable target. No hidden location is
rendered. Preferences persist until explicitly cleared/replaced.

V7 adds `fire_targets` for all squad IDs: empty string or known opposing squad ID.
Strict validation rejects missing/extra IDs, friendly/unknown targets and nonstrings.
A saved preference may be out of sight; every shot still rechecks current local
range/LOS. V1-v6 retain original fields/rules; no silent migration or extra RNG.

## Queued movement waypoints

Right-click replaces a selected squad's route. Shift-right-click appends a routed
leg from its existing final destination, preserving the queued mode and earlier
points; with no existing route it starts a normal order in the selected mode.
The bright dotted preview displays the full queue. Hold clears all legs.
Blocked destinations, a mismatched append mode and paths exceeding 128 points
reject atomically without discarding the current route. Routing follows the
existing 8 m building-clearance grid. Each queue uses one movement mode.

No save fields or simulation rules change: complete routes already persist in
`orders`. Tactical v7 remains current; old engagements keep their fields/rules.
Disk-restart regression now includes a multi-leg campaign route.
