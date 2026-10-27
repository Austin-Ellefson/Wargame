# Continue from authored route-leg boundaries

Latest validated descendant: `codex/route-leg-boundaries`, draft PR #49,
explicitly based on validated PR #48 documentation head
`763e182baa3147dd174050e12d94536fe2f00570`. Tested code:
`8b9076073b45e3942a7216be450deb61c3c83784`.
Fresh tactical v26 stores strict remaining point counts for each player-authored
blue click-leg, renders gold numbered destinations, removes a whole final leg and
consumes boundaries during execution. V1–v25 keep their exact fields and original
single-point removal without migration. All 41 local Godot 4.5.1 entries, 26
terrain tests and diff check passed. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/40430123145 succeeded with
all 18 rendered scripts. Artifact 12701174717 was inspected: 59 logs, 58 PASS-
bearing non-editor logs, no script errors and 76 PNGs. Check PR #49's final
documentation-head CI before dependent work.

Next focused task after combined validation: version per-leg MOVE/QUICK/HUNT
choices so the player may select a different mode before Shift-appending a later
leg. Preserve v1–v26 save behavior, deterministic path points, pause/response
semantics, authored-node removal and exact disk/resumed-combat parity. Display the
mode at each authored node without leaking hidden information or using RNG. Do not
duplicate the task if an unfinished successor already exists.

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

Fresh battles use tactical v26: authored route legs sit above the unchanged v25
crowded-cover retry rules. V1–v25 retain original fields and behavior.
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
