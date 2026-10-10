# Wargame development instructions

## Goal and baseline
Build a Godot 4 operational campaign with an integrated native 3D tactical simulator. The user approved this pivot on 2026-10-10; CMBS is an optional legacy handoff.
Use fictional formations and scenario data. Campaign sectors and tactical battle windows are separate.
Read README.md, docs/CODEX_NEXT_PROMPT.md, docs/BATTLE_EXPORT.md, and terrain_bridge/README.md before changing their contracts.
Until the existing stacked PRs are merged, start with codex/loop-feedback-workflow and the ledger in docs/LOOP_FEEDBACK_MILESTONE.md. It includes codex/integrated-tactical-battle, based on codex/campaign-save-load. Follow the latest validated milestone descendant recorded in the ledger; main currently contains only the starter README. Recheck branches and PR status each run.

## Autonomous work
Use docs/AUTONOMOUS_DEVELOPMENT.md for the queue and completion criteria.
The user requested unattended progress and a check-in when the repeatable campaign loop and visible firing/feedback are ready (2026-10-10). Prioritize docs/LOOP_FEEDBACK_MILESTONE.md until all its gates pass. Do not treat the initial one-battle smoke test as completion.
Complete one small, independently verifiable task per run. Make routine implementation decisions without waiting for the user.
Read existing code and instructions first. Preserve working movement, battle exports, GIS output, and Windows launchers.
Prefer the existing architecture; SQLite is a possible future direction, not a required migration.
Use a feature branch. Save code, tests, and task status together and create or update a draft PR.
Do not merge PRs, force-push, delete branches, or change repository settings.
Reuse an existing automation PR for an unfinished task. Do not create duplicate work or pile unrelated features into it.
If a task is ready for review, choose a separate independent task or report that review blocks further work.
Do not send emails or chat messages. Report in the scheduled task result and PR description.

## Verification
Run relevant existing checks and add meaningful regression tests for state changes:
- python -m pytest -q tests/test_terrain_bridge.py
- godot --headless --path . --editor --quit
- python tests/run_godot_checks.py --godot godot (editor import, campaign, save/load, tactical simulation and UI input checks)
- Rendered UI validation: see .github/workflows/verify.yml; review the captured preview.
Only claim a check passed if it actually ran successfully. Record missing dependencies and failed checks explicitly.
Keep generated exports, GIS caches, virtual environments, and user saves out of git.

## Tactical boundaries
The first native battle uses a synthetic 512 m map, two infantry detachments, abstract fire and suppression, and a scripted opponent. It is a tested first game loop, not a validated realistic military model. Preserve battle locks, deterministic restart, exact-once results, and save-write rollback. Expand in reviewable increments; real GIS terrain and vehicles are subsequent work.

## Legacy CMBS boundary
Data preparation and HTML previews do not prove a CMBS scenario was created or validated.
Do not assume access to the user's PC, CMAutoEditor, CMBS, installed binaries, or private output.
Mark Windows editor validation as user-dependent and continue independent campaign tasks.
Preserve existing export fields unless an explicit versioned migration is implemented.

## Report
State the change, branch and PR link, checks actually run, limitations, and next task.
