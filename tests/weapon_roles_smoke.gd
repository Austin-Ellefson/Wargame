extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id": "WEAPONS", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(id: String) -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    battle.state["version"] = 15
    battle.state.erase("acquisition")
    battle.state.erase("command_remaining")
    battle.state.erase("shared_contacts")
    battle.state.erase("pending_reports")
    battle.state.erase("observer_contacts")
    battle.state.erase("facing_orders")
    for squad in battle.state["squads"]:
        if squad["id"] not in [id,"RU_S1"]: squad["alive"] = 0
        squad["ammo"] = 360 if squad["id"] == id else 0
    battle.squad_by_id(id)["position"] = [180,245]
    battle.squad_by_id("RU_S1")["position"] = [240,245]
    return battle
func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished": return
        if battle.state["phase"] == "planning": battle.execute()
        battle.step()
func _run() -> void:
    var rifle = fixture("UKR_S1")
    var support = fixture("UKR_S2")
    rifle.execute()
    support.execute()
    rifle.step()
    support.step()
    check(rifle.last_events.is_empty() and support.last_events.is_empty(), "Neither profile can fire on the first second.")
    rifle.step()
    support.step()
    check(rifle.last_events.is_empty() and support.last_events.size() == 1 and support.last_events[0]["rounds"] == 18 and support.last_events[0]["weapon_role"] == "support", "Support must fire a real eighteen-round volley on second two while rifles wait.")
    var support_pressure := float(support.squad_by_id("RU_S1")["suppression"])
    rifle.step()
    check(rifle.last_events.size() == 1 and rifle.last_events[0]["rounds"] == 9 and rifle.last_events[0]["weapon_role"] == "rifle", "Rifle must fire nine actual rounds on second three.")
    check(support_pressure > float(rifle.squad_by_id("RU_S1")["suppression"]) and support.squad_by_id("UKR_S2")["ammo"] == 342 and rifle.squad_by_id("UKR_S1")["ammo"] == 351, "Support must exchange faster ammo consumption for greater volley pressure.")
    var exhausted = fixture("UKR_S2")
    exhausted.squad_by_id("UKR_S2")["ammo"] = 1
    exhausted.squad_by_id("RU_S1")["alive"] = 1
    exhausted.execute()
    exhausted.step()
    exhausted.step()
    check(exhausted.squad_by_id("UKR_S2")["ammo"] == 0 and exhausted.last_events.size() == 1 and exhausted.last_events[0]["rounds"] == 1 and int(exhausted.squad_by_id("RU_S1")["alive"]) >= 0, "Partial volleys must consume only the remaining round and clamp actual casualties.")
    exhausted.step()
    exhausted.step()
    check(exhausted.last_events.is_empty(), "Empty support ammo must prevent future shot events.")
    var held = fixture("UKR_S2")
    held.order_fire("UKR_S2","hold")
    held.execute()
    for tick in range(6): held.step()
    check(held.squad_by_id("UKR_S2")["ammo"] == 360 and held.last_events.is_empty(), "HOLD FIRE must prevent both cadence and ammo consumption.")
    var hidden = fixture("UKR_S2")
    hidden.squad_by_id("RU_S1")["position"] = [470,470]
    hidden.execute()
    for tick in range(2): hidden.step()
    check(hidden.last_events.is_empty() and hidden.squad_by_id("UKR_S2")["ammo"] == 360, "Support cadence cannot fire at hidden/out-of-range positions.")
    var mutual = fixture("UKR_S2")
    mutual.squad_by_id("RU_S1")["alive"] = 0
    var red: Dictionary = mutual.squad_by_id("RU_S2")
    red["alive"] = 1
    red["ammo"] = 2
    red["position"] = [240,245]
    mutual.squad_by_id("UKR_S2")["alive"] = 1
    mutual.squad_by_id("UKR_S2")["ammo"] = 2
    mutual.execute()
    mutual.step()
    mutual.step()
    check(mutual.last_events.size() == 2 and mutual.squad_by_id("UKR_S2")["ammo"] == 0 and red["ammo"] == 0, "Both living support squads must collect same-tick shots before applying damage.")
    for squad in mutual.state["squads"]:
        check(int(squad["alive"]) >= 0 and int(squad["alive"]) <= int(squad["initial"]), "Simultaneous attacks must never fabricate or over-subtract personnel.")
    var legacy = fixture("UKR_S2")
    legacy.state["version"] = 14
    legacy.state.erase("weapon_roles")
    check(Battle.validate(legacy.state,PAYLOAD) and legacy.weapon_role("UKR_S2") == "rifle", "V14 support-numbered squads retain original rifle behavior and field contract.")
    legacy.execute()
    legacy.step()
    legacy.step()
    check(legacy.last_events.is_empty(), "V14 cannot silently acquire a faster cadence.")
    legacy.step()
    check(legacy.last_events.size() == 1 and legacy.last_events[0]["rounds"] == 9 and not legacy.last_events[0].has("weapon_role"), "V14 keeps three-second nine-round volleys and event shape.")
    var valid = fixture("UKR_S2")
    for value in ["support","unknown",1,null,{},[]]:
        var bad: Dictionary = valid.state.duplicate(true)
        bad["weapon_roles"]["UKR_S1"] = value
        check(not Battle.validate(bad,PAYLOAD), "Changed/unknown/nonstrings cannot fabricate equipment in a save.")
    var bad: Dictionary = valid.state.duplicate(true)
    bad["weapon_roles"].erase("UKR_S1")
    check(not Battle.validate(bad,PAYLOAD), "Missing role IDs must reject.")
    bad = valid.state.duplicate(true)
    bad["weapon_roles"]["UNKNOWN"] = "rifle"
    check(not Battle.validate(bad,PAYLOAD), "Extra role IDs must reject.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://weapons_%d" % Time.get_ticks_usec()
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
    var sim = game.tactical_simulation
    sim.squad_by_id("UKR_S2")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.order_posture("UKR_S2","prone")
    sim.execute()
    sim.step()
    check(game._save_campaign()["ok"], "Campaign must checkpoint just before the first support volley.")
    var saved: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(saved,resumed._snapshot()), "Actual disk restart must preserve profiles and the exact cadence phase.")
    sim.step()
    resumed.tactical_simulation.step()
    check(same(sim.last_events,resumed.tactical_simulation.last_events) and same(sim.state,resumed.tactical_simulation.state) and not sim.last_events.is_empty(), "Restart must fire the same next support volley rather than reset its cadence.")
    finish(sim)
    finish(resumed.tactical_simulation)
    check(same(sim.state,resumed.tactical_simulation.state) and same(sim.result(),resumed.tactical_simulation.result()), "Different cadences must preserve complete real-combat disk outcomes.")
    for faction in ["UKR","RU"]:
        var force: Dictionary = sim.result()["forces"][faction]
        check(force["losses"] <= force["deployed"] and force["ammunition_used"] <= force["deployed"]*Battle.ROUNDS_PER_PERSON, "Profile results must remain bounded by deployed personnel and initial rounds.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: actual rifle/support cadence, volley pressure/ammo tradeoffs, partial/exhausted ammo, hold/hidden restrictions, simultaneous bounded attacks, strict profiles, V14 isolation and real campaign disk cadence/outcome equality.")
    quit(0 if failures.is_empty() else 1)
