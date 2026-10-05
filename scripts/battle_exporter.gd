extends RefCounted

const EXPORT_DIRECTORY := "user://battle_exports"


static func write_payload(payload: Dictionary, directory: String = EXPORT_DIRECTORY) -> Dictionary:
    var battle_id := str(payload.get("battle_id", ""))
    if battle_id.is_empty() or not battle_id.is_valid_filename() or battle_id.begins_with("."):
        return {"ok": false, "error": "Invalid battle ID for export."}

    var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if error != OK:
        return {"ok": false, "error": "Cannot create export directory: %s" % error_string(error)}

    var path := directory.path_join(battle_id + ".json")
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "error": "Cannot open export: %s" % error_string(FileAccess.get_open_error())}
    file.store_string(JSON.stringify(payload, "  ") + "\n")
    file.flush()
    error = file.get_error()
    file.close()
    if error != OK:
        return {"ok": false, "error": "Cannot write export: %s" % error_string(error)}
    return {"ok": true, "path": path}
