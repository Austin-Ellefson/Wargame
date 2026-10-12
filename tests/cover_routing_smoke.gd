extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "COVER_ROUTING", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(version: int = 10) -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    battle.state["version"] = 15
    battle.state.erase("acquisition")
    battle.state.erase("command_remaining")
    battle.state.erase("shared_contacts")
    battle.state.erase("pending_reports")
    battle.state.erase("observer_contacts")
    battle.state.erase("facing_orders")
    battle.state.erase("area_fire")
    battle.state["version"] = version
    if int(battle.state["version"]) < 15: battle.state.erase("weapon_roles")
    if int(battle.state["version"]) < 14: battle.state.erase("postures")
    if version < 13: battle.state.erase("morale_states")
    if version < 13: battle.state.erase("rally_remaining")
    if version < 12: battle.state.erase("fatigue")
    for squad in battle.state["squads"]: squad["ammo"] = 0
    battle.squad_by_id("RU_S2")["position"] = [432, 240]
    return battle
func wooded_points(path: Array) -> int:
    var count := 0
    for point in path:
        if Battle.cover(Vector2(point[0], point[1])) > 0.2: count += 1
    return count
func path_length(origin: Vector2, path: Array) -> float:
    var length := 0.0
    for point in path:
        var next := Vector2(point[0], point[1])
        length += origin.distance_to(next)
        origin = next
    return length
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var battle = fixture()
    var legacy = fixture(9)
    check(Battle.validate(battle.state, PAYLOAD) and Battle.validate(legacy.state, PAYLOAD), "V10 and V9 share valid fields without silent migration.")
    battle.execute()
    legacy.execute()
    var route: Array = battle.state["orders"]["RU_S2"].duplicate(true)
    var old_route: Array = legacy.state["orders"]["RU_S2"]
    check(wooded_points(route) >= 4 and wooded_points(old_route) == 0, "Actual objective advance must prefer nearby woods over the V9 open route.")
    check(path_length(Vector2(432, 240), route) < path_length(Vector2(432, 240), old_route) * 1.15, "Cover preference must use a modest detour in the reference lane.")
    for point in route:
        check(not Battle.inside_building(Vector2(point[0], point[1]), 5.0), "Cover paths must retain building clearance.")
    var entered_woods := false
    for tick in range(90):
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
        if Battle.cover(Battle.position(battle.squad_by_id("RU_S2"))) > 0.2: entered_woods = true
    check(entered_woods, "A real executing squad must traverse cover, not just plan a covered route.")
    var blue = fixture()
    var old_blue = fixture(9)
    blue.squad_by_id("UKR_S1")["position"] = [432, 240]
    old_blue.squad_by_id("UKR_S1")["position"] = [432, 240]
    blue.order_move("UKR_S1", Vector2(272, 242))
    old_blue.order_move("UKR_S1", Vector2(272, 242))
    check(same(blue.state["orders"], old_blue.state["orders"]), "Opponent costs must not change player path selection.")
    var hidden_a = fixture()
    var hidden_b = fixture()
    hidden_a.squad_by_id("UKR_S1")["position"] = [4, 4]
    hidden_b.squad_by_id("UKR_S1")["position"] = [4, 508]
    hidden_b.state["contacts"]["RU"] = {"UKR_S1": {"position": [500, 500], "seen_at": 0}}
    hidden_a.execute()
    hidden_b.execute()
    check(same(hidden_a.state["orders"], hidden_b.state["orders"]), "Enemy positions and shared/remembered contacts must not enter terrain costs.")
    var restored = Battle.new()
    restored.restore(legacy.state)
    check(restored.state["version"] == 9 and same(restored.state["orders"], legacy.state["orders"]), "V9 restart must retain the prior open route.")
    var blocked = fixture()
    blocked.order_move("RU_S2", Vector2(272, 242), false)
    var before: Dictionary = blocked.state.duplicate(true)
    check(not blocked.order_move("RU_S2", Vector2(230, 160), false) and same(before, blocked.state), "Blocked opponent destinations must reject atomically.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://cover_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.state["version"] = 15
    game.tactical_simulation.state.erase("acquisition")
    game.tactical_simulation.state.erase("command_remaining")
    game.tactical_simulation.state.erase("shared_contacts")
    game.tactical_simulation.state.erase("pending_reports")
    game.tactical_simulation.state.erase("observer_contacts")
    game.tactical_simulation.state.erase("facing_orders")
    game.tactical_simulation.state.erase("area_fire")
    for squad in game.tactical_simulation.state["squads"]: squad["ammo"] = 0
    game.tactical_simulation.execute()
    for tick in range(40): game.tactical_simulation.step()
    check(game._save_campaign()["ok"] and game.tactical_simulation.state["orders"].has("RU_S2"), "Actual campaign must checkpoint an unfinished cover-weighted route.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved, resumed._snapshot()), "Actual disk restart must preserve the cover route and rules version.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state) and same(game.tactical_simulation.result(), resumed.tactical_simulation.result()), "Cover routing must preserve complete disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: terrain-weighted objective routes, modest detour, actual covered movement, player/V9 isolation, hidden-information independence and campaign disk outcome equality.")
    quit(0 if failures.is_empty() else 1)
