# Next Codex Task: Last-known Enemy Contacts

The user authorized unattended progress on 2026-10-10 and requested a check-in
when the repeatable campaign loop and visible firing/feedback are both ready.
That check-in was prepared for the preserved `codex/completed-battle-report`
branch. The user now wants battles as close to Combat Mission as possible.

Inspect branches and PRs, then read AGENTS.md, docs/AUTONOMOUS_DEVELOPMENT.md,
docs/LOOP_FEEDBACK_MILESTONE.md, docs/NATIVE_TACTICAL.md and docs/CAMPAIGN_SAVES.md.
Start from codex/loop-feedback-workflow and follow the latest validated descendant
in the ledger. This includes the native battle and save/load work; main remains
a starter until the PR chain is merged. Recheck actual GitHub state.

The latest tested descendant is `codex/limited-enemy-visibility` (PR #14), with
camera/path previews, pinning and deterministic current spotting. Recheck its
ledger, PR and CI before using it. Tactical v1/v2 saves retain original behavior;
new battles use v3. Unknown versions must be rejected.

Complete one focused last-known-contact implementation with meaningful tests.
Current sight already controls live models, automatic targeting and shot cues.
Record only observed positions and timestamps. After sight is lost, uncertain
markers must remain at the last observed location rather than track hidden motion.
Do not reveal an unobserved death or exact enemy headcount/status. Design both
sides' knowledge consistently; keep local shooter LOS required for direct fire.
Persist added authoritative contact data with a versioned contract and
deterministic restart. Preserve old engagements' rules or explicitly document
and test a migration. Richer movement/fire orders,
opponent reactions, weapons, leadership and individual representation follow in
separate tasks; do not claim parity or measured real-world fidelity.
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
Keep the frozen milestone download and its check-in record available. Report the
new descendant download separately. Preserve concise task status in GitHub and
report concrete blockers without claiming completion.
