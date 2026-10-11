extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "COVERED_GOALS", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(version: int = 11) -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    battle.state["version"] = version
    if int(battle.state["version"]) < 14: battle.state.erase("postures")
    if version < 13: battle.state.erase("morale_states")
    if version < 13: battle.state.erase("rally_remaining")
    if version < 12: battle.state.erase("fatigue")
    for squad in battle.state["squads"]: squad["ammo"] = 0
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var battle = fixture()
    check(Battle.validate(battle.state, PAYLOAD), "V11 fields must validate before commands.")
    battle.execute()
    var destinations: Array[Vector2] = []
    for squad in battle.state["squads"]:
        if squad["faction"] != "RU": continue
        var route: Array = battle.state["orders"][squad["id"]]
        var target := Vector2(route.back()[0], route.back()[1])
        check(Battle.cover(target) > 0.2 and target.distance_to(Vector2(256,256)) < 52 and not Battle.inside_building(target, 5), "Every opponent destination must be covered, walkable and inside the actual capture zone.")
        for other in destinations: check(target.distance_to(other) >= 12, "Squads must reserve separated covered positions.")
        destinations.append(target)
    for tick in range(180):
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
    for index in range(4):
        var red: Dictionary = battle.squad_by_id("RU_S%d" % (index+1))
        check(Battle.position(red).is_equal_approx(destinations[index]) and not battle.state["orders"].has(red["id"]), "Actual squads must reach and hold their reserved positions across intervals.")
    check(battle.state["objective"]["RU"] > 0 and Battle.validate(battle.state, PAYLOAD), "Covered occupation must earn actual objective time and retain valid state.")
    var legacy = fixture(10)
    legacy.execute()
    for index in range(4):
        var path: Array = legacy.state["orders"]["RU_S%d" % (index+1)]
        check(Vector2(path.back()[0], path.back()[1]) == Vector2(272,218+index*24), "V10 must retain its original lane destinations.")
    var hidden = fixture()
    hidden.squad_by_id("UKR_S1")["position"] = [4,508]
    hidden.state["contacts"]["RU"] = {"UKR_S1": {"position": [300,300], "seen_at": 0}}
    hidden.execute()
    var initial = fixture()
    initial.execute()
    check(same(initial.state["orders"], hidden.state["orders"]), "Hidden enemy positions and memories must not alter covered goals or routes.")
    var blocked = fixture()
    for y in range(25,39):
        for x in range(25,39): blocked.cover_navigation.set_point_solid(Vector2i(x,y), true)
    var reserved: Array[Vector2] = []
    check(blocked.opponent_destination(blocked.squad_by_id("RU_S1"), reserved) == Vector2(272,218), "No reachable cover must return the original objective fallback.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://goals_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    for squad in game.tactical_simulation.state["squads"]: squad["ammo"] = 0
    game.tactical_simulation.execute()
    for tick in range(40): game.tactical_simulation.step()
    check(game._save_campaign()["ok"] and game.tactical_simulation.state["orders"].has("RU_S2"), "Actual campaign must checkpoint an unfinished covered objective route.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Actual disk restart must preserve the covered destinations and rules version.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Covered destinations must preserve complete disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: separated reachable covered goals, actual objective occupation/holding, fallback, V10/hidden-input isolation and disk outcome equality.")
    quit(0 if failures.is_empty() else 1)
