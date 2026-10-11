# Five-step tactical development batch — 2026-10-11

User requested five consecutive implementation steps. Preserve the frozen
completed-battle-report milestone and validate each base before dependent work.

| Step | Status | Draft PR |
| --- | --- | --- |
| AUTO/HOLD FIRE | Complete and validated | [#17](https://github.com/Austin-Ellefson/Wargame/pull/17) |
| Observed preferred targets | Complete and validated | [#18](https://github.com/Austin-Ellefson/Wargame/pull/18) |
| Queued movement waypoints | Complete and validated | [#19](https://github.com/Austin-Ellefson/Wargame/pull/19) |
| Timed movement pauses | Complete and validated | [#20](https://github.com/Austin-Ellefson/Wargame/pull/20) |
| Local-contact opponent reaction | Complete and validated | [#21](https://github.com/Austin-Ellefson/Wargame/pull/21) |


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

## Five-step batch: codex/observed-target-orders — 2026-10-11

- Ready for review; draft PR #18, base codex/infantry-fire-control.
- Tested code: 34da4ce3278bbc8825da70ca5bbf1d2e693a375b.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38146863358 succeeded.
- Inspected artifact 11704408615: Execution shows Focus ready with actual preferred-target shot cues, safe generic contact labels, hidden-contact marker and readable completed report. UI Shift-click and clear-target regression passed.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: queued movement waypoints.

## Five-step batch: codex/queued-movement-waypoints — 2026-10-11

- Ready for review; draft PR #19, base codex/observed-target-orders.
- Tested code: 6e2715b1e46de4bf9b4b7d34a50f89e2c236ac32.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38147099989 succeeded.
- Inspected artifact 11704608641: Full two-leg dotted queue visible during planning; preferred-shot/HUNT feedback and completed report remain readable. Actual Shift-right input and multi-leg disk restart passed.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: timed movement pauses.

## Five-step batch: codex/timed-movement-pauses — 2026-10-11

- Ready for review; draft PR #20, base codex/queued-movement-waypoints.
- Tested code: 01377c0015b3ac983576861c03175c1c0acc1f62.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38147398240 succeeded.
- Inspected artifact 11704464132: Execution at 00:03 shows WAIT 12s (QUICK), ammunition expenditure and actual shot cues while the timer continues; HUNT feedback and completed report remain readable. Mid-wait disk checkpoint restores 18 seconds rather than restarting.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: local-contact opponent reaction.

## Combined batch ready for user testing

Gameplay commit: `72493794c5ea0ac73fbace9bfdc7fb4c9eb40de4`.
All fourteen Godot checks and 26 terrain checks pass together; gameplay CI:
https://github.com/Austin-Ellefson/Wargame/actions/runs/38147734045 .
Rendered artifact review and final continuation are recorded below. This records
preparation of the test build, not confirmation of user delivery or Windows tests.

[Download the combined branch ZIP](https://codeload.github.com/Austin-Ellefson/Wargame/zip/refs/heads/codex/opponent-contact-reaction).
Extract it, open project.godot in Godot 4.5.1 and press F5. Start a fresh
PLAY INTEGRATED DEMO so all v9 controls/rules apply; older loaded engagements
intentionally retain their original versions. The saved slot is shared by these
project branches; back it up if keeping a previous campaign.

### Short control and two-battle/resume test

1. Give S1 a HUNT route, then Shift-right-click to append a second destination.
   Give S2 a QUICK route and PAUSE 15s. Set S3 to HOLD FIRE. Execute and check
   S2's decreasing wait, S3's conserved rounds, real shot cues from eligible AUTO
   squads, casualties and pinning. HUNT pauses on its own local sight or pressure.
2. At the next planning interval, AUTO restores S3 firing. Shift-left-click a
   contact visible/in-range to the selected squad: Focus ready confirms acceptance.
   Lost sight shows waiting and AUTO may choose another locally eligible target.
   Observe stationary amber last-seen markers, rather than moving hidden models.
3. SAVE & CAMPAIGN, restart, LOAD and OPEN TACTICAL BATTLE. Confirm queued paths,
   fire preferences/modes and any remaining wait are retained. Finish the battle
   and inspect both sides' report and campaign effects before APPLY & CAMPAIGN.
4. In the unlocked campaign, order the withdrawn formation into its adjacent
   opponent's sector and RESOLVE TURN for a fresh second battle. Confirm a new ID
   with prior losses/history retained. Save/restart/resume and apply battle 2.

The automated two-battle test also rejects stale and duplicate result application
and existing regressions cover save-write rollback. Linux checks/rendering do
not establish Windows input/performance or realistic combat fidelity. No fatigue,
individual weapons, area fire, formation tactics or cover/flanking planner yet.

## Five-step batch: codex/opponent-contact-reaction — 2026-10-11

- Ready for review; draft PR #21, base codex/timed-movement-pauses.
- Tested code: 72493794c5ea0ac73fbace9bfdc7fb4c9eb40de4.
- Full local Godot suite, 26 terrain tests and diff check passed.
- CI https://github.com/Austin-Ellefson/Wargame/actions/runs/38147734045 succeeded.
- Inspected artifact 11705009344: Combined fourteen Godot checks and 26 terrain tests passed. Inspected queued routes, preferred-target shot/HUNT execution, WAIT 12s with real firing, and readable completed report. UI regression proves the observed red squad stayed at its firing position; logic covers local/shared/hidden isolation, ammo/resume, blocked LOS, V8 preservation and real disk restart.
- Frozen milestone preserved; no Windows or Combat Mission fidelity validation.
- Next: cover-aware opponent movement using deterministic terrain and local knowledge.
