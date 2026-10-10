extends RefCounted

const SAVE_PATH := "user://saves/campaign.json"
const VERSION := 1
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
