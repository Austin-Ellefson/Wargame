# Continue from earlier authored-leg editing

Current validation descendant: `codex/edit-earlier-route-leg`, explicitly based
on the tested PR #51 documentation head
`6dee130a0f4b1ef0af3e106f0a32fa6b497a44f5`. It transiently selects any gold
authored marker during planning and edits that exact leg's MOVE/QUICK/HUNT mode
or pre-leg wait. A cyan **[EDIT]** marker, selected-mode star, numbered wait
control and command help identify the target. It preserves the future append-mode
selector, route geometry, boundaries, later legs and earned response time.

The implementation reuses tactical v28 `route_modes`/`route_pauses`; selection
is not saved and V1–v27 remain exact. Focused coverage passes actual input, both
first/later leg edits, invalid/v27 isolation, RNG/event purity, exact boundary
activation, JSON disk reopen, every rendered/headless combat tick, real shots and
the completed report. All 44 local Godot 4.5.1 logic/editor entries and 26 terrain
tests pass; this host lacks a usable Xvfb display, so rendered CI/artifact evidence
is still required before the branch becomes the latest validated descendant.

Reuse this branch/PR if it is unfinished; do not duplicate it. After its combined
validation, the next focused planning task may retarget a selected authored
destination with deterministic affected-segment rerouting and exact later-leg,
save/restart and outcome parity. Keep that separate from the current editor.

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
