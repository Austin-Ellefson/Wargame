extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const Saves = preload("res://scripts/campaign_save.gd")
const PAYLOAD = {"battle_id": "TARGET_ORDERS", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    for squad in battle.state["squads"]:
        if squad["id"] not in ["UKR_S1", "RU_S1", "RU_S2"]: squad["alive"] = 0
        if squad["faction"] == "RU": squad["ammo"] = 0
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    var near: Dictionary = battle.squad_by_id("RU_S1")
    var far: Dictionary = battle.squad_by_id("RU_S2")
    blue["position"] = [80, 250]
    near["position"] = [120, 250]
    far["position"] = [200, 250]
    var before: Dictionary = battle.state.duplicate(true)
    check(not battle.order_target("UKR_S1", "UKR_S2") and not battle.order_target("UKR_S1", "UNKNOWN") and not battle.order_target("RU_S1", "UKR_S1") and same(before, battle.state), "Friendly/unknown/opponent commands must reject without mutation.")
    check(battle.order_target("UKR_S1", "RU_S2") and battle._nearest_target(blue)["id"] == "RU_S2", "Eligible preferred target must override the nearer automatic target.")
    battle.execute()
    battle.state["orders"].clear()
    battle.state["movement_modes"].clear()
    for tick in range(3): battle.step()
    var hit_preferred := false
    for event in battle.consume_events():
        if event["shooter"] == "UKR_S1" and event["target"] == "RU_S2": hit_preferred = true
    check(hit_preferred, "Actual authoritative shots must use the eligible preferred target.")
    far["position"] = [470, 470]
    before = battle.state.duplicate(true)
    check(battle._nearest_target(blue)["id"] == "RU_S1" and battle.target_status("UKR_S1") == "Focus: waiting for sight" and same(before, battle.state), "Hidden preference must fall back to local targeting without mutating knowledge.")
    check(not battle.order_target("UKR_S1", ""), "Target orders must freeze during execution.")
    for tick in range(3): battle.step()
    var fallback := false
    for event in battle.consume_events():
        if event["shooter"] == "UKR_S1" and event["target"] == "RU_S1": fallback = true
    check(fallback and battle.state["fire_targets"]["UKR_S1"] == "RU_S2", "Actual fire must fall back without clearing or tracking the hidden preference.")
    far["alive"] = 0
    check(battle.target_status("UKR_S1") == "Focus: waiting for sight", "Unobserved death must not reveal a new target status.")
    var old = Battle.new()
    old.setup(PAYLOAD)
    old.state["version"] = 6
    if int(old.state["version"]) < 14: old.state.erase("postures")
    old.state.erase("morale_states")
    old.state.erase("rally_remaining")
    old.state.erase("fatigue")
    old.state.erase("fire_targets")
    old.state.erase("pause_remaining")
    check(Battle.validate(old.state, PAYLOAD) and not old.order_target("UKR_S1", "RU_S1"), "V6 must preserve nearest-target rules without preferences.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://target_orders_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    check(game.tactical_simulation.order_target("UKR_S1", "RU_S1"), "Campaign fixture must accept its actually observed contact.")
    game.tactical_simulation.order_fire("UKR_S1", "hold")
    game.tactical_simulation.execute()
    game.tactical_simulation.step()
    check(game._save_campaign()["ok"], "Preferred target must persist in actual campaign checkpoint.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Disk restart must preserve the target preference and HOLD FIRE override.")
    for kind in range(5):
        var bad: Dictionary = saved.duplicate(true)
        match kind:
            0: bad["tactical_state"].erase("fire_targets")
            1: bad["tactical_state"]["fire_targets"]["UKR_S1"] = "UKR_S2"
            2: bad["tactical_state"]["fire_targets"]["UKR_S1"] = "UNKNOWN"
            3: bad["tactical_state"]["fire_targets"]["UKR_S1"] = 3
            4: bad["tactical_state"]["fire_targets"].erase("UKR_S1")
        check(not Saves.validate(bad, game.initial_campaign)["ok"] and same(saved, game._snapshot()), "Malformed preferences must reject without live-state changes.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Preferences and HOLD FIRE must preserve complete disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: eligible preference shots, hidden fallback/status, command locks, validation, legacy rules and actual disk restart.")
    quit(0 if failures.is_empty() else 1)
