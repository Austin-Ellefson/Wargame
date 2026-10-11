# Next Codex Task: Infantry Fire Control

The user authorized unattended progress on 2026-10-10 and requested a check-in
when the repeatable campaign loop and visible firing/feedback are both ready.
That check-in was prepared for the preserved `codex/completed-battle-report`
branch. The user now wants battles as close to Combat Mission as possible.

Inspect branches and PRs, then read AGENTS.md, docs/AUTONOMOUS_DEVELOPMENT.md,
docs/LOOP_FEEDBACK_MILESTONE.md, docs/NATIVE_TACTICAL.md and docs/CAMPAIGN_SAVES.md.
Start from codex/loop-feedback-workflow and follow the latest validated descendant
in the ledger. This includes the native battle and save/load work; main remains
a starter until the PR chain is merged. Recheck actual GitHub state.

The latest validated descendant is `codex/infantry-movement-orders` (PR #16),
with camera/path previews, pinning, spotting, saved last-known contacts and
MOVE/QUICK/HUNT. Recheck its ledger, PR and CI before using it. V1-V4 saves
retain original behavior; fresh battles use v5. Unknown versions are rejected.

Next focused task: explicit infantry fire control, starting with AUTO and HOLD
FIRE. Give the player control over ammunition expenditure and engagements, preserve
local shooter sight and version/test changed authoritative rules. If adding
an observed-target preference fits the same small task, require current sight
and never let it track or fire at a hidden/remembered target. Keep state and
controls readable, deterministic across actual disk restart and compatible with
old engagements. Do not bundle area fire, weapons, vehicles, fatigue, leadership
or broader opponent reactions. Do not claim Combat Mission parity.
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
