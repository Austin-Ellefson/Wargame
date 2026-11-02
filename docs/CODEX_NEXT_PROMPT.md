# Continue from selected authored-leg removal

Latest validated descendant: `codex/remove-authored-route-leg`, draft PR #54,
explicitly based on tested PR #53 documentation head
`af255a1300e3e09f4e579feddc2953c4e5faabbc`. Selecting a gold authored marker
changes the command to **REMOVE L#**. It removes that destination and paired
mode/wait, keeps the complete earlier route prefix exact, then reconnects through
every unchanged later destination. Removing LEG 1 promotes the next retained
mode/wait; tail and one-leg removal retain existing last-leg/HOLD semantics.

The implementation reuses tactical v28 route metadata without a schema bump;
selection remains transient and V1–v27 reject selected removal without migration.
Feature/evidence code `91d0a4a2676cc6ceada7632e33b70a2f0fb8c995`
passed all 46 Godot 4.5.1 logic/editor entries, 23 rendered scripts and 26
terrain tests in combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/41373798243. Artifact
13110224066, digest
`sha256:8849bc65ac0cb062f33edad25c2a16273581159e3a9b3b228397262c907b4728`,
was inspected: 69 logs, 68 PASS-bearing non-editor logs, zero script/error/
failure matches and 92 PNGs. Planning visibly shows selected LEG 2, REMOVE L2,
QUICK/15s and deletion help; the result shows three retained legs. Actual 00:03
fire shows three cues, -9 rounds, SUP+18 and 351 rounds/SUP17%. The readable 02:42
report shows both sides' deployed/surviving/lost personnel, objective 0s/75s and
both campaign consequences.

Check PR #54's final documentation-head CI before dependent work and do not
duplicate selected removal. The next focused planning task may insert a new
authored destination immediately before selected intent, using bounded
deterministic route splicing while preserving later modes/waits, disk continuation
and authoritative outcome. Keep it separate.

## Prior validated hypothetical waypoint probe

Latest validated descendant: codex/waypoint-los-preview, draft PR #42, explicitly
based on tested PR #41 head 2c43483d177a78f50e1da9c2512c5ad42db8d630. Tested code:
cc8d0b8f1239c06494d069e2785e7189004d6512. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/39348395575 passed all
35 Godot checks, 12 rendered scripts and 26 terrain tests. Artifact 12231763435
inspected: current/hypothetical clear, building/prone block and removed-route
measurements, actual 00:03 firing, existing 1x/4x/8x shots and readable completed
two-sided reports with objective control and campaign consequences. Check final
documentation-head CI in PR #42 before dependent work. Do not duplicate this task.

Its selected-squad camera-follow and playback-pause follow-ups are complete in the
validated descendant above. Do not duplicate them; preserve friendly-only follow,
free camera use, frozen presentation lifetimes and exact restart/outcome behavior
while implementing single-step playback.

The current planning-only probe compares actual squad center with the final
queued route point using the current posture and a ground +0.30 m endpoint.
The latter is labeled HYPOTHETICAL, not a relocated squad or future prediction.
Replacement/append derives the new final point live; HOLD removes stale geometry
and shows NO QUEUED DESTINATION without silently using the current position.
Current-position mode remains available without a route. Right/Esc/button, another
cursor, selection, execution and reopen clear the transient mode. Posture
recalculates; camera retains the point. No contact/acquisition, order, ammunition,
clock, RNG or save changes; disk reopen and every-tick/full-result twin tests pass.
Range is horizontal, weapon-uncapped; invalid/off-map/under-1m endpoints reject.
The whole colored line reports sampled hills/buildings, not the first obstruction
or decorative tree mesh. CLEAR is not spotting, fire permission or hit probability.
No arrival, future posture/target, path-safety or individual soldier prediction.
Dense/distant labels and decorative tree/HUD occlusion remain limitations.

Fresh battles use tactical v28: per-leg waits sit above v27 modes, v26 route
boundaries and the unchanged v25 crowded-cover retry rules. V1–v27 retain original
fields and behavior.
Preserve exact disk continuation and all movement gates. These are abstract
squad behaviors, not individual collision avoidance or validated combat realism.

Inspect actual branches/open PRs and expected-head leases before work; reuse any
unfinished focused task PR. Read AGENTS.md, AUTONOMOUS_DEVELOPMENT.md,
LOOP_FEEDBACK_MILESTONE.md, NATIVE_TACTICAL.md and CAMPAIGN_SAVES.md, plus export/
GIS contracts before changing them. Main remains a starter README. Never merge,
force-push, delete branches/settings or send external messages. Preserve campaign
v2/result v1, battle locks, bounded once-only losses, rollback and Windows launchers.
No supported Windows desktop connection is present; no Windows/Combat Mission
fidelity claim. Preserve the original codex/completed-battle-report milestone
download/check-in and daily cadence; do not reannounce it without a material fix.
