# Continue from the validated public last-interval review

Latest validated descendant: `codex/review-last-interval`, draft PR #46, based
explicitly on tested PR #45 head `f34d13c2d82e0746e0c4a16bd06454234805dc87`.
Tested code: `c8f65413efa871ba7646ab82be4793a0f282e810`. All 39 local
Godot 4.5.1 entries, 26 terrain tests and diff check passed. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/40045022943 succeeded on
that code with all 16 rendered scripts. Artifact 12541201348 was inspected: 55
logs, 54 PASS-bearing non-editor logs, no script errors and 71 images. The actual
paused review frame shows recorded movement, a witnessed tracer, -9R/SUP+14 volley
feedback, public contact labels and clear review controls at 00:06/01:00. The exit
frame restores planning, INSPECT, EXECUTE and REVIEW LAST INTERVAL with no stale
review overlay. Check PR #46's final documentation-head CI before dependent work.

Next focused task: add bounded **PREVIOUS -1s** and **RESTART REVIEW** navigation
inside this same public presentation buffer. These controls are non-authoritative
review only, preferably available while paused; moving backward must clear stale
transient cues and apply a recorded frame without synthesizing a new shot. Forward
movement may display that frame's recorded events once. Never call `Battle.step()`,
read current hidden actors, consume RNG, modify the planning snapshot/checkpoint,
or serialize the buffer. Test start/end bounds, mixed forward/backward input at all
speeds, shot-cue lifecycle, hidden-data exclusion, explicit exit, disk reopen and
full-result twin parity. Capture a readable rewound action frame and restored plan.

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
