"""Describe the verified external editor handoff without launching UI automation."""

from pathlib import Path

from .request import Battlefield

UPSTREAM_COMMIT = "c219c67c9cd8c3dd1bff0eaf3d2e49687082cf70"


def command_arguments(field: Battlefield) -> dict:
    return {
        "osm_converter": ["osm2cm.exe", "-i", "osm.geojson", "-c", "default_osm_config_cmbs.json",
                          "-o", "terrain.csv", "-p", "black_sea", "-b", str(field.epsg),
                          *[str(value) for value in field.bounds]],
        "elevation_editor": ["cmautoeditor.exe", "-i", "elevations.csv", "-p", "black_sea", "-c", "15"],
        "terrain_editor": ["cmautoeditor.exe", "-i", "terrain.csv", "-p", "black_sea", "-c", "15",
                           "--start-size-from-file"],
    }


def write_guide(field: Battlefield, directory: Path, manifest: dict) -> None:
    args = command_arguments(field)
    bbox = " ".join([str(field.epsg), *map(str, field.bounds)])
    # cmd.exe execution remains an explicit action in the Windows editor session.
    content = f'''# {field.battle_id}: CMAutoEditor handoff

## Package status

OSM: **{manifest['data']['osm']['status']}**. DEM: **{manifest['data']['dem']['status']}**.
Neither this bridge nor its preview creates a playable Combat Mission scenario.
If either source is pending or failed, obtain that source and rebuild this package first.

## Install the separate Windows editor tool

Download the Windows release linked from https://github.com/DerButschi/CMAutoEditor
and extract its entire package, including its configuration files and profiles.
The flags below were checked against source commit `{UPSTREAM_COMMIT}`. If your
release differs, confirm them with `osm2cm.exe --help` and `cmautoeditor.exe --help`.
The project does not bundle CMAutoEditor or depend on its old Python environment.

## Convert surface features

Open Command Prompt in this terrain package folder. Replace `C:\\Tools\\CMAutoEditor`
with the folder where you extracted the tool. Keep the configuration from that tool.

```bat
"C:\\Tools\\CMAutoEditor\\osm2cm.exe" -i "osm.geojson" -c "C:\\Tools\\CMAutoEditor\\default_osm_config_cmbs.json" -o "terrain.csv" -p black_sea -b {bbox}
```

The DEM has already been resampled and written to `elevations.csv`; do not run
`geotiff2cm` again. Using the same projected bounds for OSM keeps roads/buildings
aligned with elevations. The bounds are left, bottom, right, top in UTM meters.
Check that the surface converter also reports {field.cells} by {field.cells} cells.
Its building models and terrain tiles approximate source geometry.

## Place elevations through the CMBS scenario editor

1. Create a **new** blank scenario in Combat Mission: Black Sea. Select its map
   editor and Elevation / Direct mode. Follow CMAutoEditor's screen setup guidance.
2. Run this command, then focus CMBS during the 15-second countdown:

```bat
"C:\\Tools\\CMAutoEditor\\cmautoeditor.exe" -i "elevations.csv" -p black_sea -c 15
```

3. Inspect the hills and map dimensions. Save a terrain-only scenario before the next pass.

## Place surface features

Keep the same generated map and use the editor mode required by CMAutoEditor for
terrain placement. Run the surface pass, then focus CMBS during the countdown:

```bat
"C:\\Tools\\CMAutoEditor\\cmautoeditor.exe" -i "terrain.csv" -p black_sea -c 15 --start-size-from-file
```

Inspect roads, buildings, forests, water, alignment, and map dimensions before
saving. Correct unsupported tiles, bridges, OSM omissions, and unusual buildings
manually. `--start-size-from-file` assumes the first pass left the same-sized map.
The upstream automation can adjust final grid dimensions; inspect its result.

CMAutoEditor operates by sending mouse/keyboard input. Keep CMBS focused while
it runs. Its documented failsafe is moving the mouse into a screen corner.
The bridge never launches that automation itself.

## Finish the playable battle manually

Add forces, objectives, setup zones, time/weather, and briefing from the campaign
export. Battle-result import is still a later milestone. Saving the map in CMBS
does not automatically resume the operational campaign.

## Source detail

The requested map is {field.side_m} by {field.side_m} UTM meters on 8 m cells.
UTM grid north differs slightly from true north. The grid center was snapped by
at most 4 m in each projected axis. `manifest.json` records both centers.
DEM heights in `dem_8m.tif` preserve source altitude. The CSV adds a recorded
constant height offset to retain relief within a convenient positive editor range.
Check `cm_height_offset_m` in the manifest. The 20..999 m bridge limit is a
prototype export limit, not a claim about all Combat Mission editor versions.

Copernicus GLO-30 is a roughly 30 m **surface** model, including vegetation and
structures. Interpolation to 8 m does not recover absent terrain detail. OSM may
omit features or reflect a different date than a campaign scenario.
'''
    (directory / "CMAUTOEDITOR.md").write_text(content, encoding="utf-8")
    manifest["cmautoeditor"] = {"upstream": "https://github.com/DerButschi/CMAutoEditor",
                               "verified_source_commit": UPSTREAM_COMMIT, "arguments": args,
                               "execution": "manual Windows editor handoff; never auto-launched"}
