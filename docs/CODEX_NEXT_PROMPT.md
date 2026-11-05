# Continue from validated per-leg arrival facing

Latest validated descendant: `codex/per-leg-arrival-facing`, draft PR #56,
based exactly on validated `codex/insert-authored-route-leg` PR #55 at
`d0f6f5794f739300a7def1a02209441ad84b1725`. Fresh tactical v29 adds strict
`route_facings` entries parallel to each editable authored leg: `-1` keeps the
live bearing, while `0..359` applies a whole-degree world bearing only when that
exact gold destination is reached.

Select a gold node, use ARRIVAL FACE, then click a direction from that node.
Labels and a short line show the queued bearing; an existing bearing clears back
to KEEP. Boundary consumption applies an explicit heading before that same
second's contact acquisition and firing. Retarget preserves paired intent,
insertion adds KEEP, and removal/cleanup consume only matching metadata.

Feature/evidence commit `3947aa2f9383fc7eba522f2ce61516e1e9af4b3b`
passed combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/41760070176: all 48
Godot 4.5.1 checks, including 24 rendered checks, and 26 terrain tests. Actual-
input coverage includes strict malformed-save rejection, exact v28 isolation,
metadata ownership, same-tick fire, disk restart, global-RNG purity and every
full-combat tick/result against an unrendered twin. Artifact `13290023227`
(`sha256:9adfac2f724dfe3970b17e1735dfdca78ad018793ca22362879400bb69d08afa`)
was downloaded: 73 logs, 98 screenshots, 72 PASS-bearing logs and no script/
error/failure matches. Planning ARRIVE 271 degrees, actual three-shot execution
with ammunition/suppression changes, and the readable completed two-sided report
were inspected. Check the final documentation-head CI before dependent work.

Next, separately scope optional per-leg arrival fire-arc width that
activates with an explicit arrival bearing. Version it independently, preserve
the live arc until its boundary, and retain exact v1–v29 shapes and outcomes.

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
