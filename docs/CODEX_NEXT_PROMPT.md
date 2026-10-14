# Continue from validated crowded-cover retry

Latest validated descendant: codex/crowded-cover-retry, draft PR #39, explicitly
based on PR #38 head 95d7b2b434fc66329c87497c9c49bce803226948. Tested code/evidence:
40c2bbdbab98b1ed38403df404cc9a2934bef762. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/38491663121 passed all
32 Godot checks, nine rendered scripts and 26 terrain tests. Artifact 11861614334
inspected: actual 00:12 support shot/-18R with 72 rounds, 00:38 retried movement
over 4 m after the friendly vacates cover, zero rounds/expired cues, and a readable
completed two-sided report with campaign consequences. Check the final
documentation-head CI in PR #39 before dependent work.

Next focused task: fix the presentation-only size discontinuity at the 80 m
camera-distance boundary. scripts/tactical_view.gd currently switches labels and
shot cues between close and overview sizes abruptly. Artifact 11861183580 from
CI 38491087067 exposed huge overlapping labels at distance 80. The final retry
fixture uses the existing 65 m scale; it does not fix that defect. Implement
bounded, continuous sizing with actual camera-input tests around the boundary,
real 1x/4x/8x firing evidence and authoritative-state/RNG isolation. Keep selection,
hidden-contact safety, report readability and known close/overview behavior.
Inspect rendered artifacts, not only planning/headless output.

After that, consider a planning-only terrain line-of-sight/range probe from the
selected friendly to explicit ground, using existing terrain/posture queries and
no hidden-enemy lookup. Do not combine these into one large feature PR.

V25 adds retry_remaining (integer 0–12) to each cover_responses record. It arms
only for reachable, in-budget cover blocked by friendly occupancy; no pathfinding
during cooldown ticks. Persistent pressure retries every 12 executed seconds;
below 30% pressure resets the timer, death/break clears it, and existing goals are
never reshuffled. Original queues/modes/waits survive pending-retry interval breaks
(a regression found and fixed their replacement by ordinary AI planning). Keep
12 m friendly destination separation, all movement gates and exact disk outcomes.
V1–v24 retain original fields/rules. This is squad-center destination spacing, not
collision avoidance, coordinated maneuver or validated combat realism.

Inspect actual branches/open PRs and expected-head leases before work; reuse any
unfinished focused task PR. Read AGENTS.md, AUTONOMOUS_DEVELOPMENT.md,
LOOP_FEEDBACK_MILESTONE.md, NATIVE_TACTICAL.md and CAMPAIGN_SAVES.md, plus export/
GIS contracts before changing them. Main remains a starter README. Never merge,
force-push, delete branches/settings or send external messages. Preserve campaign
v2/result v1, battle locks, bounded once-only losses, rollback and Windows launchers.
No supported Windows desktop connection is present; no Windows/Combat Mission
fidelity claim. Preserve the original codex/completed-battle-report milestone
download/check-in and daily cadence; do not reannounce it without a material fix.
