# Autonomous development queue

## Operating cadence
The user requested all-day unattended work on 2026-10-10. During the loop/feedback
milestone, use hourly development passes, one focused task per pass. After the
milestone check-in is prepared, restore the prior daily evening cadence around
7 PM America/Chicago. This is scheduled work, not a continuously running process.
The scheduled task uses GitHub as durable project state. It does not depend on the user's local folder.
Progress is delivered through draft PRs and scheduled run reports; review and merging remain with the user.

## Current baseline (2026-10-10)
- main: starter README only; no PRs merged at setup time.
- Existing chain: phase-1-vertical-slice -> phase-2-terrain-bridge -> codex/unattended-development-setup -> codex/campaign-save-load -> codex/integrated-tactical-battle.
- Workflow baseline: codex/loop-feedback-workflow, based on the tested native branch at 7a542b7. Follow the latest validated descendant recorded in docs/LOOP_FEEDBACK_MILESTONE.md.
- User reported the native first battle appeared to work on Windows. This is basic playtest feedback, not evidence that repeat battles, restart persistence or all inputs were tested.
- Native Linux tests and rendered/input CI passed at 7a542b7; preview reviewed. A real Windows CMBS editor handoff has not been verified.
Check this state again before each run. Follow the actual PR dependency chain if bases change.

## Queue — native simulator direction (approved 2026-10-10)

The user approved replacing the primary CMBS handoff with an integrated Godot tactical battle.
Read docs/LOOP_FEEDBACK_MILESTONE.md first. The current user-requested milestone is the repeatable loop plus visible firing and feedback. Use codex/loop-feedback-workflow and its latest validated descendant until review/merging changes the active base. Recheck PRs; do not duplicate existing battle locks or result application.

1. Prove two consecutive battles in one campaign through actual movement/contact and result application, including restart between engagements, fresh IDs, retained losses and duplicate rejection. Fix problems discovered by this check.
2. Add transient firing events tied to actual simulated attacks, render readable shot/muzzle cues, and show casualty/suppression feedback. Presentation must not change outcomes or restart determinism.
3. Add a readable completed battle report and practical command feedback; camera pan/orbit and order-path previews are supporting tasks if needed. Validate the combined milestone and prepare the requested check-in with a playable download.
4. After the milestone check-in, add more tactical depth in small steps: morale behavior, player/enemy visibility, and stronger opponent decisions. Preserve deterministic outcomes across save/load.
5. Import prepared elevation into the native renderer and simulation together; validate orientation, movement and LOS against known synthetic fixtures before adding OSM features. Keep source provenance and distinguish generated test terrain from real GIS data.
6. Add vehicles and equipment composition with a versioned simulation/save contract and bounded formation losses.

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

## Unattended loop/feedback workflow — 2026-10-10
- Status: workflow ready; milestone implementation remains planned. No gameplay features added by this workflow change.
- Branch: codex/loop-feedback-workflow, stacked on the native battle branch.
- User authorized routine work while away and requested a check-in when both the complete loop and visible firing/feedback are ready.
- Added evidence gates, a task/branch ledger, continuation rules and check-in criteria. Nightly automation follows this milestone before GIS or vehicles.
- Verification for this documentation-only task: branch/PR baseline inspected, local documentation consistency and git diff --check. No new gameplay/Windows validation claimed.
- Next: implement and test the two-battle/restart gate, then actual-shot visual feedback.
- Follow-up authorization: hourly passes while pursuing this milestone; an immediate run was requested. The user also authorized project testing on their PC if a supported desktop connection is actually available. No desktop-control connection is present in the current session; continue cloud/repository testing and do not claim local Windows tests ran.
