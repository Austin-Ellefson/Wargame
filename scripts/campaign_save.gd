extends RefCounted

const SAVE_PATH := "user://saves/campaign.json"
const VERSION := 2
const TacticalBattle = preload("res://scripts/tactical_battle.gd")
const MAX_BYTES := 1024 * 1024


static func _fail(message: String) -> Dictionary:
    return {"ok": false, "error": message}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
    if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
        return false
    return is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func _cell(value: Variant, map: Dictionary) -> bool:
    return value is Dictionary and value.size() == 2 and _integer(value.get("x"), 0, int(map["columns"]) - 1) and _integer(value.get("y"), 0, int(map["rows"]) - 1)


static func validate(snapshot: Variant, scenario: Dictionary) -> Dictionary:
    if not snapshot is Dictionary:
        return _fail("Save must be a JSON object.")
    var required := ["schema_version", "scenario_hash", "turn", "units", "pending_orders", "selected_unit_id", "battle_payload", "battle_export_path"]
    var legacy_contact := false
    # Preserve the save/load PR's v1 saves; unresolved legacy contacts start a fresh native battle.
    if snapshot.get("schema_version") == 1 and snapshot.size() == required.size():
        snapshot = snapshot.duplicate(true)
        snapshot["schema_version"] = VERSION
        snapshot["tactical_state"] = {}
        snapshot["battle_origins"] = {}
        snapshot["resolved_battle_ids"] = []
        snapshot["last_battle_result"] = {}
        if snapshot.get("battle_payload") is Dictionary and not snapshot["battle_payload"].is_empty():
            legacy_contact = true
            snapshot["pending_orders"] = {}
            snapshot["selected_unit_id"] = ""
    required.append_array(["tactical_state", "battle_origins", "resolved_battle_ids", "last_battle_result"])
    if snapshot.size() != required.size():
        return _fail("Save fields do not match this version.")
    for key in required:
        if not snapshot.has(key):
            return _fail("Save is missing %s." % key)
    if not _integer(snapshot["schema_version"], VERSION, VERSION):
        return _fail("Unsupported save version.")
    if snapshot["scenario_hash"] != JSON.stringify(scenario).sha256_text():
        return _fail("Save belongs to a different campaign scenario.")
    if not _integer(snapshot["turn"], 1, 2147483647):
        return _fail("Invalid campaign turn.")
    if not snapshot["units"] is Array or snapshot["units"].size() != scenario["units"].size():
        return _fail("Save formation roster is incompatible.")
    var roster := {}
    for index in range(scenario["units"].size()):
        var initial: Dictionary = scenario["units"][index]
        var unit = snapshot["units"][index]
        if not unit is Dictionary or unit.size() != initial.size():
            return _fail("Invalid formation fields.")
        for key in initial:
            if not unit.has(key):
                return _fail("Formation is missing %s." % key)
        for key in ["id", "name", "faction"]:
            if unit[key] != initial[key]:
                return _fail("Save formation identity is incompatible.")
        if not _cell(unit["sector"], scenario["map"]):
            return _fail("Formation sector is outside the campaign map.")
        for key in ["strength", "morale", "supply"]:
            if not _integer(unit[key], 0, 100):
                return _fail("Invalid formation %s." % key)
        if not _integer(unit["personnel"], 0, int(initial["personnel"])):
            return _fail("Invalid personnel count.")
        if not unit["vehicles"] is Dictionary or unit["vehicles"].size() != initial["vehicles"].size():
            return _fail("Invalid vehicle composition.")
        for key in initial["vehicles"]:
            if not _integer(unit["vehicles"].get(key), 0, int(initial["vehicles"][key])):
                return _fail("Invalid vehicle count.")
        roster[unit["id"]] = unit
    if not snapshot["pending_orders"] is Dictionary:
        return _fail("Invalid movement orders.")
    for id in snapshot["pending_orders"]:
        var target = snapshot["pending_orders"][id]
        if not roster.has(id) or not _cell(target, scenario["map"]):
            return _fail("Movement order has an unknown formation or invalid sector.")
        var origin: Dictionary = roster[id]["sector"]
        if absi(int(origin["x"]) - int(target["x"])) + absi(int(origin["y"]) - int(target["y"])) != 1:
            return _fail("Movement order is not adjacent.")
    var selection = snapshot["selected_unit_id"]
    if not selection is String or (selection != "" and not roster.has(selection)):
        return _fail("Invalid selected formation.")
    if not snapshot["battle_payload"] is Dictionary or not snapshot["battle_export_path"] is String:
        return _fail("Invalid saved battle display.")
    # The main scene verifies nonempty battle payloads against its existing builder.
    if snapshot["battle_payload"].is_empty() and snapshot["battle_export_path"] != "":
        return _fail("Export path requires a battle payload.")
    if not snapshot["tactical_state"] is Dictionary or not snapshot["battle_origins"] is Dictionary or not snapshot["last_battle_result"] is Dictionary or not snapshot["resolved_battle_ids"] is Array:
        return _fail("Invalid tactical campaign state.")
    var ids := {}
    if snapshot["resolved_battle_ids"].size() > 4096:
        return _fail("Resolved battle history exceeds this prototype's limit.")
    var pattern := RegEx.new()
    pattern.compile("^T[0-9]{3,}_[A-Z][1-9][0-9]*$")
    for id in snapshot["resolved_battle_ids"]:
        if not id is String or pattern.search(id) == null or ids.has(id):
            return _fail("Invalid or duplicate resolved battle identity.")
        ids[id] = true
    for id in snapshot["battle_origins"]:
        if not roster.has(id) or not _cell(snapshot["battle_origins"][id], scenario["map"]):
            return _fail("Invalid battle origin.")
        var current: Dictionary = roster[id]["sector"]
        var origin: Dictionary = snapshot["battle_origins"][id]
        if absi(int(current["x"]) - int(origin["x"])) + absi(int(current["y"]) - int(origin["y"])) > 1:
            return _fail("Battle origin must be the contact sector or an adjacent sector.")
    var battle: Dictionary = snapshot["battle_payload"]
    if battle.is_empty():
        if not snapshot["tactical_state"].is_empty() or not snapshot["battle_origins"].is_empty():
            return _fail("Tactical state requires a pending battle.")
    else:
        if not battle.get("battle_id") is String or ids.has(battle["battle_id"]) or not battle.get("ukraine") is Dictionary or not battle.get("russia") is Dictionary:
            return _fail("Invalid pending battle identity or forces.")
        if not snapshot["pending_orders"].is_empty() or snapshot["selected_unit_id"] != "":
            return _fail("Campaign orders must be clear while a battle is pending.")
        for key in ["ukraine", "russia"]:
            var force: Dictionary = battle[key]
            if not roster.has(force.get("id")) or not _integer(force.get("personnel"), 1, 1000000) or not _integer(force.get("morale"), 0, 100):
                return _fail("Invalid pending battle formation.")
        if snapshot["tactical_state"].is_empty():
            if not legacy_contact:
                return _fail("Pending battle is missing its tactical simulation.")
            var migrated_battle = TacticalBattle.new()
            migrated_battle.setup(battle)
            snapshot["tactical_state"] = migrated_battle.state.duplicate(true)
        if not TacticalBattle.validate(snapshot["tactical_state"], battle):
            return _fail("Invalid saved tactical simulation.")
        for id in snapshot["battle_origins"]:
            if id not in [battle["ukraine"]["id"], battle["russia"]["id"]]:
                return _fail("Battle origin belongs to a nonparticipant.")
    var last: Dictionary = snapshot["last_battle_result"]
    if not last.is_empty():
        if last.size() != 6 or not ids.has(last.get("battle_id")) or last.get("winner") not in ["UKR", "RU", "draw"] or not _integer(last.get("version"), 1, 1) or not _integer(last.get("elapsed"), 1, TacticalBattle.MAX_SECONDS):
            return _fail("Invalid last battle result.")
        if not last.get("forces") is Dictionary or last["forces"].size() != 2 or not last.get("objective") is Dictionary or last["objective"].size() != 2:
            return _fail("Invalid last battle forces/objective.")
        for faction in ["UKR", "RU"]:
            var force = last["forces"].get(faction)
            if not force is Dictionary or force.size() != 5 or not roster.has(force.get("id")) or roster[force["id"]]["faction"] != faction:
                return _fail("Invalid last battle participant.")
            if not _integer(force.get("deployed"), 1, TacticalBattle.DETACHMENT) or not _integer(force.get("losses"), 0, int(force["deployed"])) or not _integer(force.get("ammunition_used"), 0, int(force["deployed"]) * TacticalBattle.ROUNDS_PER_PERSON) or not _integer(force.get("morale"), 0, 100) or not _integer(last["objective"].get(faction), 0, int(last["elapsed"])):
                return _fail("Invalid last battle losses, ammunition, morale or objective.")
    return {"ok": true, "snapshot": snapshot.duplicate(true)}


static func write(snapshot: Dictionary, scenario: Dictionary, path: String = SAVE_PATH) -> Dictionary:
    var result := validate(snapshot, scenario)
    if not result["ok"]:
        return result
    var absolute := ProjectSettings.globalize_path(path)
    var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
    if error != OK:
        return _fail("Cannot create save folder: %s" % error_string(error))
    # Write beside the destination and replace only after a complete, flushed write.
    var temporary := absolute + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return _fail("Cannot open temporary save: %s" % error_string(FileAccess.get_open_error()))
    file.store_string(JSON.stringify(snapshot, "  ") + "\n")
    file.flush()
    error = file.get_error()
    file.close()
    if error == OK:
        error = DirAccess.rename_absolute(temporary, absolute)
    if error != OK:
        DirAccess.remove_absolute(temporary)
        return _fail("Cannot replace save; previous save retained: %s" % error_string(error))
    return {"ok": true, "path": path}


static func read(scenario: Dictionary, path: String = SAVE_PATH) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _fail("Cannot read save: %s" % error_string(FileAccess.get_open_error()))
    if file.get_length() > MAX_BYTES:
        file.close()
        return _fail("Save exceeds the 1 MiB limit.")
    var json := JSON.new()
    var error := json.parse(file.get_as_text())
    file.close()
    if error != OK:
        return _fail("Save JSON is malformed (line %d)." % json.get_error_line())
    return validate(json.data, scenario)
