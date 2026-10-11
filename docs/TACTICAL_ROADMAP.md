# Combat Mission-inspired tactical development

The user asked to keep developing toward Combat Mission-like battles on 2026-10-11.
The target is meaningful combined-arms WEGO play, with durable campaign outcomes.
This ledger describes our development direction; it is not a claim of product parity
or an agreed commercial release acceptance checklist. Follow tested descendants
in LOOP_FEEDBACK_MILESTONE; never build on failed checks or overwrite ready downloads.

## Working foundation

Repeatable campaign/contact/battle/result loop, two-battle restart regression,
visible shots and personnel/ammunition/suppression feedback, battle reports,
local spotting and remembered contacts, MOVE/QUICK/HUNT, fire preferences,
queued routes and pauses, pinning, local opponent reaction, cover-aware routes
and separated covered capture positions. Fatigue and morale-driven withdrawal/rally are implemented on subsequent tested descendants.

## Next infantry increments

1. Validate and refine morale retreat/rally with user playtests; add leaders/C2 later.
2. Standing/crouched/prone posture with movement, observation and protection tradeoffs: implemented on tested codex/infantry-posture PR #26 (v14); playtest tuning and transition delays remain future work.
3. Squad weapon roles and fire cadence, ammunition and bounded casualty accounting: implemented on tested codex/infantry-fire-profiles PR #27 (v15). Individual weapon inventories and reloads remain future work.
4. Local acquisition delay: implemented on tested codex/spotting-acquisition PR #28 (v16). Five-second movement response implemented on tested codex/movement-command-response PR #29 (v17). Delayed shared-contact reports and selected local visibility are implemented on tested codex/delayed-contact-reports PR #30 (v18). Observer-level contact memory is next; leaders/radios remain future work and no hidden target tracking.
5. More credible opponent support, maneuver and withdrawal, using observed information.

## Larger milestones after infantry is stable

- Imported elevation used consistently for rendering, movement and line of sight;
  then buildings and terrain features with validated origin, units and orientation.
- Individual soldier/weapon visuals, movement and firing animations, spatial sound
  and readable low-level combat events, while preserving authoritative outcomes.
- Vehicles, crews, transport, armor/weapon interactions and compositional forces,
  with versioned saves and once-only campaign losses.
- Multiple fictional scenario types, deployment/briefing/victory conditions and
  practical scenario authoring; balanced campaigns and repeatable scenario tests.
- User Windows playtests, performance/accessibility work and presentation polish.

Each increment needs reviewable code, meaningful regression checks, full Godot
and terrain tests on one candidate, actual rendered execution/report evidence
for presentation changes, and exact disk continuation. Gameplay tuning and
visual inspection do not validate realistic military fidelity.
