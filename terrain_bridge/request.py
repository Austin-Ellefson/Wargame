"""Validate campaign exports and define a metric battlefield grid."""

import json
import math
import re
from dataclasses import dataclass
from pathlib import Path

from pyproj import Transformer


class BridgeError(ValueError):
    """An input or data source cannot safely produce a terrain package."""


def read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise BridgeError(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise BridgeError(f"{path} must contain a JSON object.")
    return value


def number(value: object, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise BridgeError(f"{label} must be a JSON number.")
    try:
        value = float(value)
    except OverflowError as exc:
        raise BridgeError(f"{label} is outside numeric range.") from exc
    if not math.isfinite(value):
        raise BridgeError(f"{label} must be finite.")
    return float(value)


@dataclass(frozen=True)
class Battlefield:
    battle_id: str
    latitude: float
    longitude: float
    side_m: int
    epsg: int
    bounds: tuple[float, float, float, float]
    bbox_wgs84: tuple[float, float, float, float]
    ring_wgs84: tuple[tuple[float, float], ...]
    center_method: str

    @property
    def cells(self) -> int:
        return self.side_m // 8

    @classmethod
    def from_payload(cls, payload: dict) -> "Battlefield":
        if type(payload.get("schema_version")) is not int or payload["schema_version"] != 1:
            raise BridgeError("Unsupported schema_version; expected integer 1.")
        battle_id = payload.get("battle_id")
        if not isinstance(battle_id, str) or not re.fullmatch(r"T[0-9]{3,}_[A-Z][1-9][0-9]*", battle_id):
            raise BridgeError("battle_id must have the campaign form T003_B2.")
        request = payload.get("terrain_request")
        if not isinstance(request, dict):
            raise BridgeError("Missing terrain_request object.")
        if request.get("coordinate_system") != "EPSG:4326":
            raise BridgeError("coordinate_system must be EPSG:4326.")
        lat = number(request.get("center_lat"), "center_lat")
        lon = number(request.get("center_lon"), "center_lon")
        if not -80 <= lat <= 84 or not -180 < lon < 180:
            raise BridgeError("Center must be within UTM coverage (-80..84 latitude, -180..180 longitude).")
        size = number(request.get("tactical_map_size_km"), "tactical_map_size_km") * 1000
        if not 256 <= size <= 8000 or not math.isclose(size / 8, round(size / 8), abs_tol=1e-8):
            raise BridgeError("Tactical side must be 256..8000 meters and divisible by the 8 m CM grid.")
        # UTM measures meters locally; geographic degrees must never be used as meters.
        zone = min(60, max(1, math.floor((lon + 180) / 6) + 1))
        epsg = (32600 if lat >= 0 else 32700) + zone
        to_metric = Transformer.from_crs(4326, epsg, always_xy=True)
        to_geo = Transformer.from_crs(epsg, 4326, always_xy=True)
        x, y = to_metric.transform(lon, lat)
        side = round(size)
        # Integer 8 m origins also avoid floor-rounding an upstream 250-cell grid to 249.
        left = round((x - side / 2) / 8) * 8
        bottom = round((y - side / 2) / 8) * 8
        bounds = (left, bottom, left + side, bottom + side)
        bbox = to_geo.transform_bounds(*bounds, densify_pts=21)
        if bbox[0] >= bbox[2] or bbox[0] <= -180 or bbox[2] >= 180 or bbox[1] < -80 or bbox[3] > 84:
            raise BridgeError("Battlefield crosses the dateline or exceeds supported UTM latitude coverage.")
        ring = tuple(to_geo.transform(px, py) for px, py in [
            (left, bottom), (left + side, bottom), (left + side, bottom + side),
            (left, bottom + side), (left, bottom),
        ])
        return cls(battle_id, lat, lon, side, epsg, bounds, bbox, ring,
                   str(request.get("center_method", "unspecified")))

    def manifest(self) -> dict:
        to_geo = Transformer.from_crs(self.epsg, 4326, always_xy=True)
        left, bottom, right, top = self.bounds
        lon, lat = to_geo.transform((left + right) / 2, (bottom + top) / 2)
        return {
            "manifest_version": 1,
            "battle_id": self.battle_id,
            "requested_center": {"latitude": self.latitude, "longitude": self.longitude,
                                 "coordinate_system": "EPSG:4326", "method": self.center_method},
            "grid": {"crs": f"EPSG:{self.epsg}", "bounds_order": ["left", "bottom", "right", "top"],
                     "bounds": list(self.bounds), "width_m": self.side_m, "height_m": self.side_m,
                     "cell_size_m": 8, "columns": self.cells, "rows": self.cells,
                     "orientation": "UTM grid north; x east, y north from southwest",
                     "aligned_center": {"latitude": lat, "longitude": lon},
                     "center_shift_max_m_per_axis": 4},
            "bbox_wgs84": dict(zip(["west", "south", "east", "north"], self.bbox_wgs84)),
            "data": {"osm": {"status": "pending"}, "dem": {"status": "pending"}},
            "cm_scenario": {"status": "not_created", "profile": "black_sea"},
            "warnings": ["Engagement center is a campaign placeholder, not an actual detected contact.",
                         "An 8 m output grid does not add detail to coarser source elevation data.",
                         "Prepared data still requires map editing and checking in Windows CMBS."],
        }


def footprint(field: Battlefield) -> dict:
    return {"type": "FeatureCollection", "features": [{"type": "Feature",
            "properties": {"battle_id": field.battle_id, "side_m": field.side_m,
                           "metric_crs": f"EPSG:{field.epsg}"},
            "geometry": {"type": "Polygon", "coordinates": [field.ring_wgs84]}}]}
