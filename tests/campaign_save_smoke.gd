extends SceneTree

const CampaignSave = preload("res://scripts/campaign_save.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same_state(actual: Dictionary, expected: Dictionary) -> bool:
    # JSON numbers decode as floats; compare serialized state, not Variant types.
    return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))

func write_json(path: String, value: Variant) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify(value))
    file.close()

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var folder := "user://save_test_%d" % Time.get_ticks_usec()
    game.save_path = folder.path_join("campaign.json")
    game.battle_export_directory = folder
    check(not game._load_campaign()["ok"], "Missing save must be reported.")
    game._handle_click(Vector2(155, 402))
    game._handle_click(Vector2(155, 277))
    game.selected_unit_id = "RU_1"
    game.units[0]["strength"] = 90
    game.units[0]["personnel"] = 600
    game.units[0]["vehicles"]["tanks"] = 9
    var ordered: Dictionary = game._snapshot()
    game._handle_click(Vector2(1045, 219)) # Save control.
    check(FileAccess.file_exists(game.save_path), "Save control must write the save.")
    game._resolve_turn()
    game._handle_click(Vector2(1145, 219)) # Load control.
    check(same_state(game._snapshot(), ordered), "Load must restore turn, orders, selection, position and losses exactly.")
    # A separate scene represents restarting the game, with no shared state.
    var restarted = load("res://scenes/main.tscn").instantiate()
    root.add_child(restarted)
    await process_frame
    restarted.save_path = game.save_path
    restarted.battle_export_directory = folder
    check(restarted._load_campaign()["ok"], "Save must load after a restart.")
    check(same_state(restarted._snapshot(), ordered), "Restart must restore saved state.")
    restarted.units[0]["vehicles"]["tanks"] = 1
    check(game.units[0]["vehicles"]["tanks"] == 9, "Loaded state must not alias other scenes.")
    restarted.queue_free()
    await process_frame
    game._resolve_turn()
    game.pending_orders = {"RU_1": {"x": 2, "y": 1}}
    game._resolve_turn()
    game.pending_orders = {"UKR_1": {"x": 1, "y": 1}, "RU_1": {"x": 1, "y": 1}}
    game._resolve_turn()
    var contact: Dictionary = game._snapshot()
    check(not contact["battle_payload"].is_empty(), "Contact fixture must contain a battle.")
    check(game._save_campaign()["ok"], "An existing save must be replaceable.")
    game._resolve_turn()
    check(game._load_campaign()["ok"] and same_state(game._snapshot(), contact), "Battle payload and path must survive save/load.")
    var malformed := FileAccess.open(game.save_path, FileAccess.WRITE)
    malformed.store_string("{broken")
    malformed.close()
    check(not game._load_campaign()["ok"] and same_state(game._snapshot(), contact), "Malformed JSON must leave live state unchanged.")
    var cases: Array = []
    var bad: Dictionary = contact.duplicate(true)
    bad["schema_version"] = 2
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["scenario_hash"] = "different"
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["turn"] = 2.5
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["units"][0]["sector"]["x"] = 99
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["units"][0]["id"] = "RU_1"
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["units"][0]["personnel"] = -1
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["units"][0]["vehicles"]["tanks"] = 999
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["pending_orders"] = {"UKR_1": {"x": 3, "y": 3}}
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["pending_orders"] = {"unknown": {"x": 1, "y": 2}}
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["battle_payload"]["ukraine"]["personnel"] = 999
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["battle_export_path"] = "../../unrelated.json"
    cases.append(bad)
    bad = contact.duplicate(true)
    bad["battle_payload"] = {}
    bad["battle_export_path"] = ""
    cases.append(bad)
    cases.append([])
    for index in range(cases.size()):
        write_json(game.save_path, cases[index])
        check(not game._load_campaign()["ok"], "Invalid save %d must be rejected." % index)
        check(same_state(game._snapshot(), contact), "Invalid save %d must not partially apply." % index)
    # Failure before rename must preserve an existing save, with no partial file.
    check(game._save_campaign()["ok"], "Restore a valid save for write-failure test.")
    var original := FileAccess.get_file_as_string(game.save_path)
    DirAccess.make_dir_absolute(game.save_path + ".tmp")
    check(not game._save_campaign()["ok"], "Temporary-path failure must be reported.")
    check(FileAccess.get_file_as_string(game.save_path) == original, "Write failure must preserve the previous save.")
    DirAccess.remove_absolute(game.save_path + ".tmp")
    var blocker := folder.path_join("blocker")
    write_json(blocker, {})
    check(not CampaignSave.write(contact, game.initial_campaign, blocker.path_join("save.json"))["ok"], "Unwritable folder must be reported.")
    for filename in DirAccess.get_files_at(folder):
        DirAccess.remove_absolute(folder.path_join(filename))
    DirAccess.remove_absolute(folder)
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: save/load controls, restart, exact state, contact, invalid saves and preserved writes.")
    quit(0 if failures.is_empty() else 1)
