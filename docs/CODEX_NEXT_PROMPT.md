# Next Codex Task

Continue the Ukraine Wargame Godot 4 prototype.

Current behavior:
- Campaign data loads from `data/campaign.json`.
- Units can be selected and ordered to an adjacent sector.
- Resolve Turn moves units.
- Opposing units in the same sector generate an in-memory CMBS battle payload.

Implement the following without replacing the existing campaign logic unnecessarily:

1. Create `scripts/battle_exporter.gd`.
2. When contact occurs, write the generated battle payload to `user://battle_exports/<battle_id>.json`.
3. Include a precise placeholder engagement center in the payload:
   - `center_lat`
   - `center_lon`
4. Add campaign-map metadata to `data/campaign.json`:
   - northwest latitude/longitude
   - southeast latitude/longitude
5. Convert sector X/Y into a geographic center coordinate.
6. Add an on-screen line showing the generated latitude/longitude.
7. Keep the code modular so the sector renderer can later be replaced by an actual Ukraine map.
8. Add clear comments only where they explain architecture or non-obvious math.

Definition of done:
- Project runs in Godot 4.
- Existing movement/contact loop still works.
- A battle contact produces a valid JSON export with geographic coordinates.
