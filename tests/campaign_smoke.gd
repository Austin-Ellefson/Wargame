extends SceneTree

const SectorGeometry = preload("res://scripts/sector_geometry.gd")
const BattleExporter = preload("res://scripts/battle_exporter.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var export_directory := "user://smoke_test_%d" % Time.get_ticks_usec()
    game.battle_export_directory = export_directory
    game.save_path = export_directory.path_join("campaign.json")
    check(game.units.size() == 2, "Campaign must load two formations.")

    var map_data: Dictionary = game.campaign["map"]
    var northwest: Dictionary = SectorGeometry.center(map_data, Vector2i(0, 0))
    var southeast: Dictionary = SectorGeometry.center(map_data, Vector2i(3, 3))
    check(is_equal_approx(northwest["center_lat"], 49.0675), "Northwest latitude must be the cell center.")
    check(is_equal_approx(northwest["center_lon"], 31.895), "Northwest longitude must be the cell center.")
    check(is_equal_approx(southeast["center_lat"], 48.9325), "Rows must run south.")
    check(is_equal_approx(southeast["center_lon"], 32.105), "Columns must run east.")
    check(SectorGeometry.center(map_data, Vector2i(-1, 0)).is_empty(), "Out-of-bounds sectors must be rejected.")
    check(SectorGeometry.center({"rows": 4, "columns": 4}, Vector2i.ZERO).is_empty(), "Missing coordinates must not become a fabricated location.")

    # Exercise actual click handling and two simultaneous order rounds.
    game._handle_click(Vector2(155, 402)) # Select Ukraine in A3.
    game._handle_click(Vector2(155, 152)) # Reject a two-sector move.
    check(game.pending_orders.is_empty(), "Non-adjacent moves must be rejected.")
    game._handle_click(Vector2(155, 277)) # Ukraine to A2.
    game._handle_click(Vector2(665, 277)) # Select Russia in D2.
    game._handle_click(Vector2(495, 277)) # Russia to C2.
    check(game.pending_orders.size() == 2, "Both sides must have pending orders.")
    check(game.units[0]["sector"]["y"] == 2, "Orders must not move a unit before resolution.")
    game._resolve_turn()
    check(game.battle_payload.is_empty(), "Separated units must not generate contact.")
    check(game.pending_orders.is_empty(), "Resolution must clear orders.")

    game._handle_click(Vector2(155, 277))
    game._handle_click(Vector2(325, 277)) # Ukraine to B2.
    game._handle_click(Vector2(495, 277))
    game._handle_click(Vector2(325, 277)) # Russia to B2.
    game._resolve_turn()
    check(game.battle_payload.get("battle_id") == "T003_B2", "Contact must generate the expected battle ID.")
    check(not game.battle_export_path.is_empty(), "Contact must export a battle file.")
    check(FileAccess.file_exists(game.battle_export_path), "Battle JSON must exist on disk.")
    var exported = JSON.parse_string(FileAccess.get_file_as_string(game.battle_export_path))
    check(exported is Dictionary, "Export must parse as a JSON object.")
    if exported is Dictionary:
        check(exported["ukraine"]["personnel"] == 620, "Export must preserve Ukrainian force composition.")
        check(exported["russia"]["vehicles"]["tanks"] == 12, "Export must preserve Russian force composition.")
        check(is_equal_approx(exported["terrain_request"]["center_lat"], 49.0225), "B2 latitude must match its geographic center.")
        check(is_equal_approx(exported["terrain_request"]["center_lon"], 31.965), "B2 longitude must match its geographic center.")
    check(not BattleExporter.write_payload({"battle_id": "../escape"}, export_directory)["ok"], "Exporter must reject traversal IDs.")
    var blocked_path := export_directory.path_join("blocked")
    var blocker := FileAccess.open(blocked_path, FileAccess.WRITE)
    blocker.store_string("A file prevents directory creation here.")
    blocker.close()
    check(not BattleExporter.write_payload(game.battle_payload, blocked_path)["ok"], "Exporter must report an unwritable directory.")

    DirAccess.remove_absolute(ProjectSettings.globalize_path(blocked_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.battle_export_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
    DirAccess.remove_absolute(ProjectSettings.globalize_path(export_directory))
    game.queue_free()
    await process_frame
    if failures.is_empty():
        print("PASS: movement, simultaneous contact, geometry, JSON export, and write failures.")
    quit(0 if failures.is_empty() else 1)
