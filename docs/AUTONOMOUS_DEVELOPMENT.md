# Autonomous development queue

## Operating cadence
One focused development pass each evening in America/Chicago.
The scheduled task uses GitHub as durable project state. It does not depend on the user's local folder.
Progress is delivered through draft PRs and scheduled run reports; review and merging remain with the user.

## Current baseline (2026-10-09)
- main: starter README only.
- PR #1: phase-1-vertical-slice -> main.
- PR #2: phase-2-terrain-bridge -> phase-1-vertical-slice.
- Working baseline: phase-2-terrain-bridge until those changes are integrated.
- Existing terrain preview was reported working by the user.
- A real Windows CMBS editor handoff has not been verified.
Check this state again before each run. Follow the actual PR dependency chain if bases change.

## Queue — native simulator direction (approved 2026-10-10)

The user approved replacing the primary CMBS handoff with an integrated Godot tactical battle.
Use codex/integrated-tactical-battle, stacked on codex/campaign-save-load, until review/merging changes the active base. Recheck PRs; do not duplicate the battle lock or result implementation now included there.

1. Review and validate the native first battle on Windows, including camera/input and restarting saved engagements. Preserve existing scenario exports and optional GIS tools.
2. Improve tactical usability: camera pan/orbit, order-path previews, clear fire feedback, and readable battle reports, each with relevant checks.
3. Add more tactical depth in small steps: morale behavior, player/enemy visibility, and stronger opponent decisions. Preserve deterministic outcomes across save/load.
4. Import prepared elevation into the native renderer and simulation together; validate orientation, movement and LOS against known synthetic fixtures before adding OSM features. Keep source provenance and distinguish generated test terrain from real GIS data.
5. Add vehicles and equipment composition with a versioned simulation/save contract and bounded formation losses.

Campaign save/load, pending battle locks, and native once-only result application already exist on the stacked branches. The old manual CMBS result form is no longer the primary development priority.

## User-dependent validation
Compare real terrain output against the Windows CMBS editor with the user's installed CMAutoEditor version.
Record this as blocked on Windows editor evidence; do not let it block independent campaign persistence work.
Projected metric sectors, real map rendering, terrain movement costs, and multi-contact rules follow the validated round trip.

## Task record format
Each feature PR updates this file with: task, status, branch/PR, checks and outcomes, limitations, and next action.
Use planned, in progress, ready for review, merged, or blocked accurately.
Unmerged PR work must not be described as available on main.

## Setup verification
Repository access and active branch were confirmed.
Local baseline pytest could not run because pytest is not installed; Godot is also unavailable in the setup environment.
This setup change contains instructions only; these missing tools must be addressed or reported during feature development.

## Campaign save/load task — 2026-10-09
- Status: ready for review; not merged or available on main.
- Branch: codex/campaign-save-load; draft PR targets codex/unattended-development-setup, which contains the same phase-2 game baseline plus development instructions.
- Added explicit one-slot Save/Load, schema/scenario validation, temporary-file replacement, and restart restoration of turns, formation state, orders, selection, and battle display.
- Verification: Godot 4.5.1 headless editor import, existing campaign smoke, new save/load smoke, and 26 Python terrain tests pass. Missing setup dependencies were installed for this run.
- Limits: no autosave, result application, or battle turn lock; Windows filesystem/UI and CMBS editor handoff are not validated by these Linux headless checks.
- Next: review/integrate persistence, then implement a persistent pending-battle lock and export-retry behavior with tests. Recheck open PRs before choosing a dependent base.

## Native tactical battle task — 2026-10-10
- Status: ready for review after recorded checks; not merged or available on main.
- Branch: codex/integrated-tactical-battle, dependent on the save/load PR.
- Added a native 512 m 3D WEGO infantry battle, a one-click campaign demo, navigation/LOS, suppression/cover, a central objective, and a simple opponent.
- Contact auto-opens a battle and locks campaign movement/turns. Tactical state, paths, ammunition and timing save and restore deterministically. Results update deployed personnel losses, morale and abstract supply cost once; the losing formation retreats. Save failure rolls back result application.
- Save v2 accepts and migrates v1 campaigns. Pending legacy contacts create a native detachment; queued campaign orders on that unresolved contact are cleared for the lock.
- Local validation: Godot 4.5.1 editor import; campaign, save/load, tactical logic and actual GUI-event smoke tests; 26 Python GIS tests. Record final CI rendered check outcome in the PR.
- Limits: synthetic map; squad markers; reserve vehicles; abstract fire; full enemy visibility; scripted advance; Linux logic tests do not prove Windows graphics/input or realistic combat fidelity.
- Next: Windows user playtest, then a focused native tactical usability improvement or real elevation import as specified above.
