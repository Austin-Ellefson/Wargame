extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "FATIGUE", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(mode: String = "quick", amount: float = 0.0) -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    battle.state["version"] = 15
    battle.state.erase("acquisition")
    battle.state.erase("command_remaining")
    battle.state.erase("shared_contacts")
    battle.state.erase("pending_reports")
    for squad in battle.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1", "RU_S1"]: squad["alive"] = 0
    battle.squad_by_id("UKR_S1")["position"] = [80, 250]
    battle.squad_by_id("RU_S1")["position"] = [470, 470]
    battle.state["fatigue"]["UKR_S1"] = int(round(amount * 1000))
    battle.order_move("UKR_S1", Vector2(180,250), true, mode)
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var values: Array[float] = []
    for mode in ["quick", "move", "hunt"]:
        var battle = fixture(mode)
        battle.execute()
        battle.step()
        values.append(battle.fatigue("UKR_S1"))
        check(Battle.validate(battle.state, PAYLOAD), "Earned fatigue must validate.")
    check(is_equal_approx(values[0], 0.008) and is_equal_approx(values[1], 0.002) and is_equal_approx(values[2], 0.001), "Actual distance and mode must determine fatigue; QUICK costs most.")
    var tired = fixture("quick", 0.8)
    tired.execute()
    var origin := Battle.position(tired.squad_by_id("UKR_S1"))
    tired.step()
    check(is_equal_approx(origin.distance_to(Battle.position(tired.squad_by_id("UKR_S1"))), 2.4), "80 percent fatigue must reduce QUICK speed from 4 to 2.4 metres per second.")
    var rested = fixture("quick", 0.6)
    rested.order_pause("UKR_S1", 15)
    var before: Dictionary = rested.state.duplicate(true)
    rested.step()
    rested.fatigue("UKR_S1")
    check(same(before, rested.state), "Planning and presentation queries must not recover fatigue.")
    rested.execute()
    origin = Battle.position(rested.squad_by_id("UKR_S1"))
    rested.step()
    check(Battle.position(rested.squad_by_id("UKR_S1")) == origin and is_equal_approx(rested.fatigue("UKR_S1"), 0.597), "Timed waiting must recover rather than charge a queued QUICK route.")
    var pinned = fixture("quick", 0.6)
    pinned.squad_by_id("UKR_S1")["suppression"] = 1
    pinned.execute()
    pinned.step()
    check(is_equal_approx(pinned.fatigue("UKR_S1"), 0.597), "Pinned stationary squads must rest rather than incur movement fatigue.")
    var capped = fixture("quick", 1.0)
    capped.execute()
    capped.step()
    check(capped.fatigue("UKR_S1") == 1.0, "Moving fatigue must remain bounded at one.")
    var legacy = fixture()
    legacy.state["version"] = 11
    if int(legacy.state["version"]) < 15: legacy.state.erase("weapon_roles")
    if int(legacy.state["version"]) < 14: legacy.state.erase("postures")
    legacy.state.erase("morale_states")
    legacy.state.erase("rally_remaining")
    legacy.state.erase("fatigue")
    check(Battle.validate(legacy.state, PAYLOAD), "V11 must retain its original field contract.")
    legacy.execute()
    legacy.step()
    origin = Battle.position(legacy.squad_by_id("UKR_S1"))
    legacy.step()
    check(is_equal_approx(origin.distance_to(Battle.position(legacy.squad_by_id("UKR_S1"))), 4.0) and not legacy.state.has("fatigue"), "Legacy QUICK must not silently acquire fatigue.")
    var valid = fixture()
    for bad in [-1,1001,0.5,"500",null,NAN,INF]:
        var invalid: Dictionary = valid.state.duplicate(true)
        invalid["fatigue"]["UKR_S1"] = bad
        check(not Battle.validate(invalid, PAYLOAD), "Malformed or unbounded fatigue must reject.")
    var missing: Dictionary = valid.state.duplicate(true)
    missing["fatigue"].erase("UKR_S1")
    check(not Battle.validate(missing, PAYLOAD), "Missing squad fatigue must reject.")
    missing = valid.state.duplicate(true)
    missing["fatigue"]["UNKNOWN"] = 0
    check(not Battle.validate(missing, PAYLOAD), "Extra squad fatigue must reject.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://fatigue_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.state["version"] = 15
    game.tactical_simulation.state.erase("acquisition")
    game.tactical_simulation.state.erase("command_remaining")
    game.tactical_simulation.state.erase("shared_contacts")
    game.tactical_simulation.state.erase("pending_reports")
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    game.tactical_simulation.order_fire("UKR_S1", "hold")
    game.tactical_simulation.order_move("UKR_S3", Vector2(210,300), true, "quick")
    game.tactical_simulation.execute()
    for tick in range(3): game.tactical_simulation.step()
    check(game.tactical_simulation.fatigue("UKR_S3") > 0 and game._save_campaign()["ok"], "Actual campaign must checkpoint earned movement fatigue during actual combat.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Actual disk restart must preserve the fatigue and orders.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Fatigue must preserve complete disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: actual-distance fatigue, speed cost, paused/pinned rest, clock/query isolation, bounds/validation, V11 preservation and real-combat disk outcome equality.")
    quit(0 if failures.is_empty() else 1)
