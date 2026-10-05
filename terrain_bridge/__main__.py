"""Usage: python -m terrain_bridge battle.json [--fetch] [--dem file.tif]."""

import argparse
import json
import os
import sys
from pathlib import Path


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description="Prepare a battlefield manifest and aligned terrain for CMAutoEditor.")
    result.add_argument("battle", nargs="?", type=Path, help="Godot battle export JSON")
    result.add_argument("--latest", action="store_true", help="Use the newest export in Godot's default user-data folder")
    result.add_argument("--output", type=Path, default=Path("terrain_output"), help="Parent output directory")
    result.add_argument("--fetch", action="store_true", help="Fetch both OSM and Copernicus GLO-30 data")
    result.add_argument("--fetch-osm", action="store_true", help="Fetch OSM only")
    result.add_argument("--fetch-dem", action="store_true", help="Fetch Copernicus GLO-30 only")
    result.add_argument("--osm", type=Path, help="Use a supplied WGS84 GeoJSON file")
    result.add_argument("--dem", type=Path, action="append", help="Use a supplied elevation GeoTIFF (repeat for adjacent tiles)")
    result.add_argument("--overwrite", action="store_true", help="Rebuild this battle's generated files, retaining unrelated files")
    return result


def latest_export() -> Path:
    if sys.platform == "win32":
        directory = Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming"))) / "Godot/app_userdata/Ukraine Wargame/battle_exports"
    elif sys.platform == "darwin":
        directory = Path.home() / "Library/Application Support/Godot/app_userdata/Ukraine Wargame/battle_exports"
    else:
        directory = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "godot/app_userdata/Ukraine Wargame/battle_exports"
    exports = list(directory.glob("*.json"))
    if not exports:
        raise ValueError(f"No battle exports in {directory}. Trigger contact in Godot first, or pass a JSON path.")
    return max(exports, key=lambda path: path.stat().st_mtime_ns)


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, allow_nan=False) + "\n", encoding="utf-8")


GENERATED_FILES = ["manifest.json", "battlefield.geojson", "overpass_query.txt", "osm.geojson", "osm_raw.json",
                   "dem_8m.tif", "elevations.csv", "preview.png", "preview.html", "CMAUTOEDITOR.md", "ATTRIBUTION.txt"]


def run(args) -> int:
    from .adapter import write_guide
    from .preview import write_preview
    from .request import Battlefield, BridgeError, footprint, read_json
    from .sources import (COPERNICUS_NOTICE, COPERNICUS_LIABILITY, copernicus_tiles, fetch_osm, overpass_query, prepare_dem,
                          supplied_osm, timestamp, validate_osm, write_elevations)

    if bool(args.battle) == bool(args.latest):
        raise BridgeError("Provide one battle JSON path or --latest.")
    if args.osm and (args.fetch or args.fetch_osm):
        raise BridgeError("Choose --osm or OSM fetching, not both.")
    if args.dem and (args.fetch or args.fetch_dem):
        raise BridgeError("Choose --dem or DEM fetching, not both.")
    battle_path = args.battle or latest_export()
    payload = read_json(battle_path)
    field = Battlefield.from_payload(payload)
    raw_directory = args.output / field.battle_id
    if raw_directory.is_symlink():
        raise BridgeError("Output must not be a symbolic link.")
    directory = raw_directory.resolve()
    if directory.exists() and any(directory.iterdir()) and not args.overwrite:
        raise BridgeError(f"Output exists: {directory}. Use --overwrite to rebuild generated files.")
    directory.mkdir(parents=True, exist_ok=True)
    (args.output / ".gdignore").touch(exist_ok=True)
    if args.overwrite:
        input_paths = {path.resolve() for path in [battle_path, *([args.osm] if args.osm else []), *(args.dem or [])]}
        for filename in GENERATED_FILES:
            if (directory / filename).resolve() not in input_paths:
                (directory / filename).unlink(missing_ok=True)
    manifest = field.manifest()
    manifest["created_at"] = timestamp()
    manifest["battle_export"] = str(battle_path.resolve())
    manifest["status"] = "planned"
    manifest["dem_download_candidates"] = copernicus_tiles(field)
    write_json(directory / "battlefield.geojson", footprint(field))
    (directory / "overpass_query.txt").write_text(overpass_query(field), encoding="utf-8")
    errors = []
    osm = None
    elevations = None
    if args.osm or args.fetch or args.fetch_osm:
        print("Preparing OSM features...", flush=True)
        try:
            if args.osm:
                osm, info = supplied_osm(args.osm)
            else:
                osm, raw, info = fetch_osm(field)
                write_json(directory / "osm_raw.json", raw)
            info["acquisition"] = info.pop("status")
            info.update(validate_osm(osm, field))
            info.update({"status": "ready", "file": "osm.geojson"})
            write_json(directory / "osm.geojson", osm)
            manifest["data"]["osm"] = info
            if info["feature_count"] == 0:
                manifest["warnings"].append("OSM returned zero features; verify whether source coverage is complete.")
        except BridgeError as exc:
            osm = None
            manifest["data"]["osm"] = {"status": "failed", "error": str(exc)}
            errors.append(str(exc))
    if args.dem or args.fetch or args.fetch_dem:
        print("Preparing elevation grid...", flush=True)
        try:
            inputs = [str(path.resolve()) for path in args.dem] if args.dem else copernicus_tiles(field)
            elevations, info = prepare_dem(field, inputs, directory / "dem_8m.tif", args.output / ".dem_cache")
            info.update(write_elevations(elevations, directory / "elevations.csv"))
            info.update({"status": "ready", "provider": "supplied GeoTIFF" if args.dem else "Copernicus DEM GLO-30 Public (2021 release)",
                         "acquisition": "provided" if args.dem else "downloaded", "prepared_at": timestamp()})
            if not args.dem:
                info.update({"license_url": "https://dataspace.copernicus.eu/explore-data/data-collections/copernicus-contributing-missions/collections-description/COP-DEM",
                             "attribution": COPERNICUS_NOTICE, "distribution_notice": COPERNICUS_LIABILITY})
            manifest["data"]["dem"] = info
        except BridgeError as exc:
            elevations = None
            manifest["data"]["dem"] = {"status": "failed", "error": str(exc)}
            errors.append(str(exc))
    if errors:
        manifest["status"] = "incomplete"
    elif all(info["status"] == "ready" for info in manifest["data"].values()):
        manifest["status"] = "prepared"
    write_guide(field, directory, manifest)
    write_preview(field, directory, manifest, elevations, osm)
    write_json(directory / "manifest.json", manifest)
    attribution = ["Prepared sources and provenance are recorded in manifest.json."]
    if manifest["data"]["osm"].get("acquisition") == "downloaded":
        attribution += ["© OpenStreetMap contributors. ODbL 1.0. https://www.openstreetmap.org/copyright"]
    if manifest["data"]["dem"].get("acquisition") == "downloaded":
        attribution += [COPERNICUS_NOTICE, COPERNICUS_LIABILITY,
                        "Resampled to an 8 m grid; CSV heights use the offset recorded in manifest.json.",
                        manifest["data"]["dem"]["license_url"]]
    if args.dem or args.osm:
        attribution += ["User-supplied inputs: verify their original attribution, license, vertical units, and capture date."]
    (directory / "ATTRIBUTION.txt").write_text("\n".join(attribution) + "\n", encoding="utf-8")
    print(f"{manifest['status'].upper()}: {directory}\nPreview: {directory / 'preview.html'}", flush=True)
    for error in errors:
        print(error, file=sys.stderr)
    return 1 if errors else 0


def main(argv=None) -> int:
    args = parser().parse_args(argv)
    try:
        return run(args)
    except ImportError as exc:
        print(f"Missing bridge dependency: {exc}. Run setup_terrain_bridge.cmd or install terrain_bridge/requirements.txt.", file=sys.stderr)
        return 2
    except (ValueError, OSError) as exc:
        print(f"Terrain bridge: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
