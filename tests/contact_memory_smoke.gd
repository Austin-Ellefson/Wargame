extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
const Saves = preload("res://scripts/campaign_save.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished":
            return
        if battle.state["phase"] == "planning":
            battle.execute()
        battle.step()

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://memory_test_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    var payload: Dictionary = game.battle_payload.duplicate(true)
    for squad in battle.state["squads"]:
        squad["ammo"] = 0
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    var red: Dictionary = battle.squad_by_id("RU_S1")
    blue["position"] = [80, 250]
    red["position"] = [200, 250]
    battle.execute()
    battle.state["orders"].clear()
    battle.state["movement_modes"].clear()
    battle.step()
    check(battle.state["contacts"]["UKR"].has("RU_S1") and battle.state["contacts"]["RU"].has("UKR_S1"), "Actual simulation ticks must remember observed enemies for both sides.")
    check(battle.last_known_contacts("UKR").is_empty(), "Live contacts must not also show stale markers.")
    var observed: Dictionary = battle.state["contacts"]["UKR"]["RU_S1"].duplicate(true)
    red["position"] = [470, 470]
    battle.step()
    check(not battle.is_observed("UKR", red), "Moved-out-of-sight fixture must be hidden.")
    check(same(battle.state["contacts"]["UKR"]["RU_S1"], observed), "Hidden motion must not update the last observed position or timestamp.")
    var stale: Array = battle.last_known_contacts("UKR")
    check(stale.size() == 1 and same(stale[0]["position"], observed["position"]), "Last-known markers must use saved observation coordinates only.")
    stale[0]["position"][0] = 999
    check(same(battle.state["contacts"]["UKR"]["RU_S1"], observed), "Presentation queries must return detached records, not mutable save aliases.")
    red["alive"] = 0
    battle.step()
    check(same(battle.state["contacts"]["UKR"]["RU_S1"], observed), "Unobserved death must not remove or update the remembered contact.")
    check(Battle.validate(battle.state, payload), "A stale contact for a hidden eliminated squad remains a valid save.")
    check(game._save_campaign()["ok"], "Actual campaign save must persist contact memory mid-execution.")
    var snapshot: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(snapshot, resumed._snapshot()), "Disk restart must retain exact contact records and tactical clock.")
    check(same(battle.last_known_contacts("UKR"), resumed.tactical_simulation.last_known_contacts("UKR")), "Restart must retain last-known marker position and age.")
    var corruptions: Array = []
    for kind in range(7):
        var bad: Dictionary = snapshot.duplicate(true)
        var record: Dictionary = bad["tactical_state"]["contacts"]["UKR"]["RU_S1"]
        match kind:
            0: record["seen_at"] = 999
            1: record["seen_at"] = 1.5
            2: record["position"] = [999, 250]
            3: record["position"] = [230, 166]
            4: record["ammo"] = 300
            5: bad["tactical_state"]["contacts"]["UKR"]["UKR_S1"] = record.duplicate(true)
            6: bad["tactical_state"].erase("contacts")
        corruptions.append(bad)
    for bad in corruptions:
        check(not Saves.validate(bad, game.initial_campaign)["ok"] and same(snapshot, game._snapshot()), "Malformed contact data must be rejected without live-state changes.")
    # Reacquisition refreshes both location and time; observed death confirms loss.
    red["alive"] = 9
    red["position"] = [210, 250]
    battle.step()
    check(battle.last_known_contacts("UKR").is_empty() and battle.state["contacts"]["UKR"]["RU_S1"]["position"] == [210, 250] and battle.state["contacts"]["UKR"]["RU_S1"]["seen_at"] == battle.state["elapsed"], "Reacquisition must replace stale memory with the actual new observation.")
    red["alive"] = 0
    battle.step()
    check(not battle.state["contacts"]["UKR"].has("RU_S1"), "A living observer with LOS may confirm an eliminated contact.")
    finish(battle)
    var equal_restart = resumed.tactical_simulation
    var equal_original = Battle.new()
    equal_original.restore(snapshot["tactical_state"])
    finish(equal_original)
    finish(equal_restart)
    check(same(equal_original.state, equal_restart.state) and same(equal_original.result(), equal_restart.result()), "Contact-memory restart must preserve the complete outcome.")
    check(battle.last_known_contacts("UKR").is_empty(), "Finished reports must clear uncertain markers.")
    var legacy = Battle.new()
    legacy.setup(payload)
    legacy.state["version"] = 3
    legacy.state.erase("morale_states")
    legacy.state.erase("rally_remaining")
    legacy.state.erase("fatigue")
    legacy.state.erase("contacts")
    legacy.state.erase("movement_modes")
    legacy.state.erase("fire_modes")
    legacy.state.erase("fire_targets")
    legacy.state.erase("pause_remaining")
    check(Battle.validate(legacy.state, payload), "V3 saves without contact memory must remain valid.")
    var legacy_restart = Battle.new()
    legacy_restart.restore(JSON.parse_string(JSON.stringify(legacy.state)))
    legacy.execute()
    legacy_restart.execute()
    legacy.step()
    legacy_restart.step()
    check(same(legacy.state, legacy_restart.state) and not legacy_restart.state.has("contacts"), "Old V3 saves must preserve their rules and fields without silent migration.")
    resumed.queue_free()
    game.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty():
        print("PASS: bilateral observed memory, hidden motion/death isolation, reacquisition, observed death, disk restart, validation and V3 compatibility.")
    quit(0 if failures.is_empty() else 1)
