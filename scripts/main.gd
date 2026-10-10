extends Node2D

const SectorGeometry = preload("res://scripts/sector_geometry.gd")
const BattleExporter = preload("res://scripts/battle_exporter.gd")
const TacticalBattle = preload("res://scripts/tactical_battle.gd")
const TacticalView = preload("res://scripts/tactical_view.gd")
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
var tactical_simulation: RefCounted
var tactical_view: Control
var battle_origins: Dictionary = {}
var resolved_battle_ids: Array = []
var last_battle_result: Dictionary = {}
var auto_launch_battles := true
var status_message := "Select a unit, then click an adjacent sector."

func _ready() -> void:
    campaign = _load_json(CAMPAIGN_PATH)
    initial_campaign = campaign.duplicate(true)
    units = campaign.get("units", []).duplicate(true)
    if get_tree().current_scene == self:
        get_tree().auto_accept_quit = false
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
    if is_instance_valid(tactical_view):
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _handle_click(event.position)

func _handle_click(mouse_pos: Vector2) -> void:
    if _demo_button().has_point(mouse_pos) and int(campaign.get("turn", 1)) == 1 and battle_payload.is_empty() and pending_orders.is_empty():
        _play_demo()
        return
    if not battle_payload.is_empty() and _battle_button().has_point(mouse_pos):
        _open_tactical_battle()
        return
    if _save_button().has_point(mouse_pos):
        _save_campaign()
        return
    if _load_button().has_point(mouse_pos):
        _load_campaign()
        return
    if _point_in_end_turn_button(mouse_pos):
        _resolve_turn()
        return

    if not battle_payload.is_empty():
        status_message = "Resolve the pending tactical battle first."
        queue_redraw()
        return
    var sector := _screen_to_sector(mouse_pos)
    if sector.x < 0:
        return

    var clicked_unit := _top_unit_in_sector(sector)

    if selected_unit_id == "":
        if not clicked_unit.is_empty() and int(clicked_unit.get("personnel", 0)) > 0:
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
    if not battle_payload.is_empty():
        status_message = "Campaign locked: open the pending battle."
        queue_redraw()
        return
    var origins := {}
    for unit in units:
        origins[unit["id"]] = unit["sector"].duplicate(true)
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
        battle_origins = {battle[0]["id"]: origins[battle[0]["id"]], battle[1]["id"]: origins[battle[1]["id"]]}
        selected_unit_id = ""
        tactical_simulation = TacticalBattle.new()
        tactical_simulation.setup(battle_payload)
        status_message = "CONTACT! Tactical battle generated for Sector %s." % battle_payload.get("sector", "?")
        var export_result: Dictionary = BattleExporter.write_payload(battle_payload, battle_export_directory)
        if export_result.get("ok", false):
            battle_export_path = str(export_result["path"])
            print("Battle exported: %s" % ProjectSettings.globalize_path(battle_export_path))
        else:
            status_message = "CONTACT! Export failed; see console."
            push_error(str(export_result.get("error", "Unknown export error.")))
        var saved := _save_campaign()
        status_message = "CONTACT: battle ready. Campaign locked." if saved["ok"] else "CONTACT: save failed; battle retained in memory."
        if auto_launch_battles:
            call_deferred("_open_tactical_battle")
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
        "battle_export_path": battle_export_path,
        "tactical_state": tactical_simulation.state.duplicate(true) if tactical_simulation != null else {},
        "battle_origins": battle_origins.duplicate(true),
        "resolved_battle_ids": resolved_battle_ids.duplicate(),
        "last_battle_result": last_battle_result.duplicate(true)
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
            _close_tactical_view()
            campaign = initial_campaign.duplicate(true)
            campaign["turn"] = int(snapshot["turn"])
            units = snapshot["units"].duplicate(true)
            pending_orders = snapshot["pending_orders"].duplicate(true)
            selected_unit_id = snapshot["selected_unit_id"]
            battle_payload = saved_battle.duplicate(true)
            battle_export_path = snapshot["battle_export_path"]
            battle_origins = snapshot["battle_origins"].duplicate(true)
            resolved_battle_ids = snapshot["resolved_battle_ids"].duplicate()
            last_battle_result = snapshot["last_battle_result"].duplicate(true)
            tactical_simulation = null
            if not saved_battle.is_empty():
                tactical_simulation = TacticalBattle.new()
                if snapshot["tactical_state"].is_empty():
                    tactical_simulation.setup(saved_battle)
                else:
                    tactical_simulation.restore(snapshot["tactical_state"])
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
            if int(a.get("personnel", 0)) <= 0 or int(b.get("personnel", 0)) <= 0:
                continue
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
    if is_instance_valid(tactical_view):
        return
    draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("1a1e24"), true)

    _draw_title()
    _draw_grid()
    _draw_units()
    _draw_sidebar()
    if int(campaign.get("turn", 1)) == 1 and battle_payload.is_empty() and pending_orders.is_empty():
        var demo := _demo_button()
        draw_rect(demo, Color("397d72"), true)
        draw_string(ThemeDB.fallback_font, demo.position + Vector2(24, 31), "PLAY INTEGRATED DEMO", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

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
        if int(unit.get("personnel", 0)) <= 0:
            continue
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

    if not battle_payload.is_empty():
        var launch := _battle_button()
        draw_rect(launch, Color("397d72"), true)
        draw_string(ThemeDB.fallback_font, launch.position + Vector2(22, 26), "OPEN TACTICAL BATTLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
    elif not last_battle_result.is_empty():
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, 266), "Last battle: %s / %s" % [last_battle_result["battle_id"], str(last_battle_result["winner"]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, 390, 14, Color("a9d8ac"))
    draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, 300), "Pending Orders: %d" % pending_orders.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f0f0f0"))

    var y := 320.0
    for unit in units:
        var s: Dictionary = unit.get("sector", {})
        var line := "%s | %s | %d%% | %d personnel" % [unit.get("faction"), _sector_label(Vector2i(int(s.get("x", 0)), int(s.get("y", 0)))), int(unit.get("strength", 100)), int(unit.get("personnel", 0))]
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("cbd1d8"))
        y += 28

    if not battle_payload.is_empty():
        y += 18
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "PENDING TACTICAL BATTLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd166"))
        y += 26
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "%s — Sector %s" % [battle_payload.get("battle_id"), battle_payload.get("sector")], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eeeeee"))
        y += 24
        draw_string(ThemeDB.fallback_font, Vector2(SIDEBAR_X + 20, y), "Native battle: 512 m / export request: 2 km", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("eeeeee"))
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
        if int(unit.get("personnel", 0)) > 0 and _same_sector(unit.get("sector", {}), {"x": sector.x, "y": sector.y}):
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


func _battle_button() -> Rect2:
    return Rect2(Vector2(SIDEBAR_X + 20, 253), Vector2(380, 36))

func _open_tactical_battle() -> void:
    if battle_payload.is_empty() or tactical_simulation == null or is_instance_valid(tactical_view):
        return
    tactical_view = TacticalView.new()
    tactical_view.simulation = tactical_simulation
    tactical_view.checkpoint.connect(_save_campaign)
    tactical_view.leave_battle.connect(_leave_tactical_battle)
    tactical_view.commit_result.connect(_apply_tactical_result)
    add_child(tactical_view)
    queue_redraw()

func _close_tactical_view() -> void:
    if is_instance_valid(tactical_view):
        remove_child(tactical_view)
        tactical_view.queue_free()
    tactical_view = null
    queue_redraw()

func _leave_tactical_battle() -> void:
    var saved := _save_campaign()
    if saved["ok"]:
        _close_tactical_view()
        status_message = "Battle saved. Open it to continue; campaign remains locked."
    else:
        tactical_view.report_label.text = "Save failed. Battle remains open. Check Godot Output."
    queue_redraw()

func _apply_tactical_result(result: Dictionary) -> Dictionary:
    if str(result.get("battle_id", "")) in resolved_battle_ids:
        return {"ok": false, "error": "Battle result was already applied."}
    if battle_payload.is_empty() or tactical_simulation == null or result.is_empty():
        return {"ok": false, "error": "No pending completed battle."}
    if not TacticalBattle.validate(tactical_simulation.state, battle_payload):
        return {"ok": false, "error": "Completed tactical state is invalid."}
    var expected: Dictionary = tactical_simulation.result()
    if expected.is_empty() or JSON.parse_string(JSON.stringify(result)) != JSON.parse_string(JSON.stringify(expected)):
        return {"ok": false, "error": "Result does not match the completed simulation."}
    var before := _snapshot()
    for faction in ["UKR", "RU"]:
        var force: Dictionary = result["forces"][faction]
        var unit := _get_unit(force["id"])
        if unit.is_empty() or int(force["losses"]) > int(unit["personnel"]):
            return {"ok": false, "error": "Result exceeds formation strength."}
    for faction in ["UKR", "RU"]:
        var force: Dictionary = result["forces"][faction]
        var unit := _get_unit(force["id"])
        unit["personnel"] = int(unit["personnel"]) - int(force["losses"])
        var initial := 1
        for original in initial_campaign["units"]:
            if original["id"] == unit["id"]:
                initial = int(original["personnel"])
        unit["strength"] = int(round(float(unit["personnel"]) / initial * 100))
        unit["morale"] = mini(int(unit["morale"]), int(force["morale"]))
        var supply_cost := int(ceil(float(force["ammunition_used"]) / maxi(1, int(force["deployed"]) * TacticalBattle.ROUNDS_PER_PERSON) * 5.0))
        unit["supply"] = maxi(0, int(unit["supply"]) - supply_cost)
    var retreating: String = "UKR" if result["winner"] in ["RU", "draw"] else "RU"
    var loser := _get_unit(result["forces"][retreating]["id"])
    if int(loser["personnel"]) > 0:
        loser["sector"] = _retreat_sector(loser)
    resolved_battle_ids.append(result["battle_id"])
    last_battle_result = result.duplicate(true)
    battle_payload = {}
    battle_export_path = ""
    battle_origins = {}
    tactical_simulation = null
    var saved := _save_campaign()
    if not saved["ok"]:
        units = before["units"]
        battle_payload = before["battle_payload"]
        battle_export_path = before["battle_export_path"]
        battle_origins = before["battle_origins"]
        resolved_battle_ids = before["resolved_battle_ids"]
        last_battle_result = before["last_battle_result"]
        tactical_simulation = TacticalBattle.new()
        tactical_simulation.restore(before["tactical_state"])
        if is_instance_valid(tactical_view):
            tactical_view.simulation = tactical_simulation
            tactical_view.report_label.text = "Result save failed. Nothing applied. Retry after fixing the save folder."
        return saved
    _close_tactical_view()
    status_message = "%s: %s. Losses UKR %d / RU %d." % [result["battle_id"], str(result["winner"]).to_upper(), result["forces"]["UKR"]["losses"], result["forces"]["RU"]["losses"]]
    queue_redraw()
    return {"ok": true}

func _retreat_sector(unit: Dictionary) -> Dictionary:
    var origin: Dictionary = battle_origins.get(unit["id"], {})
    var current: Dictionary = unit["sector"]
    var candidates: Array = []
    if not origin.is_empty() and not _same_sector(origin, current):
        candidates.append(origin)
    for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
        var point: Vector2i = Vector2i(int(current["x"]), int(current["y"])) + offset
        if point.x >= 0 and point.y >= 0 and point.x < int(campaign["map"]["columns"]) and point.y < int(campaign["map"]["rows"]):
            candidates.append({"x": point.x, "y": point.y})
    for candidate in candidates:
        var blocked := false
        for other in units:
            if other["id"] != unit["id"] and int(other["personnel"]) > 0 and other["faction"] != unit["faction"] and _same_sector(other["sector"], candidate):
                blocked = true
        if not blocked:
            return candidate.duplicate(true)
    return current.duplicate(true)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and get_tree().current_scene == self:
        var saved := _save_campaign()
        if saved["ok"]:
            get_tree().quit()


func _demo_button() -> Rect2:
    return Rect2(Vector2(70, 635), Vector2(310, 48))

func _play_demo() -> void:
    # Use the same simultaneous campaign rules as the documented two-turn demo.
    if int(campaign.get("turn", 1)) != 1 or not battle_payload.is_empty() or not pending_orders.is_empty():
        return
    pending_orders = {"UKR_1": {"x": 0, "y": 1}, "RU_1": {"x": 2, "y": 1}}
    _resolve_turn()
    pending_orders = {"UKR_1": {"x": 1, "y": 1}, "RU_1": {"x": 1, "y": 1}}
    _resolve_turn()
