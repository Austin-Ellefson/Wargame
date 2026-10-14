# Finish crowded-cover retry validation

In-progress task: codex/crowded-cover-retry, based on PR #38 head
95d7b2b434fc66329c87497c9c49bce803226948. Reuse this branch and its task PR;
do not start another retry implementation. V25 adds a saved 12-second cooldown
only when otherwise viable cover is blocked by friendly occupancy. Original
queues/modes/waits now survive interval planning during the cooldown. The focused
regression passes after exposing and fixing that interval replacement issue.
Combined local/CI/rendered validation and final status are still in progress.
The validated base and its evidence below remain the fallback until this passes.

Latest validated descendant: codex/opponent-cover-spacing, draft PR #38, based
on PR #37 head 70d60f2f7b7960684c7977c912c29a5b50325818. Tested code:
ee79493ca036a91125aa3a9a73af023d7348bc86. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/38268504575 passed all
31 Godot checks, eight rendered scripts and 26 terrain tests. Artifact 11755223640
inspected: actual 00:16 support tracer/-18R with 216 rounds and two acquired cover
moves; 00:57 arrival 16 m apart with 0 rounds and expired cues; readable completed
06:00 two-sided report and campaign consequences. Some decorative tree occlusion
remains. Check the final documentation-head CI in the PR before dependent work.

Current focused task: bounded retry for crowded-cover searches after friendly space
becomes available while pressure persists. V24 failed searches currently wait
until pressure falls below 30% before rearming. Improve this in one small task,
without per-frame pathfinding, hidden enemy information or extra simulation RNG.
Keep reservations, existing original queues, explicit waits, command response,
HUNT, pinning, retreat/rally, local acquisition and exact disk continuation.
Version changed rules/save fields. Do not divert into vehicles/GIS/equipment.

V24 uses the v23 cover_responses fields and validates active goals at least 12 m
apart. Candidate points also avoid other living red current positions. Fixed
roster order resolves simultaneous choices. Recovery/death/break release goals;
no occupancy cache is added. This is destination spacing, not collision avoidance:
paths may cross and later movement can enter reserved space. V1–v23 retain their
original fields/rules. Campaign v2/result v1 and frozen downloads are preserved.

Inspect actual branches/open PRs and expected-head leases before work; reuse any
unfinished focused task PR. Read AGENTS.md, AUTONOMOUS_DEVELOPMENT.md,
LOOP_FEEDBACK_MILESTONE.md, NATIVE_TACTICAL.md and CAMPAIGN_SAVES.md, plus export/
GIS contracts before changing them. Main remains a starter README. Never merge,
force-push, delete branches/settings or send external messages. Run combined
Godot/terrain tests and inspect actual execution/arrival/report CI artifacts.
No supported Windows desktop connection is present; no Windows/Combat Mission
fidelity claim. The original milestone check-in and daily cadence are preserved;
do not repeat the announcement without a material fix to that frozen build.
