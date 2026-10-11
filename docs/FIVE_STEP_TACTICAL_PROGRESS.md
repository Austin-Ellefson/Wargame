# Five-step tactical development batch — 2026-10-11

User requested five consecutive implementation steps. Preserve the frozen
completed-battle-report milestone and validate each base before dependent work.

1. AUTO/HOLD FIRE — implemented locally on codex/infantry-fire-control; CI pending.
2. Observed preferred-target orders — planned.
3. Append routed movement waypoints — planned.
4. Timed movement pauses — planned.
5. Opponent reaction using its own local contacts — planned.

Each step gets a focused draft PR, versioned contract when necessary, regression
checks, actual rendered CI review and durable ledger evidence. No merges, Windows
validation claims, vehicles/GIS changes or Combat Mission fidelity claims.

## Five-step batch: codex/infantry-fire-control — 2026-10-11

- Ready for review; draft PR #17, base codex/infantry-movement-orders.
- Tested code: 1ad7350fc9ff0bbf67f7bcaae5893b983a99ec76.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38146581297 succeeded.
- Inspected artifact 11705446305: Readable AUTO/HOLD FIRE controls and separated order status during actual shot execution; completed report retained. First capture exposed tight spacing, corrected and rerendered.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: observed preferred-target orders.
