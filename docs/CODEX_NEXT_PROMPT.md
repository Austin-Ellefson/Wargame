# Continue from validated bounded interval-review navigation

Latest validated descendant: `codex/review-navigation`, draft PR #47, explicitly
based on tested PR #46 head `56bf09a10739a7c556a0d3db374f2940ecf9f7c3`.
Tested code: `091c6dcdc02ae91b7bb58daab1c1aeaf55639ae4`. All 40 local
Godot 4.5.1 entries, 26 terrain tests and diff check passed. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/40148036657 succeeded with
all 17 rendered scripts. Artifact 12581840422 was inspected: 57 logs, 56 PASS-
bearing non-editor logs, no script errors and 73 images. Its 1280x720 rewound
frame visibly shows REVIEW 00:02/01:00 PAUSED, PREVIOUS/RESTART/STEP/RESUME,
recorded public movement and no stale tracer after a two-shot volley was removed.
The planning capture restores INSPECT, EXECUTE, REVIEW LAST INTERVAL and SAVE &
CAMPAIGN. Check PR #47's final documentation-head CI before dependent work.

Next focused task: add planning-only **REMOVE LAST WAYPOINT** for the selected
friendly route. Remove exactly the final queued destination without moving the
squad, querying enemies or consuming RNG. With multiple points, preserve earlier
legs, movement mode, timed pause and any already-earned command-response time;
with one point, use the existing HOLD cleanup semantics. Disable the control when
there is no editable friendly route and restore it correctly after selection,
execution boundaries and disk reopen. Test actual replace/append/remove input,
single/multiple/boundary routes, route preview cleanup, strict saved-state validity,
exact resumed movement/combat and full-result twin parity. Capture the shortened
planning route plus actual later execution/report evidence.

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

Fresh battles remain tactical v25: crowded-cover retries save retry_remaining
(0–12), preserve original queues/modes/waits across interval breaks, and keep
12 m friendly destination spacing. V1–v24 retain original fields and rules.
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
