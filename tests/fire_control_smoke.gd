extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const Saves = preload("res://scripts/campaign_save.gd")
const PAYLOAD = {"battle_id": "FIRE_CONTROL", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    battle.state["version"] = 15
    battle.state.erase("acquisition")
    battle.state.erase("command_remaining")
    battle.state.erase("shared_contacts")
    battle.state.erase("pending_reports")
    battle.state.erase("observer_contacts")
    for squad in battle.state["squads"]:
        if squad["id"] not in ["UKR_S1", "RU_S1"]:
            squad["alive"] = 0
    battle.squad_by_id("UKR_S1")["position"] = [180, 245]
    battle.squad_by_id("RU_S1")["position"] = [240, 245]
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var battle = fixture()
    var before: Dictionary = battle.state.duplicate(true)
    check(not battle.order_fire("UKR_S1", "invalid") and same(before, battle.state), "Invalid fire command must not mutate state.")
    check(not battle.order_fire("RU_S1", "hold") and not battle.order_fire("UKR_S2", "hold"), "Player cannot change red or dead squads' fire rules.")
    check(battle.order_fire("UKR_S1", "hold"), "A live squad can hold fire during planning.")
    battle.execute()
    before = battle.state.duplicate(true)
    check(not battle.order_fire("UKR_S1", "auto") and same(before, battle.state), "Fire orders must freeze during execution.")
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    var rounds := int(blue["ammo"])
    var fired_blue := false
    var fired_red := false
    for tick in range(6):
        battle.step()
        for event in battle.consume_events():
            if event["shooter"] == "UKR_S1": fired_blue = true
            if event["shooter"] == "RU_S1": fired_red = true
    check(not fired_blue and int(blue["ammo"]) == rounds and fired_red and float(blue["suppression"]) > 0, "HOLD FIRE must preserve rounds and emit no shots while incoming fire still affects the squad.")
    # A fresh firing pair proves AUTO produces authoritative shots.
    var automatic = fixture()
    automatic.execute()
    for tick in range(3): automatic.step()
    check(int(automatic.squad_by_id("UKR_S1")["ammo"]) < rounds, "AUTO must retain locally observed automatic firing.")
    var moving = fixture()
    moving.order_fire("UKR_S1", "hold")
    moving.order_move("UKR_S1", Vector2(200, 245), true, "quick")
    moving.execute()
    var origin := Battle.position(moving.squad_by_id("UKR_S1"))
    moving.step()
    check(Battle.position(moving.squad_by_id("UKR_S1")) != origin and moving.is_observed("UKR", moving.squad_by_id("RU_S1")), "Holding fire must not disable movement or spotting.")
    for version in range(1, 6):
        var old = fixture()
        old.state["version"] = version
        if int(old.state["version"]) < 15: old.state.erase("weapon_roles")
        if int(old.state["version"]) < 14: old.state.erase("postures")
        if version < 13: old.state.erase("morale_states")
        if version < 13: old.state.erase("rally_remaining")
        if version < 12: old.state.erase("fatigue")
        old.state.erase("fire_modes")
        old.state.erase("fire_targets")
        old.state.erase("pause_remaining")
        if version < 5: old.state.erase("movement_modes")
        if version < 4: old.state.erase("contacts")
        check(Battle.validate(old.state, PAYLOAD) and not old.order_fire("UKR_S1", "hold"), "Legacy engagements retain automatic fire and their old contract.")
        var restarted = Battle.new()
        restarted.restore(JSON.parse_string(JSON.stringify(old.state)))
        old.execute()
        restarted.execute()
        for tick in range(6):
            old.step()
            restarted.step()
        check(same(old.state, restarted.state), "Legacy automatic fire must preserve restart determinism.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://fire_control_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.state["version"] = 15
    game.tactical_simulation.state.erase("acquisition")
    game.tactical_simulation.state.erase("command_remaining")
    game.tactical_simulation.state.erase("shared_contacts")
    game.tactical_simulation.state.erase("pending_reports")
    game.tactical_simulation.state.erase("observer_contacts")
    game.tactical_simulation.order_fire("UKR_S1", "hold")
    game.tactical_simulation.execute()
    game.tactical_simulation.step()
    check(game._save_campaign()["ok"], "Campaign must checkpoint fire modes mid-execution.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Actual disk restart must preserve fire rules exactly.")
    for kind in range(4):
        var bad: Dictionary = saved.duplicate(true)
        match kind:
            0: bad["tactical_state"].erase("fire_modes")
            1: bad["tactical_state"]["fire_modes"]["UKR_S1"] = "invalid"
            2: bad["tactical_state"]["fire_modes"].erase("UKR_S1")
            3: bad["tactical_state"]["fire_modes"]["UNKNOWN"] = "hold"
        check(not Saves.validate(bad, game.initial_campaign)["ok"] and same(saved, game._snapshot()), "Malformed fire maps must reject the full snapshot without live-state changes.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Fire-rule disk restart must preserve the complete outcome.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: AUTO/HOLD FIRE, incoming fire, movement/spotting, command locks, validation, legacy rules and disk restart.")
    quit(0 if failures.is_empty() else 1)
