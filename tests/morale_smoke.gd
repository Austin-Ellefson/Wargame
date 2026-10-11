extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "MORALE", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    for squad in battle.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1", "RU_S1"]: squad["alive"] = 0
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    blue["position"] = [200,250]
    blue["alive"] = 4
    blue["morale"] = 60
    blue["suppression"] = 0.72
    blue["ammo"] = 100
    battle.squad_by_id("RU_S1")["position"] = [240,250]
    battle.order_move("UKR_S1", Vector2(280,250))
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var waiting = fixture()
    waiting.squad_by_id("UKR_S1")["morale"] = 70
    waiting.squad_by_id("UKR_S1")["suppression"] = 0.7
    waiting.order_pause("UKR_S1", 15)
    waiting.execute()
    waiting.step()
    check(waiting.state["pause_remaining"]["UKR_S1"] == 0 and Battle.position(waiting.squad_by_id("UKR_S1")).x < 200, "A new withdrawal must clear and supersede the previous movement wait immediately.")
    var battle = fixture()
    battle.execute()
    battle.step()
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    check(battle.morale_state("UKR_S1") == "broken" and battle.combat_status(blue) == "BROKEN", "Heavy losses, low morale and suppression must trigger a persistent break.")
    var path: Array = battle.state["orders"]["UKR_S1"]
    check(path.back()[0] == 32 and battle.movement_mode("UKR_S1") == "quick" and Battle.validate(battle.state, PAYLOAD), "Breaking must replace the advance with a valid rearward QUICK route.")
    for tick in range(8): battle.step()
    check(blue["ammo"] == 100 and Battle.position(blue).x < 200, "Broken squads must withdraw without firing, subject to existing pinning/fatigue.")
    var rallied := false
    for tick in range(160):
        if battle.state["phase"] == "planning":
            check(not battle.order_move("UKR_S1", Vector2(280,250)) and not battle.order_hold("UKR_S1") and not battle.order_fire("UKR_S1", "auto"), "Broken squads must reject player override during planning.")
            battle.execute()
        battle.step()
        if battle.morale_state("UKR_S1") != "broken":
            rallied = true
            break
    check(rallied and Battle.position(blue).x <= 40 and battle.morale_state("UKR_S1") == "shaken" and battle.state["rally_remaining"]["UKR_S1"] == 0, "Thirty quiet stationary rear seconds must rally survivors to shaken.")
    battle.squad_by_id("RU_S1")["position"] = [80,250]
    for tick in range(3): battle.step()
    check(blue["ammo"] < 100, "Rallied shaken survivors must be able to fire again.")
    var legacy = fixture()
    legacy.state["version"] = 12
    legacy.state.erase("morale_states")
    legacy.state.erase("rally_remaining")
    check(Battle.validate(legacy.state, PAYLOAD), "V12 must preserve its original state fields.")
    legacy.execute()
    for tick in range(3): legacy.step()
    check(legacy.morale_state("UKR_S1") == "steady" and legacy.squad_by_id("UKR_S1")["ammo"] < 100, "V12 must not acquire retreat or withheld-fire rules.")
    var invalid: Dictionary = fixture().state.duplicate(true)
    invalid["rally_remaining"]["UKR_S1"] = 1
    check(not Battle.validate(invalid, PAYLOAD), "Nonbroken squads cannot have rally progress.")
    invalid = fixture().state.duplicate(true)
    invalid["morale_states"]["UKR_S1"] = "broken"
    check(not Battle.validate(invalid, PAYLOAD), "Living broken squads require a positive rally timer.")
    invalid["rally_remaining"]["UKR_S1"] = 30.5
    check(not Battle.validate(invalid, PAYLOAD), "Fractional/out-of-range rally timers reject.")
    invalid["morale_states"]["UNKNOWN"] = "steady"
    check(not Battle.validate(invalid, PAYLOAD), "Unknown morale IDs reject.")
    var firefight = Battle.new()
    firefight.setup(PAYLOAD)
    for squad in firefight.state["squads"]:
        squad["position"] = [100,208] if squad["faction"] == "UKR" else [250,208]
        if squad["faction"] == "UKR":
            squad["ammo"] = 0
            if squad["id"] != "UKR_S1": squad["alive"] = 0
    firefight.execute()
    var real_break := false
    for tick in range(24):
        firefight.step()
        if firefight.morale_state("UKR_S1") == "broken": real_break = true
    check(real_break, "Actual concentrated simulated fire must trigger break behavior without manually setting casualties or suppression.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://morale_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    for squad in game.tactical_simulation.state["squads"]: squad["ammo"] = 0
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180,245]
    game.tactical_simulation.squad_by_id("UKR_S1")["alive"] = 4
    game.tactical_simulation.squad_by_id("UKR_S1")["morale"] = 60
    game.tactical_simulation.squad_by_id("UKR_S1")["suppression"] = 0.72
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    game.tactical_simulation.order_fire("UKR_S1", "hold")
    game.tactical_simulation.execute()
    for tick in range(3): game.tactical_simulation.step()
    check(game.tactical_simulation.morale_state("UKR_S1") == "broken" and game._save_campaign()["ok"], "Actual campaign must checkpoint automatic withdrawal and rally progress.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Actual disk restart must preserve the broken state, withdrawal route and rally progress.")
    var partial_rally := false
    for tick in range(200):
        if game.tactical_simulation.state["phase"] == "planning":
            game.tactical_simulation.execute()
            resumed.tactical_simulation.execute()
        game.tactical_simulation.step()
        resumed.tactical_simulation.step()
        if game.tactical_simulation.state["rally_remaining"]["UKR_S1"] == 17:
            partial_rally = true
            break
    check(partial_rally and game._save_campaign()["ok"], "Actual disk checkpoint must persist a partially consumed rear rally timer.")
    resumed.tactical_simulation.step()
    check(resumed._load_campaign()["ok"] and same(game._snapshot(), resumed._snapshot()) and resumed.tactical_simulation.state["rally_remaining"]["UKR_S1"] == 17, "Reload must restore 17 remaining rally seconds rather than restarting the countdown.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Morale retreat/rally must preserve complete disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: real-fire morale break, rearward withdrawal, withheld fire/orders, timed rear rally, return fire, V12/validation and actual disk outcome equality.")
    quit(0 if failures.is_empty() else 1)
