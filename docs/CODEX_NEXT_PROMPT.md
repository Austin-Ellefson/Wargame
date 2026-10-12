# Continue tested nearby-cover response

Latest validated descendant: codex/opponent-nearby-cover, draft PR #37, based on
PR #36 head eefad59a297764ec9504760f44d8fdda06a4ef0e. Gameplay commit
10c20b3cc4bd582fdd3c1b4c88b92af3dd7f136a; inspected code/evidence commit
e46e61c6504616792084cc7be65e1b396c039c9b. Combined CI
https://github.com/Austin-Ellefson/Wargame/actions/runs/38265744976 passed all30
Godot checks, seven rendered scripts and26 terrain tests. Artifact11754062886
inspected: real00:12 support fire with252 rounds,01:01 acquired wooded arrival
with0 rounds and expired cues, and readable06:00 two-sided report/consequences.
Some figures remain occluded by decorative trees. See ledger for all evidence,
initial JSON-drift fix, camera refinement and limitations. Check the final
documentation-head CI before dependent work; PR body records its conclusion.

Next focused task: reserve/separate nearby cover destinations among living red
squads, using only friendly current positions/goals and local terrain. Several
pressured squads can currently choose the same point. Keep deterministic roster
ordering and a bounded fallback when space is unavailable; preserve original
queues, explicit waits, command response, HUNT, pinning, retreat/rally, local
acquisition and exact disk continuation. Version changed rules/save contracts.
Do not divert into vehicles, GIS or unrelated equipment before this small task.

V23 persists cover_responses (pressure_ticks/goal/path). Six consecutive recovered
pressure ticks at30% trigger a search within32m radius/40m routed distance.
Original routes remain queued; below15% recovery reconnects through terrain
navigation. A failed search rearms only below30%; already covered squads do not
relocate. No attacker/contact lookup or extra RNG. Pressure writes round to
millionths so moving area-fire falloff resumes exactly. V1–v22 retain their
fields/rules. Campaign v2/result v1 remain unchanged. Rendering uses real4x
playback, ages cues, and matches an unrendered twin every tick.

Inspect actual branches/open PRs and leases before work; reuse unfinished focused
PRs. Read AGENTS/AUTONOMOUS/LOOP_FEEDBACK_MILESTONE/NATIVE_TACTICAL/CAMPAIGN_SAVES
and export/GIS contracts before changing them. Main is still a starter README.
Never merge, force-push, delete branches/settings or send external messages.
Preserve frozen milestone and prior downloads, locks, bounded once-only losses,
rollback and Windows launchers. Run combined Godot/terrain and meaningful
rendered CI with actual artifacts. Local Godot was transiently missing when the
last camera refinement was completed; CI provided final checks. No supported
Windows desktop connection is present; do not claim Windows or combat-fidelity
validation. The original milestone check-in is prepared; preserve daily cadence
and do not repeat its announcement without a material fix to that build.
