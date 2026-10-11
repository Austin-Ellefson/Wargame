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
2. Standing/crouched/prone posture with movement, observation and protection tradeoffs.
3. Squad weapon roles and fire cadence, ammunition and bounded casualty accounting.
4. Acquisition delay and command/communication limits; no hidden target tracking.
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
