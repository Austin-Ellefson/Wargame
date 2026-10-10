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

## Queue
Complete in dependency order, splitting milestones into reviewable tasks.

1. Campaign save/load.
   - Persist turn, formation IDs, positions, strengths, and movement state.
   - Version and validate saves; reject malformed or incompatible data without overwriting the live campaign.
   - Write safely and restore exactly; test round-trip and bad-save handling.
2. Pending battle state and turn lock.
   - Persist unresolved contact and its export identifier.
   - Block further campaign resolution until the pending battle is resolved.
   - Save/load must preserve the lock; export failures must not silently lose the battle.
3. Manual battle-result entry/import.
   - Validate battle identity, participating formations, and losses against available strength.
   - Apply losses once, persist updated forces, and resolve the pending battle.
   - Reject duplicate, stale, negative, and excessive losses; test restart and duplicate handling.
4. Campaign usability and documentation.
   - Show save/load state, pending battle, export path, and actionable errors.
   - Document a complete campaign -> export -> manual CMBS -> result -> campaign walkthrough.

Keep implementation choices small and consistent with existing code.
Do not mark a milestone complete based only on written code.

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
