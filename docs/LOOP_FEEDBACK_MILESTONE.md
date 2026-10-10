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

- Milestone status: in progress
- Workflow baseline branch: codex/loop-feedback-workflow
- Last validated gameplay branch: codex/visible-shot-cues
- Last validated gameplay commit: 29dded6867df2c869803c985644a2f38c562f124
- Current task: readable casualty/ammunition/suppression feedback
- Current task branch / PR: not started; use codex/visible-shot-cues (PR #8) as the base
- Next task: completed battle report and campaign consequences
- Check-in prepared for code commit: none
- Baseline CI: https://github.com/Austin-Ellefson/Wargame/actions/runs/38080482143
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
| Readable combat feedback | Squad casualty, ammunition and suppression changes are visible during execution; dead squads stop acting and cannot receive orders. Feedback is legible and does not obscure commands or imply unsupported ballistic realism. | Counters exist; improve and verify |
| Battle report and continuation | Finished report shows outcome, both sides' deployed/surviving/lost personnel, objective control and campaign consequences. APPLY & CAMPAIGN succeeds once; player can continue and resume without a stale report. | Basic summary exists; improve and verify |
| Combined build | All logic/input/GIS checks pass on the same candidate; rendered execution/report previews reviewed; one branch ZIP includes all work and docs. Windows-specific limits are stated. | Planned |

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

## Scope and priorities

Camera pan/rotation and movement paths support readable combat, but must not
displace the repeatable loop and visible fire/feedback. Separate transient visual
events from saved authoritative state: rendering, playback and animation must
not consume simulation RNG or change results. Version any save contract change.

Synthetic terrain and infantry remain the baseline. Vehicles, real GIS maps,
fog of war, campaign AI and deeper behavior are later milestones. No merge,
force push, branch deletion, settings changes or external messaging. The check-in
is delivered as the scheduled task result in ChatGPT.
