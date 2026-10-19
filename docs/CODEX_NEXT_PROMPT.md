# Continue from the validated planning terrain probe

Latest validated descendant: codex/terrain-los-probe, draft PR #41, explicitly
based on tested PR #40 head 06c93d89d4a57d5368507710950a6abbb56103d6. Tested code:
1f26c2137f27d1a1b31d5b53f1132ea725635b0d. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/39084668828 passed all
34 Godot checks, 11 rendered scripts and 26 terrain tests. Artifact 12120660690
inspected: clear/building/prone ground measurements, actual 00:03 firing, existing
1x/4x/8x shots and readable completed two-sided reports with campaign consequences.
First passing CI exposed thin probe-line raster gaps; only that overlay width
was refined and rerendered. Check final documentation-head CI in PR #41 before
dependent work; do not duplicate this completed current-position probe.

Next focused task: an explicitly hypothetical terrain LOS/range preview from
the selected living friendly's final queued waypoint to an explicit ground point.
Label the hypothetical origin and current-posture assumption clearly. Reuse
terrain queries without moving the squad, altering orders or projecting spotting,
fire permission, target positions or future outcomes. Handle absent/changed routes
without retaining a stale origin. Keep the current-position mode available.
No hidden-unit lookup, authority, save fields, RNG or execution-time query.
Add real input, geometry, purity and disk-reopen regression coverage; preserve
actual firing and report renders. One focused PR on the tested descendant only.

The existing probe is planning-only, current squad center/posture to ground
+0.30 m. The whole green/red segment reports terrain status, not the first
obstruction. Range is horizontal and uncapped by weapons; invalid/off-map/under-1m
points reject. Right/Esc/button, another cursor, selection, execution and reopen
clear it. Posture recalculates; camera retains the point. No contact/acquisition,
orders or ammunition change; every-tick/full-result comparisons match a twin.
Existing sampled hills/buildings are not decorative tree-mesh raycasts. CLEAR
does not establish spotting or a hit. Smooth zoom remains presentation-only;
dense/distant labels and decorative tree/HUD occlusion remain limitations.

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
