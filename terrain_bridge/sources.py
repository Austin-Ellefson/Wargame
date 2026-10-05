"""Read supplied terrain or explicitly fetch public OSM and Copernicus data."""

import csv
import json
import math
import os
import ssl
import tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import numpy as np
import rasterio
from rasterio.transform import from_origin
from rasterio.warp import Resampling, reproject, transform_bounds
from shapely.geometry import box, shape

from .request import Battlefield, BridgeError, read_json

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
COPERNICUS_ROOT = "https://copernicus-dem-30m.s3.amazonaws.com"
COPERNICUS_NOTICE = (
    "produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and "
    "© Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS "
    "by the European Union and ESA; all rights reserved."
)
COPERNICUS_LIABILITY = (
    "The organisations in charge of the Copernicus programme by law or by delegation "
    "do not incur any liability for any use of the Copernicus WorldDEM-30."
)


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def overpass_query(field: Battlefield) -> str:
    w, s, e, n = field.bbox_wgs84
    # A small margin gives the converter context just outside the tactical window.
    bbox = f"{s - .002:.8f},{w - .003:.8f},{n + .002:.8f},{e + .003:.8f}"
    selectors = "\n".join(f'  nwr["{tag}"]({bbox});' for tag in
                          ["highway", "building", "landuse", "natural", "waterway", "railway", "leisure", "barrier"])
    return f"[out:json][timeout:45];\n(\n{selectors}\n);\nout body geom;\n"


def fetch_osm(field: Battlefield) -> tuple[dict, dict, dict]:
    import osm2geojson

    request = Request(OVERPASS_URL, data=urlencode({"data": overpass_query(field)}).encode(),
                      headers={"User-Agent": "UkraineWargameTerrainBridge/0.1", "Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urlopen(request, timeout=60) as response:
            raw = response.read(32 * 1024 * 1024 + 1)
        if len(raw) > 32 * 1024 * 1024:
            raise BridgeError("OSM response exceeds the 32 MiB bridge limit; use a smaller battlefield.")
        data = json.loads(raw)
        if not isinstance(data, dict) or not isinstance(data.get("elements"), list) or data.get("remark"):
            raise BridgeError(f"Overpass returned incomplete data: {data.get('remark', 'missing elements') if isinstance(data, dict) else 'invalid object'}")
        geojson = osm2geojson.json2geojson(data, raise_on_failure=True)
    except (HTTPError, URLError, TimeoutError, OSError, json.JSONDecodeError) as exc:
        raise BridgeError(f"OSM download failed: {exc}. Retry later or supply --osm a GeoJSON file.") from exc
    except (ValueError, TypeError, KeyError) as exc:
        raise BridgeError(f"OSM geometry conversion failed: {exc}. Check the source data before retrying.") from exc
    return geojson, data, {"status": "downloaded", "provider": "OpenStreetMap via Overpass",
        "endpoint": OVERPASS_URL, "retrieved_at": timestamp(),
        "osm_base_timestamp": data.get("osm3s", {}).get("timestamp_osm_base"),
        "attribution": "© OpenStreetMap contributors", "license": "ODbL 1.0",
        "license_url": "https://www.openstreetmap.org/copyright"}


def validate_osm(data: dict, field: Battlefield) -> dict:
    if data.get("type") != "FeatureCollection" or not isinstance(data.get("features"), list):
        raise BridgeError("OSM input must be a GeoJSON FeatureCollection, not raw Overpass JSON or OSM XML.")
    if "crs" in data:
        raise BridgeError("GeoJSON must use standard WGS84 coordinates without a legacy crs override.")
    extent = box(*field.bbox_wgs84)
    intersecting = 0
    for index, feature in enumerate(data["features"]):
        if not isinstance(feature, dict) or feature.get("type") != "Feature" or not isinstance(feature.get("properties"), dict):
            raise BridgeError(f"GeoJSON feature {index} lacks a Feature object or properties.")
        if not isinstance(feature["properties"].get("tags", feature["properties"]), dict):
            raise BridgeError(f"GeoJSON feature {index} tags must be an object.")
        try:
            geometry = shape(feature["geometry"])
        except (ValueError, TypeError, KeyError, AttributeError) as exc:
            raise BridgeError(f"Invalid geometry in GeoJSON feature {index}.") from exc
        if geometry.is_empty or not geometry.is_valid or not all(math.isfinite(v) for v in geometry.bounds):
            raise BridgeError(f"GeoJSON feature {index} has an empty, invalid, or non-finite geometry.")
        w, s, e, n = geometry.bounds
        if w < -180 or e > 180 or s < -90 or n > 90:
            raise BridgeError(f"GeoJSON feature {index} is outside WGS84 coordinate ranges.")
        intersecting += int(geometry.intersects(extent))
    if data["features"] and not intersecting:
        raise BridgeError("None of the GeoJSON features intersects this battlefield; check the source location.")
    return {"feature_count": len(data["features"]), "intersecting_feature_count": intersecting}


def copernicus_tiles(field: Battlefield) -> list[str]:
    w, s, e, n = field.bbox_wgs84
    # Tiny edge overlap is intentional: geographic raster pixel centers can straddle degree lines.
    urls = []
    for lat in range(math.floor(s), math.floor(n) + 1):
        for lon in range(math.floor(w), math.floor(e) + 1):
            ns = f"{'N' if lat >= 0 else 'S'}{abs(lat):02d}"
            ew = f"{'E' if lon >= 0 else 'W'}{abs(lon):03d}"
            tile = f"Copernicus_DSM_COG_10_{ns}_00_{ew}_00_DEM"
            urls.append(f"{COPERNICUS_ROOT}/{tile}/{tile}.tif")
    return urls


def download_tile(url: str, destination: Path) -> None:
    """Fallback for GDAL-specific HTTPS/proxy failures; urllib still verifies TLS."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        request = Request(url, headers={"User-Agent": "UkraineWargameTerrainBridge/0.1"})
        with urlopen(request, timeout=45) as response:
            size = int(response.headers.get("Content-Length", 0))
            if size > 256 * 1024 * 1024:
                raise BridgeError("Elevation tile exceeds the 256 MiB download limit.")
            with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".partial", delete=False) as output:
                temporary = Path(output.name)
                received = 0
                while chunk := response.read(1024 * 1024):
                    received += len(chunk)
                    if received > 256 * 1024 * 1024:
                        raise BridgeError("Elevation tile exceeds the 256 MiB download limit.")
                    output.write(chunk)
            if size and received != size:
                raise BridgeError("Elevation tile transfer was incomplete.")
        # Validate the downloaded file before allowing later runs to reuse it.
        with rasterio.open(temporary) as dataset:
            if dataset.crs is None or dataset.count != 1:
                raise BridgeError("Downloaded tile is not a georeferenced elevation raster.")
        temporary.replace(destination)
    except (HTTPError, URLError, OSError, TimeoutError) as exc:
        raise BridgeError(f"Verified HTTPS elevation download failed: {exc}") from exc
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


@contextmanager
def open_dem(filename: str, cache: Path | None):
    known_url = filename.startswith(COPERNICUS_ROOT + "/")
    cached = cache / filename.rsplit("/", 1)[-1] if known_url and cache else None
    if cached and cached.exists():
        with rasterio.open(cached) as dataset:
            yield dataset, "verified HTTPS tile cache"
        return
    try:
        dataset = rasterio.open(filename)
    except rasterio.errors.RasterioIOError:
        if not known_url:
            raise
        print("GDAL could not stream the tile; downloading through verified HTTPS...", flush=True)
        with tempfile.TemporaryDirectory(prefix="wargame-dem-") as scratch:
            local = cached or Path(scratch) / "source.tif"
            download_tile(filename, local)
            with rasterio.open(local) as dataset:
                yield dataset, "verified HTTPS full tile download"
        return
    with dataset:
        yield dataset, "GDAL COG streaming" if known_url else "local file"


def prepare_dem(field: Battlefield, inputs: list[str], destination: Path,
                cache_directory: Path | None = None) -> tuple[np.ndarray, dict]:
    left, bottom, right, top = field.bounds
    transform = from_origin(left, top, 8, 8)
    output = np.full((field.cells, field.cells), np.nan, dtype="float32")
    sources = []
    try:
        gdal_options = dict(GDAL_HTTP_TIMEOUT="30", GDAL_HTTP_MAX_RETRY="1", GDAL_HTTP_RETRY_DELAY="1",
                            GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR", CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif")
        # GDAL's bundled trust store can differ from Python's in managed environments.
        # Reuse a trusted CA file when available; never disable certificate verification.
        ca_file = (os.environ.get("GDAL_CURL_CA_BUNDLE") or os.environ.get("CURL_CA_BUNDLE")
                   or os.environ.get("SSL_CERT_FILE") or ssl.get_default_verify_paths().cafile)
        if ca_file:
            gdal_options["GDAL_CURL_CA_BUNDLE"] = ca_file
        with rasterio.Env(**gdal_options):
            for filename in inputs:
                with open_dem(filename, cache_directory) as (source, transfer):
                    if source.crs is None or source.count != 1:
                        raise BridgeError("DEM must have a CRS and exactly one elevation band.")
                    unit = source.units[0]
                    if unit is not None and unit.lower() not in ("m", "meter", "meters", "metre", "metres"):
                        raise BridgeError(f"DEM elevations must be in meters; found {unit!r}.")
                    source_bounds = transform_bounds(source.crs, f"EPSG:{field.epsg}", *source.bounds, densify_pts=21)
                    if not box(*source_bounds).intersects(box(*field.bounds)):
                        raise BridgeError("DEM does not intersect the requested battlefield.")
                    patch = np.full_like(output, np.nan)
                    reproject(source=rasterio.band(source, 1), destination=patch,
                              src_transform=source.transform, src_crs=source.crs, src_nodata=source.nodata,
                              dst_transform=transform, dst_crs=f"EPSG:{field.epsg}", dst_nodata=np.nan,
                              resampling=Resampling.bilinear, num_threads=2)
                    patch = patch * source.scales[0] + source.offsets[0]
                    valid = np.isfinite(patch)
                    output[valid] = patch[valid]
                    sources.append({"input": filename, "crs": str(source.crs), "transfer": transfer,
                                    "pixel_size_in_source_crs": list(source.res),
                                    "height_unit": unit or "meters assumed; verify supplied DEM"})
    except rasterio.errors.RasterioError as exc:
        raise BridgeError(f"DEM preparation failed: {exc}. Supply --dem a local elevation GeoTIFF if the public source is unavailable.") from exc
    missing = int(np.count_nonzero(~np.isfinite(output)))
    if missing:
        raise BridgeError(f"DEM has {missing} uncovered or NoData cells in this battlefield. A complete covering DEM is required; gaps are not filled with invented heights.")
    with rasterio.open(destination, "w", driver="GTiff", width=field.cells, height=field.cells,
                       count=1, dtype="float32", crs=f"EPSG:{field.epsg}", transform=transform,
                       nodata=-9999, compress="deflate") as dataset:
        dataset.write(output, 1)
        dataset.set_band_unit(1, "m")
    return output, {"sources": sources, "resampling": "bilinear", "coverage_percent": 100,
                    "minimum_elevation_m": float(output.min()), "maximum_elevation_m": float(output.max()),
                    "raster": destination.name}


def write_elevations(heights: np.ndarray, destination: Path) -> dict:
    # Keep relief but translate the vertical datum into a convenient positive CM range.
    # Absolute altitude is retained in dem_8m.tif and the recorded datum offset.
    offset = 20 - math.floor(float(heights.min()))
    translated = np.rint(heights + offset).astype(int)
    if translated.max() > 999:
        raise BridgeError("Terrain relief exceeds this prototype's 20..999 m editor export range.")
    rows, columns = heights.shape
    with destination.open("w", newline="", encoding="utf-8") as output:
        writer = csv.writer(output)
        writer.writerow(["x", "y", "z"])
        # Raster rows run south. CMAutoEditor's y index runs north from the southwest.
        for y in range(rows):
            for x in range(columns):
                writer.writerow([x, y, int(translated[rows - 1 - y, x])])
    return {"csv": destination.name, "rows": rows * columns, "cm_height_offset_m": offset,
            "cm_height_rule": "z = round(source_elevation_m + offset)",
            "minimum_cm_height": int(translated.min()), "maximum_cm_height": int(translated.max())}


def supplied_osm(path: Path) -> tuple[dict, dict]:
    return read_json(path), {"status": "provided", "input": str(path.resolve()),
                           "provider": "user-supplied GeoJSON; origin not independently verified"}
