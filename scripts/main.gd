extends Node2D

const SectorGeometry = preload("res://scripts/sector_geometry.gd")
const BattleExporter = preload("res://scripts/battle_exporter.gd")
const CampaignSave = preload("res://scripts/campaign_save.gd")
const CAMPAIGN_PATH := "res://data/campaign.json"
const GRID_ORIGIN := Vector2(70, 90)
const CELL_SIZE := Vector2(170, 125)
const SIDEBAR_X := 790.0

var initial_campaign: Dictionary = {}
var save_path: String = CampaignSave.SAVE_PATH
var campaign: Dictionary = {}
var units: Array = []
var selected_unit_id: String = ""
var pending_orders: Dictionary = {}
var battle_payload: Dictionary = {}
var battle_export_directory: String = BattleExporter.EXPORT_DIRECTORY
var battle_export_path: String = ""
var status_message := "Select a unit, then click an adjacent sector."

func _ready() -> void:
    campaign = _load_json(CAMPAIGN_PATH)
    initial_campaign = campaign.duplicate(true)
    units = campaign.get("units", []).duplicate(true)
    set_process_input(true)
    queue_redraw()

func _load_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("Missing campaign file: %s" % path)
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("Cannot read campaign: %s" % error_string(FileAccess.get_open_error()))
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("Campaign JSON is invalid.")
        return {}
    return parsed

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _handle_click(event.position)

func _handle_click(mouse_pos: Vector2) -> void:
    if _save_button().has_point(mouse_pos):
        _save_campaign()
        return
    if _load_button().has_point(mouse_pos):
        _load_campaign()
        return
    if _point_in_end_turn_button(mouse_pos):
        _resolve_turn()
        return

    var sector := _screen_to_sector(mouse_pos)
    if sector.x < 0:
        return

    var clicked_unit := _top_unit_in_sector(sector)

    if selected_unit_id == "":
        if not clicked_unit.is_empty():
            selected_unit_id = str(clicked_unit.get("id", ""))
            status_message = "Selected %s. Choose an adjacent sector." % clicked_unit.get("name", "Unit")
    else:
        var selected := _get_unit(selected_unit_id)
        if selected.is_empty():
            selected_unit_id = ""
            return

        if not clicked_unit.is_empty() and str(clicked_unit.get("id", "")) == selected_unit_id:
            selected_unit_id = ""
            status_message = "Selection cleared."
        elif _is_adjacent(selected.get("sector", {}), sector):
            pending_orders[selected_unit_id] = {"x": sector.x, "y": sector.y}
            status_message = "%s ordered to Sector %s." % [selected.get("name", "Unit"), _sector_label(sector)]
            selected_unit_id = ""
        else:
            status_message = "Units can move one sector per turn in this prototype."

    queue_redraw()

func _resolve_turn() -> void:
    battle_payload = {}
    battle_export_path = ""

    for unit_id in pending_orders.keys():
        var idx := _get_unit_index(str(unit_id))
        if idx == -1:
            continue
        units[idx]["sector"] = pending_orders[unit_id].duplicate(true)

    pending_orders.clear()
    campaign["turn"] = int(campaign.get("turn", 1)) + 1

    var battle := _detect_first_contact()
    if not battle.is_empty():
        battle_payload = _build_battle_payload(battle[0], battle[1])
        status_message = "CONTACT! Tactical battle generated for Sector %s." % battle_payload.get("sector", "?")
        var export_result: Dictionary = BattleExporter.write_payload(battle_payload, battle_export_directory)
        if export_result.get("ok", false):
            battle_export_path = str(export_result["path"])
            print("Battle exported: %s" % ProjectSettings.globalize_path(battle_export_path))
        else:
            status_message = "CONTACT! Export failed; see console."
            push_error(str(export_result.get("error", "Unknown export error.")))
    else:
        status_message = "Turn resolved. No opposing units share a sector."

    queue_redraw()

func _snapshot() -> Dictionary:
    return {
        "schema_version": CampaignSave.VERSION,
        "scenario_hash": JSON.stringify(initial_campaign).sha256_text(),
        "turn": campaign.get("turn", 1),
        "units": units.duplicate(true),
        "pending_orders": pending_orders.duplicate(true),
        "selected_unit_id": selected_unit_id,
        "battle_payload": battle_payload.duplicate(true),
        "battle_export_path": battle_export_path
    }

func _save_campaign() -> Dictionary:
    var result: Dictionary = CampaignSave.write(_snapshot(), initial_campaign, save_path)
    status_message = "Campaign saved." if result["ok"] else "Save failed: " + str(result["error"])
    queue_redraw()
    return result

func _load_campaign() -> Dictionary:
    var result: Dictionary = CampaignSave.read(initial_campaign, save_path)
    if result["ok"]:
        var snapshot: Dictionary = result["snapshot"]
        # Check the saved battle with the same builder used for live exports,
        # on a detached scene so a rejected save cannot mutate this campaign.
        var probe = get_script().new()
        probe.campaign = initial_campaign.duplicate(true)
        probe.campaign["turn"] = snapshot["turn"]
        probe.units = snapshot["units"].duplicate(true)
        var saved_battle: Dictionary = snapshot["battle_payload"]
        var contact: Array = probe._detect_first_contact()
        if not saved_battle.is_empty():
            if contact.is_empty() or saved_battle != JSON.parse_string(JSON.stringify(probe._build_battle_payload(contact[0], contact[1]))):
                result = {"ok": false, "error": "Saved battle does not match campaign contact."}
            elif snapshot["battle_export_path"] != "" and snapshot["battle_export_path"] != battle_export_directory.path_join(str(saved_battle["battle_id"]) + ".json"):
                result = {"ok": false, "error": "Saved battle export path is incompatible."}
        elif not contact.is_empty():
            result = {"ok": false, "error": "Save is missing the current contact battle."}
        probe.free()
        if result["ok"]:
            campaign = initial_campaign.duplicate(true)
            campaign["turn"] = int(snapshot["turn"])
            units = snapshot["units"].duplicate(true)
            pending_orders = snapshot["pending_orders"].duplicate(true)
            selected_unit_id = snapshot["selected_unit_id"]
            battle_payload = saved_battle.duplicate(true)
            battle_export_path = snapshot["battle_export_path"]
    status_message = "Campaign loaded." if result["ok"] else "Load failed: " + str(result["error"])
    queue_redraw()
    return result

func _save_button() -> Rect2:
    return Rect2(Vector2(SIDEBAR_X + 210, 195), Vector2(90, 48))

func _load_button() -> Rect2:
    return Rect2(Vector2(SIDEBAR_X + 310, 195), Vector2(90, 48))

func _detect_first_contact() -> Array:
    for i in range(units.size()):
        for j in range(i + 1, units.size()):
            var a: Dictionary = units[i]
            var b: Dictionary = units[j]
            if a.get("faction") == b.get("faction"):
                continue
            if _same_sector(a.get("sector", {}), b.get("sector", {})):
                return [a, b]
    return []

func _build_battle_payload(a: Dictionary, b: Dictionary) -> Dictionary:
    var ukr := a if a.get("faction") == "UKR" else b
    var ru := b if b.get("faction") == "RU" else a
    var sector: Dictionary = a.get("sector", {})
    var geographic_center: Dictionary = SectorGeometry.center(
        campaign.get("map", {}),
        Vector2i(int(sector.get("x", 0)), int(sector.get("y", 0))))
    var terrain_request: Dictionary = {
        "sector_size_km": campaign.get("map", {}).get("sector_size_km", 5),
        "tactical_map_size_km": 2,
        "source": "future_osm_dem_pipeline"
    }
    terrain_request.merge(geographic_center)

    return {
        "schema_version": 1,
        "battle_id": "T%03d_%s" % [int(campaign.get("turn", 1)), _sector_label(Vector2i(int(sector.get("x", 0)), int(sector.get("y", 0))))],
        "sector": _sector_label(Vector2i(int(sector.get("x", 0)), int(sector.get("y", 0)))),
        "turn": campaign.get("turn", 1),
        "ukraine": _unit_summary(ukr),
        "russia": _unit_summary(ru),
        "terrain_request": terrain_request
    }

func _unit_summary(unit: Dictionary) -> Dictionary:
    return {
        "id": unit.get("id"),
        "name": unit.get("name"),
        "personnel": unit.get("personnel"),
        "vehicles": unit.get("vehicles", {}).duplicate(true),
        "morale": unit.get("morale"),
        "supply": unit.get("supply")
    }

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("1a1e24"), true)

    _draw_title()
    _draw_grid()
    _draw_units()
    _draw_sidebar()

func _draw_title() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(70, 45), "UKRAINE WARGAME — PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("f2f2f2"))
    draw_string(ThemeDB.fallback_font, Vector2(70, 72), "Campaign Turn %d  •  %d-hour turns" % [campaign.get("turn", 1), campaign.get("turn_hours", 6)], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("b7bcc5"))

func _draw_grid() -> void:
    var map_data: Dictionary = campaign.get("map", {})
    var rows := int(map_data.get("rows", 4))
    var cols := int(map_data.get("columns", 4))

    for y in range(rows):
        for x in range(cols):
            var pos := GRID_ORIGIN + Vector2(x * CELL_SIZE.x, y * CELL_SIZE.y)
            var rect := Rect2(pos, CELL_SIZE)
            var fill := Color("2b323b") if (x + y) % 2 == 0 else Color("303842")
            draw_rect(rect, fill, true)
            draw_rect(rect, Color("69727d"), false, 2.0)
            draw_string(ThemeDB.fallback_font, pos + Vector2(10, 22), _sector_label(Vector2i(x, y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c8cdd3"))

    var selected := _get_unit(selected_unit_id)
    if not selected.is_empty():
        var s: Dictionary = selected.get("sector", {})
        var cell_pos := GRID_ORIGIN + Vector2(int(s.get("x", 0)) * CELL_SIZE.x, int(s.get("y", 0)) * CELL_SIZE.y)
        draw_rect(Rect2(cell_pos + Vector2(4, 4), CELL_SIZE - Vector2(8, 8)), Color("e9d66b"), false, 4.0)

func _draw_units() -> void:
    var stack_counts := {}
    for unit in units:
        var s: Dictionary = unit.get("sector", {})
        var key := "%d,%d" % [int(s.get("x", 0)), int(s.get("y", 0))]
        var stack_idx := int(stack_counts.get(key, 0))
        stack_counts[key] = stack_idx + 1

        var center := GRID_ORIGIN + Vector2((int(s.get("x", 0)) + 0.5) * CELL_SIZE.x, (int(s.get("y", 0)) + 0.5) * CELL_SIZE.y)
        center += Vector2((stack_idx % 2) * 38 - 19, (stack_idx / 2) * 34)
        var color := Color("4da3ff") if unit.get("faction") == "UKR" else Color("d95757")
        var rect := Rect2(center - Vector2(28, 20), Vector2(56, 40))
        draw_rect(rect, color, true)
        draw_rect(rect, Color("f4f4f4"), false, 2.0)
        draw_string(ThemeDB.fallback_font, center + Vector2(-21, 6), str(unit.get("faction")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

        var order = pending_orders.get(unit.get("id"), null)
        if order != null:
            var target := GRID_ORIGIN + Vector2((int(order.get("x", 0)) + 0.5) * CELL_SIZE.x, (int(order.get("y", 0)) + 0.5) * CELL_SIZE.y)
            draw_line(center, target, Color("f5d76e"), 3.0)

func _draw_sidebar() -> void:
    draw_rect(Rect2(Vector2(SIDEBAR_X, 90), Vector2(430, 540)), Color("222831"), true)
    draw_rect(Rect2(Vector2(SIDEBAR_X, 90), Vector2(430, 540)), Color("59636f"), false, 2.0)

    draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, 125), "CAMPAIGN CONTROL", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, 160), status_message, HORIZONTAL_ALIGNMENT_LEFT, 390, 15, Color("d0d4da"))

    var button := Rect2(Vector2(SIDEBAR_X + 20, 195), Vector2(180, 48))
    draw_rect(button, Color("526274"), true)
    draw_rect(button, Color("a6b0bb"), false, 2.0)
    draw_string(ThemeDB.fallback_font, button.position + Vector2(28, 31), "RESOLVE TURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

    for control in [{"rect": _save_button(), "label": "SAVE"}, {"rect": _load_button(), "label": "LOAD"}]:
        var rect: Rect2 = control["rect"]
        draw_rect(rect, Color("526274"), true)
        draw_rect(rect, Color("a6b0bb"), false, 2.0)
        draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 31), control["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

    draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, 280), "Pending Orders: %d" % pending_orders.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f0f0f0"))

    var y := 320.0
    for unit in units:
        var s: Dictionary = unit.get("sector", {})
        var line := "%s  |  %s  |  %d%% str" % [unit.get("faction"), _sector_label(Vector2i(int(s.get("x", 0)), int(s.get("y", 0)))), int(unit.get("strength", 100))]
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("cbd1d8"))
        y += 28

    if not battle_payload.is_empty():
        y += 18
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "CMBS BATTLE PAYLOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd166"))
        y += 26
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "%s — Sector %s" % [battle_payload.get("battle_id"), battle_payload.get("sector")], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eeeeee"))
        y += 24
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "Tactical terrain request: 2 x 2 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eeeeee"))
        y += 24
        var terrain: Dictionary = battle_payload.get("terrain_request", {})
        var coordinate_text := "Geographic bounds unavailable."
        if terrain.has("center_lat") and terrain.has("center_lon"):
            coordinate_text = "Center: %.6f, %.6f" % [terrain["center_lat"], terrain["center_lon"]]
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), coordinate_text, HORIZONTAL_ALIGNMENT_LEFT, 390, 14, Color("eeeeee"))
        y += 22
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "Placeholder sector center / WGS84", HORIZONTAL_ALIGNMENT_LEFT, 390, 13, Color("b7bcc5"))
        if not battle_export_path.is_empty():
            y += 24
            draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "Export: user://battle_exports/", HORIZONTAL_ALIGNMENT_LEFT, 390, 13, Color("a9d8ac"))
            y += 20
            draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), battle_export_path.get_file(), HORIZONTAL_ALIGNMENT_LEFT, 390, 13, Color("a9d8ac"))

func _point_in_end_turn_button(point: Vector2) -> bool:
    return Rect2(Vector2(SIDEBAR_X + 20, 195), Vector2(180, 48)).has_point(point)

func _screen_to_sector(point: Vector2) -> Vector2i:
    var local := point - GRID_ORIGIN
    if local.x < 0 or local.y < 0:
        return Vector2i(-1, -1)

    var x := int(floor(local.x / CELL_SIZE.x))
    var y := int(floor(local.y / CELL_SIZE.y))
    var map_data: Dictionary = campaign.get("map", {})
    if x < 0 or y < 0 or x >= int(map_data.get("columns", 4)) or y >= int(map_data.get("rows", 4)):
        return Vector2i(-1, -1)
    return Vector2i(x, y)

func _top_unit_in_sector(sector: Vector2i) -> Dictionary:
    for unit in units:
        if _same_sector(unit.get("sector", {}), {"x": sector.x, "y": sector.y}):
            return unit
    return {}

func _get_unit(unit_id: String) -> Dictionary:
    var idx := _get_unit_index(unit_id)
    return units[idx] if idx >= 0 else {}

func _get_unit_index(unit_id: String) -> int:
    for i in range(units.size()):
        if str(units[i].get("id", "")) == unit_id:
            return i
    return -1

func _same_sector(a: Dictionary, b: Dictionary) -> bool:
    return int(a.get("x", -99)) == int(b.get("x", -98)) and int(a.get("y", -99)) == int(b.get("y", -98))

func _is_adjacent(from_sector: Dictionary, to_sector: Vector2i) -> bool:
    var dx := absi(int(from_sector.get("x", 0)) - to_sector.x)
    var dy := absi(int(from_sector.get("y", 0)) - to_sector.y)
    return dx + dy == 1

func _sector_label(sector: Vector2i) -> String:
    return "%s%d" % [String.chr(65 + sector.x), sector.y + 1]
