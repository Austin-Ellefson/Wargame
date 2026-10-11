extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "OPPONENT_REACTION", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(blue_point: Vector2 = Vector2(80, 250)) -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    for squad in battle.state["squads"]:
        if squad["id"] not in ["UKR_S1", "RU_S1"]: squad["alive"] = 0
        if squad["faction"] == "UKR": squad["ammo"] = 0
    battle.squad_by_id("UKR_S1")["position"] = [blue_point.x, blue_point.y]
    battle.squad_by_id("RU_S1")["position"] = [200, 250]
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var battle = fixture()
    battle.execute()
    var red: Dictionary = battle.squad_by_id("RU_S1")
    var origin := Battle.position(red)
    var route: Array = battle.state["orders"]["RU_S1"].duplicate(true)
    for tick in range(3): battle.step()
    var actual_fire := false
    for event in battle.consume_events():
        if event["shooter"] == "RU_S1": actual_fire = true
    check(battle.opponent_engaging(red) and Battle.position(red) == origin and same(route, battle.state["orders"]["RU_S1"]) and actual_fire, "Red must retain its objective route and fire from its local contact position.")
    battle.squad_by_id("UKR_S1")["position"] = [500, 480]
    battle.step()
    check(not battle.opponent_engaging(red) and Battle.position(red) != origin, "Lost local contact must resume objective advance.")
    var empty = fixture()
    empty.squad_by_id("RU_S1")["ammo"] = 0
    empty.execute()
    origin = Battle.position(empty.squad_by_id("RU_S1"))
    empty.step()
    check(Battle.position(empty.squad_by_id("RU_S1")) != origin, "Ammunition exhaustion must end the stop-and-engage reaction.")
    var withheld = fixture()
    withheld.order_fire("RU_S1", "hold", false)
    withheld.execute()
    origin = Battle.position(withheld.squad_by_id("RU_S1"))
    withheld.step()
    check(Battle.position(withheld.squad_by_id("RU_S1")) != origin, "HOLD FIRE must not create an automatic firing-contact halt.")
    var shared = fixture(Vector2(500, 480))
    shared.squad_by_id("RU_S2")["alive"] = 9
    shared.squad_by_id("RU_S2")["position"] = [430, 480]
    shared.execute()
    origin = Battle.position(shared.squad_by_id("RU_S1"))
    check(shared.is_observed("RU", shared.squad_by_id("UKR_S1")) and not shared.can_engage(shared.squad_by_id("RU_S1"), shared.squad_by_id("UKR_S1")), "Shared-contact fixture must be outside the individual squad's sight/range.")
    shared.step()
    check(Battle.position(shared.squad_by_id("RU_S1")) != origin, "Shared contacts must not halt a squad with no local firing contact.")
    var hidden_a = fixture(Vector2(480, 480))
    var hidden_b = fixture(Vector2(500, 480))
    hidden_a.execute()
    hidden_b.execute()
    hidden_a.step()
    hidden_b.step()
    check(same(hidden_a.squad_by_id("RU_S1")["position"], hidden_b.squad_by_id("RU_S1")["position"]) and same(hidden_a.state["orders"]["RU_S1"], hidden_b.state["orders"]["RU_S1"]), "Unobserved player positions must not change red movement decisions.")
    var blocked = fixture(Vector2(280, 166))
    blocked.squad_by_id("RU_S1")["position"] = [200, 166]
    check(not blocked.opponent_engaging(blocked.squad_by_id("RU_S1")), "Building-blocked contact cannot cause the firing reaction.")
    var legacy = fixture()
    legacy.state["version"] = 8
    legacy.state.erase("morale_states")
    legacy.state.erase("rally_remaining")
    legacy.state.erase("fatigue")
    check(Battle.validate(legacy.state, PAYLOAD), "V8 retains exactly its prior fields.")
    legacy.execute()
    origin = Battle.position(legacy.squad_by_id("RU_S1"))
    legacy.step()
    check(not legacy.opponent_engaging(legacy.squad_by_id("RU_S1")) and Battle.position(legacy.squad_by_id("RU_S1")) != origin, "V8 objective advance must not silently acquire V9 reaction behavior.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://reaction_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    game.tactical_simulation.order_fire("UKR_S1", "hold")
    game.tactical_simulation.execute()
    for tick in range(3): game.tactical_simulation.step()
    check(game.tactical_simulation.opponent_engaging(game.tactical_simulation.squad_by_id("RU_S1")) and game._save_campaign()["ok"], "Actual campaign must checkpoint an engaging red squad.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Actual disk restart must preserve the opponent's derived reaction and route.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Local-contact reaction must preserve complete disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: local stop-and-fire, route resume, ammo/HOLD FIRE, shared/hidden isolation, blocked LOS, V8 preservation and disk restart.")
    quit(0 if failures.is_empty() else 1)
