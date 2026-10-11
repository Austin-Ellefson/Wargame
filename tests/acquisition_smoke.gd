extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id":"ACQUIRE", "ukraine":{"id":"BLUE","personnel":36,"morale":80}, "russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    for squad in battle.state["squads"]:
        if squad["id"] not in ["UKR_S1","RU_S1"]: squad["alive"] = 0
        squad["ammo"] = 0
    battle.squad_by_id("UKR_S1")["position"] = [180,245]
    battle.squad_by_id("RU_S1")["position"] = [240,245]
    battle.execute()
    battle.state["orders"].clear()
    battle.state["movement_modes"].clear()
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var battle = fixture()
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    var red: Dictionary = battle.squad_by_id("RU_S1")
    check(battle.state["version"] == 16 and battle.has_sight(blue,red) and not battle.can_spot(blue,red), "Geometry alone must not identify a fresh contact.")
    var saved: Dictionary = battle.state.duplicate(true)
    for repeat in range(20):
        battle.can_spot(blue,red)
        battle.is_observed("UKR",red)
        battle._update_contacts()
    battle.step() # execution time, not queries, earns progress
    check(not battle.can_spot(blue,red) and int(battle.state["acquisition"]["UKR_S1"]["RU_S1"]) == 1, "One executed second must earn exactly one second, independent of queries.")
    battle.step()
    check(not battle.is_observed("UKR",red) and battle.state["contacts"]["UKR"].is_empty(), "Two seconds cannot expose current or remembered enemy positions.")
    var snapshot: Dictionary = battle.state.duplicate(true)
    for repeat in range(20): battle.can_spot(blue,red)
    check(same(snapshot,battle.state), "Spotting queries cannot mutate acquisition or RNG.")
    blue["ammo"] = 360
    battle.step()
    check(battle.can_spot(blue,red) and battle.can_engage(blue,red) and battle.last_events.size() == 1, "Third consecutive second must permit the actual rifle shot.")
    check(battle.state["contacts"]["UKR"].has("RU_S1"), "Identified contact must enter observed memory.")
    blue["ammo"] = 0
    var remembered: Dictionary = battle.state["contacts"]["UKR"]["RU_S1"].duplicate(true)
    red["position"] = [470,470]
    battle.step()
    check(not battle.state["acquisition"]["UKR_S1"].has("RU_S1") and same(remembered,battle.state["contacts"]["UKR"]["RU_S1"]), "Lost sight resets local progress without tracking hidden motion.")
    red["position"] = [240,245]
    battle.step()
    battle.step()
    check(not battle.can_spot(blue,red) and battle.last_known_contacts("UKR").size() == 1, "Reacquisition requires a fresh uninterrupted delay; remembered contact gives no firing permission.")
    battle.step()
    check(battle.can_spot(blue,red), "Third reacquisition second restores the contact.")
    var shared = fixture()
    for tick in range(3): shared.step()
    var second: Dictionary = shared.squad_by_id("UKR_S2")
    second["alive"] = 9
    second["position"] = [180,250]
    check(shared.is_observed("UKR",shared.squad_by_id("RU_S1")) and not shared.can_engage(second,shared.squad_by_id("RU_S1")), "Another squad's shared contact cannot bypass local acquisition.")
    shared.step()
    check(int(shared.state["acquisition"]["UKR_S2"]["RU_S1"]) == 1, "New observer must start its own timer.")
    second["alive"] = 0
    shared.step()
    check(shared.state["acquisition"]["UKR_S2"].is_empty(), "Dead observers cannot retain acquisition.")
    var blocked = fixture()
    blocked.step()
    blocked.squad_by_id("RU_S1")["position"] = [270,166]
    blocked.squad_by_id("UKR_S1")["position"] = [200,166]
    blocked.step()
    check(blocked.state["acquisition"]["UKR_S1"].is_empty(), "Building occlusion must erase partial progress.")
    var death = fixture()
    for tick in range(3): death.step()
    death.squad_by_id("RU_S1")["alive"] = 0
    death.step()
    check(death.state["contacts"]["UKR"].is_empty(), "Visible death of an already acquired contact must clear memory.")
    var hidden_death = fixture()
    for tick in range(3): hidden_death.step()
    var memory: Dictionary = hidden_death.state["contacts"]["UKR"].duplicate(true)
    hidden_death.squad_by_id("RU_S1")["position"] = [470,470]
    hidden_death.squad_by_id("RU_S1")["alive"] = 0
    hidden_death.step()
    check(same(memory,hidden_death.state["contacts"]["UKR"]), "Hidden death cannot reveal an outcome or erase last observation.")
    var legacy = fixture()
    legacy.state["version"] = 15
    legacy.state.erase("acquisition")
    check(legacy.can_spot(legacy.squad_by_id("UKR_S1"),legacy.squad_by_id("RU_S1")) and Battle.validate(legacy.state,PAYLOAD), "V15 retains immediate spotting and its original field contract.")
    for value in [0,4,-1,1.5,"3",null,{},[]]:
        var bad: Dictionary = battle.state.duplicate(true)
        bad["acquisition"]["UKR_S1"]["RU_S1"] = value
        check(not Battle.validate(bad,PAYLOAD), "Malformed timers must reject.")
    for target in ["UNKNOWN","UKR_S2"]:
        var bad: Dictionary = battle.state.duplicate(true)
        bad["acquisition"]["UKR_S1"][target] = 3
        check(not Battle.validate(bad,PAYLOAD), "Unknown/friendly target timers must reject.")
    var bad: Dictionary = battle.state.duplicate(true)
    bad["acquisition"].erase("UKR_S1")
    check(not Battle.validate(bad,PAYLOAD), "Missing observer maps must reject.")
    bad = saved.duplicate(true)
    bad["acquisition"]["UKR_S1"]["RU_S1"] = 1
    check(not Battle.validate(bad,PAYLOAD), "Progress cannot exceed executed time.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://acquisition_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var sim = game.tactical_simulation
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.execute()
    sim.step()
    sim.step()
    check(int(sim.state["acquisition"]["UKR_S1"]["RU_S1"]) == 2 and game._save_campaign()["ok"], "Actual campaign must checkpoint a partially acquired contact.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()), "Disk restart must preserve exact partial local timers.")
    sim.step()
    resumed.tactical_simulation.step()
    check(not sim.last_events.is_empty() and same(sim.last_events,resumed.tactical_simulation.last_events) and same(sim.state,resumed.tactical_simulation.state), "Resume must identify and fire the identical next real shot without restarting delay.")
    finish(sim)
    finish(resumed.tactical_simulation)
    check(same(sim.state,resumed.tactical_simulation.state) and same(sim.result(),resumed.tactical_simulation.result()), "Full actual campaign disk outcomes must remain identical.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: timed local acquisition, actual delayed shots, query purity, lost-sight reset/memory isolation, shared/dead observer restrictions, strict saves, V15 preservation and actual campaign disk outcomes.")
    quit(0 if failures.is_empty() else 1)
