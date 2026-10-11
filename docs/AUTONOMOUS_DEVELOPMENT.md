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
   The user reiterated the goal of Combat Mission-like battles on 2026-10-10.
   Prioritize meaningful infantry decisions: suppression/pinning, limited enemy
   visibility, then explicit movement/fire orders and opponent reactions. Keep
   behavior documented and tested; do not imply parity with Combat Mission.
5. Import prepared elevation into the native renderer and simulation together; validate orientation, movement and LOS against known synthetic fixtures before adding OSM features. Keep source provenance and distinguish generated test terrain from real GIS data.
6. Add vehicles and equipment composition with a versioned simulation/save contract and bounded formation losses.

Campaign save/load, pending battle locks, and native once-only result application already exist on the stacked branches. The old manual CMBS result form is no longer the primary development priority.

## Suppression pinning task — 2026-10-10
- Status: ready for review; `codex/suppression-pinning`, draft PR #13, based on PR #12.
- Heavy suppression halts movement, retains orders and permits suppressed return
  fire; morale changes the threshold and recovery resumes the queued route.
- New tactical rules v2; existing v1 engagements keep their behavior on load.
- Seven Godot checks and 26 terrain tests passed; CI 38112927417 succeeded and
  execution/report captures were inspected. Full evidence is in the milestone ledger.
- Limits: abstract squad behavior, full enemy visibility, no Windows validation.
- Next: limited enemy visibility and spotting, then richer movement/fire commands.

## Current spotting task — 2026-10-11
- Status: ready for review; `codex/limited-enemy-visibility`, draft PR #14,
  based on PR #13. New tactical rules v3; existing v1/v2 saves keep their rules.
- Living squads spot current enemies using LOS/range and target concealment;
  both sides' shooters require local sight. The player view shares current
  contacts but hides unseen models/labels/cues and exact enemy live state.
- Eight Godot checks and 26 terrain tests passed on code b0d3043; CI 38143726275
  succeeded. Planning, actual-shot execution and report captures were inspected.
- Limits: no remembered contacts, spotting delay or C2 delay; no Windows check.
- Next: versioned last-known-position memory without hidden tracking, then richer
  movement/fire commands. The frozen milestone download remains preserved.

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

## Camera navigation — 2026-10-10
- Branch: codex/tactical-camera-controls, stacked on codex/order-path-preview.
- Status: ready for review; draft PR #12, gameplay commit 8f50548.
- Validation: editor and all five Godot smoke checks, 26 GIS tests and diff check
  passed. CI 38112521064 passed; rotated camera, execution and report previews
  inspected in artifact 11692042769. Windows remains unverified.
- Added bounded middle-drag pan, Shift-middle orbit and one-click reset. Actual
  GUI-event regression covers picking/orders after navigation, state isolation,
  reset and camera use during execution. No save/simulation contract changed.
- Preserve the completed-battle-report milestone download.
- Next: preserve the tested camera descendant and frozen milestone build; a
  small morale behavior with deterministic restart tests is a subsequent task.

## Last-known contacts — 2026-10-11
- Status: ready for review; draft PR #15, codex/last-known-contacts, explicitly
  based on tested PR #14. See LOOP_FEEDBACK_MILESTONE.md for code/CI/artifact evidence.
- Bilateral saved observation memory and amber timestamped markers; hidden
  movement/death do not leak through memory. New tactical v4; old rules retained.
- Nine Godot checks, 26 terrain tests and diff check pass locally. Rendered CI
  captures last-known markers, actual firing and completed reports. Windows unverified.
- Frozen milestone build preserved. Next: focused infantry movement modes.

## Infantry movement modes — 2026-10-11
- Status: ready for review; draft PR #16, code 138ca1fa.
- Branch: codex/infantry-movement-orders, based on tested PR #15.
- MOVE/QUICK/HUNT choose distinct pace; HUNT pauses on local contact/pressure
  and retains its route. Versioned v5 modes persist; older engagements keep rules.
- Ten local Godot checks and 26 terrain tests passed. UI input regression uses
  actual mode-button clicks and map commands; CI 38145385583 succeeded.
  Artifact 11704915470 inspected: queued HUNT, execution HUNT PAUSED with real
  shots/feedback and completed report readable. Full evidence is in the ledger.
- Frozen milestone preserved. No fatigue, Windows or Combat Mission fidelity claim.
- Next: explicit AUTO/HOLD FIRE infantry control with deterministic save validation.

## Five-step batch: codex/infantry-fire-control — 2026-10-11

- Ready for review; draft PR #17, base codex/infantry-movement-orders.
- Tested code: 1ad7350fc9ff0bbf67f7bcaae5893b983a99ec76.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38146581297 succeeded.
- Inspected artifact 11705446305: Readable AUTO/HOLD FIRE controls and separated order status during actual shot execution; completed report retained. First capture exposed tight spacing, corrected and rerendered.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: observed preferred-target orders.

## Five-step batch: codex/observed-target-orders — 2026-10-11

- Ready for review; draft PR #18, base codex/infantry-fire-control.
- Tested code: 34da4ce3278bbc8825da70ca5bbf1d2e693a375b.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38146863358 succeeded.
- Inspected artifact 11704408615: Execution shows Focus ready with actual preferred-target shot cues, safe generic contact labels, hidden-contact marker and readable completed report. UI Shift-click and clear-target regression passed.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: queued movement waypoints.

## Five-step batch: codex/queued-movement-waypoints — 2026-10-11

- Ready for review; draft PR #19, base codex/observed-target-orders.
- Tested code: 6e2715b1e46de4bf9b4b7d34a50f89e2c236ac32.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38147099989 succeeded.
- Inspected artifact 11704608641: Full two-leg dotted queue visible during planning; preferred-shot/HUNT feedback and completed report remain readable. Actual Shift-right input and multi-leg disk restart passed.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: timed movement pauses.

## Five-step batch: codex/timed-movement-pauses — 2026-10-11

- Ready for review; draft PR #20, base codex/queued-movement-waypoints.
- Tested code: 01377c0015b3ac983576861c03175c1c0acc1f62.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38147398240 succeeded.
- Inspected artifact 11704464132: Execution at 00:03 shows WAIT 12s (QUICK), ammunition expenditure and actual shot cues while the timer continues; HUNT feedback and completed report remain readable. Mid-wait disk checkpoint restores 18 seconds rather than restarting.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: local-contact opponent reaction.

## Five-step batch: codex/opponent-contact-reaction — 2026-10-11

- Ready for review; draft PR #21, base codex/timed-movement-pauses.
- Tested code: 72493794c5ea0ac73fbace9bfdc7fb4c9eb40de4.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38147734045 succeeded.
- Inspected artifact 11705009344: Combined fourteen Godot checks and 26 terrain tests passed. Inspected queued routes, preferred-target shot/HUNT execution, WAIT 12s with real firing, and readable completed report. UI regression proves the observed red squad stayed at its firing position; logic covers local/shared/hidden isolation, ammo/resume, blocked LOS, V8 preservation and real disk restart.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: cover-aware opponent movement using deterministic terrain and local knowledge.

## Cover-aware opponent routing — 2026-10-11

- Ready for review: codex/opponent-cover-routing, draft PR #22, explicit base codex/opponent-contact-reaction (PR #21 head 5a3605294c3ca2e257f2c9a6e4fadf2e59fd0f82).
- Tested code commit: c2050659ad46eace43a80e00c528d0047a01ef09. Tactical v10 uses V9 fields; old rules and blue routes preserved.
- All 15 local Godot checks, 26 terrain tests and diff check passed; missing transient Godot/pytest/terrain dependencies were restored before running them.
- Combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38152146018 succeeded on the same candidate.
- Inspected artifact 11706762606: cover-routing log proves real wooded traversal and disk outcome equality; actual 00:03 shot/ammunition/casualty/pinning capture and completed two-sided report are readable. Rendering verifies existing feedback, not realistic cover tactics. CI emits VSync/anchor/test-event warnings; no script errors or failed checks.
- Frozen original milestone and completed five-step download preserved. No Windows or Combat Mission fidelity validation. Fixed destinations may be open; contact can halt an advance before reaching cover.
- Next: covered opponent objective destinations without hidden enemy-position input.

## codex/covered-objective-positions — validated 2026-10-11

- Ready for review, draft PR #23, base codex/opponent-cover-routing.
- Tested gameplay: 9220f10fd0e071fa4086dcfd996ccc1315a624c3. All Godot checks, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38153202700 succeeded. Inspected artifact 11707776142: Real covered arrival/objective scoring and disk outcome equality in regression logs; actual shot/ammunition/pinning execution and readable completed report inspected. Rendering does not prove realistic cover tactics.
- Frozen milestone and prior downloads preserved; no Windows or Combat Mission fidelity claim.
- Next: persistent infantry fatigue and visible movement cost.

## codex/infantry-fatigue — validated 2026-10-11

- Ready for review, draft PR #24, base codex/covered-objective-positions.
- Tested gameplay: 11c9a990161902025d76dad064caa5ddf977b344. All Godot checks, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38153705906 succeeded. Inspected artifact 11707716785: All 17 Godot checks plus 26 terrain tests pass together. Inspected actual earned FAT28 percent after QUICK movement at 00:57 (ammunition disabled only in that render checkpoint), real 00:03 shot/casualty/pinning feedback and readable completed report. Full disk/combat outcome equality passes after integer storage fixed initial JSON drift; initial parse-scope error corrected. CI retains nonfatal VSync/anchor/test-event warnings.
- Frozen milestone and prior downloads preserved; no Windows or Combat Mission fidelity claim.
- Next: morale states and deterministic retreat/rally behavior.

## codex/morale-retreat-rally — validated 2026-10-11

- Ready for review, draft PR #25, base codex/infantry-fatigue.
- Tested gameplay: 9c260fa18d063d4e0488f6fc5a9862266f3ef99e. All Godot checks, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38154770519 succeeded. Inspected artifact 11707872681: All 18 Godot checks and 26 terrain tests pass on the combined candidate. Inspected actual shot/casualty/pinning execution, completed two-sided report with eliminated-order fix, withdrawal at 00:09 and RALLY25s at the rear at 00:54. Morale render uses seeded stress and ammunition disabled; separate actual concentrated fire regression triggers break. Actual disk restart preserves routes, a 17-second partial rally and full outcomes. First pinning regression exposed expected broken-versus-return-fire interaction; fixture now isolates high morale. Initial render exposed eliminated RALLY labels, corrected with regression before this successful CI. Nonfatal renderer/test harness warnings remain.
- Frozen milestone and prior downloads preserved; no Windows or Combat Mission fidelity claim.
- Next: standing crouched and prone infantry posture commands.


## Infantry posture — 2026-10-11

- In validation on codex/infantry-posture, explicit base tested PR #25
  codex/morale-retreat-rally at 79ccfc713a0ce4e395441c071f6144205d03fd5d
  (combined CI 38154985632 success). No newer open task/branch or merges found.
- V14 adds strict posture state and planning commands, movement/sight/exposure
  tradeoffs, low-height terrain LOS and symbolic body/shot-height feedback.
  Broken withdrawal forces standing; older versions preserve original behavior.
- Meaningful regressions include actual motion and attacks, lost/reacquired
  sight, hill occlusion, malformed saves, UI clicks and full campaign disk outcomes.
  Initial version-fixture/type errors and a routed-distance assertion corrected.
- Full suite/CI render evidence pending. Frozen ready builds preserved.
- Limits: abstract tuning, no posture transition time/enemy posture planner or
  individual soldier animation; no Windows or fidelity validation.
- Next: infantry weapon roles/cadence with bounded ammunition and casualties.
