# Continue nearby-cover response validation

Current focused work: codex/opponent-nearby-cover, based on tested PR #36 head
eefad59a297764ec9504760f44d8fdda06a4ef0e. Reuse this branch/PR while unfinished;
inspect actual remote heads, open PRs and leases before changing files. Main is
still only the starter README. No merges, force pushes or deleted branches.

Tactical v23 adds a saved six-tick pressure timer and bounded local cover detour,
retains original routes and reconnects through terrain navigation after recovery.
No attacker lookup/RNG. Old v1–v22 rules and save fields remain intact. Fixed
actual moving-area-fire JSON precision drift by rounding v23 pressure writes to
millionths. Read CAMPAIGN_SAVES and NATIVE_TACTICAL for contracts/limits.

Implementation and focused real-fire/disk regression are present. All30 local
Godot checks and26 terrain tests passed; validate the latest test additions,
publish a draft PR, require combined rendered CI and inspect moving/arrival shot
captures plus a completed report before marking ready. Record exact commits,
CI URLs/artifacts and limitations in AUTONOMOUS_DEVELOPMENT and the milestone
ledger. Preserve frozen milestone download and do not repeat its check-in.

Read AGENTS, current queue/ledger, save and native docs before work. Preserve
campaign locks, bounded once-only results/losses, rollback, deterministic restart,
export/GIS and Windows launchers. No supported Windows desktop connection was
available; Linux results do not establish Windows or combat-fidelity validation.
