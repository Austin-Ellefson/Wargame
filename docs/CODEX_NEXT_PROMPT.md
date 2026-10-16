# Continue from validated continuous combat zoom

Latest validated descendant: codex/continuous-combat-zoom, draft PR #40, explicitly
based on tested PR #39 head ad768942bff43b172b977b8c2ea6765e78bab5d9. Tested code:
354432409976c937a0bec0881f33e6ecaca28ff5. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/38831813254 passed all
33 Godot checks, ten rendered scripts and 26 terrain tests. Artifact 12018070598
inspected: actual 1x/4x/8x firing at 80 m, narrow/wide FOV through real wheel
input, hidden-contact memory and readable completed two-sided reports with
campaign consequences. Check final documentation-head CI in PR #40 before
dependent work; do not duplicate this completed zoom task.

Next focused task: a planning-only terrain line-of-sight/range probe from the
selected living friendly to an explicit ground point. Reuse existing terrain and
posture queries; do not query hidden units, imply a detected enemy or promise a
hit. Make the tool's terrain-only meaning and range clear. Keep it separate from
orders, authoritative simulation, saved state, RNG and execution. Add actual
input/visibility/purity regressions and inspect rendered evidence with real
execution/report checks preserved. Do not combine unrelated features into this PR.

The zoom fix uses bounded continuous focus-distance/FOV sizes for world labels,
their heights, fire-arc thickness and muzzle/tracer geometry. Actual camera input
resizes existing cues without replay, TTL/recoil reset or endpoint/length change.
Default close/overview scales and physical area/arc extents remain intact.
Full real-combat results match unrendered twins; no save/rule migration. This is
not per-anchor screen-space sizing or collision avoidance; distant/dense labels
and decorative tree/HUD occlusion remain limitations.

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
