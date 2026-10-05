# Ukraine Wargame

Prototype operational campaign layer intended to use **Combat Mission: Black Sea** as the tactical battle resolver.

## Phase 1 vertical slice

This starter project proves the core campaign loop:

1. Select an operational unit.
2. Order it one sector at a time.
3. Resolve the campaign turn.
4. Detect opposing units occupying the same sector.
5. Generate a tactical battle payload for a future CMBS integration layer.

The prototype deliberately uses a 4x4 abstract grid before adding a real Ukraine GIS map. That keeps campaign logic separate from rendering and terrain generation.

## Requirements

- Godot 4.x

## Run

Open `project.godot` in Godot and press **F6/F5**.

### Controls

- Left-click a unit token to select it.
- Left-click an adjacent sector to issue a movement order.
- Click **RESOLVE TURN** to execute orders simultaneously.
- If Ukrainian and Russian units occupy the same sector, a CMBS battle payload appears.

## Architecture direction

```text
Godot campaign layer
    |
    +-- campaign state / formations / turns
    +-- map + sectors
    +-- movement + supply + fog of war
    +-- battle detection
    |
    +--> battle_payload.json
             |
             v
Python GIS bridge
    +-- OpenStreetMap
    +-- DEM/elevation
    +-- battle bounding box
    +-- CMAutoEditor integration
             |
             v
Combat Mission: Black Sea
             |
             v
battle result import
             |
             v
Godot campaign state
```

## Next milestones

- Replace the abstract grid with a georeferenced map of Ukraine.
- Define sectors by latitude/longitude bounds rather than screen coordinates.
- Add operational movement costs by road/terrain.
- Add formation composition and persistent losses.
- Add a battle-export JSON file.
- Add a Python `terrain_bridge` that accepts battle coordinates and prepares OSM/DEM data for CMAutoEditor.
- Add battle-result import.

## Design rule

The campaign sector is **not** the CMBS tactical battlefield. A campaign sector may be 5–10 km across, while a contact inside that sector generates a smaller tactical window such as 2x2 km centered on the engagement location.
