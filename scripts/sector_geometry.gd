extends RefCounted


static func center(map_data: Dictionary, sector: Vector2i) -> Dictionary:
    var rows := int(map_data.get("rows", 0))
    var columns := int(map_data.get("columns", 0))
    if rows <= 0 or columns <= 0:
        return {}
    if sector.x < 0 or sector.y < 0 or sector.x >= columns or sector.y >= rows:
        return {}

    var bounds: Dictionary = map_data.get("geographic_bounds", {})
    for key in ["northwest_lat", "northwest_lon", "southeast_lat", "southeast_lon"]:
        if not bounds.has(key):
            return {}
    var north := float(bounds["northwest_lat"])
    var west := float(bounds["northwest_lon"])
    var south := float(bounds["southeast_lat"])
    var east := float(bounds["southeast_lon"])
    if not (is_finite(north) and is_finite(south) and is_finite(west) and is_finite(east)):
        return {}
    if north <= south or west >= east or south < -90 or north > 90 or west < -180 or east > 180:
        return {}

    # Rows run south from the northwest corner. Half a cell selects its center.
    # This is a uniform geographic grid; a projected metric grid will replace it.
    return {
        "center_lat": lerpf(north, south, (sector.y + 0.5) / rows),
        "center_lon": lerpf(west, east, (sector.x + 0.5) / columns),
        "coordinate_system": "EPSG:4326",
        "center_method": "placeholder_sector_center"
    }
