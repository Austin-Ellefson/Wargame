# Wargame development instructions

## Goal and baseline
Build a Godot 4 operational campaign with a Combat Mission: Black Sea tactical handoff.
Use fictional formations and scenario data. Campaign sectors and tactical battle windows are separate.
Read README.md, docs/CODEX_NEXT_PROMPT.md, docs/BATTLE_EXPORT.md, and terrain_bridge/README.md before changing their contracts.
Until the existing stacked PRs are merged, the active baseline is phase-2-terrain-bridge; main currently contains only the starter README. Recheck branches and PR status each run.

## Autonomous work
Use docs/AUTONOMOUS_DEVELOPMENT.md for the queue and completion criteria.
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
- godot --headless --path . --script res://tests/campaign_smoke.gd
Only claim a check passed if it actually ran successfully. Record missing dependencies and failed checks explicitly.
Keep generated exports, GIS caches, virtual environments, and user saves out of git.

## CMBS boundary
Data preparation and HTML previews do not prove a CMBS scenario was created or validated.
Do not assume access to the user's PC, CMAutoEditor, CMBS, installed binaries, or private output.
Mark Windows editor validation as user-dependent and continue independent campaign tasks.
Preserve existing export fields unless an explicit versioned migration is implemented.

## Report
State the change, branch and PR link, checks actually run, limitations, and next task.
