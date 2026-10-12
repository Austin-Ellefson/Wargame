extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id":"REPORTS","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
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
    sim.state["version"] = 18
    if int(sim.state["version"]) < 23: sim.state.erase("cover_responses")
    sim.state.erase("observer_contacts")
    sim.state.erase("facing_orders")
    sim.state.erase("area_fire")
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1","UKR_S2","RU_S1"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("UKR_S2")["position"] = [40,450]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
    return sim
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished": return
        if sim.state["phase"] == "planning": sim.execute()
        sim.step()
func _run() -> void:
    var sim = fixture()
    for tick in range(3): sim.step()
    check(sim.state["version"] == 18 and sim.can_spot(sim.squad_by_id("UKR_S1"),sim.squad_by_id("RU_S1")) and sim.shared_reports("UKR","UKR_S2").is_empty(), "Local identification must not instantly become a report for another squad.")
    var packet: Dictionary = sim.state["pending_reports"]["UKR"]["RU_S1"].duplicate(true)
    check(packet["seen_at"] == 3 and packet["deliver_at"] == 8 and packet["position"] == [240,245], "Report must capture a real local observation and five-second delivery deadline.")
    var snapshot: Dictionary = sim.state.duplicate(true)
    for repeat in range(20): sim.shared_reports("UKR","UKR_S2")
    check(same(snapshot,sim.state), "Report queries cannot advance delivery or mutate state.")
    sim.squad_by_id("RU_S1")["position"] = [250,245]
    sim.step()
    check(same(packet,sim.state["pending_reports"]["UKR"]["RU_S1"]), "New observations cannot overwrite an in-flight snapshot.")
    sim.squad_by_id("RU_S1")["position"] = [470,470]
    for tick in range(3): sim.step()
    check(sim.shared_reports("UKR","UKR_S2").is_empty(), "Report must remain absent before second eight even after sight is lost.")
    sim.step()
    var reports: Array = sim.shared_reports("UKR","UKR_S2")
    check(reports.size() == 1 and reports[0]["position"] == [240,245] and reports[0]["seen_at"] == 3, "Delivery must reveal only captured position/time, never the hidden current position.")
    check(not sim.can_engage(sim.squad_by_id("UKR_S2"),sim.squad_by_id("RU_S1")), "Reports must grant no local firing/target permission.")
    var planning = Battle.new()
    planning.restore(sim.state)
    for tick in range(52): planning.step()
    check(planning.state["phase"] == "planning" and planning.squad_by_id("RU_S1")["alive"] > 0 and not planning.shared_reports("UKR","UKR_S2").is_empty() and not planning.order_target("UKR_S2","RU_S1"), "Actual planning target command must reject a living unseen enemy known only by delivered report.")
    sim.squad_by_id("RU_S2")["alive"] = 9
    sim.squad_by_id("RU_S2")["position"] = [470,470]
    sim.squad_by_id("RU_S1")["alive"] = 0
    sim.step()
    check(same(reports,sim.shared_reports("UKR","UKR_S2")), "Hidden death cannot erase reports or reveal an outcome.")
    var visible = fixture()
    for tick in range(8): visible.step()
    visible.squad_by_id("RU_S2")["alive"] = 9
    visible.squad_by_id("RU_S2")["position"] = [470,470]
    visible.squad_by_id("RU_S1")["alive"] = 0
    visible.step()
    check(visible.state["pending_reports"]["UKR"]["RU_S1"]["kind"] == "contact", "Earlier in-flight contact packet must not be replaced by a death confirmation.")
    for tick in range(4): visible.step()
    check(visible.state["pending_reports"]["UKR"]["RU_S1"]["kind"] == "lost" and visible.state["shared_contacts"]["UKR"].has("RU_S1"), "Observed death must send a delayed removal after the in-flight snapshot arrives.")
    for tick in range(5): visible.step()
    check(not visible.state["shared_contacts"]["UKR"].has("RU_S1"), "Death confirmation must remove the report at its saved deadline.")
    var firing = fixture()
    firing.squad_by_id("UKR_S1")["ammo"] = 9
    for tick in range(3): firing.step()
    check(not firing.last_events.is_empty() and firing.last_events[0]["local_observers"].has("UKR_S1") and not firing.last_events[0]["local_observers"].has("UKR_S2"), "Real shot cue must snapshot local endpoint visibility per observer without report leakage.")
    var legacy = fixture()
    legacy.state["version"] = 17
    if int(legacy.state["version"]) < 23: legacy.state.erase("cover_responses")
    legacy.state.erase("shared_contacts")
    legacy.state.erase("pending_reports")
    legacy.state.erase("observer_contacts")
    legacy.state.erase("facing_orders")
    legacy.state.erase("area_fire")
    check(Battle.validate(legacy.state,PAYLOAD), "V17 retains original fields.")
    for tick in range(3): legacy.step()
    check(legacy.is_observed("UKR",legacy.squad_by_id("RU_S1")) and not legacy.state.has("shared_contacts"), "Old aggregate visibility rules cannot silently migrate.")
    var valid = fixture()
    for tick in range(3): valid.step()
    for corruption in range(10):
        var bad: Dictionary = valid.state.duplicate(true)
        var pending: Dictionary = bad["pending_reports"]["UKR"]["RU_S1"]
        match corruption:
            0: pending["deliver_at"] = 3
            1: pending["deliver_at"] = 7
            2: pending["kind"] = "unknown"
            3: pending["seen_at"] = "3"
            4: pending["position"] = [999,245]
            5: pending["extra"] = 0
            6: bad["pending_reports"]["UKR"]["UKR_S1"] = pending.duplicate(true)
            7: bad["shared_contacts"]["UKR"]["RU_S1"] = {"position":[240,245],"seen_at":3}
            8: bad["pending_reports"].erase("RU")
            9: bad["shared_contacts"]["UKR"]["UNKNOWN"] = {"position":[240,245],"seen_at":1}
        check(not Battle.validate(bad,PAYLOAD), "Malformed/future/friendly/extra report state must reject.")
    var current = fixture()
    var baseline = fixture()
    baseline.state["version"] = 17
    if int(baseline.state["version"]) < 23: baseline.state.erase("cover_responses")
    baseline.state.erase("shared_contacts")
    baseline.state.erase("pending_reports")
    baseline.state.erase("observer_contacts")
    baseline.state.erase("facing_orders")
    baseline.state.erase("area_fire")
    for battle in [current,baseline]:
        battle.squad_by_id("UKR_S1")["ammo"] = 360
        battle.squad_by_id("RU_S1")["ammo"] = 360
        finish(battle)
    var authoritative: Dictionary = current.state.duplicate(true)
    authoritative["version"] = 17
    authoritative.erase("shared_contacts")
    authoritative.erase("pending_reports")
    authoritative.erase("observer_contacts")
    authoritative.erase("facing_orders")
    authoritative.erase("area_fire")
    check(same(authoritative,baseline.state) and same(current.result(),baseline.result()), "Report transport/presentation metadata must not change authoritative combat or consume simulation RNG.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://reports_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    battle.squad_by_id("UKR_S1")["position"] = [180,245]
    battle.squad_by_id("RU_S1")["position"] = [240,245]
    battle.execute()
    for tick in range(4): battle.step()
    check(not battle.state["pending_reports"]["UKR"].is_empty() and game._save_campaign()["ok"], "Actual campaign must save an in-flight observed report.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()), "Real disk restart must preserve report positions and delivery time exactly.")
    for tick in range(4):
        battle.step()
        resumed.tactical_simulation.step()
    check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events), "Delivery and local shot-visibility snapshots must match after restart.")
    finish(battle)
    finish(resumed.tactical_simulation)
    check(same(battle.state,resumed.tactical_simulation.state) and same(battle.result(),resumed.tactical_simulation.result()), "Full actual campaign report/combat disk outcomes must match.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: delayed immutable observed reports, hidden movement/death isolation, ordered death confirmation, local firing/cue permissions, strict saves, V17 isolation and full actual campaign disk outcomes.")
    quit(0 if failures.is_empty() else 1)
