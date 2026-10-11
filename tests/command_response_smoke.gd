extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id":"RESPONSE","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.state["version"] = 17
    sim.state.erase("shared_contacts")
    sim.state.erase("pending_reports")
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.order_move("UKR_S1",Vector2(420,245))
    return sim
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished": return
        if sim.state["phase"] == "planning": sim.execute()
        sim.step()
func _run() -> void:
    var sim = fixture()
    var start: Array = sim.squad_by_id("UKR_S1")["position"].duplicate()
    check(sim.state["version"] == 17 and sim.command_delay("UKR_S1") == 5 and Battle.validate(sim.state,PAYLOAD), "New valid movement orders must store five response seconds.")
    var snapshot: Dictionary = sim.state.duplicate(true)
    for repeat in range(20): sim.movement_status(sim.squad_by_id("UKR_S1"))
    sim.step()
    check(same(snapshot,sim.state), "Planning/query time cannot consume response.")
    check(not sim.order_move("UKR_S1",Vector2(-1,245)) and same(snapshot,sim.state), "Rejected orders must retain path and timer.")
    check(sim.order_move("UKR_S1",Vector2(440,245),true,"move",true) and sim.command_delay("UKR_S1") == 5, "Appending must preserve pending command response.")
    sim.squad_by_id("UKR_S1")["ammo"] = 9
    sim.execute()
    for tick in range(3): sim.step()
    check(sim.command_delay("UKR_S1") == 2 and same(start,sim.squad_by_id("UKR_S1")["position"]) and not sim.last_events.is_empty(), "Response holds movement but permits actual acquired fire at second three.")
    sim.step()
    sim.step()
    check(sim.command_delay("UKR_S1") == 0 and same(start,sim.squad_by_id("UKR_S1")["position"]), "Fifth response second must still hold movement.")
    sim.step()
    check(not same(start,sim.squad_by_id("UKR_S1")["position"]), "Sixth executed second must start actual movement.")
    for tick in range(54): sim.step()
    check(sim.state["phase"] == "planning" and sim.command_delay("UKR_S1") == 0 and sim.state["orders"].has("UKR_S1"), "Long route must persist across interval without charging response again.")
    check(sim.order_move("UKR_S1",Vector2(450,245),true,"move",true) and sim.command_delay("UKR_S1") == 0, "Appending to acknowledged route cannot restart delay.")
    check(sim.order_move("UKR_S1",Vector2(180,245)) and sim.command_delay("UKR_S1") == 5, "Replacing a route must charge a fresh response.")
    check(sim.order_hold("UKR_S1") and sim.command_delay("UKR_S1") == 0 and not sim.state["orders"].has("UKR_S1"), "Hold must cancel route and pending response.")
    var paused = fixture()
    paused.order_pause("UKR_S1",15)
    paused.execute()
    for tick in range(15): paused.step()
    check(paused.command_delay("UKR_S1") == 0 and paused.state["pause_remaining"]["UKR_S1"] == 0 and same(start,paused.squad_by_id("UKR_S1")["position"]), "Manual wait and response must count concurrently, not add five hidden seconds.")
    paused.step()
    check(not same(start,paused.squad_by_id("UKR_S1")["position"]), "Completed pause must allow motion on the next second.")
    var broken = fixture()
    broken.squad_by_id("UKR_S1")["suppression"] = 0.7
    broken.squad_by_id("UKR_S1")["morale"] = 30
    broken.execute()
    broken.step()
    check(broken.morale_state("UKR_S1") == "broken" and broken.command_delay("UKR_S1") == 0, "Automatic withdrawal must replace orders without waiting for a player response.")
    var dead = fixture()
    dead.squad_by_id("UKR_S1")["alive"] = 0
    dead.execute()
    dead.step()
    check(dead.command_delay("UKR_S1") == 0 and not dead.state["orders"].has("UKR_S1"), "Death must clear response and orders.")
    var combat_death := false
    for trial in range(30):
        var victim = fixture()
        victim.state["battle_id"] = "RESPONSE_DEATH_%d" % trial
        victim.squad_by_id("UKR_S1")["alive"] = 1
        victim.squad_by_id("RU_S1")["ammo"] = 360
        victim.execute()
        for tick in range(3): victim.step()
        if victim.squad_by_id("UKR_S1")["alive"] == 0:
            combat_death = true
            var payload: Dictionary = PAYLOAD.duplicate(true)
            payload["battle_id"] = victim.state["battle_id"]
            check(victim.command_delay("UKR_S1") == 0 and Battle.validate(victim.state,payload), "Actual same-tick shot death must clear response before a valid checkpoint.")
            break
    check(combat_death, "Death cleanup regression must reach an actual firing casualty.")
    var legacy = fixture()
    legacy.state["version"] = 16
    legacy.state.erase("command_remaining")
    legacy.state.erase("shared_contacts")
    legacy.state.erase("pending_reports")
    legacy.execute()
    legacy.step()
    check(Battle.validate(legacy.state,PAYLOAD) and not same(start,legacy.squad_by_id("UKR_S1")["position"]), "V16 retains immediate movement and old fields.")
    var valid = fixture()
    for value in [-1,6,1.5,"5",null,{},[]]:
        var bad: Dictionary = valid.state.duplicate(true)
        bad["command_remaining"]["UKR_S1"] = value
        check(not Battle.validate(bad,PAYLOAD), "Malformed response timers must reject.")
    for corruption in range(4):
        var bad: Dictionary = valid.state.duplicate(true)
        match corruption:
            0: bad["command_remaining"].erase("UKR_S1")
            1: bad["command_remaining"]["UNKNOWN"] = 0
            2: bad["command_remaining"]["UKR_S2"] = 5
            3: bad["squads"][0]["alive"] = 0
        check(not Battle.validate(bad,PAYLOAD), "Missing/extra/no-route/dead response entries must reject.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://response_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.state["version"] = 17
    game.tactical_simulation.state.erase("shared_contacts")
    game.tactical_simulation.state.erase("pending_reports")
    var battle = game.tactical_simulation
    battle.order_move("UKR_S1",Vector2(210,245),true,"quick")
    battle.execute()
    battle.step()
    battle.step()
    check(battle.command_delay("UKR_S1") == 3 and game._save_campaign()["ok"], "Actual campaign must save a partially acknowledged order.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()), "Real disk restart must preserve path and remaining response exactly.")
    finish(battle)
    finish(resumed.tactical_simulation)
    check(same(battle.state,resumed.tactical_simulation.state) and same(battle.result(),resumed.tactical_simulation.result()), "Partial-response campaign disk continuation must preserve full actual combat outcomes.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: actual response motion/fire, planning purity, replacement/append/hold, concurrent pause, withdrawal/death cleanup, strict saves, V16 isolation and full actual campaign disk outcomes.")
    quit(0 if failures.is_empty() else 1)
