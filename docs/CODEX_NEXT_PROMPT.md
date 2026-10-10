# Next Codex Task: Complete the Loop and Combat Feedback Milestone

The user authorized unattended progress on 2026-10-10 and requested a check-in
when the repeatable campaign loop and visible firing/feedback are both ready.

Inspect branches and PRs, then read AGENTS.md, docs/AUTONOMOUS_DEVELOPMENT.md,
docs/LOOP_FEEDBACK_MILESTONE.md, docs/NATIVE_TACTICAL.md and docs/CAMPAIGN_SAVES.md.
Start from codex/loop-feedback-workflow and follow the latest validated descendant
in the ledger. This includes the native battle and save/load work; main remains
a starter until the PR chain is merged. Recheck actual GitHub state.

Complete one focused implementation task from the ledger. First add a meaningful
regression for two consecutive campaign battles with restart and fix discovered
defects. Then implement actual-shot visual cues, suppression/casualty feedback
and a readable result report. Supporting camera/order usability is in scope.
GIS, vehicles and deeper tactical models wait until this milestone is ready.
Preserve exports, deterministic saves, locks, bounded losses, duplicate rejection
and save-failure rollback.

Reuse an unfinished task PR. Otherwise create a focused draft PR on the latest
validated milestone branch, keep its dependency explicit and update the ledger.
Continue on tested descendants without waiting for routine review or Windows
feedback; do not merge, force-push or change settings. Investigate failed checks
before building dependent work on that branch.

Run python tests/run_godot_checks.py with an available Godot binary and
python -m pytest -q tests/test_terrain_bridge.py for combined validation.
For rendered changes, use .github/workflows/verify.yml, check the actual CI
conclusion and inspect artifacts. Exercise firing visuals during execution,
not only in a planning screenshot. State absent Windows validation accurately.

Update the ledger with actual outcomes, code commit, CI run and preview evidence.
When every gate passes on one playable branch, prepare the user's check-in with
the download, exact launch/test instructions, evidence and limits. Record the
code commit for which the check-in was prepared; avoid repeat announcements on
every run. Until then, persist concise task status in GitHub and report concrete
blockers without claiming completion.
