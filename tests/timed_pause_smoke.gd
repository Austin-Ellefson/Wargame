extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const Saves = preload("res://scripts/campaign_save.gd")
const PAYLOAD = {"battle_id": "PAUSE_ORDERS", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
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
    for squad in battle.state["squads"]: squad["ammo"] = 0
    check(not battle.order_pause("UKR_S1", 15), "Wait requires a queued route.")
    battle.order_move("UKR_S1", Vector2(180, 250), true, "quick")
    var untouched: Dictionary = battle.state.duplicate(true)
    check(not battle.order_pause("UKR_S1", -1) and not battle.order_pause("UKR_S1", 61) and not battle.order_pause("UKR_S1", 1.5) and not battle.order_pause("RU_S1", 15) and same(untouched, battle.state), "Invalid/fractional/excessive/opponent waits must reject atomically.")
    battle.order_pause("UKR_S1", 15)
    battle.order_move("UKR_S1", Vector2(320, 300), true, "quick", true)
    check(battle.state["pause_remaining"]["UKR_S1"] == 15, "Appending a leg must preserve the wait.")
    battle.execute()
    check(not battle.order_pause("UKR_S1", 0), "Wait cannot be changed during execution.")
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    var origin := Battle.position(blue)
    var route: Array = battle.state["orders"]["UKR_S1"].duplicate(true)
    for tick in range(15):
        battle.step()
        check(Battle.position(blue) == origin and same(route, battle.state["orders"]["UKR_S1"]) and int(battle.state["pause_remaining"]["UKR_S1"]) == 14 - tick, "Each exact wait second must decrement without consuming route points.")
    battle.step()
    check(Battle.position(blue) != origin, "Movement must resume on the tick after the requested wait.")
    var firing = Battle.new()
    firing.setup(PAYLOAD)
    firing.squad_by_id("UKR_S1")["position"] = [180, 245]
    firing.squad_by_id("RU_S1")["position"] = [240, 245]
    firing.order_move("UKR_S1", Vector2(200, 245))
    firing.order_pause("UKR_S1", 15)
    firing.execute()
    for tick in range(3): firing.step()
    check(int(firing.squad_by_id("UKR_S1")["ammo"]) < 360 and Battle.position(firing.squad_by_id("UKR_S1")) == Vector2(180, 245), "Waiting must preserve real automatic firing without moving.")
    var replacement = Battle.new()
    replacement.setup(PAYLOAD)
    replacement.order_move("UKR_S1", Vector2(180, 250))
    replacement.order_pause("UKR_S1", 30)
    replacement.order_move("UKR_S1", Vector2(160, 250))
    check(replacement.state["pause_remaining"]["UKR_S1"] == 0, "Replacing the route clears the old timer.")
    replacement.order_pause("UKR_S1", 60)
    replacement.order_hold("UKR_S1")
    check(replacement.state["pause_remaining"]["UKR_S1"] == 0, "Hold clears route and timer together.")
    var old = Battle.new()
    old.setup(PAYLOAD)
    old.state["version"] = 7
    old.state.erase("fatigue")
    old.state.erase("pause_remaining")
    check(Battle.validate(old.state, PAYLOAD) and not old.order_pause("UKR_S1", 15), "Old v7 fields/rules must remain valid without timers.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://pause_orders_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    for squad in game.tactical_simulation.state["squads"]: squad["ammo"] = 0
    game.tactical_simulation.order_move("UKR_S1", Vector2(180, 250), true, "quick")
    game.tactical_simulation.order_pause("UKR_S1", 30)
    game.tactical_simulation.execute()
    for tick in range(12): game.tactical_simulation.step()
    check(game._save_campaign()["ok"], "Campaign must checkpoint a partially consumed wait.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()) and resumed.tactical_simulation.state["pause_remaining"]["UKR_S1"] == 18, "Actual disk restart must retain the remaining wait, not restart the timer.")
    for kind in range(6):
        var bad: Dictionary = saved.duplicate(true)
        match kind:
            0: bad["tactical_state"].erase("pause_remaining")
            1: bad["tactical_state"]["pause_remaining"]["UKR_S1"] = -1
            2: bad["tactical_state"]["pause_remaining"]["UKR_S1"] = 61
            3: bad["tactical_state"]["pause_remaining"]["UKR_S1"] = 1.5
            4: bad["tactical_state"]["pause_remaining"]["UNKNOWN"] = 15
            5: bad["tactical_state"]["orders"].erase("UKR_S1"); bad["tactical_state"]["movement_modes"].erase("UKR_S1")
        check(not Saves.validate(bad, game.initial_campaign)["ok"] and same(saved, game._snapshot()), "Invalid and orphan waits must reject without live-state changes.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Timed-wait restart must preserve full outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: exact countdown, route retention/resume, live fire, command locks, timer cleanup, validation and disk restart.")
    quit(0 if failures.is_empty() else 1)
