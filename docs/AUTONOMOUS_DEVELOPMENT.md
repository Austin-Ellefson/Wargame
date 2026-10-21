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


## Infantry posture — validated 2026-10-11

- Ready for review: codex/infantry-posture, draft PR #26, based on tested PR #25.
- Tested gameplay d0c113b6ab93eaaf5eecb995eefaf76c2fcb4932; all 19 Godot checks,
  26 terrain tests and diff check passed. Combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38164109023 succeeded.
- Inspected artifact 11711402288: actual low-posture shots at 00:06 and readable
  completed report. Initial summary overlap fixed and covered by bounds checks.
  Logic proves actual posture effects and exact real-combat disk continuation;
  two-battle campaign loop remains passing. Full evidence in milestone ledger.
- Old fields/rules and frozen ready branches preserved. No Windows/fidelity claim;
  instant posture changes, standing red planner and abstract squad bodies remain.
- Next: infantry weapon roles/fire cadence with bounded ammunition/casualties.


## Infantry rifle/support profiles — 2026-10-11

- In validation on codex/infantry-fire-profiles, explicit tested base PR #26
  codex/infantry-posture at 505b84c0e73812ff05327d0e81a36b7216e0fca4
  (combined CI 38164319208 success). No duplicate role task or newer branch found.
- V15 strict fixed rifle/support roles, distinct cadence/burst size, finite shared
  ammo, per-round exposure tuning, same-tick attacks and readable friendly role
  status/cues. Old rules and campaign/GIS/export/launcher contracts preserved.
- All 20 local Godot checks and 26 terrain tests passed. Added actual volley/ammo/
  pressure, partial/exhausted ammo, hold/hidden restrictions, simultaneous losses,
  strict role validation, UI selection and pre-volley real disk continuation.
- Initial UI type inference and malformed-role comparison errors were caught and
  corrected before successful checks. CI/render inspection pending.
- No individual weapons, reload/overheat, resupply or fidelity/Windows validation.
- Next: deterministic spotting acquisition delay; C2 delay is a separate later step.


## Rifle/support profiles — validated 2026-10-11

- Ready for review: codex/infantry-fire-profiles, draft PR #27, base tested PR #26.
- Tested code 247ca3edc861ae451130835bca3665d256af78f2: all 20 Godot checks,
  26 terrain tests and diff check passed. Combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38165101643 succeeded.
- Inspected artifact 11711941046: actual SUPPORT -18R shots at 00:04 and readable
  bounded completed report. Initial type/save errors and ambiguous role labels
  fixed before this successful candidate. Full restart/two-battle tests pass.
- Frozen builds/contracts preserved; no Windows or realistic-fidelity validation.
  Abstract fixed roles, no individual weapons/reloads/overheating/resupply.
- Next: deterministic spotting acquisition delay, with C2 limits separate later.


## Local spotting acquisition — 2026-10-11

- In validation: codex/spotting-acquisition, base tested PR #27 head
  e5190c169ff78ee7b2cd78b172245c1270824690 (CI 38165341512 success).
  No overlapping task/newer branch or merges found.
- V16 strict per-observer three-second continuous local sight. Queries/planning
  never advance; sight loss resets, shared contacts do not bypass local firing.
  Partial disk restart/full outcomes and old V15 rules covered. Prior feature
  fixtures explicitly retain V15 to isolate their original contracts; campaign
  loop, acquisition and UI run fresh V16. Initial contact-memory fixture timed
  out on an immediate-contact assumption; corrected compatibility fixture. UI
  target/reaction assumptions corrected to use actually executed acquisition.
- Full suite/CI/render evidence pending. Frozen ready downloads preserved.
- No Windows/fidelity claim, variable signatures, C2 delays or search arcs.
- Next: command/communication limits as a separate focused increment.

- All 21 local Godot checks, 26 terrain tests and diff check now pass on the candidate. Initial capture variable-scope error fixed. Combined CI/render review pending.


## codex/spotting-acquisition — validated 2026-10-11

- Ready for review, draft PR #28, explicit tested base codex/infantry-fire-profiles
  PR #27 at e5190c169ff78ee7b2cd78b172245c1270824690 (CI 38165341512 success).
- Tested code 0d913e23ba90df68e54740e6b1daf81ea9107c5a; all 21 local Godot
  checks, 26 terrain tests and diff check pass. Combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38167460477 succeeded.
- Inspected artifact 11711894221: actual execution hides enemies at 00:02, then
  identifies contacts and displays a real RIFLE -9R shot at 00:03. Completed
  report at 02:18 remains readable, with both forces and bounded once-only
  campaign consequences. Capture fixture isolates delay with stationary squads
  and ammunition disabled except the actual third-second volley; the later
  execution/report fixture uses actual combat. Full game fidelity is not inferred.
- V16 persists strict per-observer three-second continuous sight progress. New
  regression proves actual delayed fire, query purity, LOS/range reset, shared
  observer isolation, hidden motion/death memory, visible death confirmation,
  malformed timers and exact partial campaign disk continuation/full outcomes.
  Two campaign contacts/fresh IDs/history/losses/retreat/unlock/stale/duplicate
  checks also pass. Earlier focused tests explicitly retain V15 to isolate their
  prior contracts; campaign, repeat-loop, acquisition and UI exercise new V16.
- Initial immediate-contact assumptions caused a contact-memory fixture timeout
  and UI target/reaction failures; compatibility fixtures and real elapsed UI
  acquisition corrected. Initial capture variable scope fixed. First successful
  CI 38167306195/artifact 11712228058 exposed capture-only live-panel omission;
  corrected fixture now calls the normal combat-feedback path before capture.
  Nonfatal VSync/anchor/input-harness warnings remain; no script errors.
- V1–V15 fields/rules, frozen downloads, campaign/result/GIS/export/Windows
  launchers preserved. No Windows or Combat Mission fidelity validation; fixed
  abstract delay, no signatures/search arcs/C2 model or unidentified corpse type.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/spotting-acquisition
  Godot 4.5.1: open project.godot/F5/fresh integrated demo for V16; old pending
  battles retain saved rules. Next: a separate command/communication-limits task.


## Movement-command response — 2026-10-11

- In validation: codex/movement-command-response, based on tested PR #28 head
  71b641941218eba46f76cb69ba53b1883d824818 (CI 38167670786 success).
  No overlapping task/newer branch or merges found.
- V17 five-second new/replaced route response on both sides; fire/spotting continue.
  Append retains timers, pause counts concurrently, hold/death clear, automatic
  withdrawal bypasses. Fixed abstraction, no radio/leader model or Windows claim.
- New regression proves actual delayed motion and firing, planning/query purity,
  route replacement/append/hold, pause/withdrawal/death and strict save validation,
  V16 isolation and full partial-response campaign disk outcomes.
- Initial UI assertion exposed HUNT PAUSED priority while responding; halt-reason
  label now takes priority without changing response. Review found same-tick
  firing deaths needed timer cleanup before save; actual shot-death regression added.
- Full candidate suite/CI/render review pending; frozen ready downloads preserved.
- Next: delayed shared contact reports with local firing restrictions preserved.


## codex/movement-command-response — validated 2026-10-11

- Ready for review, draft PR #29, explicit tested base codex/spotting-acquisition
  PR #28 at 71b641941218eba46f76cb69ba53b1883d824818 (CI 38167670786 success).
- Tested gameplay 7ccaaa8d40c0e51d5ee94f35647bdda8e70715f3. All 22 local
  Godot checks, 26 terrain tests and diff check passed. Combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38168246861 succeeded.
- Inspected artifact 11712579466: actual execution at 00:03 shows MOVE IN 2s
  together with RIFLE -9R and actual shot cue. Completed report at 06:00 shows
  both forces, bounded personnel losses, objective control and withdrawal.
  Delay capture uses a close-contact/no-ammo checkpoint except the actual rifle
  volley; subsequent combat/report is fully simulated. Nonfatal renderer/anchor/
  input-harness warnings remain; no script errors.
- V17 strict response map, replacement/new routes wait five executed seconds on
  both sides. Append retains, pause counts concurrently, hold/death clear and
  automatic withdrawal bypasses. Fire/local acquisition continue; no extra RNG.
- Tests prove actual delayed movement/fire, query/planning purity, failed commands,
  replacement/append/hold, concurrent pause, withdrawal/death cleanup, malformed
  save maps, V16 compatibility and full actual partial-response disk outcomes.
  Actual firing death clears response before checkpoint validation. HUNT halt
  label priority corrected after initial UI assertion failure. The two-contact
  campaign loop, history/losses/restart/retreat/unlock/stale/duplicate checks pass.
- Older focused fixtures preserve old versions explicitly; fresh campaign, UI,
  repeat-loop and response tests exercise V17. Frozen builds, V1–V16 rules/fields,
  campaign/result/export/GIS/Windows launchers preserved. Publishing briefly hit
  an exec transport disconnect; retry succeeded without duplicate remote writes.
- Limits: fixed movement-response abstraction only, immediate HOLD/fire/posture,
  no leader/radio/delayed shared-contact model. No Windows or fidelity validation.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/movement-command-response
  Open project.godot in Godot 4.5.1/F5/fresh integrated demo for V17. Existing
  pending battles retain their rules. Next: delayed shared-contact reports with
  local firing restrictions and exact disk restart preserved.


## Delayed shared-contact reports — 2026-10-11

- In validation: codex/delayed-contact-reports, explicit tested PR #29 base
  b7dfb3f9a616059deb0919a76689ce840d0d12ce (CI 38168470311 success).
  No overlapping task/newer branch or merges found.
- V18 immutable five-second reports and delayed observed-death confirmations;
  selected-squad live sight/cue permissions, amber timestamped markers. Shared
  reports never grant local firing. Strict maps, disk restart and old rules covered.
- Initial inferred-type parse error and immediate-memory UI fixture assumptions
  corrected. Latest observed memory queues after an earlier packet rather than
  dropping sightings made while the packet was in flight. New UI uses real
  selection/delivery, reports captured old position instead of hidden live actor.
- Full final suite/CI/render evidence pending. Frozen downloads/contracts preserved.
- Limits: fixed transport, no leaders/radios/failed channels, per-observer memory
  UI or Windows/fidelity validation. Red acts only on local sight.
- Next: observer-level contact memory, with clear local/shared timestamps.

## codex/delayed-contact-reports — validated 2026-10-11

- Ready for review: draft PR #30, explicit tested base codex/movement-command-response
  PR #29 at b7dfb3f9a616059deb0919a76689ce840d0d12ce. No merges or force pushes.
- Tested code commit: 755017c39f8ee429f80f5809fd808d9d3d2a0cac.
- Combined successful CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38169442252
  (verify.yml, artifact tactical-validation 11713641616).
- All 23 local Godot checks passed with Godot 4.5.1; all 26 terrain tests passed;
  git diff --check passed. CI includes the same combined suite and actual render checks.
- V18 saves immutable five-executed-second contact/death packets, delivered captured
  positions/timestamps, strict validation and exact disk continuation. Selecting a
  squad restricts live enemy actors and shot cues to its own real observations.
  Shared markers neither track hidden movement/death nor grant fire permission.
- Regression proves delivery timing, packet ordering, hidden movement/death, observed
  death confirmation, rejected malformed records, living reported target rejection
  during actual planning, in-flight disk restart and exact full battle continuation.
  A full V17/V18 comparison proves report transport leaves other authoritative state,
  RNG and battle results unchanged. Repeat-loop/rollback/once-only checks remain passing.
- Inspected actual CI renders: shared-report-preview.png at execution 00:08 shows
  S2 local 0, four REPORT 5s markers and the captured x240 position after real target
  movement to x270; no live enemy actor or unwitnessed firing cue. At 00:03,
  acquisition-shot-preview.png shows S1 local 4, a real rifle volley/shot cue and
  MOVE IN 2s. battle-report-preview.png at 06:00 reads blue 36/6/30 and red 36/5/31
  deployed/surviving/lost, objective 89/159s, bounded campaign costs and withdrawal.
- Corrected initial inferred-bool parse and immediate shared-marker/HUD assumptions.
  Refined target rejection to test a living reported enemy in planning, rather than
  a vacuous dead-target or execution-phase rejection. Corrected checks all passed.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/delayed-contact-reports
  Import project.godot in Godot 4.5.1, F5, fresh PLAY INTEGRATED DEMO for v18.
  Existing pending battles keep older rules; campaign v2 and result v1 unchanged.
- Limits: abstract fixed transport, no leaders/radio range/failure/cancellation,
  no observer-specific remembered marker yet; Linux checks do not prove Windows
  compatibility or realistic combat fidelity. Frozen milestone downloads preserved.
- Next focused task: observer-level contact memory with separate local/shared timestamps.

## Individual soldier visuals — in validation 2026-10-11

- Branch codex/individual-soldier-visuals; tested base delayed-contact-reports PR #30
  at 4323c302476987a97b8c21f77ae88981bf5d8d1a (CI 38169698216 success).
- User asked when soldier models would happen, then approved continuing the proposed
  visual priority. Scope is procedural individual figures/static postures, known
  casualties and close inspection camera; animation is the following focused task.
- New regression checks real firing/casualties, nominal live enemy figure counts,
  exact complete authoritative-state/results equality against an unrendered twin,
  posture geometry, camera isolation/reset. No save/simulation contract changed.
- Initial local suite: new regression and all logic passed; UI camera-reset comparison
  exposed inconsistent initial/focused terrain height. Initial camera now uses the
  same placement helper as reset. Final suite/CI and actual renders pending.
- Preserve frozen downloads. No Windows/per-soldier AI/animation/fidelity claim.

## codex/individual-soldier-visuals — validated 2026-10-11

- Ready for review: draft PR #31, based on tested delayed-contact-reports PR #30
  at 4323c302476987a97b8c21f77ae88981bf5d8d1a. No merges/force pushes.
- Tested presentation code: 9dc78617d3de5731f95ac6ba425aac9d17e1b040.
- Combined successful CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38170496126
  (verify.yml; artifact tactical-validation 11713177798). Initial successful render
  CI 38170304071 followed by uniform/equipment refinement and corrected shot HUD.
- All 24 local Godot checks and 26 terrain tests passed; diff check passed. Added
  actual INSPECT SQUAD/RESET GUI input regression passed separately before final head.
- Replaced three oversized capsules with one low-poly procedural display rig per
  initially deployed person (up to nine). Olive/tan uniforms, side-color insignia,
  helmets, rifles/support silhouette, packs/vests/boots, torso/arm/leg postures.
  Actual blue losses become grey fallen slots without rifles, including zero
  survivors. Acquired live enemies retain nominal initial figure counts, hiding
  exact losses; unacquired actors/cues remain hidden. No downloaded art dependency.
- Inspected stand/crouch/prone captures, actual 00:03 prone shot with RIFLE -9R,
  ammo351/SUP17 and 00:09 actual two-person losses (7P,333R,SUP30), with two grey
  fallen figures and a real volley cue. Completed report remains readable at
  06:00: blue36/6/30, red36/5/31, objective89/159s and once-only campaign consequences.
- New regression executes full real combat against an unrendered twin and checks
  exact authoritative state/results every tick, actual losses/shot, hidden enemy
  counts, pose geometry and camera isolation/reset. Existing two-battle campaign,
  restart, battle locks, bounded once-only losses and save rollback remain passing.
- Initial camera reset discrepancy fixed by consistent initial/reset placement and
  restored distance. Nonfatal anchor/driver/test-input warnings remain; no script
  errors in successful checks. Tactical v18/campaign v2/result v1 unchanged.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/individual-soldier-visuals
  Godot4.5.1: import project.godot/F5, integrated demo, select squad and INSPECT SQUAD.
  STAND/CROUCH/PRONE change poses in planning; RESET CAMERA restores overview.
- Limits: simple static procedural figures, fixed display offsets that can overlap
  obstacles, no independent soldier AI/collision/identity/aim/inventory or animation.
  Loss slots derive from counts rather than individual injury events. Not Windows
  or realistic-fidelity validation. Frozen ready milestone download preserved.
- Next focused task: movement and firing animations tied to actual executed
  motion/shot events, outside saved state/RNG. Observer contact memory remains queued.

## Soldier motion/fire animation — in validation 2026-10-11

- codex/soldier-motion-fire-animation, explicit tested individual-soldier-visuals
  PR #31 base ba78cd1c922d36576d29ad85c38b68f88bdefe60 (CI 38170726386 success).
- Walking/crouched stride/prone crawl derive from actual observed displacement,
  not queued routes. Visible shot snapshots orient rigs and trigger 0.42-second
  wall-time recoil/muzzle flashes at 1/4/8x; selection/visibility clears witnesses.
- No simulation/save changes or simulation RNG. Transient poses reset on reopen.
  Hidden motion history discarded; live enemy nominal counts preserved.
- Initial exact-east assertion corrected to actual terrain/grid path direction;
  fixed newly acquired enemy shot initialization that could clear its real cue.
  Full twin-outcome test now advances animation at all playback speeds.
- New real-motion/wait/pinned/shot/selection regression; combined final tests/CI
  and actual paired stride/recoil/report render inspection pending.
- Next: observer-level contact memory; retain ready figures branch and milestone.

## codex/soldier-motion-fire-animation — validated 2026-10-11

- Ready for review: draft PR #32; explicit tested base individual-soldier-visuals
  PR #31 at ba78cd1c922d36576d29ad85c38b68f88bdefe60. No merges/force pushes.
- Tested animation code: 1933013080685e84d539f9461dbe9ff3e9a2f267.
- Combined successful CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38172678327
  (verify.yml; tactical-validation artifact 11714971044). Prior code runs
  38172340607/38172473351 succeeded before casualty/slow-frame refinements.
- All 25 local Godot checks, 26 terrain tests and diff check passed together.
  CI includes actual original UI, soldier and animation render checks.
- Actual observed displacement drives walk/crouched stride/prone crawl and travel
  facing. Real witnessed shot snapshots orient figures and trigger decorative
  per-rifle flash/recoil for 0.42 wall seconds. 4/8/1x playback cycles through actual
  GUI input; planning clicks never advance simulation. No queued-route idle gait.
- Inspected actual 00:06 paired walking/crouched/crawling frames. Pixel differences
  localized to figure regions: standing3124, crouched2311, prone1843 changed pixels
  between phases (same authoritative state). Actual recoil captures at 1x/4x/8x
  show correct playback label, rifle -9R, ammo342/333/324 respectively, shot direction
  and individual muzzle cues at execution00:06/00:09/00:12. Finished06:00 report
  remains readable: blue36/6/30, red36/5/31, objectives89/159s, campaign consequences.
- Tests prove actual command-response idle, executed movement, pinned stop with
  retained route/rest geometry, known casualty rig stillness, real shot lifetime,
  hidden firing/selected witness clearance, no replay on reselection, newly acquired
  enemy volley and discarded hidden motion history. A slow actual 4x frame executes
  four ticks and preserves fresh flashes plus exact outcome against a twin.
- Full real-combat regression advances animation at all speeds while comparing
  authoritative state every tick and completed results to an unanimated twin.
  Existing two-battle disk restart, locks, bounded once-only loss/result and failed
  save rollback regressions remain passing. Saved contracts remain v18/v2/v1;
  animation caches/phase/witnesses are transient and reset on reopening.
- Fixed initial exact-east path assertion, new enemy cue initialization, casualty
  rig turning and fresh cue expiry on slow frames. Capture speed labels now follow
  actual speed-button binding; latest volley feedback included. No script errors
  in successful checks; existing nonfatal driver/anchor/input warnings remain.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/soldier-motion-fire-animation
  Godot4.5.1: import project.godot/F5/integrated demo; INSPECT SQUAD, planning
  STAND/CROUCH/PRONE + right-click QUICK/MOVE, then execute. Watch wait before
  motion; use playback1x and acquire contact for recoil. RESET CAMERA restores overview.
- Limits: simple procedural animation, no individual AI/pathfinding/collision/aim
  inventory/reloads or smooth center interpolation. Fixed display/loss slots may
  overlap obstacles and follow squad centers; they are not individual corpses or
  authoritative shooters. Nominal enemy figures preserve hidden survivor counts.
  Not Windows/performance/realistic-fidelity validation. Frozen milestone preserved.
- Next focused task: observer-level contact memory with distinct local/shared times.


## Observer contact memory — in validation 2026-10-11

- Branch `codex/observer-contact-memory`, explicit tested PR #32 base
  a5bfcc33c57e46e571ad9c6ed2f6559fd5add062; final baseline CI38172926001 success.
- Tactical v19 adds bilateral per-observer sight memory and observed elimination
  tombstones. Selected marker chooses freshest local/report observation and labels
  source/age. Hidden movement/death never updates knowledge; no new fire permission.
- Focused regression covers separate observers, report recency/ties, query-copy
  purity, real lethal shots, strict saves, complete v18 authoritative comparison
  and exact every-tick actual campaign disk continuation. GUI input compares local
  and report markers. Old fixtures explicitly erase the new v19 field.
- Initial UI report-only fixture accidentally had prior local sight; corrected by
  placing that observer out of sight before acquisition. Combined final checks,
  draft PR/CI and rendered artifact evidence pending; do not promote yet.
- Limits: squad-level deterministic knowledge, no uncertain area/error/radio network
  or individual perception; no Windows/fidelity claim. Frozen downloads preserved.
- Next focused task: explicit squad facing and bounded fire arcs with versioned
  orders, local-visibility-only targeting and exact disk continuation.


## Observer contact memory — validated 2026-10-11

- Ready for review: draft PR #33, `codex/observer-contact-memory`, explicit tested
  PR #32 base a5bfcc33c57e46e571ad9c6ed2f6559fd5add062. No merges or force pushes.
- Tested code commit: 9755dd7376832a546d352a22f7cfde182635fcd7.
- Combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38173613294
  succeeded; verify.yml tactical-validation artifact 11714428819 inspected.
- All 26 local Godot checks, 26 terrain tests and diff check passed together.
  CI also passed original UI, soldier and animation render checks on that code.
- Tactical v19 persists bilateral observer sightings and elimination tombstones.
  Pure query chooses the newest delivered report or local observation (local wins
  ties), copies data and grants no local acquisition/fire permission. Hidden
  movement/death leaves knowledge untouched. Witnessed elimination suppresses
  older in-flight reports; nonwitnesses wait for ordered delayed confirmation.
- Inspected actual execution00:09 `? LOCAL 1s` at captured x270 for selected S1,
  versus execution00:08 `? REPORT 5s` at original x240 for remote S2. Current live
  actors remain hidden when not locally acquired; selected Memory count is readable.
  Captured execution00:03 actual rifle -9R acquisition shot and execution00:06
  1x soldier muzzle/recoil/ammo342. Completed06:00 report remains readable:
  blue36/6/30, red36/5/31, objective89/159s and campaign consequences.
- Regression proves bilateral/separate observers, newer report/tie preference,
  copy/query purity, hidden-death isolation, local elimination through actual lethal
  simulated fire, older-report suppression, 13 malformed save cases and unchanged
  complete v18 authoritative combat state/results excluding only new knowledge.
  Actual campaign disk restart compares every resumed tick/state/event and result.
  Existing two-battle/restart/lock/once-only loss/result/rollback regressions pass.
- Fixed initial report-only GUI fixture to place observer out of sight before its
  acquisition and updated HUD assertion for Memory count. Successful checks have
  no script errors; existing nonfatal driver/anchor/test-input warnings remain.
- V1–V18 keep original fields/rules; no silent migration. Campaign v2/result v1,
  export/GIS and optional Windows launchers unchanged. Animation stays transient
  outside saved state/RNG; frozen ready milestone/figure/animation downloads preserved.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/observer-contact-memory
  Godot4.5.1: import project.godot/F5/integrated demo; acquire and lose contact,
  switch squads to compare LOCAL/REPORT source/age and use checkpoint Save/Load.
- Limits: synthetic squad-level knowledge, no uncertainty radius, report error,
  radio network or individual perception; no Windows/Combat Mission fidelity claim.
- Next focused task: explicit squad facing and bounded fire arcs; version orders,
  require local visibility for targets, preserve restart and existing animations.


## Squad facing and fire arcs — in validation 2026-10-11

- Branch `codex/squad-facing-fire-arcs`, tested PR #33 base
  83c9f30361156466fa20cb7288bff2f34959c719; final baseline CI38173815596 success.
- Versioned v20 heading/width orders, planning FACE + ground click, ARC0/90/180
  and cyan selected-friendly maximum-range outline. Local acquisition/LOS/range
  still required; outside-arc enemies remain visible but cannot receive fire.
- Real shot/edge/wrap/hidden-target/route-origin/withdrawal/strict-save regressions,
  full default v19 outcome parity, actual bounded-arc every-tick disk continuation
  and mouse-input/figure-facing/cancellation/presentation-purity tests added.
- Fixed initial GDScript inference annotations before testing; focus feedback now
  distinguishes acquired outside-arc targets without leaking hidden bearings.
  Shortened v20 phase header to leave readable room for FACE/ARC controls.
  First rendered CI38174507882 passed; inspected artifact11715017733. Close
  inspection exposed thick cyan preview over figures; adaptive width fix and
  actual INSPECT/RESET purity regression added, pending final rerender.
- Final combined Godot/terrain checks, draft PR, rendered CI and artifact review
  pending. Do not promote before checks finish. V1–V19 fields/rules retained.
- Limits: direction-only fire restriction, no traverse delay/self-defense exception
  or individual perception; no Windows/fidelity claim. Frozen downloads preserved.
- Next focused task: ammunition-consuming area suppression orders at ground points,
  without converting remembered contacts to live knowledge or targeted entity fire.

- Publication checkpoint: final local 27 Godot checks, 26 terrain tests and diff
  check passed with adaptive preview before the execution environment disconnected.
  Same tested edits published directly through GitHub with expected-head lease;
  final CI/rerender pending. Do not claim final refined-artifact visual inspection
  until a working inspection environment is available.


## Squad facing and fire arcs — validated 2026-10-11

- Ready for review: draft PR #34, codex/squad-facing-fire-arcs, explicit tested
  PR #33 base 83c9f30361156466fa20cb7288bff2f34959c719. No merges/force pushes.
- Gameplay commit ef5a2e4ade47f628ae5520e0b112445d79380b70; adaptive preview
  53daaaba6447a0a6a2837da588f64ba147130195. Tested code/evidence head:
  83f6790b128e43412eedcc591cff4972d7d89214.
- All 27 local Godot checks, 26 terrain tests and diff check passed with the
  adaptive preview before local execution disconnected (environment_offline).
- Combined initial CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38174507882
  passed; tactical-validation artifact11715017733 inspected locally: FACE90/ARC90
  planning wedge, actual execution00:03 rifle -9R into the east sector while an
  outside-arc southern contact remained visible, close actual00:06 1x muzzle/recoil
  with342 rounds and readable completed06:00 report blue36/6/30, red36/5/31,
  objectives89/159s and campaign consequences. Initial thick inspection line fixed.
- Adaptive build CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38175174701
  passed. Final combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38175330630
  passed all logic/terrain and four rendered scripts; artifact11715353232 generated.
  Actual close inspection PNG retrieved and visually inspected through decoded CI
  job114576405525 logs: thin cyan cone leaves nine east-facing figures readable.
  The workflow now exposes this actual screenshot alongside regular artifacts,
  allowing inspection when a local execution/download environment is unavailable.
- Local publication stalled after environment disconnect. Same locally tested
  edits recovered from known branch content and published via GitHub APIs with
  exact expected-head leases; actual remote head rechecked. No Windows/PC tests.
- Tactical v20 stores whole-degree heading0–359 and width0/90/180 per known squad.
  FACE + left ground click changes only facing; right-click cancels without move.
  Arc follows executed position with fixed world bearing. Both automatic/preferred
  shots require local acquisition/LOS/range AND arc, including return fire. Visible
  outside-arc enemies stay visible; generic hidden-target feedback never leaks bearing.
- Regression proves actual nearest/preferred restricted shots, inclusive edges/north
  wrap, frozen/dead/enemy/invalid commands, moving-origin bounds, morale break cleanup,
  11 malformed save cases, complete default v19 authoritative field/result parity,
  every-tick bounded-arc campaign disk restart, mouse commands/cancellation/inspection,
  preview purity and stationary/casualty geometry. Existing loop/locks/once-only
  losses/results/save rollback, contact memory and real-shot animations remain passing.
- Stationary living figures obey facing after shot expiry; moving figures follow
  actual travel and casualty rigs do not turn. Preview adapts overview/inspection
  thickness. V1–V19 keep original fields/rules; campaign v2/result v1, export/GIS
  and optional Windows launchers unchanged. Frozen milestone/older downloads preserved.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/squad-facing-fire-arcs
  Godot4.5.1/project.godot/F5/fresh integrated demo. Select squad, FACE + ground,
  ARC90/180, execute; clear arc for unrestricted local fire. Old saves retain rules.
- Limits: synthetic squad-level direction restriction; no traverse delay, automatic
  self-defense exception, per-soldier sectors or spotting cone. Linux/render checks
  do not establish Windows or Combat Mission fidelity. Local runtime remains offline;
  future work must reacquire/fetch the remote branch before changing files.
- Next focused task: ammunition-consuming area suppression at explicit ground points,
  without turning remembered reports into live knowledge or entity-target permissions.


## Ground area suppression — in validation 2026-10-11

- Branch codex/ground-area-suppression, tested PR #34 base
  e285903d94a3a8b58635959f0ea5e33a84e2c2f5; final CI38175577819 success.
- Reacquired working runtime and fresh isolated worktree; preserved unsynchronized
  old worktree. Restored Godot4.5.1, pytest and terrain dependencies after reset.
- v21 ground-point orders, real cadence/ammo, deterministic16m pressure-only effect,
  safe actual cues and orange order preview. HOLD/arc/clear/posture/memory behavior
  remains isolated. No hidden hit IDs or casual damage; area does not grant sight.
- New regression covers real concealed pinning/expenditure, falloff/boundary,
  actual old observation followed by a legal concealment/posture command, direct
  target rejection, hidden enemy cues, mode replacement, query/render purity,
  strict saves, complete v20 parity and every-tick actual campaign disk restart.
- Initial endpoint array assertion fixed for int/float representation (event was
  correct). Combined final checks, draft PR and actual rendered CI review pending.
- Limits: synthetic squad pressure; no casualty/friendly effects/ballistics or
  Windows/fidelity validation. No changes to campaign/result/export/GIS/launchers.
- Next: improve opponent reactions to received suppression using local knowledge,
  or a focused area-fire usability fix discovered in actual review.


## Ground area suppression — validated 2026-10-11

- Ready for review: draft PR #35, codex/ground-area-suppression, explicit tested
  PR #34 base e285903d94a3a8b58635959f0ea5e33a84e2c2f5. No merges/force pushes.
- Tested code 9445b35c8db8eeb826e9d81dacfea38b15b8e8fd; combined successful CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38186131756
  tactical-validation artifact11719174547 inspected. All28 local Godot checks,
  26 terrain tests and diff check passed; CI adds five actual rendered scripts.
- Fresh isolated worktree from actual remote; old unsynchronized worktree preserved.
  Restored Godot4.5.1/pytest/terrain dependencies after runtime reset; tests ran.
- v21 AREA FIRE + ground click stores a copied fixed point, spends real rounds at
  existing rifle/support cadence and applies deterministic opposing suppression
  within16m with linear falloff. No casualty RNG/friendly effect or hidden-hit IDs.
  HOLD pauses without losing point; ARC/LOS/range withhold shots without fallback;
  CLEAR FIRE or accepted preferred target removes it; morale withdrawal cancels it.
- Inspected planning00:00 AREA FIRE marker at woods, blue360R/local0; actual00:03
  real rifle -9R shot to selected ground, ammo351, local0/Memory0 and no hidden
  actor/pressure feedback. Controls frozen, Area: active and CLEAR FIRE readable.
  Existing1x actual recoil00:06/ammo342 and completed06:00 report also inspected:
  blue36/6/30, red36/5/31, objectives89/159s and once-only campaign consequences.
- Regression proves actual support volleys pin concealed opposition (198R after18s,
  no casualties/contact), endpoint/falloff/exact16m edge, real last sight lost after
  a legal posture command and stale memory preserved while direct targeting rejects,
  hidden enemy area cues, hold/arc/mode replacement, query copies, 10 malformed
  save cases, complete no-area v20 authoritative field/result equality, every-tick
  actual campaign disk restart and real mouse/cue/preview purity against a twin.
  Existing loop/locks/bounded once-only loss/results/save rollback remain passing.
- Initial endpoint assertion compared int/float arrays strictly; fixed test using
  normalized data. Event was correct. Successful checks have no script errors;
  existing nonfatal driver/anchor/test-input warnings remain.
- V1–V20 keep fields/rules; campaign v2/result v1/export/GIS/Windows launchers
  unchanged. Simulation pressure is authoritative; cues/preview are transient and
  consume no RNG. Frozen ready milestone and earlier downloads preserved.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/ground-area-suppression
  Godot4.5.1/project.godot/F5/fresh integrated demo. AREA FIRE + reachable ground,
  execute; HOLD FIRE pauses, AUTO resumes, CLEAR FIRE cancels. Respect saved arcs.
- Limits: synthetic squad suppression, no area casualties/friendly effects, blast,
  dispersion/ballistics/individual aim or Windows/Combat Mission fidelity proof.
- Next focused task: opponent response to received suppression (duck/seek nearby
  cover) using own pressure/local terrain rather than hidden attacker coordinates.


## Opponent duck response — in validation 2026-10-11 (America/Chicago)

- Branch codex/opponent-duck-under-fire, tested PR #35 base
  2a13dc407a268480718a0a8af20cab6bde8233af; final CI38186379868 success.
- v22 red-only crouch/prone/recover from own suppression after tick recovery and
  morale, before movement/acquisition. Existing posture supplies hysteresis; no
  extra saved fields/RNG/contact lookup. Blue/dead/withdrawal priority preserved.
- Focused tests pass real support fire from a concealed source, both postures,
  quiet recovery, threshold/hysteresis/priority, old v21 rules/quiet full outcomes,
  every-tick actual disk continuation and render-vs-twin purity. Area fixture is
  explicitly pinned to v21 to keep previous version's regression meaningful.
- Initial55% float edge test exposed binary subtraction drift; fixed by derived
  millionth-precision comparisons, without rewriting suppression or old rules.
- Combined final checks, draft PR/CI and actual acquired crouch/prone shot captures
  pending; do not promote yet. Windows/fidelity unverified; frozen build preserved.
- Next focused task: nearby-cover response to sustained pressure, based on own
  suppression/local terrain without hidden attacker coordinates; keep scope small.

- Initial CI38189250156 passed; artifact11720761195 inspected: actual crouch00:08,
  prone00:12 and completed report. Found oversized close-zoom AREA FIRE label;
  added adaptive scale/height and pure rendered regression, pending final rerender.


## Opponent duck response — validated 2026-10-11 (America/Chicago)

- Ready for review: draft PR #36, codex/opponent-duck-under-fire; explicit tested
  PR #35 base2a13dc407a268480718a0a8af20cab6bde8233af. Main remains starter
  README; no merges/force pushes. Frozen milestone and earlier builds preserved.
- Gameplay fcf523383b9e526d22976b3d40bdd73efeef88f5; tested refinement
  2e98be3b1765ddc5d6d81184d6cfd18d405c12a4. All29 local Godot checks, 26 terrain tests and
  diff check passed. Missing Godot/pytest/GIS dependencies were restored and run.
- Initial CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38189250156
  passed; artifact11720761195 inspected. Final combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38189516298 passed
  logic/terrain plus six rendered scripts; artifact11721271483 inspected.
- Actual acquired nine-figure enemy crouch00:08 and prone00:12 accompany real
  support -18R shot cues, blue288/252 rounds. No exact enemy live suppression/loss
  labels are disclosed. Fixed an oversized close AREA FIRE label discovered in
  initial capture; final adaptive scale/height separates it from ENEMY CONTACT.
- Completed06:00 report remains readable: UKR wins, blue36/6/30 and red36/12/24,
  objective80/15s, bounded losses/supply/morale and red retreat/unlock consequences.
  V22's existing posture tradeoffs intentionally change combat/objective outcomes;
  prototype balance/fidelity remains unvalidated, not inferred from these figures.
- V22 uses own recovered suppression: red standing crouches at30%, prone at55%;
  retains lower posture until below15%, then stands. No attacker/contact lookup,
  route replacement, extra state field or RNG. Blue/manual posture, dead units
  and standing morale withdrawal retain priority. Existing movement/exposure/sight
  tradeoffs apply. Comparisons use derived millionths for stable decimal thresholds.
- New regression proves actual support fire from concealed woods triggers both
  postures/recovery while the source stays unidentified; threshold/hysteresis,
  query/planning purity, priorities, v21 compatibility/complete quiet parity,
  every-tick actual campaign disk continuation/results and render-vs-twin equality.
  Existing loop/locks/once-only losses/results/save rollback/area/fire/animation
  checks remain passing. Previous area-fire fixture pins v21 to keep legacy tests.
- Fixed real binary55% edge after initial failure, leaving saved suppression/old
  rules untouched. Successful checks have no script errors; existing nonfatal
  driver/anchor/input-harness warnings remain. V1–V21 retain rules/fields; v22 uses
  v21 save shape. Campaign v2/result v1/export/GIS/Windows launchers unchanged.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/opponent-duck-under-fire
  Godot4.5.1/project.godot/F5/fresh integrated demo. Acquire red, suppress it via
  AREA FIRE, watch lowered posture, stop fire and allow executed time to recover.
- Limits: synthetic squad posture response, no cover-seeking/re-routing or
  individual awareness. No Windows/Combat Mission fidelity claim. Daily cadence
  and original prepared milestone remain preserved; no repeated milestone check-in.
- Next focused task: deterministic nearby-cover response to sustained pressure
  using own suppression/local terrain rather than hidden attacker coordinates.


## Nearby-cover response — validated 2026-10-12 (America/Chicago)

- Ready for review: draft PR #37, codex/opponent-nearby-cover, explicitly based
  on tested PR #36 head eefad59a297764ec9504760f44d8fdda06a4ef0e. Branches and
  open PRs rechecked before resuming; no overlapping successor or merge found.
  Main remains starter README. Frozen milestone and prior downloads preserved.
- Gameplay 10c20b3cc4bd582fdd3c1b4c88b92af3dd7f136a; playback evidence
  537349d58e0a8e7ffacbb1140427c65ec6a29396; inspected code/evidence head
  e46e61c6504616792084cc7be65e1b396c039c9b. All30 local Godot4.5.1 checks,
  26 terrain tests and diff check passed on the gameplay candidate. Focused
  real-playback refinement passed locally; the later camera-angle refinement
  used CI because the transient local Godot binary was no longer present.
- Combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38190935425
  passed; real-playback CI38191095762 also passed. Artifact11721683027 inspected:
  correct movement/arrival and report, but the first camera hid most arriving
  figures behind a tree. Adjusted only the test inspection angle toward open ground.
- Final combined code CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38265744976 passed
  30 Godot checks, all seven rendered scripts and26 terrain tests on the same
  candidate. Inspected artifact11754062886: actual00:12 support -18R shot cue,
  252 blue rounds, acquired red detour;01:01 wooded arrival with0 rounds and
  expired tracers. Decorative trees still occlude some figures; no hidden intent,
  pressure or exact live enemy losses are disclosed. Real4x playback drives
  these captures and matches an unrendered authoritative twin every tick.
- Readable actual06:00 report: UKR wins, blue36 deployed/6 survived/30 lost,
  red36/11/25, objective80/15s. Campaign morale caps57/56, supply-4/-3, red
  retreat, once-only commit and unlocked campaign turns are shown. These
  abstract v23 outcomes differ from v22; combat balance/fidelity is unvalidated.
- V23 persists a six-tick own-pressure timer, local wooded goal and remaining
  detour. Searches are bounded to32m radius/40m routed travel. Original queues
  remain intact during the detour and rejoin through terrain navigation below15%
  pressure. Pauses, command response, HUNT, pinning and standing withdrawal
  retain priority; blue orders remain manual. No attacker lookup or extra RNG.
- Regression covers concealed-source real fire, motion/arrival/recovery, partial
  timing and interruption, blocked/remote/covered/full-queue fallbacks, active
  death/break cancellation, retained multi-leg queues and gates,14 malformed
  saves, v22 legacy/quiet full-result parity and every-tick actual campaign disk
  continuation through the final outcome. Existing loop, lock, once-only loss,
  save rollback, fire/visibility/animation and terrain checks remain passing.
- First restart regression found long-decimal suppression divergence during
  moving area-fire falloff. V23 rounds recovery/attack pressure writes to
  millionths; exact disk comparisons pass. Old v1–v22 fields/rules are retained;
  legacy fixtures remove the new field, and the duck-only fixture pins v22.
  Campaign v2/result v1/export/GIS/Windows launchers are preserved. Successful
  logs have no script errors; existing nonfatal driver/anchor/input warnings remain.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/opponent-nearby-cover
  Godot4.5.1/project.godot/F5/fresh integrated demo for v23. Use AREA FIRE near
  observed red squads close to woods; heavy pressure can pin them before arrival.
  Stop firing and allow executed recovery time to resume their original route.
- Limits: synthetic squad response, no occupied-cover spacing, threat-direction
  scoring, coordinated maneuver or Windows/Combat Mission fidelity validation.
  A failed search rearms only after pressure drops below30%. Daily cadence and
  the original prepared milestone remain preserved without another announcement.
- Next focused task: deterministic separation/reservation of nearby cover goals
  among living red squads, using friendly state and terrain only. Keep this tested
  download available, version changed behavior and preserve exact disk continuation.


## Friendly cover spacing — validated 2026-10-12 (America/Chicago)

- Ready for review: draft PR #38, codex/opponent-cover-spacing, explicitly based
  on PR #37 at 70d60f2f7b7960684c7977c912c29a5b50325818. Rechecked branches,
  open PRs and expected remote head before resuming the unfinished task; no
  overlapping successor or merges found. Main still contains the starter README.
- Tested code: ee79493ca036a91125aa3a9a73af023d7348bc86. All 31 local Godot
  4.5.1 checks, 26 terrain tests and diff check passed after restoring missing
  transient dependencies. Combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38268504575 succeeded
  on the same candidate, including all eight rendered scripts.
- Inspected artifact 11755223640: actual 00:16 support tracer and -18R feedback,
  216 rounds remaining, two acquired red squads moving toward separate woods
  positions. At 00:57 they hold (324,204) and (324,220), 16 m apart; both contact
  groups are visible, with some figures occluded by a decorative tree. Blue has
  0 rounds and no expired tracers. Real 4x playback matches an unrendered twin
  every tick; no enemy intent, live pressure or exact enemy loss labels are added.
- The actual 06:00 report is readable: UKR wins, blue 36 deployed / 6 survived /
  30 lost; red 36 / 11 / 25; objective 80 / 15 seconds. Campaign morale caps
  57 / 56, supply -4 / -3, red withdrawal, once-only result and unlocked turns
  remain visible. These abstract results do not establish combat fidelity.
- V24 keeps new cover goals at least 12 m from other living friendly positions
  and active goals. Validated roster order resolves concurrent choices; saved
  goals reserve space before arrival with no separate cache or RNG. One survivor
  and withdrawing squads still occupy their current position. Enemy positions
  and reports never influence spacing. Exactly 12 m is accepted.
- Same v23 fields, with v24 goal-pair validation; v1–v23 retain their rules,
  including overlapping v23 goals. Crowded bounded searches preserve the original
  route and rearm below 30% pressure. Recovery, death and break release goals.
  Existing pauses, command response, HUNT, pinning, retreat/rally, acquisition,
  route rejoin, battle locks, bounded once-only losses and rollback are preserved.
- Regressions cover simultaneous choice and actual arrival; living/dead/enemy/
  broken occupancy; exact spacing/save boundaries; no-space queue/pause retention;
  bounded failure/rearming; released reservations; v23/quiet parity; and an actual
  campaign disk checkpoint after real support volleys, matching every subsequent
  state, event and complete result. Initial fixture-only convergence, withdrawal
  and payload-property errors were corrected before the passing suite. Successful
  artifact logs contain no script errors; existing nonfatal driver/anchor/input
  harness warnings remain. Campaign v2/result v1/export/GIS/Windows launchers and
  frozen milestone/prior downloads remain unchanged.
- Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/opponent-cover-spacing
  Godot 4.5.1: import project.godot, F5, start a fresh integrated demo for v24.
  Old pending battles keep their saved rules. Suppress acquired red squads near
  woods with AREA FIRE and allow executed time for the response; pinning can
  delay arrival. Stop firing to allow recovery and original-route continuation.
- Limits: destination spacing only, no individual collision avoidance. Paths can
  cross, and later movement can enter another squad's reserved space. No threat-
  direction scoring, coordinated maneuver or Windows/Combat Mission validation.
  The original milestone check-in and daily cadence remain preserved.
- Next focused task: a bounded retry for crowded-cover searches after friendly
  space becomes available while pressure persists. Avoid per-frame pathfinding,
  preserve occupied-goal separation/queues/gates and exact disk continuation,
  and version any changed rules or save fields. First confirm the final
  documentation-head CI recorded in the PR before creating a descendant.

## Crowded-cover retry — ready for review 2026-10-13 (America/Chicago)

- Draft PR #39, codex/crowded-cover-retry, based on tested PR #38 head
  95d7b2b434fc66329c87497c9c49bce803226948; no overlap or merges found.
- V25 saves a 12-second congestion-only retry. Fixed the discovered interval
  planning bug so the original queue/mode/wait survives a pending retry.
  No intervening pathfinding, enemy lookup or extra RNG; old saves retain rules.
- Code/evidence 40c2bbdbab98b1ed38403df404cc9a2934bef762: all 32 local Godot
  checks, 26 terrain tests and diff check pass. Combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38491663121 succeeded,
  including nine rendered scripts. Artifact 11861614334 inspected: actual 00:12
  support shot/-18R, 00:38 retried motion after friendly departure, expired cues
  and readable 06:00 report. Full test/failure/evidence record is in the ledger.
- Initial passing CI exposed oversized labels at the 80 m camera switch. The
  fixture now uses the established 65 m inspection scale and waits for 4 m of
  actual movement; the zoom defect itself is not fixed. Next: smooth world-label
  and shot-cue sizing across close/overview zoom with execution/render purity tests.
  A planning-only terrain LOS/range probe can follow; no vehicles/GIS diversion.
- Campaign/save/export/GIS/Windows contracts and frozen downloads preserved.
  No Windows/Combat Mission fidelity claim. Check PR #39's final documentation-head
  CI before creating a descendant; do not duplicate this completed retry task.

## Continuous combat zoom — ready for review 2026-10-15 (America/Chicago)

- Draft PR #40, codex/continuous-combat-zoom, based on tested PR #39 head
  ad768942bff43b172b977b8c2ea6765e78bab5d9; final base CI 38492211883 succeeded.
  No overlapping successor or merges; expected-head leases honored.
- Fixes abrupt 80 m label/shot-cue scaling with bounded distance/FOV sizing.
  Actual wheel input resizes existing geometry without resetting lifetime/recoil,
  changing endpoints/preview extents, updating hidden knowledge or consuming RNG.
  Tactical v25/campaign v2/result v1 and old saved rules are unchanged.
- Code/evidence 354432409976c937a0bec0881f33e6ecaca28ff5: all 33 local Godot
  checks, 26 terrain tests and diff check passed. Combined CI
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38831813254 succeeded,
  including ten rendered scripts. Artifact 12018070598 inspected: actual
  1x/4x/8x shots, real narrow/wide wheel zoom, hidden-contact memory and readable
  completed reports. Complete real-combat state/results match an unrendered twin.
  No failing checks; existing nonfatal driver/anchor/input warnings remain.
- Download and detailed render evidence are in the milestone ledger. Frozen
  downloads and original prepared check-in preserved. Distant/dense labels and
  tree/HUD occlusion remain; no Windows/CMBS/realistic-fidelity claim.
- Next: planning-only terrain LOS/range probe from selected friendly to explicit
  ground, using existing terrain/posture and no hidden-unit queries or state/RNG
  changes. Check PR #40 final documentation-head CI before creating a descendant.

## Planning terrain probe — ready for review 2026-10-18 (America/Chicago)

- Draft PR #41, codex/terrain-los-probe, explicit tested PR #40 base
  06c93d89d4a57d5368507710950a6abbb56103d6, final CI 38832781656 successful.
  Existing task reused; branches/open PRs and expected-head leases rechecked on
  October 18: no successor, overlap or merges; main remains starter.
- Planning-only button/cursor measures current friendly posture-to-ground terrain
  LOS and horizontal range. Explicit terrain-only text, fixed low endpoint,
  green/red status line, cancellation/selection/execution cleanup; no enemy query.
  No authority, RNG, save version, GIS/export or Windows-launcher changes.
- Focused regression passed actual input, hill/posture/building bounds, hidden
  position independence, RNG/state purity, disk reopen and full twin combat.
  Missing transient Godot/Python dependencies restored. Final code/evidence:
  1f26c2137f27d1a1b31d5b53f1132ea725635b0d. All 34 local Godot checks, 26 terrain
  tests and diff check passed. Combined CI 39084668828 succeeded (11 rendered
  scripts). Artifact 12120660690 inspected: clear/building/prone measurements,
  actual 00:03 firing and readable completed reports. Full evidence in the ledger.
  First passing CI 39084314965 exposed thin probe-line raster gaps; the final
  candidate thickens only this overlay and shows continuous status lines.
- Preserve frozen downloads. No Windows or combat-fidelity claim. Check PR #41's
  final documentation-head CI before branching; do not duplicate this task.
  Next separate task: clearly hypothetical terrain LOS from the final queued
  waypoint, with no actual movement, hidden-target lookup or changed orders.

## Hypothetical waypoint LOS — ready for review 2026-10-19 (America/Chicago)

- Branch codex/waypoint-los-preview / draft PR #42, explicit tested PR #41 base
  2c43483d177a78f50e1da9c2512c5ad42db8d630. Final base CI 39179526725 succeeded;
  branches/open PRs checked, no overlapping task or merges, main still starter.
- Planning origin toggle compares actual position with the final saved route
  point, labeled hypothetical with the current-posture assumption. Route changes
  refresh it; route removal clears geometry instead of using a stale origin.
- Focused regression passed actual HUNT/right/Shift-right/PAUSE/mode/camera/HOLD
  inputs, geometry/posture/range, hidden-information/global-RNG/state isolation,
  valid disk reopen, execution cleanup and every-tick/full-result twin equality.
  Transient Godot/Python dependencies restored; 35 local Godot checks and 26
  terrain tests passed. Code cc8d0b8f1239c06494d069e2785e7189004d6512 passed
  combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/39348395575
  (35 Godot checks, 12 rendered scripts, 26 terrain tests). Artifact 12231763435
  inspected: six waypoint planning/cleanup/real-fire/report captures, existing
  current-origin probe and 1x/4x/8x shots; all logs checked, no script errors.
  Final report shows both forces' deployed/surviving/lost personnel, objective
  control and campaign consequences. Full details are in the milestone ledger.
  Check final documentation-head CI recorded in PR #42 before dependent work;
  do not duplicate this completed task. No Windows/realistic-combat claim.
- Frozen downloads and tactical v25/campaign v2/result v1 contracts preserved.
  After validation: a small selected-squad camera-follow control during execution,
  keeping navigation optional and presentation independent of simulation/RNG.

## Selected-squad execution follow — ready for review 2026-10-20 (America/Chicago)

- Branch codex/execution-camera-follow, explicit tested PR #42 documentation head
  976361487f78d15545f5acc3095d5a942612387e; final base CI 39349051469 succeeded.
  Branches/open PRs checked: no successor or overlapping follow task, no merges;
  main remains the starter and the expected-head lease is reserved.
- Adds an execution-only FOLLOW S# control for the selected living friendly's
  actual position. Wheel zoom retains follow; pan/orbit, selection, INSPECT, RESET,
  elimination, completion and reopening stop it. No waypoint/enemy lookup.
- Draft PR #43, code 9fa3eacdf2df47cc6ddee7187f06c520c721734f.
  Focused actual-input regression passes real motion/fire, follow updates, manual
  controls, lifecycle cleanup, RNG/full-state purity, disk reopen and every-tick/
  full-result equality to an unfollowed twin. All 36 local Godot 4.5.1 checks,
  26 terrain tests and diff check pass. CI 39525325026 succeeded with 13 rendered
  scripts; artifact 12313326055 has 49 logs / 48 PASS-bearing non-editor logs and
  inspected readable actual execution and completed-report captures.
- Frozen milestone/prior downloads, locks, once-only losses, rollback, export/GIS
  and Windows launchers remain unchanged. No Windows/Combat Mission fidelity claim.
- Next: presentation-only execution playback pause/resume, freezing ticks/RNG and
  cue lifetime while retaining free camera controls and exact resumed twin parity.
