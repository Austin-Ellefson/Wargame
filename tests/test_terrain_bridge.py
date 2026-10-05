"""Engine-export, GIS orientation, source errors, and offline end-to-end checks."""

import copy
import csv
import json
import io
from pathlib import Path

import numpy as np
import pytest
import rasterio
from pyproj import Transformer
from rasterio.transform import from_bounds, from_origin

from terrain_bridge.__main__ import main
from terrain_bridge.adapter import command_arguments
from terrain_bridge.request import Battlefield, BridgeError
from terrain_bridge.sources import (copernicus_tiles, fetch_osm, prepare_dem, validate_osm, write_elevations, download_tile)


@pytest.fixture
def payload():
    return json.loads((Path(__file__).parents[1] / "terrain_bridge/fixtures/battle_demo.json").read_text())


def create_raster(path, data, crs, transform, nodata=-9999):
    with rasterio.open(path, "w", driver="GTiff", height=data.shape[0], width=data.shape[1],
                       count=1, dtype="float32", crs=crs, transform=transform, nodata=nodata) as ds:
        ds.write(data.astype("float32"), 1)
        ds.set_band_unit(1, "m")


def test_metric_bounds_and_alignment(payload):
    field = Battlefield.from_payload(payload)
    left, bottom, right, top = field.bounds
    assert right - left == top - bottom == 2000
    assert field.cells == 250 and field.epsg == 32636
    assert all(value % 8 == 0 for value in field.bounds)
    cx, cy = Transformer.from_crs(4326, field.epsg, always_xy=True).transform(field.longitude, field.latitude)
    assert abs((left + right) / 2 - cx) <= 4
    assert abs((bottom + top) / 2 - cy) <= 4
    for lon, lat in field.ring_wgs84:
        x, y = Transformer.from_crs(4326, field.epsg, always_xy=True).transform(lon, lat)
        assert min(abs(x - left), abs(x - right)) < 1e-6
        assert min(abs(y - bottom), abs(y - top)) < 1e-6
    w, s, e, n = field.bbox_wgs84
    assert w < field.longitude < e and s < field.latitude < n
    args = command_arguments(field)["osm_converter"]
    assert args[args.index("-b") + 1:] == ["32636", *map(str, field.bounds)]


@pytest.mark.parametrize("key,value", [
    ("center_lat", None), ("center_lat", True), ("center_lat", "49.0"),
    ("center_lat", float("nan")), ("center_lat", 90), ("center_lon", 181),
    ("tactical_map_size_km", 0), ("tactical_map_size_km", 9),
    ("tactical_map_size_km", 2.001), ("coordinate_system", "EPSG:3857"),
])
def test_reject_bad_geography(payload, key, value):
    payload["terrain_request"][key] = value
    with pytest.raises(BridgeError):
        Battlefield.from_payload(payload)


@pytest.mark.parametrize("key,value", [("schema_version", 2), ("schema_version", True),
                                       ("battle_id", "../escape"), ("battle_id", "CON")])
def test_reject_bad_contract(payload, key, value):
    payload[key] = value
    with pytest.raises(BridgeError):
        Battlefield.from_payload(payload)


def test_geographic_reprojection_and_csv_orientation(payload, tmp_path):
    field = Battlefield.from_payload(payload)
    w, s, e, n = field.bbox_wgs84
    source = tmp_path / "geographic.tif"
    # The known geographic source slopes down toward the south.
    data = np.repeat(np.linspace(110, 10, 128)[:, None], 128, axis=1)
    create_raster(source, data, "EPSG:4326", from_bounds(w - .002, s - .002, e + .002, n + .002, 128, 128))
    raster_path = tmp_path / "dem.tif"
    heights, info = prepare_dem(field, [str(source)], raster_path)
    assert heights.shape == (250, 250) and info["coverage_percent"] == 100
    assert heights[0, 125] > heights[-1, 125] + 70
    with rasterio.open(raster_path) as result:
        assert result.res == (8, 8) and result.crs.to_epsg() == 32636
        assert tuple(result.bounds) == field.bounds
    details = write_elevations(heights, tmp_path / "elevations.csv")
    records = list(csv.DictReader((tmp_path / "elevations.csv").open()))
    assert len(records) == 62500
    southwest = records[0]
    northwest = records[-250]
    assert (southwest["x"], southwest["y"]) == ("0", "0")
    assert int(northwest["z"]) > int(southwest["z"]) + 70
    assert 20 <= details["minimum_cm_height"] <= 21
    assert int(southwest["z"]) - details["cm_height_offset_m"] == pytest.approx(float(heights[-1, 0]), abs=.51)


def test_missing_dem_coverage_and_crs_rejected(payload, tmp_path):
    field = Battlefield.from_payload(payload)
    left, bottom, right, top = field.bounds
    missing = tmp_path / "missing.tif"
    grid = np.full((250, 250), 50, dtype="float32")
    grid[:10, :10] = -9999
    create_raster(missing, grid, "EPSG:32636", from_origin(left, top, 8, 8))
    with pytest.raises(BridgeError, match="NoData"):
        prepare_dem(field, [str(missing)], tmp_path / "out.tif")
    unknown = tmp_path / "unknown.tif"
    create_raster(unknown, grid, None, from_origin(left, top, 8, 8))
    with pytest.raises(BridgeError, match="CRS"):
        prepare_dem(field, [str(unknown)], tmp_path / "out.tif")


def test_cm_height_limit():
    with pytest.raises(BridgeError, match="relief"):
        write_elevations(np.array([[0, 2000]], dtype="float32"), Path("never_written.csv"))


def test_osm_features_and_wrong_location(payload):
    field = Battlefield.from_payload(payload)
    geojson = {"type": "FeatureCollection", "features": [{"type": "Feature", "properties": {"tags": {"building": "yes"}},
               "geometry": {"type": "Polygon", "coordinates": [[
                   [31.964, 49.022], [31.965, 49.022], [31.965, 49.023], [31.964, 49.023], [31.964, 49.022]
               ]]}}]}
    assert validate_osm(geojson, field)["intersecting_feature_count"] == 1
    wrong = copy.deepcopy(geojson)
    wrong["features"][0]["geometry"] = {"type": "Point", "coordinates": [0, 0]}
    with pytest.raises(BridgeError, match="intersects"):
        validate_osm(wrong, field)
    geojson["crs"] = {"type": "name", "properties": {"name": "EPSG:3857"}}
    with pytest.raises(BridgeError, match="WGS84"):
        validate_osm(geojson, field)


def test_overpass_errors_never_use_partial_data(payload, monkeypatch):
    class Response:
        def __enter__(self): return self
        def __exit__(self, *args): return False
        def read(self, limit): return b'{"elements": [], "remark": "runtime timeout"}'
    monkeypatch.setattr("terrain_bridge.sources.urlopen", lambda *args, **kwargs: Response())
    with pytest.raises(BridgeError, match="incomplete"):
        fetch_osm(Battlefield.from_payload(payload))


def test_overpass_geometry_and_tags_are_converted(payload, monkeypatch):
    raw = {"elements": [{"type": "way", "id": 1, "tags": {"building": "yes"}, "geometry": [
        {"lon": 31.964, "lat": 49.022}, {"lon": 31.965, "lat": 49.022},
        {"lon": 31.965, "lat": 49.023}, {"lon": 31.964, "lat": 49.023}, {"lon": 31.964, "lat": 49.022},
    ]}]}
    class Response(io.BytesIO):
        def __enter__(self): return self
        def __exit__(self, *args): self.close()
    monkeypatch.setattr("terrain_bridge.sources.urlopen", lambda *args, **kwargs: Response(json.dumps(raw).encode()))
    field = Battlefield.from_payload(payload)
    converted, source, info = fetch_osm(field)
    assert validate_osm(converted, field)["intersecting_feature_count"] == 1
    assert converted["features"][0]["properties"]["tags"]["building"] == "yes"


def test_verified_dem_download_fallback_and_cache(payload, tmp_path, monkeypatch):
    field = Battlefield.from_payload(payload)
    source = tmp_path / "source.tif"
    create_raster(source, np.full((250, 250), 123.5), "EPSG:32636", from_origin(field.bounds[0], field.bounds[3], 8, 8))
    data = source.read_bytes()
    class Response(io.BytesIO):
        headers = {"Content-Length": str(len(data))}
        def __enter__(self): return self
        def __exit__(self, *args): self.close()
    monkeypatch.setattr("terrain_bridge.sources.urlopen", lambda *args, **kwargs: Response(data))
    real_open = rasterio.open
    def open_source(path, *args, **kwargs):
        if str(path).startswith("https://"):
            raise rasterio.errors.RasterioIOError("Synthetic GDAL TLS error")
        return real_open(path, *args, **kwargs)
    monkeypatch.setattr("terrain_bridge.sources.rasterio.open", open_source)
    url = copernicus_tiles(field)[0]
    heights, info = prepare_dem(field, [url], tmp_path / "first.tif", tmp_path / "cache")
    assert np.allclose(heights, 123.5)
    assert info["sources"][0]["transfer"] == "verified HTTPS full tile download"
    monkeypatch.setattr("terrain_bridge.sources.urlopen", lambda *args, **kwargs: pytest.fail("Cached tile should not download again"))
    heights, info = prepare_dem(field, [url], tmp_path / "second.tif", tmp_path / "cache")
    assert info["sources"][0]["transfer"] == "verified HTTPS tile cache"


def test_partial_tile_download_never_becomes_cache(tmp_path, monkeypatch):
    class Response(io.BytesIO):
        headers = {"Content-Length": "100"}
        def __enter__(self): return self
        def __exit__(self, *args): self.close()
    monkeypatch.setattr("terrain_bridge.sources.urlopen", lambda *args, **kwargs: Response(b"incomplete"))
    path = tmp_path / "tile.tif"
    with pytest.raises(BridgeError, match="incomplete"):
        download_tile("https://example.invalid/tile.tif", path)
    assert not path.exists() and not list(tmp_path.glob("*.partial"))


def test_degree_boundary_dem_uses_adjacent_tiles(payload):
    payload["terrain_request"].update(center_lat=49, center_lon=32)
    urls = copernicus_tiles(Battlefield.from_payload(payload))
    assert len(urls) == 4
    assert any("N48_00_E031" in url for url in urls)
    assert any("N49_00_E032" in url for url in urls)


def test_offline_plan_pending_and_rebuild_preserves_unrelated_files(payload, tmp_path):
    battle = tmp_path / "battle.json"
    battle.write_text(json.dumps(payload))
    root = tmp_path / "output"
    assert main([str(battle), "--output", str(root)]) == 0
    package = root / "T003_B2"
    manifest = json.loads((package / "manifest.json").read_text())
    assert manifest["status"] == "planned"
    assert manifest["data"]["osm"]["status"] == manifest["data"]["dem"]["status"] == "pending"
    assert not (package / "dem_8m.tif").exists()
    assert not (package / "elevations.csv").exists()
    assert (package / "preview.html").exists() and (package / "battlefield.geojson").exists()
    (package / "my_notes.txt").write_text("Keep this")
    assert main([str(battle), "--output", str(root)]) == 2
    assert main([str(battle), "--output", str(root), "--overwrite"]) == 0
    assert (package / "my_notes.txt").read_text() == "Keep this"


def test_full_supplied_pipeline_and_failed_input_status(payload, tmp_path):
    field = Battlefield.from_payload(payload)
    battle = tmp_path / "battle.json"
    battle.write_text(json.dumps(payload))
    dem = tmp_path / "source.tif"
    create_raster(dem, np.full((250, 250), 100, dtype="float32"), "EPSG:32636", from_origin(field.bounds[0], field.bounds[3], 8, 8))
    osm = tmp_path / "osm.geojson"
    osm.write_text(json.dumps({"type": "FeatureCollection", "features": []}))
    root = tmp_path / "output"
    args = [str(battle), "--output", str(root), "--osm", str(osm), "--dem", str(dem)]
    assert main(args) == 0
    package = root / "T003_B2"
    manifest = json.loads((package / "manifest.json").read_text())
    assert manifest["status"] == "prepared"
    assert manifest["cm_scenario"]["status"] == "not_created"
    assert (package / "elevations.csv").exists()
    # Rebuilding from the package's own supplied inputs must not delete those inputs.
    assert main([str(battle), "--output", str(root), "--osm", str(package / "osm.geojson"),
                 "--dem", str(package / "dem_8m.tif"), "--overwrite"]) == 0
    assert (package / "elevations.csv").exists()
    assert main([str(battle), "--output", str(root), "--dem", str(tmp_path / "missing.tif"), "--overwrite"]) == 1
    manifest = json.loads((package / "manifest.json").read_text())
    assert manifest["data"]["dem"]["status"] == "failed" and manifest["status"] == "incomplete"
    assert not (package / "elevations.csv").exists()
