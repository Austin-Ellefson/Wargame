extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "POSTURE", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
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
    battle.squad_by_id("UKR_S1")["position"] = [80,250]
    battle.squad_by_id("RU_S1")["position"] = [470,470]
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    for value in ["stand", "crouch", "prone"]:
        var battle = fixture()
        check(battle.order_move("UKR_S1", Vector2(180,250), true, "quick") and battle.order_pause("UKR_S1", 15), "Posture fixture must establish a queued route and timed wait.")
        var orders: Dictionary = battle.state["orders"].duplicate(true)
        check(battle.order_posture("UKR_S1", value) and same(orders, battle.state["orders"]) and battle.state["pause_remaining"]["UKR_S1"] == 15, "Posture orders must retain the route, mode and pause.")
        var before: Dictionary = battle.state.duplicate(true)
        battle.step()
        battle.posture_height("UKR_S1")
        check(same(before, battle.state), "Planning/query time must not move squads or consume simulation randomness.")
        battle.order_pause("UKR_S1", 0)
        battle.execute()
        check(not battle.order_posture("UKR_S1", "stand"), "Posture commands must freeze in execution.")
        var origin := Battle.position(battle.squad_by_id("UKR_S1"))
        battle.step()
        var expected: float = {"stand": 4.0, "crouch": 2.8, "prone": 1.2}[value]
        check(is_equal_approx(origin.distance_to(Battle.position(battle.squad_by_id("UKR_S1"))), expected), "Actual QUICK motion must scale with posture.")
        check(Battle.validate(battle.state, PAYLOAD), "Each executed posture must validate.")
    var sight = fixture()
    var blue: Dictionary = sight.squad_by_id("UKR_S1")
    var red: Dictionary = sight.squad_by_id("RU_S1")
    blue["position"] = [100,250]
    red["position"] = [290,250]
    check(sight.can_spot(blue,red), "Standing observer must spot the unobstructed standing contact.")
    sight.order_posture("RU_S1", "prone", false)
    check(not sight.can_spot(blue,red) and not sight.can_engage(blue,red), "Prone target concealment must remove distant contact and prohibit firing.")
    sight.order_posture("RU_S1", "stand", false)
    red["position"] = [330,250]
    sight.order_posture("UKR_S1", "prone")
    check(not sight.can_spot(blue,red), "Prone observer must lose distant sight even of standing target.")
    sight.order_posture("UKR_S1", "stand")
    check(sight.can_spot(blue,red), "Standing must reacquire an unobstructed contact within its range.")
    # Find one real synthetic hill segment where lower eyes lose terrain LOS.
    var hill_occluded := false
    for y in range(60, 230, 10):
        for x in range(40, 240, 10):
            var a := Vector2(x,y)
            var b := Vector2(x+140,y)
            if Battle.visible(a,b) and not Battle.visible(a,b,0.35,0.35): hill_occluded = true
    check(hill_occluded, "The actual terrain sampler must obstruct a low posture where standing eyes see over a hill.")
    blue["position"] = [180,245]
    red["position"] = [240,245]
    var probability: float = sight.hit_probability(red,blue)
    sight.order_posture("UKR_S1", "crouch")
    check(is_equal_approx(sight.hit_probability(red,blue), probability*0.75), "Crouched exposure must reduce hit probability.")
    sight.order_posture("UKR_S1", "prone")
    check(is_equal_approx(sight.hit_probability(red,blue), probability*0.5), "Prone exposure must reduce hit probability further.")
    # Same battle ID and tick use identical attack random samples. Actual shots
    # must consume the same ammo but cannot produce more prone-target casualties.
    var standing = fixture()
    standing.squad_by_id("UKR_S1")["position"] = [180,245]
    standing.squad_by_id("RU_S1")["position"] = [240,245]
    standing.squad_by_id("RU_S1")["ammo"] = 100
    var prone = Battle.new()
    prone.restore(standing.state)
    prone.order_posture("UKR_S1", "prone")
    standing.execute()
    prone.execute()
    for tick in range(3):
        standing.step()
        prone.step()
    check(not standing.last_events.is_empty() and not prone.last_events.is_empty() and prone.squad_by_id("UKR_S1")["alive"] >= standing.squad_by_id("UKR_S1")["alive"] and prone.squad_by_id("RU_S1")["ammo"] == standing.squad_by_id("RU_S1")["ammo"], "Real attacks must apply reduced exposure with unchanged shot cadence/ammo/random samples.")
    var broken = fixture()
    broken.order_posture("UKR_S1", "prone")
    broken.squad_by_id("UKR_S1")["morale"] = 30
    broken.squad_by_id("UKR_S1")["suppression"] = 0.72
    broken.execute()
    broken.step()
    check(broken.morale_state("UKR_S1") == "broken" and broken.posture("UKR_S1") == "stand", "Automatic withdrawal must stand a broken prone squad before routing it rearward.")
    broken.state["phase"] = "planning"
    check(not broken.order_posture("UKR_S1","prone"), "Broken survivors cannot override withdrawal posture.")
    var valid = fixture()
    check(not valid.order_posture("RU_S1","prone") and not valid.order_posture("UKR_S2","prone") and not valid.order_posture("UKR_S1","flying") and not valid.order_posture("UNKNOWN","prone"), "Enemy, eliminated, unknown and invalid posture commands must reject.")
    for bad in ["kneel",1,null,[],{}]:
        var invalid: Dictionary = valid.state.duplicate(true)
        invalid["postures"]["UKR_S1"] = bad
        check(not Battle.validate(invalid,PAYLOAD), "Unknown/nonstrings must reject in posture saves.")
    var invalid: Dictionary = valid.state.duplicate(true)
    invalid["postures"].erase("UKR_S1")
    check(not Battle.validate(invalid,PAYLOAD), "Missing posture IDs must reject.")
    invalid = valid.state.duplicate(true)
    invalid["postures"]["UNKNOWN"] = "stand"
    check(not Battle.validate(invalid,PAYLOAD), "Extra posture IDs must reject.")
    var legacy = fixture()
    legacy.state["version"] = 13
    if int(legacy.state["version"]) < 15: legacy.state.erase("weapon_roles")
    legacy.state.erase("postures")
    check(Battle.validate(legacy.state,PAYLOAD) and not legacy.order_posture("UKR_S1","prone"), "V13 retains its field contract and cannot silently acquire posture orders.")
    legacy.order_move("UKR_S1",Vector2(180,250),true,"quick")
    legacy.execute()
    legacy.step()
    check(is_equal_approx(Battle.position(legacy.squad_by_id("UKR_S1")).distance_to(Vector2(80,250)),4.0) and not legacy.state.has("postures"), "V13 retains standing speed and fields.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://posture_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var sim = game.tactical_simulation
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.order_posture("UKR_S1","prone")
    sim.order_posture("UKR_S3","crouch")
    sim.order_move("UKR_S3",Vector2(210,300),true,"quick")
    sim.execute()
    for tick in range(3): sim.step()
    check(not sim.last_events.is_empty() and game._save_campaign()["ok"], "Actual campaign must checkpoint mixed postures during real combat.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved,resumed._snapshot()), "Actual disk restart must restore postures, contacts and orders exactly.")
    finish(sim)
    finish(resumed.tactical_simulation)
    check(same(sim.state,resumed.tactical_simulation.state) and same(sim.result(),resumed.tactical_simulation.result()), "Mixed-posture actual combat must preserve full disk-restarted outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: posture input restrictions, real speed/spotting/hill LOS/exposure attacks, withdrawal override, strict saves, V13 isolation and actual combat disk outcome equality.")
    quit(0 if failures.is_empty() else 1)
