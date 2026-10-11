# Native tactical battle: first integrated slice

The native simulator runs in the campaign's Godot process. Download the
`codex/completed-battle-report` branch, import `project.godot`, and press F5.
This milestone branch includes the unmerged stacked campaign and tactical work.
Godot 4.5.1 is the tested version.
Python, CMAutoEditor and Combat Mission are not required for native play.

The newer `codex/infantry-fatigue` descendant includes route previews,
camera navigation, pinning, spotting/contact memory, MOVE/QUICK/HUNT, fire control,
queued waypoints, timed pauses, local-contact reactions and cover-weighted red routes. The milestone
branch above remains frozen. Fresh battles use tactical rules v12. See the five-step
batch test guide in [FIVE_STEP_TACTICAL_PROGRESS.md](FIVE_STEP_TACTICAL_PROGRESS.md).

## Complete game loop

1. Click **PLAY INTEGRATED DEMO** in a fresh campaign, or use the documented
   two-turn movement demo. Both formations meet in B2 and create `T003_B2`.
2. Contact autosaves and opens the tactical view. The campaign stays locked until
   the result is applied; export failure does not discard the native battle.
3. Command blue squads with the side-panel buttons or left-click their markers.
   Right-click ground to move; small blue disks mark destinations. Hold clears
   the selected squad's movement. Bright blue dots preview the selected squad's
   complete routed path during planning, including turns around buildings. The
   preview clears during execution and never changes the saved order or outcome.
   An order stays in effect across intervals until reached or replaced. Buildings
   are impassable.
4. Execute a 60-second interval. Orders freeze, and both forces move/fire in
   simultaneous one-second ticks. The red opponent advances toward the objective.
   Playback at 4x takes approximately 15 real seconds per complete interval; 8x
   changes presentation speed without changing simulated results. Each actual
   automatic attack flashes briefly at the firing squad and draws an orange shot
   cue toward its target. A cue means rounds were fired, not that they hit. Unit
   labels and the blue roster continuously show personnel, rounds and suppression.
   The translucent **LATEST VOLLEY** panel spells out recent changes for both sides
   in legacy rules; v3 reveals exact changes only for your blue squads:
   `P` is personnel, `R` is rounds and `SUP` is suppression percentage points.
5. Capture the gold objective. It scores one point per uncontested second within
   52 m of the flag. A surviving side wins if its opposing detachment is eliminated;
   otherwise objective time determines the winner at 360 seconds. Equal scores draw.
6. Click **APPLY & CAMPAIGN** on the finished report. Deployed infantry losses,
   morale and an abstract supply cost apply automatically, once. The losing
   formation withdraws to its prior sector if possible, or a free adjacent sector.
   In a draw the blue formation withdraws. The committed result autosaves. Before
   applying, the completed report shows both formations' deployed, surviving and
   lost personnel, objective-control seconds, morale caps, abstract supply costs,
   the withdrawing formation and the resulting campaign unlock. Applying closes
   the report; restart returns to the unlocked campaign rather than a stale result.

## Camera controls on the latest descendant

The `codex/tactical-camera-controls` descendant adds middle-button drag to pan,
Shift + middle-button drag to rotate, wheel zoom, and **RESET CAMERA** to restore
the overview. Navigation also works during execution and changes presentation
only. Pitch and map-focus limits keep the camera usable. Camera position is not
saved: reopening a battle starts with the overview. The preserved milestone ZIP
above remains available separately.

## Simulation scope

Up to 36 personnel deploy from each current formation, split into squads of up
to nine. A depleted formation deploys only its available personnel. The remaining
battalion personnel and all vehicles stay in reserve. Three simple figures
represent a squad; the label gives its actual surviving headcount.

Terrain is a synthetic 512 x 512 m test map with procedural hills, buildings,
woods and a road. This slice does not load the existing OSM/DEM packages.
The native map size is separate from the unchanged 2 km legacy GIS export request.

Squads route on an 8 m grid with building clearance. They move at an abstract
2.4 m/s before suppression modifiers. Automatic fire uses a 230 m range limit,
terrain/building line-of-sight checks and a distance/cover/suppression probability.
Attacks are collected before casualties apply, allowing simultaneous fire.
Woods provide cover (and conceal targets at distance under v3). Each deployed person starts
with an abstract pool of 40 rounds. Morale decreases with casualties. On the
`codex/suppression-pinning` descendant, new engagements use tactical rules v2:
a living squad is **PINNED** when suppression reaches `0.50 + morale * 0.0035`
(morale is 0–100). Suppression recovers by 0.035 per simulated second before
movement. Pinned squads halt but retain their routes, can return fire with the
existing suppression penalty, and automatically resume movement below the
threshold. Low morale makes pinning easier. The roster, world label and selected
squad panel show **PINNED**; latest-volley feedback reports status transitions.
These are prototype tuning values, not measured Combat Mission rules or validated
real-world parameters. Expenditure reduces operational supply
by up to five abstract percentage points per battle, rather than inventing a
campaign-wide ammunition inventory.

Shot cues come directly from the simulation's eligible attacks, so blocked,
out-of-range and empty-ammunition squads do not flash. They are short-lived
presentation events: they are not added to the save schema, do not consume random
numbers, and cannot change the authoritative result or deterministic restart.
The live combat panel is also presentation-only and compares state immediately
before and after an authoritative tick. Casualties are listed first so personnel
losses remain visible even when several squads fire together. Dead squads vanish,
their roster button and hold control disable, and both movement and hold orders
are rejected by the simulation.

Legacy v1/v2 battles retain full enemy visibility. This first model has no detailed ballistics,
weapon classes, armor, animations, multi-contact battles or realistic
military-model validation. Those are separate, testable improvements. Existing
formation snapshots and legacy exports remain available.

## Current spotting in tactical rules v3

A living squad can spot an enemy within 280 m on open ground, or within 120 m
when the target is in woods, if terrain/building line of sight is clear. Both
sides use the same observer/target rule, with no random spotting roll. A side's
view shows contacts observed by any living squad, but each shooter must spot its
own target before automatic fire. The opponent still follows scripted objective
routes; it does not use hidden player positions to plan movement.

Unspotted red actors, labels and orders are hidden. Observed enemies show only
**ENEMY CONTACT**, without exact personnel, rounds, morale or suppression. The
live sidebar shows blue personnel, current contact count and your own objective
seconds; exact red strength and objective time are withheld until the completed
report. Live volley changes describe blue squads only. A shot cue appears only
when both endpoints were observed at the moment of firing; unobserved incoming
fire can still damage/suppress blue squads without revealing its source.

Contacts are current sight only: losing LOS/range or the last living observer
hides the enemy again. No last-known-position marker, spotting delay, relative
contact sharing delay or area fire exists yet. The ranges are prototype tuning
values. This is a first visibility layer, not Combat Mission fidelity validation.

## Saving and resuming

Contact, execution start, completed intervals and result application autosave.
**SAVE & CAMPAIGN** saves the planning/finished state and returns to the operational
screen with the lock intact. An execution interval must finish before that button
becomes available. A normal game-window close requests a save of the current
tick; forcibly stopping Godot can lose ticks since the last checkpoint.

Startup opens the initial campaign. Click **LOAD**, then **OPEN TACTICAL BATTLE**
to resume. Saves preserve squad positions, counts, ammunition, morale, suppression,
paths, execution clock, objective control, contact origins and resolved IDs.
Shot randomness comes from battle ID, simulated tick and squad ID, so a restored
engagement reaches the same outcome with the same orders.

Tactical saves carry their rules version separately from campaign schema v2.
Existing tactical v1 engagements load and finish with their original slowed
movement rules; v2 keeps pinning and full visibility. V3 keeps pinning and current spotting; v4 adds saved contact memory. Fresh
v5 battles also persist movement modes. Existing engagements retain their version. Result/export
shapes and campaign schema remain unchanged. Unknown tactical versions are
rejected; there is no automatic rewrite of an in-flight battle.

If a result cannot be saved, force changes and resolved history roll back and
the completed battle stays available for retry. Unsupported/malformed saves and
altered, stale, negative, excessive or duplicate results are rejected. There is
one save slot shared by projects using this game name; back up `saves/campaign.json`
if you want to keep a separate save history while testing.

## Verification

Run `python tests/run_godot_checks.py --godot /path/to/godot` for editor import,
campaign, save/load, tactical state/results and GUI-event tests. The Python runner
also treats Godot script errors as failures when Godot itself exits with status 0.
The existing GIS suite remains `python -m pytest -q tests/test_terrain_bridge.py`.

GitHub Actions runs the same tests and a software-rendered OpenGL input check under
Xvfb, producing `tactical-validation` with a PNG preview and individual test logs.
Linux validation and a rendered screenshot do not replace a Windows playtest.

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

## Infantry movement orders (tactical v5)

Select a blue squad, click MOVE, QUICK or HUNT, then right-click a destination.
The star marks the mode for the next map command; changing that selector alone
does not change an existing order. The selected-squad panel shows the actual
queued order, including **HUNT PAUSED**. Hold clears the route and mode together.
Commands freeze during execution and dead squads cannot receive them.

| Mode | Base speed | Response |
| --- | --- | --- |
| MOVE | 2.4 m/s | Current normal movement, slowed by suppression and halted by pinning. |
| QUICK | 4.0 m/s | Faster route traversal, with the same suppression/pinning rules. |
| HUNT | 1.2 m/s | Pauses before movement on a locally spotted living enemy or suppression at least 25% after recovery. |

A paused HUNT retains its route, can fire using existing local sight rules, and
resumes once local sight clears and suppression falls below the threshold. Shared
or last-known contacts alone do not pause it. Pinning overrides every mode.
Movement/observation update on one-second ticks; HUNT reacts on the next tick
after contact acquisition. The red scripted advance still issues MOVE.

These are abstract tuning values. QUICK has no fatigue, posture or weapon-specific
accuracy penalty yet; HUNT is a reversible pause, not a permanent halt command
or a reproduction of proprietary Combat Mission rules. Paths/modes persist
across intervals and restart. Reaching the destination, Hold or elimination
clears them. No presentation changes consume simulation RNG.

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
