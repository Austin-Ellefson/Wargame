# Native tactical battle: first integrated slice

The native simulator runs in the campaign's Godot process. Download the
`codex/completed-battle-report` branch, import `project.godot`, and press F5.
This milestone branch includes the unmerged stacked campaign and tactical work.
Godot 4.5.1 is the tested version.
Python, CMAutoEditor and Combat Mission are not required for native play.

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
   The translucent **LATEST VOLLEY** panel spells out recent changes for both sides:
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
Woods provide cover; they do not yet conceal units. Each deployed person starts
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

Enemy positions remain visible. This first model has no detailed ballistics,
weapon classes, armor, animations, multi-contact battles, fog of war or realistic
military-model validation. Those are separate, testable improvements. Existing
formation snapshots and legacy exports remain available.

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
movement rules, while newly created engagements use v2 pinning. Result/export
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
