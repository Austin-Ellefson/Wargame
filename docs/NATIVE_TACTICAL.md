# Native tactical battle: first integrated slice

The native simulator runs in the campaign's Godot process. Download the
`codex/completed-battle-report` branch, import `project.godot`, and press F5.
This milestone branch includes the unmerged stacked campaign and tactical work.
Godot 4.5.1 is the tested version.
Python, CMAutoEditor and Combat Mission are not required for native play.

The newer `codex/terrain-los-probe` descendant includes a planning-only terrain
LOS/range tool, smooth combat zoom, route previews,
camera navigation, pinning, spotting/contact memory, MOVE/QUICK/HUNT, fire control,
queued waypoints, timed pauses, local-contact reactions and cover-weighted red routes. The milestone
branch above remains frozen. Fresh battles use tactical rules v25, including selected-squad visibility, delayed shared reports, spaced nearby cover and saved retries when friendlies block otherwise usable cover. See the five-step
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
   takes about 7.5 seconds; 1x takes 60 seconds. The button cycles 4x/8x/1x
   without changing simulated results. Each actual
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
battalion personnel and all vehicles stay in reserve. The frozen milestone uses three simple figures
per squad; newer soldier descendants use up to nine procedural display slots.
Friendly labels show surviving headcount; live enemy counts remain concealed.

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
losses remain visible even when several squads fire together. In the preserved
milestone dead squads vanish; newer soldier descendants show known loss slots.
their roster button and hold control disable, and both movement and hold orders
are rejected by the simulation.

Legacy v1/v2 battles retain full enemy visibility. The preserved milestone model
has no detailed ballistics, weapon classes, armor or soldier animations. Later
descendants add roles/animations below; none establish realistic military-model
validation. Those are separate, testable improvements. Existing
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

## Combined infantry playtest

Download codex/morale-retreat-rally, open project.godot in Godot 4.5.1 and press F5.
Start a fresh PLAY INTEGRATED DEMO to use V13; older pending engagements retain
their saved versions. Existing controls and two-battle/resume steps remain in
FIVE_STEP_TACTICAL_PROGRESS.md.

1. Select a living squad, choose QUICK and right-click a distant clear point.
   Execute and watch FAT increase as it moves. On a later planning interval,
   queue a route with PAUSE: stationary execution seconds recover fatigue.
2. Watch incoming suppression, casualties and numerical morale. Shaken squads
   slow down; severe pressure/heavy losses can cause BROKEN, WITHDRAWING and
   NO FIRE. They choose a rear route automatically and reject manual overrides.
   A break is conditional, not guaranteed in every encounter.
3. A broken survivor at its rear shows RALLY with remaining seconds. After 30
   quiet stationary seconds it returns to shaken; renewed suppression resets
   progress. Elimination correctly removes the withdrawal/rally display.
4. After an interval, SAVE & CAMPAIGN, quit/reopen and load the campaign. Verify
   the same pending battle, positions, orders, FAT and any rally countdown.
5. Finish/apply once, inspect both sides and campaign consequences, then use
   surviving opposing formations for the documented next-contact test.

The headless suite also tests mid-execution saves and 17-second partial rally
restoration directly, plus duplicate/stale results and two consecutive contacts.
Rendered morale evidence uses a seeded damaged checkpoint; separate regression
triggers break from actual simulated fire. Linux checks do not establish Windows
validation, realistic infantry fidelity, or combined-arms completeness.


## Infantry posture (tactical v14)

Fresh engagements add STAND, CROUCH and PRONE planning controls for a living
selected blue squad. Posture changes immediately without clearing its route,
movement mode, fire preference or timed pause. Execution freezes these commands.
Broken survivors stand automatically for rear withdrawal and reject posture
overrides until rallied. Red defaults to standing; this increment adds no enemy
posture planner. Start a fresh integrated demo to use v14; existing pending
engagements retain their saved rules.

| Posture | Movement multiplier | Observer range multiplier | Target concealment multiplier | Incoming hit multiplier | LOS height |
| --- | --- | --- | --- | --- | --- |
| STAND | 1.0 | 1.0 | 1.0 | 1.0 | 1.6 m |
| CROUCH | 0.7 | 0.9 | 0.85 | 0.75 | 1.0 m |
| PRONE | 0.3 | 0.75 | 0.65 | 0.5 | 0.35 m |

Range multipliers combine with the existing open/woods range. Lower posture can
lose sight behind hills; buildings still block all sight. Target exposure scales
hit probability with the same per-shot random samples, ammunition and cadence.
Suppression pressure is unchanged. Movement multipliers combine with fatigue,
suppression, pinning, HUNT and morale. QUICK while prone crawls; it does not
silently stand the squad. Fatigue still charges actual travelled distance.

Selection text and starred buttons show current posture. Symbolic squad bodies
lower/elongate, and visible shot cues follow their display height. These are
exaggerated markers, not individual soldier animations. Hidden enemy state is
not added to labels, markers or live feedback. Rendering consumes no combat RNG.

Playtest: select S1, CROUCH then PRONE, queue MOVE/QUICK, execute and compare
motion with a standing squad. At close contact watch actual shots and rounds;
lower posture reduces exposure, without guaranteeing survival. SAVE & CAMPAIGN,
quit/reopen/LOAD, and confirm postures and complete orders persist. Repeated
campaign contact/results remain covered by the combined regression suite.

The multipliers are abstract prototype tuning, not empirical combat values.
No transition delay, weapon-specific posture restrictions, automatic cover
seeking, individual soldiers, leaders or Windows validation is claimed.


## Rifle and support-fire profiles (tactical v15)

Fresh battles assign S1/S3 on each side to RIFLE and S2/S4 to SUPPORT. These are
fictional squad-level fire profiles, not individual rifle/machine-gun inventories.
Selection text and live friendly volley lines identify RIFLE/SUPPORT; hover the selected
status for cadence/ammunition details. A support shot uses a warmer muzzle cue
only when the actual shot is visible. Unseen enemy roles and rounds stay hidden.

| Profile | Cadence | Maximum rounds per volley | Per-round hit multiplier |
| --- | --- | --- | --- |
| RIFLE | Every 3 simulated seconds | 1 per living squad member | 1.0 |
| SUPPORT | Every 2 simulated seconds | 2 per living squad member | 0.65 |

Volleys clamp to available rounds; both profiles start with the existing 40 rounds
per deployed person. More support rounds apply more pressure through the existing
`0.07 + rounds * 0.012` suppression rule, but spend the finite supply faster.
No extra personnel/ammunition is granted. Casualties remain bounded by survivors,
and same-tick attacks are collected before either side takes damage. Support fire
is still aimed at a currently locally engageable enemy, not an area-fire command.
HOLD FIRE, broken morale, zero ammo, LOS and spotting restrict both profiles.
Posture, cover and suppression still modify hit probability.

Cadence derives from saved elapsed seconds; restart cannot reset it or grant an
extra volley. Rendering/playback never samples combat RNG. V1–V14 engagements
retain their original three-second single-round-per-survivor behavior and event
shape. New V15 saves add strict fixed role assignments; campaign/result/export/
GIS contracts and Windows launchers are unchanged.

Playtest: fresh PLAY INTEGRATED DEMO, select S2 and confirm SUPPORT, then maneuver it
to a locally visible contact. Execute and watch larger frequent round reductions
and live SUPPORT lines; use HOLD FIRE in a later planning interval to conserve ammo.
Compare S1 RIFLE and save/reopen between intervals. Partial-ammo and one-second
pre-volley disk restart are also covered by regression.

This is abstract profile tuning: no individual weapon/ammo pools, gunner losses,
reloads, overheating, ammunition transfer, penetration, realistic cyclic rates or
platform-specific performance validation. Real support-fire tactics/fidelity and
Windows playtesting remain unverified.


## Local acquisition delay (v16)

New contacts require three consecutive executed simulated seconds of geometric
sight for each living observer/target pair. No UI query, planning pause, order
or playback speed earns observation time. The third second permits identification
and an eligible cadence shot. Shared faction contacts and remembered markers do
not give another squad local firing permission. HUNT and red engagement reaction
use identified local contacts. Loss of LOS/range or observer death resets progress;
reacquisition requires three fresh seconds. Already observed hidden movement/death
does not update remembered positions. Planning posture changes invalidate lost sight.

Sparse per-observer timers persist exactly across saves and restart. V1–V15 retain
immediate spotting and their original save fields/rules. Campaign/result, GIS,
exports and Windows launchers remain unchanged. This is a fixed abstract delay,
not a measured detection model: no probabilistic signatures, search arcs, leaders,
communication delay or firing-signature bonuses. It identifies living contacts;
unidentified corpses are not a new contact type. Windows remains unvalidated.

Playtest: start a fresh integrated demo, approach an enemy with HUNT and execute.
Sight must be maintained for three simulated seconds before an enemy contact or
eligible shot appears; actual rifle/support cadence still applies. Lose LOS and
reacquire; saved last-seen markers alone permit no fire. SAVE & CAMPAIGN/LOAD must
resume the same remaining delay. Existing pending battles retain their old rules.


## Movement-command response (v17)

New or replaced MOVE/QUICK/HUNT routes on either side wait five executed seconds
before movement starts on the sixth. The delay is a fixed squad response rule,
not a leader/radio model. Friendly selection shows MOVE/QUICK/HUNT IN Ns.
Observation, acquisition and fire continue; no extra combat RNG is consumed.
Manual PAUSE counts concurrently with response, so a 15-second pause remains
15 seconds rather than becoming 20. WAIT/HUNT PAUSED labels show the dominant
halt reason while the response clock still counts down. Planning/playback/UI
queries cannot consume time. Pinning also does not restart the timer.

Append preserves a pending or completed response on the existing route. A new
route or replacement gets five seconds; unsuccessful commands change neither
path nor timer. HOLD cancels movement and the response timer immediately. Dead
squads clear their timer, including actual same-tick firing deaths. Automatic
morale withdrawal bypasses response. Existing fire/posture commands keep their
current timing; command-delay tuning, leaders, communications and delayed contact
sharing remain future work. V1–V16 keep their original movement/save rules.

Playtest: fresh demo, select MOVE or QUICK and right-click nearby clear ground.
Execute: the IN Ns countdown must fall while position holds, then motion begins
on second six unless another halt applies. A contact can be acquired/fired on
during response. SAVE & CAMPAIGN/LOAD preserves unfinished response and route.
Windows and Combat Mission fidelity remain unvalidated.


## Selected-squad contacts and shared reports (v18)

Before a battle finishes, the selected blue squad supplies live enemy visibility.
Switching squads changes the local picture; the summary labels the selected squad's
local count and the number of delivered reports. Enemy live actors and shot endpoints
require that squad's identified sight. Actual firing events snapshot which observers
could see both endpoints before simultaneous casualties, so killing shots remain
visible to real witnesses without hidden-position leaks. Changing perspective removes
cues not witnessed by the newly selected squad. Friendly status remains available.

Observed contacts are transmitted as immutable position/time snapshots taking five
executed seconds to arrive. Amber `? REPORT Ns` marks observation age, not countdown
or live tracking. One packet per faction/contact is in flight; intermediate updates
wait, and the latest actually observed memory can be sent once the channel is free.
Packets preserve original coordinates through hidden movement/death and sender loss.
Observed elimination sends a delayed removal after earlier in-flight packets. Hidden
death leaves remembered reports intact. Reports never authorize a shot or preferred
target; each squad's own three-second acquisition and LOS/range still apply.

Transmission/delivery occurs only on execution ticks, not planning/UI/playback time.
Both factions use the same saved transport; red still acts on its own local contacts.
V1–V17 retain aggregate visibility and existing fields/rules. This is fixed abstract
sharing, not a leader/radio network: no range/channel failures, sender-loss cancellation,
search arcs or real communications modeling. A selected squad's lost contact may have
no marker until its report is delivered; there is no separate per-observer memory UI.

Playtest: fresh demo, approach a contact, execute and select the observing squad.
Switch to a distant squad: live enemies disappear, then a timestamped amber report
appears five seconds after transmission. The report stays at observed coordinates
while the enemy moves unseen, and grants no fire permission. SAVE & CAMPAIGN/LOAD
retains packets, ages and delivery deadlines. Windows/fidelity remain unvalidated.

## Individual soldier figures — presentation increment

The individual-soldier-visuals descendant replaces three oversized squad capsules
with one procedural low-poly helmeted rifle figure per initially deployed soldier
(up to nine per squad). STAND/CROUCH/PRONE articulate torso, arms and legs. Blue
casualties become grey fallen figures without rifles, including eliminated squads.
Enemy figures remain hidden until acquired; live enemy formations retain nominal
initial figure counts so exact hidden losses are not exposed. The finished report
reveals actual surviving/lost personnel. These are display slots, not individual
soldier identities, independent pathfinding, collision, weapon inventory or AI.

Click INSPECT SQUAD for a close camera on the selected friendly squad. Middle-drag
pans and Shift-middle-drag rotates; RESET CAMERA restores overview distance.
Figures conform to terrain height at fixed formation offsets, which may overlap
obstacles: offsets do not participate in simulation movement/LOS. Shot endpoints
now use infantry height, with smaller cues in inspection view. Firing and movement
animations are the next presentation increment; this pass provides static poses.
No downloaded art or external asset dependency. Tactical v18/campaign v2/result v1
are unchanged; presentation leaves authoritative state and RNG untouched. Linux
render checks do not prove Windows performance or realistic fidelity.

## Soldier motion and firing animation

The soldier-motion-fire-animation descendant adds procedural walking/crouched
strides/prone crawling and travel facing only after an observed squad actually
moves. A queued route or response/pause/pinning halt does not earn a gait.
Squad centers still advance in simulation ticks; this pass animates limbs rather
than interpolating route positions or adding individual formation pathfinding.

Actual visible shot events supply captured aim direction, rifle/arm recoil and
individual decorative muzzle flashes. Cues last 0.42 wall seconds at 1x/4x/8x,
so faster playback does not shorten them. All nominal enemy figures may animate
one witnessed squad volley; this does not identify individual shooters/weapons
or disclose surviving enemy personnel. Selected-local visibility/witness rules
still apply; changing observers clears old firing, and hidden movement history
is discarded. Casualty slots never animate/fire. Animations reset on reopening
and are outside saved state, simulation RNG and outcomes. Tactical v18/campaign
v2/result v1 unchanged. No Windows performance or realistic fidelity validation.


## Selected squad remembered contacts (v19)

The selected squad keeps its own acquired last sight. After losing sight, an amber
`? LOCAL Ns` marker shows that recorded position and observation age, immediately.
A squad that never acquired the contact receives only `? REPORT Ns` after the
existing five-second report delay. The newer observation wins; own sight wins ties.
Switching squads can therefore change the marker location, source and age without
changing any battle state. Live acquired enemies hide their uncertain markers;
remembered positions grant no direct-target or firing permission. The Memory
count includes selected-squad uncertain local/report markers.

Neither kind follows hidden movement or learns hidden deaths. An observer who
witnessed elimination immediately suppresses that contact, including older
in-flight reports; others retain their report until the ordered death confirmation
arrives. This prototype has no report reliability/error, uncertainty radius, radio
network or per-soldier perception. It is not Combat Mission fidelity or Windows
validation. Procedural soldier movement, witnessed real-shot recoil/muzzle cues,
completed reports and the frozen milestone build remain preserved.

Try the integrated demo, execute until contact is acquired, move out of sight and
select other squads. Compare LOCAL and REPORT ages, Save/Load during execution
using the existing checkpoint workflow, and confirm hidden markers cannot be
Shift-clicked as direct targets. Godot 4.5.1/project.godot/F5 remains the launch path.


## Squad facing and covered fire arcs (v20)

During planning, select a blue squad, click **FACE**, then left-click a ground
point. The order changes bearing without moving or replacing the squad's route.
Click FACE again or right-click to cancel the cursor mode. **ARC OFF / 90° / 180°**
cycles unrestricted fire and a cone centered on that bearing. A cyan selected
friendly outline shows the direction/230m maximum firing range; terrain, local
sight and acquisition still decide whether a target is eligible. Map-edge clipping
keeps the preview within the playable window. FACE's whole-degree bearing is
clockwise from north0/east90/south180/west270. Controls freeze during execution.

A squad can still spot enemies outside its arc, but withholds all fire there,
including return fire and any old preferred-target order. An acquired preferred
target outside the arc says **Focus: outside arc**. Hidden targets retain generic
waiting-for-sight feedback. Clear the arc to restore unrestricted local fire.
Movement carries the arc's origin but keeps its world direction; it does not
automatically point toward the route or threats. Broken squads clear their arc
and withdraw under the existing rules. Red uses unrestricted fire by default.

Stationary living figures face the order after real-shot recoil expires; moving
figures follow actual travel and witnessed shots face actual endpoints. Known
casualties do not turn. The order does not change spotting, exposure, cover or
turning delays; no quick self-defense exception, traverse speed, per-soldier
sectors or ammunition inventory is modeled. Existing saves keep their version;
start a fresh integrated demo for v20. This remains a synthetic prototype, with
no Windows or Combat Mission fidelity validation.


## Ground-directed suppressive fire (v21)

In planning, select a squad, click **AREA FIRE**, then left-click reachable
ground. An orange16m disk marks your explicitly chosen area; it is not an enemy
location/hit report. Right-click cancels the cursor without a movement order.
**CLEAR FIRE** removes the saved area or preferred target. HOLD FIRE pauses an
area order; AUTO resumes it. Facing/arc restrictions still apply. Choosing an
identified preferred target replaces area fire, and area fire replaces that target.

During execution the squad spends actual rounds at its rifle/support cadence
and flashes/traces to the selected ground point. Nearby opposing squads can
receive suppression even when concealed, without becoming spotted or targetable.
The selected panel shows Area: active, HOLD FIRE, empty or waiting for LOS/range/arc;
rounds and your own combat changes remain visible. No hidden-hit feedback or enemy
pressure appears. Nearby suppression falls linearly to zero at16m and requires
LOS from the area center. This increment applies no casualties or friendly effects.

Routes carry the shooter away from its fixed ground point; invalid geometry
withholds fire while retaining the order. It never auto-snaps to a remembered
contact or falls back to a live enemy. Breaking cancels the order; ammunition
used still contributes to the existing campaign supply result. Saved orders and
full outcomes resume exactly. Start a fresh integrated demo for v21; old battles
retain their rules. This is abstract suppression, without ballistics, blast,
individual aim/traverse, friendly fire or validated Combat Mission/Windows fidelity.


## Opponent ducking under fire (v22)

Red infantry reacts to its own suppression during execution: standing squads
crouch at30%, then go prone at55%. They keep the lower posture until pressure
fades below15%, so they do not toggle between poses every volley. This occurs
after the normal per-second recovery and before movement/spotting/fire. Existing
posture reductions to pace, exposure and observation range apply. Automatic
morale withdrawal retains its standing/QUICK priority; dead units do not react.
Blue posture stays under player control. Red keeps existing routes rather than
seeking new cover in this increment.

The reaction uses no attacker position or reported contact. Concealed area fire
can make red duck while its shooter stays unidentified. Enemy figures reveal the
pose only while your selected squad actually acquires them; exact live enemy
pressure and losses stay hidden. Save/restart retains the current posture and
pressure, with identical subsequent ticks/results. Start a fresh integrated demo
for v22; old pending battles keep their rules. Prototype thresholds have no
measured Combat Mission fidelity or Windows validation.


## Nearby cover under sustained fire (v23)

The `codex/opponent-nearby-cover` descendant adds a local red cover response.
Six consecutive execution seconds at 30% or more recovered suppression trigger a
search for reachable woods within 32 m (at most 40 m of actual routed travel).
Selection uses only the squad's own pressure and local terrain. Blue movement
remains manual, and received fire does not identify a concealed attacker.

Red retains its original route while moving toward cover and holds the selected
point until pressure fades below 15%. It then rejoins the saved route through
terrain navigation. Pinning, HUNT, explicit waits and pending command response
remain stronger than the detour; a locally engageable target no longer strands
that detour in the open. Normal firing and ducking continue. Breaking overrides
the response with standing withdrawal. The detour survives intervals and restart.

Only actually acquired red figures show this movement. There is no enemy intent
marker or disclosure of live enemy pressure/losses. Use AREA FIRE near observed
opposition to apply pressure, then stop firing to see recovery; heavy fire can pin
squads before they reach cover. Already covered squads do not relocate, and no
nearby reachable woods means no detour. Start a fresh demo for tactical v23.
This remains abstract squad behavior, without threat-direction scoring, coordinated
maneuver, occupied-cover separation or Windows/Combat Mission fidelity validation.

## Friendly cover spacing (v24)

Fresh battles on `codex/opponent-cover-spacing` keep new red cover destinations
at least 12 m from other living red squad centers and their active cover goals.
The fixed squad roster resolves simultaneous choices. A reserved goal counts
while its squad is still moving or paused, so another squad chooses a different
reachable point. A lone survivor and a withdrawing squad still occupy their
current position; dead squads do not. Enemy positions and reports never reserve
space or influence this decision.

The existing 32 m search radius, 40 m route limit and original queued orders stay
in effect. If no separated cover fits, red keeps its original orders; it retries
only after pressure falls below 30% and then builds for six seconds again. Goals
release on recovery, death or morale withdrawal. Already selected routes do not
reshuffle every tick. The 12 m spacing is a prototype squad-center buffer, not
individual collision avoidance: paths can cross and later movement can enter
another squad's space. It does not provide coordinated maneuver or threat-direction
scoring. Old v23 engagements retain their original unspaced behavior; start a
fresh integrated demo for v24. Windows and combat fidelity remain unverified.

## Retrying crowded cover (v25)

If all otherwise usable nearby wooded destinations are occupied by friendlies,
red waits 12 executed seconds before searching again while suppression stays at
least 30%. Still-crowded searches repeat at that bounded cadence; an available
point is reserved normally. The cooldown survives save/load and interval breaks.
Planning, pause/playback controls and queries cannot advance its clock. A pending
retry preserves the original route, movement mode and remaining explicit wait
when the next execution interval starts. Pinning, HUNT, waits, command response
and morale withdrawal still control whether the squad actually moves.

This retry requires a terrain-reachable point inside the existing radius, route
length and queue budget. Distant/unreachable woods, an already covered squad and
a full movement queue do not arm it. Falling below 30% pressure cancels the timer
and restarts the normal six-second pressure requirement. Death or breaking clears
it. Active cover goals are never reshuffled by a retry. Enemy positions/reports
and random samples play no part. Start a fresh demo for v25; older saves retain
their original rules. This remains abstract destination selection, not individual
collision avoidance or validated Windows/Combat Mission behavior.

The v25 regression captures actual support fire at 4x playback and at least 4 m
of later movement after a friendly frees cover. Its 65 m inspection camera uses
the existing close-view label/cue scale. At the old 80 m switch, overview
labels and cues jumped in size and obscured this close engagement. The following
presentation increment fixes that transition on the newer descendant; the earlier
retry fixture remains unchanged as evidence for the separate cover behavior.

## Continuous combat zoom — presentation increment

The `codex/continuous-combat-zoom` descendant removes the abrupt 80 m size switch.
Squad/AREA FIRE/remembered-contact labels and their heights, fire-arc line widths,
and squad muzzle/tracer widths interpolate continuously using camera distance
and field of view. Sizing stays between the existing close-inspection and default
overview values. The ordinary 65 m close scale and default 52-degree overview
remain unchanged; extremely close/wide views clamp rather than growing without bound.

Mouse-wheel zoom still changes field of view between 30 and 70 degrees. It now
resizes existing labels and active shot geometry immediately, including during
planning. INSPECT/RESET and pan/orbit retain their controls. Zoom never creates a
shot, resets its 0.42-second lifetime or recoil, changes its endpoints/length, or
advances the simulation. The 16 m area and 230 m arc extents remain physical map
distances; only their text/line presentation changes. Remembered labels stay at
the observed location and do not reveal the hidden squad's current position.

No tactical rules, save fields, RNG, animation cadence or report contents change.
This is readability work, not a new combat model. It does not add label collision
avoidance or eliminate decorative tree/HUD occlusion. Windows remains unvalidated.

## Planning terrain LOS and range probe

On `codex/terrain-los-probe`, select a living blue squad during planning and click
**CHECK TERRAIN LOS**, then left-click ground. The readout shows horizontal ground
range and **TERRAIN CLEAR/BLOCKED**, from the squad's current posture eye height
to an endpoint 0.30 m above the clicked ground. Click another point to compare;
right-click, Escape or the same button cancels without issuing a movement order.
FACE, AREA FIRE, squad selection, execution and reopening also clear the probe.
Posture changes recalculate the same point. Camera pan/zoom preserve its location.

This uses the simulation's existing sampled hills/building LOS, not decorative
tree meshes. A ground endpoint inside a building is blocked. Woods still affect
spotting separately. The whole line is green/red and drawn over terrain so its
status remains visible; it does not identify the first obstruction. Shorter than
1 m, nonfinite and off-map endpoints are rejected; a missed ground pick clears
the prior measurement. Range is not capped to weapon range.

**Terrain clearance is not enemy detection, fire permission or hit probability.**
The probe never queries a hidden enemy/remembered target, grants acquisition,
changes orders or spends rounds. A CLEAR point may be outside firing range or
arc; HOLD FIRE, ammunition, acquisition, concealment and target height still
govern real shots. Results are for the current squad center and posture, not a
future waypoint or an individual soldier. UI state is transient, outside saves
and simulation RNG; tactical v25/campaign v2/result v1 are unchanged. Linux/render
checks do not establish Windows validation or realistic combat fidelity.

## Hypothetical LOS from the final queued waypoint

On `codex/waypoint-los-preview`, queue a movement route, open **CHECK TERRAIN
LOS**, then click **ORIGIN: CURRENT POSITION — SWITCH** in the probe panel.
The origin button now identifies the final queued coordinates as **HYPOTHETICAL**.
Ground clicks measure from that destination using the selected squad's current
posture, explicitly shown as an assumption. Switch back to compare the same
endpoint from the actual squad position. Neither action issues movement or fire.

The origin is derived from the current route on every refresh/query. Replacement
or appended legs change it immediately; HOLD removes the line and shows **NO
QUEUED DESTINATION**, never silently substituting the actual position. With no
route, current-position probing still works. Cancellation, selection, execution
and reopening reset the mode. Existing sampled terrain/building and low ground
endpoint limits apply; the preview predicts neither arrival nor future spotting,
fire eligibility, target positions or combat outcomes. It is not a ghost squad,
path-safety assessment or individual soldier line of sight. No save fields change.
