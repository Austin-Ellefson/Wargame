# Next Codex Task: Improve the Native Tactical Battle

The user approved an integrated Godot tactical simulator on 2026-10-10.
Inspect current branches and PRs. Use the native branch `codex/integrated-tactical-battle`, stacked on `codex/campaign-save-load`, until merging/review changes the active base. Do not duplicate locks or result application already implemented there.

Read `AGENTS.md`, `docs/AUTONOMOUS_DEVELOPMENT.md`, `docs/NATIVE_TACTICAL.md`, and `docs/CAMPAIGN_SAVES.md`. Preserve existing battle-export fields and GIS tooling.

The first slice provides a synthetic 512 m 3D infantry battle, squad orders, 60-second WEGO intervals, an objective, navigation/LOS, simple fire/suppression, persistent battle locks, deterministic restart and once-only campaign results. Vehicles remain in reserve. Native GIS import and deeper combat modeling are future milestones.

Complete one focused improvement from the queue. Prioritize camera/order/report usability or a small native elevation import with synthetic orientation/LOS tests. Record Windows feedback if provided. Do not describe an unmerged branch as available on main, or Linux/headless checks as Windows validation.

Checks to preserve:

```bash
python tests/run_godot_checks.py --godot godot
python -m pytest -q tests/test_terrain_bridge.py
```

The workflow in `.github/workflows/verify.yml` performs a rendered view/input check and captures a PNG. Check its actual conclusion and review the preview when available. Keep draft PRs stacked, update the queue, and do not merge or force-push.
