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

## Authored route-leg boundaries (tactical v26)

Fresh v26 battles add `route_legs`, a dictionary for editable blue routes. Each
entry is a nonempty array of positive integer point counts, one count per player
click, whose sum must exactly equal that squad's remaining `orders` path length.
The map may contain only known, non-broken blue squads with routes; every such
route requires an entry. Red objective routes and automatic broken-squad
withdrawals are deliberately not described as player-authored legs.

Right-click replacement stores one leg. Each successful Shift-right-click appends
one bounded leg without changing earlier path points. As execution consumes routed
points, the first count decrements and disappears at its boundary. Death,
withdrawal, destination completion and HOLD clear matching metadata. The existing
128-point total route limit still applies; leg counts and list length are each
bounded to 1–128.

**REMOVE LAST WAYPOINT** now removes the complete last authored leg in v26. It
does not reroute, move, inspect contacts, advance time or sample RNG. Earlier legs,
movement mode, timed pause and earned command-response delay remain exact. A
single-leg route delegates to HOLD. Gold numbered planning markers are derived
from the validated counts and are not saved separately.

Missing/extra IDs, red or broken owners, empty/fractional/nonpositive/oversized
counts, and sums inconsistent with `orders` reject before restore. V1–v25 states
retain their exact fields and point-by-point removal rules; loading never invents
leg boundaries. Campaign v2, result v1, locks, once-only losses, rollback,
exports/GIS and launchers are unchanged.

## Timed movement pauses (tactical v8)

With a queued route, PAUSE cycles 0/15/30/60 simulated seconds. The squad waits
before moving, but can spot/fire and receive damage. Countdown runs only during
execution, independently of playback speed; pinning/HUNT may still prevent
movement after it expires. WAIT status and remaining seconds are visible.
A replacement route, Hold, destination completion or elimination clears the
wait; appending retains it. Commands remain frozen during execution.

V8 persists `pause_remaining` for every squad ID as integer 0–60; a positive
value requires a nonempty queued route. Missing/extra IDs, fractional/negative/
excessive values and orphan waits reject the save. V1-v7 retain original
fields/rules. No RNG, campaign/result/export or GIS contract changes.

## Opponent contact reaction (tactical v9)

Red squads still receive fixed objective routes, but now stop advancing while
a living enemy is locally visible within their firing range and they have rounds
and AUTO fire enabled. They retain the route and fire with existing combat rules.
When local contact clears, ammunition is exhausted or fire is withheld, advance
resumes subject to suppression and other wait rules. This is derived each tick
from the squad's own current sight; shared/last-known contacts and hidden player
positions do not influence it. No tactical intent/status is revealed through
the enemy's generic contact label. Blue commands retain their explicit modes.

Rules version is v9 with the same fields as v8; versioning preserves the prior
blind objective advance for existing v1-v8 engagements. No RNG or campaign/
result/export fields change. This is a small stop-and-engage reaction, not a
flanking planner, formation AI, cover-selection model or validated combat fidelity.

## Cover-aware opponent routes (tactical v10)

Fresh red objective advances use a separate deterministic terrain graph: wooded
cells cost 1, open cells 1.6. This favors nearby woods over short open routes
without ordering arbitrary distant cover detours. The fixed lane destinations,
8 m grid, building clearance and local stop-and-engage rules remain in force.
Routing never reads enemy positions, shared contacts or remembered contacts;
local sight still governs firing and halting. Blue routes keep their original
shortest-path graph. A squad can still halt in open ground when contact appears,
and an objective destination need not itself be covered. This is terrain-aware
routing, not tactical flanking, coordinated maneuver or a fidelity claim.

V10 has exactly the same saved fields as V9. Queued routes persist verbatim,
and the terrain graph rebuilds on restart. Existing V1–V9 engagements keep their
original routing rules with no migration. No simulation RNG calls or campaign,
result, terrain/export or launcher contract changes. Regression covers actual
wood traversal, modest detour, hidden-information independence, player/V9
isolation, blocked destinations and complete actual campaign disk outcomes.

## Covered objective positions (tactical v11)

Red squads reserve reachable wooded grid positions inside the existing 52 m
objective radius, at least 12 m apart, in stable roster order. Each position is
chosen nearest its former lane goal using terrain and its own route reachability.
Enemy positions, contact memory and RNG do not enter selection. Squads hold
these points across intervals; uncovered/unreachable choices fall back to the
old lane goal. Local contact still halts an advance before its destination.
This does not provide flanking, mutual support, dynamic threat scoring or collision avoidance.

V11 has the same fields as V10; queued destinations persist in orders. V1–V10
keep original destinations on restart. Campaign/result/GIS/export contracts and
Windows launchers are preserved. Tests exercise real arrival, objective scoring,
separation, fallback, hidden-input isolation and actual disk continuation.

## Infantry fatigue (tactical v12)

Moving squads earn fatigue from metres actually travelled: QUICK 2 points/m,
MOVE 1 point/m, HUNT 0.5 points/m, rounded to integer points each simulated
second. Fatigue is 0–1000 points; speed multiplies by `1 - fatigue/2000`.
A fully tired squad still moves at half its otherwise available speed. Existing
suppression, pinning, timed wait, local HUNT and opponent halts still apply.
Stationary living squads recover 3 points per simulated second, including waits
and pinning. Planning time and playback/render speed do not change fatigue.
Eliminated squads retain their last value. FAT percentage appears for the selected
blue squad; hidden enemy fatigue is never shown. This is abstract tuning: no
load, slope, injury, weather or weapon-specific fatigue effects.

V12 adds `fatigue` for exactly every squad ID, as integer 0–1000. Missing/extra
IDs, fractional, nonnumeric, nonfinite and out-of-range values reject. Integer
storage avoids JSON precision drift discovered during development. Existing
V1–V11 saves retain their original fields and speeds. New engagements start
fresh; fatigue currently ends with the battle and does not modify campaign
forces or result fields. Campaign v2/result v1/export/GIS/launchers are unchanged.

## Morale, withdrawal and rally (tactical v13)

Morale updates after suppression recovery each execution second. A living squad
is shaken with half-or-more personnel lost, morale below 60, or suppression at
least 50 percent. Shaken squads move and fire at 75 percent effectiveness; old
pinning/fatigue rules still apply. Otherwise they return to steady. A squad breaks
with suppression at least 65 percent plus either morale at most 35, or half-or-more
losses and morale at most 70. These are abstract prototype thresholds.

Broken squads replace orders/waits with a routed QUICK withdrawal to their own
rear edge (blue x32, red x480), stop firing and reject manual movement/fire/target/
pause/Hold commands. Pinning can still stop them, and retreat incurs fatigue.
They do not halt to engage enemies or accept red objective orders. At the rear,
after their route ends, 30 consecutive stationary execution seconds with
suppression below 25 percent rally them to shaken. Disruption resets the timer.
If a route cannot be found, they remain broken and retry; they do not teleport.
The sidebar shows BROKEN, WITHDRAWING/NO FIRE or the remaining RALLY countdown.
Hidden enemy morale/intent remains concealed. Numerical formation morale still
reflects casualties; tactical rally does not restore personnel or rewrite it.

V13 adds strict `morale_states` (steady/shaken/broken) and `rally_remaining`
(integer 0–30) for every squad. Nonbroken squads require zero rally time; living
broken squads require a positive timer. State, automatic paths and partial rally
progress survive restart. V1–V12 preserve original fields and rules. No extra RNG
or campaign/result/GIS/export/launcher fields change. Morale state does not yet
carry across battles; no leaders, C2, surrender, formations or coordinated retreat.
Real-fire regression triggers a break without injected damage; rendered withdrawal/
rally uses a seeded damaged checkpoint, actual movement and timer progression.


## Infantry posture (tactical v14)

V14 adds `postures`, keyed by exactly every squad ID, with `stand`, `crouch` or
`prone` values. Missing/extra IDs, unknown/nonstrings and nonstanding broken
squads reject. Postures, routes, contacts and timed pauses survive exact disk
restart; mixed-posture real combat reaches identical complete outcomes. V1–V13
keep their original fields, standing LOS/range/exposure and movement behavior,
and cannot receive posture orders. No silent upgrade occurs. Campaign v2,
battle result v1, export/GIS fields and optional Windows launchers are unchanged.


## Rifle/support cadence (tactical v15)

V15 adds `weapon_roles` for exactly every squad ID. S1/S3 must be `rifle`, S2/S4
must be `support`, on both sides. Missing/extra IDs, altered assignments, unknown
values and nonstrings reject before applying live state. Role is a fixed fictional
roster profile; saves cannot fabricate a different equipment mix. All existing
ammo and survivor bounds remain in force. Cadence uses persisted elapsed seconds,
so a checkpoint at 00:01 fires the same support volley at 00:02 after restart.
Complete campaign disk continuation with mixed profiles produces identical state
and result. V1–V14 retain original fields and rifle cadence; no upgrade on load.
Campaign v2/result v1, GIS/export fields and Windows launchers remain unchanged.


## Tactical acquisition v16

New battles add `acquisition`: exactly one dictionary per squad ID. Each sparse
map contains opposing known squad IDs and integer consecutive-sight progress 1–3,
no greater than executed elapsed time. Zero/negative/fractional/nonstrings, extra
or missing observer maps, friendly/unknown targets and unknown fields reject.
Geometry is still checked at query time, so saved progress cannot bypass LOS/range.
Progress advances only once per executed second; dead/lost-sight observers reset.
Partial timers and full combat outcomes restore exactly from disk. V1–V15 keep
their fields and immediate acquisition; campaign v2/result v1 are unchanged.


## Tactical response v17

New battles add `command_remaining`, exactly one integer 0–5 per known squad.
Positive entries require a saved route, living squad and non-broken morale.
Missing/extra IDs, malformed timers, no-route/dead/broken positive timers reject.
Replacement starts five seconds; append retains the old timer; hold/route finish/
death clear it. Automatic withdrawal bypasses it. Mid-response disk saves retain
exact remaining time and full combat outcomes. V1–V16 retain original fields and
immediate route response. Campaign v2/result v1 and rollback contracts unchanged.


## Tactical shared reports v18

New battles add `shared_contacts` and `pending_reports`, each exactly UKR/RU maps
keyed only by opposing known squad IDs. Delivered records contain position and
integer `seen_at` at least five seconds old. Pending records contain position,
`seen_at`, `sent_at`, `deliver_at` and kind `contact`/`lost`. Observation must be
no later than transmission; delivery is exactly sent_at + 5 and remains in the
future, at most five seconds ahead. Coordinates/time/field counts/factions/IDs
are validated; malformed/future/friendly/extra entries reject. Query results copy
records. One in-flight packet per target stays immutable; later observed memory
waits until it is free. Actual hidden positions/deaths never replace report data.
Packets, delivered memories and full combat outcomes restore exactly from disk.
V1–V17 retain their fields/rules; campaign v2/result v1/rollback remain unchanged.
Shot local-observer lists remain transient outside saved authoritative state.


## Tactical observer memory v19

New engagements add `observer_contacts`, exactly one dictionary per known squad
ID. Each sparse map records only opposing known squad IDs with exactly `position`,
integer `seen_at` (3 through elapsed) and `kind` (`contact` or `lost`). Valid bounded
non-building positions are required; `lost` requires an eliminated target. Missing/extra
observer maps, friendly/unknown targets, malformed fields/times/coordinates reject.
This is observation metadata; acquisition, fire permission and simulation RNG are
unchanged. A local sighting advances only from actual acquired execution sight;
unseen movement/death leaves it unchanged. A witnessed elimination leaves a local
tombstone so older in-flight reports cannot resurrect that witness's contact.

Queries combine own sightings with delivered reports using original observation
time, prefer own sight on ties, return copied data and hide currently acquired
contacts. Dead/missing observers and completed battles have no uncertain markers.
No camera/UI query advances clocks or writes knowledge. Bilateral records and
full combat outcomes continue exactly after actual campaign disk restart. V1–V18
retain their original shape/rules; existing saves are not silently upgraded.
Campaign v2/result v1, battle locks, bounded once-only loss/result application,
save-write rollback, export/GIS and optional Windows launchers remain unchanged.


## Tactical facing and fire arcs v20

New engagements add `facing_orders`, exactly one record per known squad ID, with
exactly integer `heading` (0–359) and `width` (0, 90 or 180). Heading is clockwise
from north (-south axis): east90, south180, west270. Width0 means unrestricted fire.
Unknown/missing IDs, extra fields, nonfinite/fractional/string angles, unsupported
widths and a nonzero arc on a broken squad reject before restoring live state.
Living steady/shaken squads receive planning-only facing and arc commands;
player commands cannot affect red. Dead/broken/executing squads reject commands.

Facing ground points must be finite and within map bounds, at least1m from the
squad; stored bearing rounds to whole degrees. Routes/response/pauses are unchanged.
Arc origin follows actual squad position while bearing remains fixed in world
space. Automatic and preferred fire both require the arc plus existing local
acquisition, LOS and range. Outside-arc sightings remain visible. Morale break
clears the width before withdrawal; dead squads retain their last saved record.
Default unrestricted v20 combat matches all v19 authoritative fields/results
except new facing metadata. No additional RNG samples. V1–V19 retain original
fields/rules and reject facing orders rather than migrate silently.

The cyan selected-friendly preview, cursor mode and decorative figure rotation
are transient presentation. Moving figures follow actual displacement; stationary
living figures return to ordered bearing after a witnessed shot cue expires.
Known casualty figures do not rotate. Camera/preview queries cannot alter state.
Actual campaign disk restart restores angles/arcs, each tick, shots and complete
results exactly. Campaign v2/result v1, once-only losses, locks, save rollback,
export/GIS and optional Windows launchers remain unchanged.


## Tactical ground area fire v21

New engagements add `area_fire`: exactly one array per known squad ID. Empty
means no area order; otherwise exactly two finite bounded coordinates outside
buildings. Missing/extra IDs, malformed points and simultaneous preferred entity
targets reject. Broken squads require empty area orders. Dead squads may retain
their last point but cannot shoot or receive commands. Saved orders may become
out of LOS/range/arc after movement; restore retains them rather than inventing
a new endpoint or switching to targeted fire. V1–V20 keep original fields/rules.

Planning-only ground commands require living nonbroken squads, at least1m and
less than230m distance, terrain/building LOS to a0.3m endpoint, and the saved fire
arc. Player commands cannot order red. Area and preferred target are exclusive;
accepting either replaces the other, and clearing target also clears the area.
HOLD FIRE pauses but retains the area; breaking clears it before withdrawal.

Execution uses the existing rifle/support cadence and bounded real round count.
Nearby living opposing squads with LOS from the endpoint receive deterministic
pressure `(0.04 + rounds*0.008)*(1-distance/16)` within16m; exactly16m receives
none. No damage/loss RNG, friendly effects or hit feedback is added. A chosen
point can be fired upon without identifying an enemy; it never creates acquisition
or updates observation memory. Hidden-hit IDs/positions/pressure do not enter
shot events. Friendly endpoints are explicit player orders; enemy area cues require
local acquired sight of the shooter and sight/range of its ground endpoint.

Events and previews remain transient; pure queries copy saved arrays. Exact
actual campaign disk restart restores orders, rounds, suppression, every tick/event
and completed outcomes. No-area v21 reproduces all v20 authoritative fields and
results except its new empty map. Campaign v2/result v1, battle locks, once-only
bounded losses, save rollback, export/GIS and optional Windows launchers unchanged.


## Opponent duck response (tactical v22)

V22 keeps the complete v21 field shape, including saved postures. Only fresh
engagements use the new red behavior; v1–v21 retain their original posture rules.
After0.035 per-second suppression recovery and morale handling, living nonbroken
red squads crouch from standing at30% pressure and go prone at55%. Existing lower
posture persists until pressure falls below15%, then they stand. Comparisons
round to millionths to avoid JSON/binary threshold drift; no additional saved
timer or random samples. Blue manual posture, dead units and standing automatic
withdrawal remain unchanged. Posture's existing movement/exposure/sight tradeoffs
apply to red. Planning and rendering do not advance reaction/recovery.

No attacker/contact/report query enters this decision. Received suppression can
change posture even when the source remains unidentified; it grants no sight or
location. Current posture and suppression fully restore hysteresis from disk.
Full real-fire campaign continuation compares every state/event and completed
result. Quiet v22 battles reproduce all v21 fields/results except version.
Campaign v2/result v1, locks, bounded once-only losses, save-write rollback,
export/GIS fields and optional Windows launchers remain unchanged.


## Nearby-cover response (tactical v23)

Fresh engagements add `cover_responses`, exactly one record per known squad ID:
`pressure_ticks` (integer 0–6), `goal` (empty or one bounded wooded point), and
`path` (remaining bounded terrain waypoints, empty after arrival). Blue, dead and
broken squads require zero ticks and empty goal/path. An active goal requires six
ticks; its path must end at that goal and be at most 40 m from current position.
An empty active path requires arrival. Missing/extra IDs or fields, malformed
points/timers, blocked/open goals, orphan paths and excessive paths reject.
V1–V22 retain their existing fields and rules, with no silent migration.

After recovery, morale and ducking, red requires six consecutive executed seconds
at at least 30% suppression before choosing nearby woods. A single deterministic
local terrain search ranks reachable cover-weighted paths by travel length,
within 32 m straight line and 40 m routed distance, breaking ties in y/x grid
order. Already covered
squads, unreachable/distant woods and queues without rejoin budget receive no new
detour. A failed search waits for pressure below 30% before rearming. No enemy
position, contact/report or random sample enters destination selection.

The response path temporarily takes priority over the retained movement queue.
It uses MOVE pace with existing posture, fatigue, morale and suppression modifiers.
Pinning, HUNT, command response and explicit pauses still halt it; local automatic
stop-and-engage yields to the cover move, with ordinary return fire retained.
At arrival red holds until recovered pressure falls below 15%. Terrain navigation
then reconnects to the original first queued point, retaining subsequent legs,
mode and remaining waits. The 128-point queue budget is reserved before selection.
Intervals do not replace active cover goals. Death or morale break clears the
response immediately; automatic standing withdrawal keeps priority.

Moving through an area-fire falloff exposed last-decimal JSON suppression drift.
V23 rounds suppression writes to millionths after recovery and each received
attack; older rules are untouched. Partial timers, motion, holding and recovery
restore exactly, including every subsequent campaign tick, shot and full result.
Campaign schema v2/result v1, battle locks, bounded once-only losses, rollback,
export/GIS contracts and Windows launchers are unchanged. Drawing consumes no RNG.

## Friendly cover reservations (tactical v24)

V24 uses the v23 field shape, including `cover_responses`. Selection excludes
points less than 12 m from another living friendly squad's current position or
active cover goal. Exactly 12 m is allowed. Decisions run in the validated saved
roster order; earlier choices reserve space before later squads choose. No
separate cache, occupancy map, timer or random sample is introduced. The existing
saved goal reserves space during travel, pauses, pinning and arrival until the
normal recovery/death/break cleanup releases it. If every eligible point is
occupied, the bounded search fails and retains the original queue; rearming
still requires recovered pressure below 30%.

V24 validation rejects active goal pairs closer than 12 m. It does not reject a
living squad currently near another goal, because ordinary movement can legally
enter that space after selection; this increment does not change movement into
collision avoidance. V1–v23 retain their original fields and rules, including
overlapping v23 goals. Campaign schema v2/result v1 and existing lock, bounded
once-only loss, rollback, export/GIS and Windows launcher contracts are unchanged.
Exact disk continuation covers simultaneous reservations driven by real fire,
movement, release and complete results. Rendering consumes no simulation RNG.

## Crowded-cover retry (tactical v25)

Each v25 `cover_responses` record adds `retry_remaining`, an integer 0–12 in
simulated seconds. A positive value requires six pressure ticks, an empty goal
and path, and a living nonbroken red squad. Blue/dead/broken squads require zero.
Missing, extra, fractional, nonnumeric, out-of-range or inconsistent retry data
rejects before load. V1–v24 retain their original record shapes and behavior.

Only a failed search with a reachable in-budget candidate blocked by friendly
occupancy arms 12 seconds. The next search occurs on the twelfth subsequent
execution tick, with no pathfinding during intervening ticks. Continued congestion
rearms 12; success leaves zero and reserves the ordinary cover goal. Failure for
other terrain/queue reasons leaves zero until the usual pressure rearm. Recovered
pressure below 30% resets timer and pressure ticks; recovery/death/break cleanup
clears it. The authoritative integer countdown, not wall time or transient cache,
survives JSON disk checkpoints and interval transitions exactly.

Interval execution preserves a pending retry's original queued route, mode and
wait; its old destination (or current position if no route) remains reserved for
ordinary opponent objective selection. Existing movement gates still apply.
Campaign v2/result v1, locks, bounded once-only losses/results, rollback, exports,
GIS and Windows launchers are unchanged. No additional simulation RNG is used.

## Continuous combat zoom — no save change

Distance/FOV-derived label/cue sizing and resizing existing transient shots are
presentation-only. Tactical v25, campaign v2, result v1 and all older saved rules
stay unchanged. Camera input cannot advance elapsed time, acquisition, retries,
knowledge, ammunition or losses. Shot lifetimes and endpoints are unaffected;
neither the sizes nor the camera are added to campaign snapshots. Full combat
state/result comparisons against an unrendered twin cover changing zoom at every
tick. Existing disk restart/lock/once-only/rollback/export/GIS checks remain required.

## Planning terrain probe — no save change

The LOS cursor, explicit ground point, status line and range text are transient
view state. They are not campaign/tactical snapshot fields and reset on reopening
or execution. Querying terrain cannot alter orders, acquisition/knowledge, clocks,
ammunition, losses or RNG. Tactical v25/campaign v2/result v1 and legacy saved
rules stay unchanged; no migration is introduced. Regression saves/reloads the
authoritative state with the probe visible, verifies clean reopened UI and compares
every tick and complete combat result against an unrendered twin.

## Hypothetical waypoint probe — no save change

Current-position/final-waypoint mode is transient UI state and resets on reopening
or execution. The hypothetical origin is read from the selected friendly's final
saved route point, never written into its actual position or remembered contacts.
Clearing the route removes the measurement. Tactical v25/campaign v2/result v1
and older saves keep their rules; no new clock, RNG sample, order or save field.
The regression validates and disk-round-trips the actual state while the preview
is visible, then compares every execution tick and the complete result to a twin.

## Execution camera follow — no save change

The selected friendly ID used by FOLLOW S# and the camera transform are transient
view state. They are absent from tactical v25, campaign v2 and result v1. Reopening
starts at the overview with follow off, including when authoritative execution is
restored from disk. Follow reads actual friendly positions after completed ticks;
it cannot advance a clock, alter orders/knowledge/ammunition/losses, consume RNG,
replay a shot or extend a cue. Regression compares each tick and the full result
with an unfollowed twin while exercising actual camera and selection inputs.

## Last-interval review — no save change

The 61 public presentation frames used by **REVIEW LAST INTERVAL**, its current
frame, fractional playback time, pause/completion flags and recreated shot cues
are intentionally absent from tactical v25 and campaign v2 snapshots. A later
execution replaces the buffer; battle completion or reopening discards it. Review
cannot call a simulation tick, issue an order, mutate the current planning state or
emit a campaign checkpoint. Actual disk round-trip coverage confirms that only the
authoritative boundary state survives, then every later tick and the completed
result remain identical to an unreviewed twin. No migration is required.

## Review navigation — no save change

The paused PREVIOUS and RESTART controls change only the current index and
fractional time inside the existing transient public review buffer. Reverse
navigation clears presentation cues and applies a recorded public frame; it does
not restore, invert or step tactical authority. The index, pause/completion state,
tracers and buffer remain absent from tactical v25 and campaign v2 snapshots.
Disk reopen therefore returns to the same authoritative boundary state with no
review controls, and subsequent ticks/results remain identical to an unreviewed
twin. No migration is required.
