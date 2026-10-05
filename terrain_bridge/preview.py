"""Render a static terrain inspection image, without fetching map tiles."""

from html import escape
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from pyproj import Transformer
from shapely.geometry import shape
from shapely.ops import transform

from .request import Battlefield


def write_preview(field: Battlefield, directory: Path, manifest: dict,
                  elevations: np.ndarray | None, osm: dict | None) -> None:
    width = 750
    if elevations is None:
        canvas = Image.new("RGB", (width, width), "#273745")
    else:
        normalized = (elevations - elevations.min()) / max(float(np.ptp(elevations)), 1)
        stops = np.array([[44, 90, 99], [108, 144, 86], [190, 166, 100], [234, 226, 201]])
        scaled = normalized * (len(stops) - 1)
        lower = np.minimum(scaled.astype(int), len(stops) - 2)
        fraction = (scaled - lower)[..., None]
        colors = (stops[lower] * (1 - fraction) + stops[lower + 1] * fraction).astype("uint8")
        canvas = Image.fromarray(colors).resize((width, width), Image.Resampling.BILINEAR)
    draw = ImageDraw.Draw(canvas)
    to_grid = Transformer.from_crs(4326, field.epsg, always_xy=True)
    left, bottom, right, top = field.bounds

    def pixels(coordinates):
        return [((point[0] - left) / field.side_m * width,
                 (top - point[1]) / field.side_m * width) for point in coordinates]

    def render(geometry, tags):
        kind = geometry.geom_type
        if kind in ("MultiPolygon", "MultiLineString", "GeometryCollection", "MultiPoint"):
            for member in geometry.geoms:
                render(member, tags)
        elif kind == "Polygon":
            color = "#dfa87c" if "building" in tags else "#76a0cb" if tags.get("natural") == "water" else "#386b45"
            draw.line(pixels(geometry.exterior.coords), fill=color, width=2)
            for hole in geometry.interiors:
                draw.line(pixels(hole.coords), fill=color, width=2)
        elif kind == "LineString":
            color = "#82c1e6" if "waterway" in tags else "#faf0d5" if "highway" in tags else "#c9cbd0"
            draw.line(pixels(geometry.coords), fill=color, width=3)

    if osm:
        for feature in osm["features"]:
            properties = feature["properties"]
            tags = properties.get("tags", properties)
            render(transform(to_grid.transform, shape(feature["geometry"])), tags)
    for offset in (0, width // 4, width // 2, width * 3 // 4, width - 1):
        draw.line([(offset, 0), (offset, width)], fill="#ffffff", width=1)
        draw.line([(0, offset), (width, offset)], fill="#ffffff", width=1)
    draw.rectangle((8, 8, 185, 35), fill="#192532")
    draw.text((15, 16), "UTM GRID NORTH ^", fill="white")
    canvas.save(directory / "preview.png")
    status = escape(" | ".join(f"{key.upper()}: {value['status']}" for key, value in manifest["data"].items()))
    warnings = "".join(f"<li>{escape(warning)}</li>" for warning in manifest["warnings"])
    dem_info = manifest["data"]["dem"]
    credits = "".join(f"<p>{escape(info['attribution'])}</p>" for info in manifest["data"].values() if "attribution" in info)
    relief = (f"Elevation: {dem_info['minimum_elevation_m']:.1f} to {dem_info['maximum_elevation_m']:.1f} m"
              if "minimum_elevation_m" in dem_info else "Elevation is pending; the background is a placeholder.")
    html = f'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escape(field.battle_id)} terrain preview</title>
<style>body{{background:#17212c;color:#ecf1f5;font:16px system-ui;margin:24px auto;max-width:900px;padding:0 20px}}
img{{width:100%;max-width:750px;border:1px solid #77879a}}p,li{{line-height:1.6}}code{{color:#a7dbfb}}</style>
<h1>{escape(field.battle_id)} — terrain preparation</h1>
<p>{field.side_m} × {field.side_m} m · {field.cells} × {field.cells} cells · EPSG:{field.epsg}</p>
<p>{status}</p><p>{escape(relief)}</p><img src="preview.png" alt="Battlefield elevation colors with OSM feature outlines">
<p>Low elevation: blue-green; high elevation: tan. Roads: cream; buildings: orange; waterways: blue; other polygons: green.
Grid lines divide the map into quarters. This is a source-data preview, not a CMBS render.</p>
<ul>{warnings}</ul><p>Read <code>CMAUTOEDITOR.md</code> for the editor handoff.</p>
{credits}<p><a href="ATTRIBUTION.txt">Source notices</a></p></html>'''
    (directory / "preview.html").write_text(html, encoding="utf-8")
