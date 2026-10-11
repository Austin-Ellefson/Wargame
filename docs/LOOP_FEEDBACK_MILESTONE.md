# Repeatable campaign loop and visible combat feedback

Requested on 2026-10-10. Continue routine development while the user is away.
Prepare a check-in once all gates pass together on a downloadable branch.
This is a playable prototype milestone, not realistic-model validation.

The user subsequently requested all-day development and authorized project
testing on their PC if needed. Run hourly passes during this milestone, then
restore the prior daily evening cadence after preparing the milestone check-in.
Use an actual supported desktop connection only if available; permission alone
does not provide PC access. The setup session has no desktop-control connection,
so independent cloud/GitHub testing continues. Record Windows tests only when
they actually run on Windows.

## Durable ledger

- Milestone status: ready for user testing
- Workflow baseline branch: codex/loop-feedback-workflow
- Last validated gameplay branch: codex/completed-battle-report
- Last validated gameplay commit: 733b6d8feafcd2f96265cfb387dd2d0823945966
- Current task: milestone check-in prepared; preserve this downloadable branch
- Current task branch / PR: codex/completed-battle-report / PR #10
- Next task: user Windows playtest, then small independent tactical improvements
- Latest validated post-milestone descendant: codex/infantry-posture / PR #26
- Post-milestone next task: infantry weapon roles and fire cadence
- Check-in prepared for code commit: 733b6d8feafcd2f96265cfb387dd2d0823945966
- Baseline CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38087842201
- Baseline evidence: two-battle loop, save/load, GUI input, terrain render and
  actual-shot execution cues. The user said only that the first battle appeared
  to work; Windows repeat-loop and cue validation remain outstanding.

Update the ledger and gates after each run with real branches, PRs, code commits,
CI runs and artifact evidence. Do not mark a gate passed from a plan, export,
unrelated CI run or screenshot lacking the behavior under test.

## Gates for the requested check-in

| Gate | Evidence required | Status |
| --- | --- | --- |
| Repeatable campaign loop | Actual orders create contact; play and apply battle 1; loser retreats and campaign unlocks; new orders create battle 2 with a fresh ID; battle 2 completes and applies without resetting prior losses or history. | Passed at `aa96bbb` in PR #7: actual click orders created `T004_B2`; both results applied; cumulative losses/history and both retreats/unlocks verified. CI run 38076428133 succeeded. |
| Restart and safe results | Restart between battles and during execution preserves state and deterministic outcome. Duplicate/stale results are rejected after restart. Failed result save rolls back live state and retains the prior slot. | Repeat-loop restart, pending-battle restart, stale first result and duplicate results passed at `aa96bbb`. Existing tactical smoke still covers mid-execution deterministic restart and save rollback. CI run 38076428133 succeeded. |
| Visible firing | Cues derive from actual simulated firing events with shooter and target. No cues for out-of-range/blocked fire or empty ammunition. A cue means a shot, not a guaranteed hit. Rendered execution shows shots clearly at supported playback speeds. | Passed at `29dded6` in PR #8: logic covers actual/blocked/range/ammunition cases; CI run 38080482143 succeeded. Its artifact 11680700605 visibly shows two emissive orange shot lines at `EXECUTION | 00:03` and 4x playback. |
| Readable combat feedback | Squad casualty, ammunition and suppression changes are visible during execution; dead squads stop acting and cannot receive orders. Feedback is legible and does not obscure commands or imply unsupported ballistic realism. | Passed at `13a9fe5` in PR #9. Continuous compact squad/roster status and a latest-volley panel show actual tick deltas; casualties are prioritized. Dead movement/hold rejection and disabled controls are tested. CI run 38084345802 succeeded; artifact 11681289149 visibly shows actual `-1P`, rounds and suppression changes with shot cues at `EXECUTION | 00:03`. |
| Battle report and continuation | Finished report shows outcome, both sides' deployed/surviving/lost personnel, objective control and campaign consequences. APPLY & CAMPAIGN succeeds once; player can continue and resume without a stale report. | Passed at `733b6d8` in PR #10. The UI test finishes a real battle, verifies all report sections, applies once, rejects a repeat, reloads the unlocked campaign and rejects the stale result. CI run 38087842201 succeeded; artifact 11682945674 contains a reviewed readable finished report. |
| Combined build | All logic/input/GIS checks pass on the same candidate; rendered execution/report previews reviewed; one branch ZIP includes all work and docs. Windows-specific limits are stated. | Passed for code commit `733b6d8`: all six Godot checks and 26 terrain tests passed on the descendant containing every gate. CI 38087842201 passed; both 1280x720 execution and report captures were reviewed. Download: https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/completed-battle-report. Windows remains unverified. |

## Ordered work flow

1. Inspect GitHub state and the ledger; identify the latest tested descendant.
2. Select the first incomplete gate. Implement one small part with meaningful
   regression evidence, fixing discovered loop defects before extra features.
3. Run relevant checks. Rendering changes need execution-time captures or sampled
   frames showing transient cues, plus a report preview. HUD construction or
   headless success alone is insufficient.
4. Publish/update a focused draft PR and durable task status. Reuse unfinished
   work; do not duplicate PRs. A validated dependency can be the next task's base
   without merging it. Keep one clear descendant chain for the final download.
5. Investigate failures, inspect artifacts, update evidence-supported gates and
   choose the next step. Missing Windows feedback does not block Linux work.
6. Once all gates pass together, mark ready for user testing and prepare the
   requested check-in in the scheduled task result: playable ZIP, project.godot/
   F5 instructions, a short repeat-battle test, feedback description, PR/CI
   evidence and limits. Record the code commit for which the report was prepared
   (preparation is not confirmation of delivery). Avoid repeating the same
   announcement unless a material fix changes the build.

Persist enough state for a fresh session to resume. Record and report concrete
access/dependency blockers. Do not announce completion with incomplete gates.

## Run record — repeatable loop, 2026-10-10

- Branch / draft PR: `codex/repeatable-two-battle-loop` / PR #7, based on
  `codex/loop-feedback-workflow` (PR #6).
- Gameplay commit: `aa96bbb68172c6df3a491407e3382a31d5f9ad64`.
- Added `repeatable_loop_smoke.gd` to the standard runner. It completes battle 1,
  restarts from the committed slot, creates battle 2 through actual map clicks,
  restarts with that contact pending, and applies battle 2. It checks fresh IDs,
  retained/cumulative losses and ordered history, retreat/unlock after each
  result, and stale/duplicate rejection without state mutation.
- Local evidence: Godot 4.5.1 editor, campaign, save/load, tactical, repeat-loop
  and tactical-view checks passed together. Terrain bridge: 26 passed.
  `git diff --check` passed.
- CI evidence: gameplay commit run
  https://github.com/Austin-Ellefson/Wargame/actions/runs/38076428133 and the
  ledger-head run https://github.com/Austin-Ellefson/Wargame/actions/runs/38076455800
  both completed successfully.
- No gameplay defect was found. The first test assertion needed JSON-normalized
  numeric comparison because restored Godot JSON numbers are floats; this did
  not affect campaign behavior.
- Next: add deterministic transient shot events to actual attacks, then render
  execution-time cues without adding saved authoritative state or consuming RNG.

## Run record — visible firing cues, 2026-10-10

- Branch / draft PR: `codex/visible-shot-cues` / PR #8, based on
  `codex/repeatable-two-battle-loop` (PR #7).
- Gameplay commit: `29dded6867df2c869803c985644a2f38c562f124`.
- Actual eligible attacks now emit transient events containing tick, shooter,
  target, endpoints, rounds and losses. The view consumes them as short-lived
  emissive muzzle flashes and orange shot lines. Events remain outside saved
  state and use no additional random samples.
- Regression coverage proves cues for actual fire and none for blocked,
  out-of-range or empty-ammunition cases. Godot 4.5.1 editor, campaign,
  save/load, tactical, repeat-loop and tactical-view checks passed together;
  terrain bridge: 26 passed; `git diff --check` passed.
- CI evidence: https://github.com/Austin-Ellefson/Wargame/actions/runs/38080482143
  completed successfully. Artifact `tactical-validation` ID 11680700605 was
  inspected: the 1280x720 frame says `EXECUTION | 00:03 elapsed` and visibly
  shows two orange shot cues between the firing squads at 4x playback.
- The first artifact exposed that capture happened after the interval returned
  to planning. The render regression was corrected to capture during execution,
  then CI and artifact review were repeated on the recorded gameplay commit.
- Limits: Linux software rendering is not Windows validation; cues show abstract
  squad-level fire, not projectiles or confirmed hits. Readable live state changes
  and the completed battle report are still incomplete milestone gates.
- Next: make ammunition, casualties and suppression changes unmistakable during
  execution, while keeping command controls legible and outcomes unchanged.

## Run record — readable combat feedback, 2026-10-10

- Branch / draft PR: `codex/readable-combat-feedback` / PR #9, based on
  `codex/visible-shot-cues` (PR #8).
- Gameplay commit: `13a9fe5fcf0ca7d7c6019c5bc43a3a34c204da14`.
- World labels and the blue roster continuously show personnel, rounds and
  suppression. A translucent latest-volley panel compares authoritative state
  immediately before/after each tick and prioritizes casualty lines. This adds
  no save data, RNG calls or outcome changes.
- Dead squads already stopped acting in execution and rejected movement; hold
  now applies the same alive check. The UI disables dead squad and hold controls.
- Regression evidence reaches a real simulated casualty during execution and
  verifies simultaneous personnel, ammunition and suppression feedback plus
  shot cues. Godot 4.5.1 editor, campaign, save/load, tactical, repeat-loop and
  tactical-view checks passed together; terrain bridge: 26 passed;
  `git diff --check` passed.
- CI evidence: https://github.com/Austin-Ellefson/Wargame/actions/runs/38084345802
  completed successfully. Inspected artifact `tactical-validation` ID 11681289149:
  the 1280x720 frame says `EXECUTION | 00:03 elapsed`, shows orange shots, compact
  current squad values, and the panel records UKR S1 `-1P -9R SUP+18` and RU S1
  `-2P -9R SUP+71` without covering command controls.
- Limits: Linux software rendering is not Windows validation. `P`, `R` and `SUP`
  are abstract squad feedback, not individual hit/ballistic visualization.
- Next: replace the basic finished-state sentence with a readable two-sided
  battle report covering deployed, surviving and lost personnel, objective
  control and the consequences that will apply to the campaign.

## Run record — completed report and milestone candidate, 2026-10-10

- Branch / draft PR: `codex/completed-battle-report` / PR #10, based on
  `codex/readable-combat-feedback` (PR #9).
- Gameplay/check-in commit: `733b6d8feafcd2f96265cfb387dd2d0823945966`.
- Replaced the basic result sentence with a large report showing outcome, elapsed
  time, both formations' deployed/surviving/lost personnel, objective-control
  seconds, personnel losses, morale caps, abstract supply costs, withdrawal or
  elimination, autosave and campaign unlock. Existing authoritative rules and
  save schema are unchanged.
- The view regression now finishes an actual battle, checks every report section,
  applies it, verifies one history entry and an unlocked campaign, rejects an
  immediate duplicate, reloads from disk without a stale report and rejects the
  result again without mutation.
- Local evidence on the same code candidate: Godot 4.5.1 editor, campaign,
  save/load, tactical, repeat-loop and tactical-view checks passed; terrain
  bridge: 26 passed; `git diff --check` passed.
- CI evidence: https://github.com/Austin-Ellefson/Wargame/actions/runs/38087842201
  completed successfully. Artifact `tactical-validation` ID 11682945674 was
  inspected. `tactical-preview.png` still shows actual shots and readable live
  casualty/ammunition/suppression changes at `EXECUTION | 00:03`.
  `battle-report-preview.png` shows a readable `FINISHED` report with both force
  rows, objective control, campaign consequences and the exposed apply button.
- Test-ready ZIP:
  https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/completed-battle-report
- Launch: extract, import/open `project.godot` in Godot 4.5.1 and press F5.
- Short validation: choose **PLAY INTEGRATED DEMO**; order blue squads and execute
  intervals until the report, then apply. On the campaign map select the retreated
  formation, order it into the opponent's adjacent sector and resolve to create
  `T004_B2`. During battle 2, finish one interval, choose **SAVE & CAMPAIGN**,
  restart/F5, **LOAD**, reopen the tactical battle, finish and apply. Confirm the
  fresh ID, prior losses/history, visible fire/feedback and no stale report.
- Limits: Linux logic/software rendering is not a Windows input/performance test;
  combat remains abstract infantry on synthetic terrain with full enemy visibility
  and a scripted opponent. No realistic-fidelity claim is made.
- The higher-frequency milestone cadence was restored to the normal daily evening
  schedule after this check-in was prepared. Preserve this branch/commit for the
  user's download; later work must not obscure it.

## Post-milestone run record — selected order path preview, 2026-10-10

- Preserved milestone branch/commit remain `codex/completed-battle-report` and
  `733b6d8feafcd2f96265cfb387dd2d0823945966`; its ZIP and PR #10 are unchanged.
- Branch / draft PR: `codex/order-path-preview` / PR #11, based directly on the
  preserved milestone branch. Gameplay commit:
  `5b573826bf457cc630fe5216a99de8e6cbb6df47`.
- During planning, the selected living Ukrainian squad now shows bright-blue
  dots along its complete saved route, including intermediate building-avoidance
  waypoints. Execution clears the preview. Rendering only reads the existing
  order and does not modify simulation state, saves, outcomes or RNG.
- Regression coverage issues an order through actual viewport input, verifies a
  multi-dot preview without state mutation, and proves execution clears it.
  Local Godot 4.5.1 editor, campaign, save/load, tactical, repeat-loop and
  tactical-view checks passed together; terrain bridge: 26 passed;
  `git diff --check` passed.
- CI evidence: https://github.com/Austin-Ellefson/Wargame/actions/runs/38100096376
  completed successfully. Inspected artifact `tactical-validation` ID
  11687700236: `order-path-preview.png` is a readable 1280x720 planning frame
  showing the selected squad's dotted route across the terrain while all command
  controls remain unobscured.
- Limits: Linux software rendering is not Windows input/performance validation.
  The preview shows the current squad-level route, not formation spacing or
  individual soldier paths.
- Next: retain the frozen milestone build for user testing; a later independent
  usability pass may add camera pan/rotation without changing simulation state.

## Scope and priorities

Camera pan/rotation and movement paths support readable combat, but must not
displace the repeatable loop and visible fire/feedback. Separate transient visual
events from saved authoritative state: rendering, playback and animation must
not consume simulation RNG or change results. Version any save contract change.

Synthetic terrain and infantry remain the baseline. Vehicles, real GIS maps,
campaign AI and deeper behavior are later milestones. No merge,
force push, branch deletion, settings changes or external messaging. The check-in
is delivered as the scheduled task result in ChatGPT.

## Post-milestone run record — camera navigation, 2026-10-10

- Status: ready for review; draft PR #12. Gameplay commit: 8f50548e32b12291c0dd282f597e518f78f47350.
- Branch: codex/tactical-camera-controls, based on the validated
  codex/order-path-preview branch (PR #11). The frozen milestone build remains
  available from codex/completed-battle-report.
- Middle drag pans, Shift + middle drag orbits, and RESET CAMERA restores the
  overview. Pitch/focus are bounded. Controls work in planning and execution
  without changing simulation state, save data or RNG. Reopen uses the overview.
- Regression uses actual GUI mouse events to pan/orbit/reset, proves projected
  terrain picking and issuing a new order still work, and checks state isolation
  during execution. CI captures camera-preview.png for visual review.
- Evidence: Godot 4.5.1 editor and all five smoke checks passed; 26 GIS tests
  passed; git diff --check passed. CI run 38112521064 succeeded at the gameplay
  commit. Artifact 11692042769 was inspected: camera-preview.png shows the rotated
  map and route; execution shot cues and completed report remain readable.
  CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38112521064
  Latest tested descendant: codex/tactical-camera-controls / PR #12.
  Windows input/performance remain unverified.
- Next: preserve the milestone build for user testing; a later focused task may
  add a small morale behavior with deterministic save/restart regressions.

## Post-milestone run record — suppression pinning, 2026-10-10

- Status: ready for review; draft PR #13, branch `codex/suppression-pinning`,
  based on tested `codex/tactical-camera-controls` (PR #12). Gameplay commit:
  `04f51274c505c1cc1e50170c72e4c875cf859677`.
- User asked for battles as close to Combat Mission as possible. New v2 battles
  halt a living squad's movement above a morale-sensitive suppression threshold,
  retain its path, allow suppressed return fire, and resume movement after pressure
  recovers. PINNED appears in roster, world and selection labels; live feedback
  includes status transitions. Parameters are our prototype design, not recovered
  Combat Mission values or real-world validation.
- Tactical rules version is now 2 for new battles. Existing v1 saves remain v1
  through completion with original behavior; no silent rules migration occurs.
  Campaign schema v2, result/export contracts, RNG and squad fields are unchanged.
- Local evidence: seven Godot checks passed (including the new suppression
  regression), 26 terrain tests passed, `git diff --check` passed. Actual simulated
  incoming volleys pin a survivor; tests cover queued-route retention, recovery,
  morale sensitivity, return fire, JSON restart equality and v1 compatibility.
- CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38112927417 succeeded.
  Artifact `tactical-validation` ID 11692347558 inspected: execution capture at
  00:03 shows visible firing, casualty feedback and selected S2 PINNED at SUP89%;
  the completed two-sided report remains readable. The HUD capture initializes
  S2 with high pressure; the separate logic regression proves actual-fire pinning.
- Download this descendant:
  https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/suppression-pinning
  Open `project.godot` in Godot 4.5.1, F5, PLAY INTEGRATED DEMO.
  The frozen milestone branch/ZIP/check-in commit are unchanged.
- Limits: abstract squad-level pinning without panic, routing, leadership or
  individual soldier behavior; full enemy visibility remains. Linux rendering
  does not establish Windows validation or Combat Mission fidelity.
- Next focused task: limited enemy visibility/spotting with deterministic saved
  contacts and no hidden-enemy leakage through labels, shot cues or opponent logic.

## Post-milestone run record — current enemy spotting, 2026-10-11

- Status: ready for review; draft PR #14, `codex/limited-enemy-visibility`, based
  on tested `codex/suppression-pinning` (PR #13). Tested code commit:
  `b0d304316e78e341660d394eaa3e0ad5ffdeb824`.
- New battles use tactical rules v3: living observers spot LOS-valid enemies
  within 280 m on open ground or 120 m when the target is wooded. Each shooter
  must spot its own target; the side's view shares current contacts instantly.
  The opponent follows existing objective routes without hidden-position input.
- Hidden actors, labels, orders and shot endpoints are withheld. Observed red
  labels show ENEMY CONTACT without exact state. Live enemy totals, objective
  seconds and volley deltas are withheld until the completed report. Unobserved
  incoming fire still affects blue squads without exposing its source.
- Spotting is a pure query of saved squad/terrain state: no extra RNG, persistent
  contact fields or campaign/result/export schema changes. V1/V2 saves keep their
  original rules and full visibility; new v3 saves restore the same sight picture.
- Local validation on the tested code: eight Godot checks and 26 terrain tests
  passed; `git diff --check` passed. Coverage includes acquisition/loss, dead
  observers, target concealment, building LOS, actual unobserved fire, no hidden
  auto-targeting, observed return fire and full-result restart equality.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38143726275 succeeded.
  Inspected `tactical-validation` artifact 11704290060: planning has zero enemy
  contacts and no red markers; execution 00:03 shows three generic contacts,
  observed shots, PINNED and blue casualty/ammunition/pressure feedback while
  the distant fourth red squad stays hidden. Completed report remains readable
  and reveals both sides' final totals and campaign effects.
- The first local UI run caught a test-variable type declaration error, fixed
  before publication. Fresh pytest/dependencies were installed after transient
  download timeouts. First CI 38143591088 passed, but its artifact exposed a
  sidebar-caption overflow; corrected and rerendered on the tested code above.
- Download:
  https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/limited-enemy-visibility
  Godot 4.5.1, open project.godot, F5, fresh PLAY INTEGRATED DEMO. Loading an old
  v1/v2 engagement intentionally retains its old visibility rules. The preserved
  milestone branch, ZIP and check-in commit are unchanged.
- Limits: current sight only, instant side-wide sharing, no spotting delay,
  last-known markers, area fire or weapon-specific sensors. Windows validation
  and Combat Mission fidelity remain unverified.
- Next: persist timestamped last-known contacts and show uncertain stationary
  markers after sight is lost. Never update them from hidden enemy motion or
  reveal an unobserved death; version/test the added save fields and preserve
  existing engagements' rules. Richer movement/fire commands follow separately.

## Post-milestone run record — last-known contacts, 2026-10-11

- Status: ready for review; draft PR #15, `codex/last-known-contacts`, based on
  tested `codex/limited-enemy-visibility` (PR #14). Tested gameplay commit:
  `bb8e0ac071155238b3db53951babeb1fbf552d1a`. No milestone reannouncement.
- Tactical v4 persists both sides' observed positions and elapsed timestamps.
  Lost contacts show stationary amber `? LAST SEEN Ns` markers. Hidden motion
  and unobserved deaths do not update or remove memory. Reacquisition refreshes
  it; sight of an eliminated contact confirms its loss. Direct fire still requires
  each shooter's current sight. Presentation queries return detached records.
- V1/V2/V3 engagements keep their original fields/rules. Strict v4 validation
  rejects unknown/friendly IDs, invalid positions, future/fractional timestamps,
  extra fields and missing maps. Campaign v2, result v1 and exports unchanged.
- Local checks on the gameplay candidate: all nine Godot checks, 26 terrain
  tests and git diff --check passed. Regression covers actual campaign disk
  save/restart, bilateral memory, hidden death/movement, reacquisition, confirmed
  death, malformed records, legacy compatibility, complete restarted outcomes
  and UI state isolation. Existing two-battle regression passes.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38144714762 succeeded.
  Inspected artifact `tactical-validation` 11704555666: execution at 00:04 shows
  a readable amber `? LAST SEEN 1s` at the prior location with the actual enemy
  hidden; the 00:03 capture shows observed simulated shot cues and blue casualty,
  ammunition and pinning feedback. Completed two-sided report remains readable.
- First CI 38144589444 passed, but artifact inspection found the contact age
  label too small at the default camera. Enlarged/raised it and rerendered on
  the tested gameplay commit above. The rendered fixture loses a contact by
  relocating it outside sight; the logic regression proves saved memory behavior.
- Download:
  https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/last-known-contacts
  Godot 4.5.1, open project.godot, F5, fresh PLAY INTEGRATED DEMO. Loading older
  engagements intentionally retains their original rules. Frozen milestone
  branch/ZIP/check-in commit remain unchanged.
- Limits: instant side-wide sharing, no contact expiry/spotting delay/area fire,
  abstract squad markers and combat. No Windows or Combat Mission fidelity validation.
- Next: distinct infantry movement orders with deterministic response/speed
  tradeoffs, readable queued orders and regression coverage. Keep weapons,
  vehicles and broader opponent modeling in separate tasks.

## Post-milestone run record — infantry movement orders, 2026-10-11

- Status: ready for review; draft PR #16, `codex/infantry-movement-orders`, based
  on tested `codex/last-known-contacts` (PR #15), head 4fcb4aa. Tested code commit:
  `138ca1fa1511443099c479234a7635c1de050704`. Frozen milestone preserved.
- New tactical v5 offers MOVE 2.4 m/s, QUICK 4 m/s and HUNT 1.2 m/s, before
  existing suppression slowing. HUNT pauses on its own local sight of a living
  enemy or suppression >=25% after recovery, retaining the route and return fire.
  Shared/remembered contacts alone do not trigger it; clearing conditions resumes
  movement. Pinning stops every mode. Scripted opponent retains MOVE.
- Mode selection configures the next right-click command without mutating a
  queued order. Selected-squad feedback shows actual mode/HUNT PAUSED. Controls
  freeze during execution; dead squads cannot receive commands. Hold, reaching
  the destination and elimination clear mode/path together.
- New movement_modes map is paired exactly with nonempty orders and validated.
  Old v1-v4 saves retain fields/rules and reject new modes. Campaign schema v2,
  result v1, legacy export/GIS contracts and Windows launchers unchanged.
- Ten Godot checks, 26 terrain tests and git diff --check passed locally on the
  same candidate. Added coverage includes distinct speeds, HUNT local contact
  and fire, shared-contact isolation, suppression recovery, pinning, replacement,
  completion/death cleanup, malformed maps, legacy restart, actual campaign disk
  persistence and complete restarted outcomes. Existing two-battle checks pass.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38145385583 succeeded.
  Inspected tactical-validation artifact 11704915470: planning shows HUNT and
  a queued route; execution at 00:03 shows HUNT PAUSED with actual observed
  shot cues, personnel/ammunition changes and pinning. The completed report and
  apply controls remain readable. Fixture places opposing squads in clear local
  contact; dedicated logic tests cover acquisition, pause and resume rules.
- Initial editor check caught an inferred Variant speed variable; explicit float
  typing fixed it before successful checks/publication. No remaining failed check.
- Download:
  https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/infantry-movement-orders
  Godot 4.5.1, open project.godot, F5, fresh PLAY INTEGRATED DEMO. Choose a squad
  and mode, then right-click. Older loaded engagements keep normal movement.
- Limits: abstract tuning, no fatigue/posture/weapon-specific speed or accuracy,
  HUNT reversible pause rather than permanent halt. Linux evidence does not
  establish Windows validation or Combat Mission fidelity.
- Next: AUTO/HOLD FIRE controls with versioned state, readable feedback, local
  LOS preservation and actual disk-restart regression; broader opponent reactions,
  area fire, weapons, vehicles and fatigue remain separate tasks.

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

## Covered objective positions — 2026-10-11

- In validation: codex/covered-objective-positions, base tested codex/opponent-cover-routing PR #22. All 16 local Godot checks pass; actual occupation and restart regression added. CI pending.

## codex/covered-objective-positions — validated 2026-10-11

- Ready for review, draft PR #23, base codex/opponent-cover-routing.
- Tested gameplay: 9220f10fd0e071fa4086dcfd996ccc1315a624c3. All Godot checks, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38153202700 succeeded. Inspected artifact 11707776142: Real covered arrival/objective scoring and disk outcome equality in regression logs; actual shot/ammunition/pinning execution and readable completed report inspected. Rendering does not prove realistic cover tactics.
- Frozen milestone and prior downloads preserved; no Windows or Combat Mission fidelity claim.
- Next: persistent infantry fatigue and visible movement cost.

## Infantry fatigue — 2026-10-11

- In validation on codex/infantry-fatigue, based on tested covered-objective-positions PR #23. Integer fatigue storage fixes JSON round-trip drift discovered by tactical_smoke. Initial validation scope parse error corrected. Full checks/render CI pending.

## codex/infantry-fatigue — validated 2026-10-11

- Ready for review, draft PR #24, base codex/covered-objective-positions.
- Tested gameplay: 11c9a990161902025d76dad064caa5ddf977b344. All Godot checks, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38153705906 succeeded. Inspected artifact 11707716785: All 17 Godot checks plus 26 terrain tests pass together. Inspected actual earned FAT28 percent after QUICK movement at 00:57 (ammunition disabled only in that render checkpoint), real 00:03 shot/casualty/pinning feedback and readable completed report. Full disk/combat outcome equality passes after integer storage fixed initial JSON drift; initial parse-scope error corrected. CI retains nonfatal VSync/anchor/test-event warnings.
- Frozen milestone and prior downloads preserved; no Windows or Combat Mission fidelity claim.
- Next: morale states and deterministic retreat/rally behavior.

## Morale retreat/rally — 2026-10-11

- In validation on codex/morale-retreat-rally, based on tested infantry-fatigue PR #24. V13 persists morale states and rally counters. Real-fire break, rearward withdrawal, withheld commands/fire, rear rally and actual disk continuation regression added. Old pinning return-fire fixture now explicitly isolates high morale from break behavior. Full CI pending.

## codex/morale-retreat-rally — validated 2026-10-11

- Ready for review, draft PR #25, base codex/infantry-fatigue.
- Tested gameplay: 9c260fa18d063d4e0488f6fc5a9862266f3ef99e. All Godot checks, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38154770519 succeeded. Inspected artifact 11707872681: All 18 Godot checks and 26 terrain tests pass on the combined candidate. Inspected actual shot/casualty/pinning execution, completed two-sided report with eliminated-order fix, withdrawal at 00:09 and RALLY25s at the rear at 00:54. Morale render uses seeded stress and ammunition disabled; separate actual concentrated fire regression triggers break. Actual disk restart preserves routes, a 17-second partial rally and full outcomes. First pinning regression exposed expected broken-versus-return-fire interaction; fixture now isolates high morale. Initial render exposed eliminated RALLY labels, corrected with regression before this successful CI. Nonfatal renderer/test harness warnings remain.
- Frozen milestone and prior downloads preserved; no Windows or Combat Mission fidelity claim.
- Next: standing crouched and prone infantry posture commands.


## Infantry posture — 2026-10-11

- In validation: codex/infantry-posture, base PR #25 at
  79ccfc713a0ce4e395441c071f6144205d03fd5d (CI 38154985632 success).
- Strict V14 postures, movement/sight/exposure tradeoffs, lower-eye hill LOS,
  symbolic posture and actual shot cues. Campaign/export/GIS/launchers preserved.
- Regression exercises real commands/movement/attacks and actual disk restart.
  Initial test parse/version/routed-distance assumptions fixed. CI pending.
- Frozen milestone build preserved; no Windows or realistic-fidelity claim.

- Initial candidate 48cb1774d9592842044ae93c50422f1c9d3384e1 passed CI
  38163805273 and artifact 11711526519 showed actual PRONE/shot execution
  at 00:06. Visual inspection caught completed-summary/roster overlap after
  the denser controls. Compact summary/selection labels and bounds regressions
  added before final validation; readiness remains pending the corrected CI.


## codex/infantry-posture — validated 2026-10-11

- Ready for review, draft PR #26, explicit base codex/morale-retreat-rally PR #25
  at 79ccfc713a0ce4e395441c071f6144205d03fd5d (CI 38154985632 success).
- Tested gameplay commit: d0c113b6ab93eaaf5eecb995eefaf76c2fcb4932. Tactical v14 persists
  strict per-squad postures, standing/crouched/prone movement, observation,
  concealment/exposure and terrain LOS. Withdrawal stands broken squads.
- All 19 local Godot checks, 26 terrain tests and diff check passed on the corrected
  candidate. Combined CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38164109023 succeeded.
- Inspected artifact 11711402288: PRONE at actual firing 00:06, rounds/suppression,
  symbolic lowered bodies, frozen controls and readable completed report.
  Shortened summary/selection and roster spacing correct overlap found in initial
  render 11711526519; new UI bounds checks pass. The render uses a mixed-posture
  checkpoint and close-contact positions; shots are actually simulated. Separate
  regression uses real posture-button inputs and proves actual movement, sight,
  hill occlusion, exposure attacks and full real-combat campaign disk equality.
- Two actual campaign contacts, fresh IDs T003_B2/T004_B2, restart, retained history/
  losses, retreat, unlocked turns and stale/duplicate rejection pass in this CI.
  Nonfatal renderer/anchor/test-event warnings remain; no script errors.
- Frozen milestone and prior downloads preserved. V1–V13 keep original fields/
  rules; campaign/result/GIS/export/Windows launchers unchanged. No Windows or
  Combat Mission fidelity validation. Instant posture changes, abstract tuning,
  standing red planner and symbolic squad bodies remain limitations.
- Next: infantry weapon roles and fire cadence, with bounded ammunition/casualties.


## Infantry rifle/support profiles — 2026-10-11

- In validation: codex/infantry-fire-profiles, explicit base tested PR #26 final
  head 505b84c0e73812ff05327d0e81a36b7216e0fca4 (CI 38164319208 success).
- V15 adds fixed strict roles, rifle 3s/support 2s cadence and finite burst/ammo
  tradeoffs. Same-tick attacks and once-only campaign bounds remain unchanged.
- All 20 local Godot checks, 26 terrain tests and diff check passed. Initial
  GDScript type inference and malformed-role comparison errors fixed; runner
  correctly rejected script errors even when a direct script printed PASS.
- New regression uses actual volleys, partial ammo, hold/hidden restrictions,
  simultaneous attacks, strict maps, V14 preservation and pre-volley campaign
  disk restart with complete outcome equality. Actual support render CI pending.
- No Windows/fidelity/individual-weapon validation; frozen ready branches preserved.
