extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const PAYLOAD = {"battle_id":"OBSERVER_MEMORY","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.state["version"] = 19
    sim.state.erase("facing_orders")
    sim.state.erase("area_fire")
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1","UKR_S2","RU_S1","RU_S2"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("UKR_S2")["position"] = [40,450]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.squad_by_id("RU_S2")["position"] = [470,470]
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
    check(sim.state["version"] == 19 and sim.state["observer_contacts"]["UKR_S1"].has("RU_S1") and sim.state["observer_contacts"]["UKR_S2"].is_empty(), "Only an actually acquiring observer records its own contact.")
    check(sim.state["observer_contacts"]["RU_S1"].has("UKR_S1"), "Observation memory must be bilateral.")
    sim.squad_by_id("RU_S1")["position"] = [250,245]
    sim.step()
    sim.squad_by_id("RU_S1")["position"] = [470,470]
    sim.step()
    var local: Array = sim.remembered_contacts("UKR_S1")
    check(local.size() == 1 and local[0]["source"] == "local" and local[0]["position"] == [250,245] and local[0]["seen_at"] == 4 and sim.remembered_contacts("UKR_S2").is_empty(), "Own lost sight must preserve last position/time before any report arrives.")
    for tick in range(3): sim.step()
    var reports: Array = sim.remembered_contacts("UKR_S2")
    check(reports.size() == 1 and reports[0]["source"] == "report" and reports[0]["position"] == [240,245] and reports[0]["seen_at"] == 3 and same(local,sim.remembered_contacts("UKR_S1")), "Delivered report retains older time/position; fresher own memory wins.")
    var snapshot: Dictionary = sim.state.duplicate(true)
    for repeat in range(20):
        var copy: Array = sim.remembered_contacts("UKR_S1")
        copy[0]["position"][0] = 999
    check(same(snapshot,sim.state) and sim.remembered_contacts("UNKNOWN").is_empty() and sim.remembered_contacts("UKR_S3").is_empty(), "Queries return deep copies, reject missing/dead observers and never advance timers.")
    sim.squad_by_id("RU_S1")["alive"] = 0
    sim.step()
    check(same(local,sim.remembered_contacts("UKR_S1")) and same(reports,sim.remembered_contacts("UKR_S2")), "Unseen death cannot erase either observer's knowledge.")
    check(not sim.can_engage(sim.squad_by_id("UKR_S1"),sim.squad_by_id("RU_S1")), "Remembered sight grants no fire permission.")
    var newer = fixture()
    for tick in range(3): newer.step()
    newer.squad_by_id("UKR_S1")["position"] = [40,450]
    newer.squad_by_id("UKR_S2")["position"] = [180,245]
    newer.squad_by_id("RU_S1")["position"] = [250,245]
    for tick in range(5): newer.step()
    newer.squad_by_id("RU_S1")["position"] = [470,470]
    for tick in range(5): newer.step()
    check(newer.remembered_contacts("UKR_S1")[0]["source"] == "report" and newer.remembered_contacts("UKR_S1")[0]["seen_at"] == 8 and newer.remembered_contacts("UKR_S2")[0]["source"] == "local", "Newer delivered knowledge supersedes old own sight; equal own sight wins.")
    for tick in range(47): newer.step()
    check(newer.state["phase"] == "planning" and not newer.order_target("UKR_S1","RU_S1") and not newer.order_target("UKR_S2","RU_S1"), "Actual planning targeting rejects living hidden enemies known by either marker source.")
    var killed = fixture()
    for tick in range(8): killed.step()
    killed.squad_by_id("RU_S1")["alive"] = 0
    killed.step()
    check(killed.state["observer_contacts"]["UKR_S1"]["RU_S1"]["kind"] == "lost" and killed.remembered_contacts("UKR_S1").is_empty() and not killed.remembered_contacts("UKR_S2").is_empty(), "Observed elimination clears only witness memory immediately, retaining the other squad's delayed report.")
    for tick in range(4): killed.step()
    check(killed.remembered_contacts("UKR_S1").is_empty() and not killed.remembered_contacts("UKR_S2").is_empty(), "Older in-flight contact cannot resurrect witness's eliminated target.")
    for tick in range(5): killed.step()
    check(killed.remembered_contacts("UKR_S2").is_empty(), "Ordered shared death confirmation eventually clears nonwitness report.")
    var real_fire = fixture()
    real_fire.squad_by_id("UKR_S1")["ammo"] = 360
    real_fire.squad_by_id("RU_S1")["alive"] = 1
    real_fire.squad_by_id("RU_S1")["position"] = [188,245]
    var witnessed_shots := 0
    for tick in range(100):
        if real_fire.squad_by_id("RU_S1")["alive"] == 0: break
        if real_fire.state["phase"] == "planning": real_fire.execute()
        real_fire.step()
        witnessed_shots += real_fire.last_events.size()
    check(witnessed_shots > 0 and real_fire.squad_by_id("RU_S1")["alive"] == 0 and real_fire.state["observer_contacts"]["UKR_S1"]["RU_S1"]["kind"] == "lost" and real_fire.remembered_contacts("UKR_S1").is_empty() and Battle.validate(real_fire.state,PAYLOAD), "Actual simulated lethal shots create a valid witness tombstone after simultaneous damage.")
    var valid = fixture()
    for tick in range(3): valid.step()
    check(Battle.validate(valid.state,PAYLOAD), "Real v19 memory state validates.")
    for corruption in range(13):
        var bad: Dictionary = valid.state.duplicate(true)
        var record: Dictionary = bad["observer_contacts"]["UKR_S1"]["RU_S1"]
        match corruption:
            0: bad.erase("observer_contacts")
            0: bad.erase("facing_orders")
            0: bad.erase("area_fire")
            1: bad["observer_contacts"].erase("UKR_S2")
            2: bad["observer_contacts"]["UNKNOWN"] = {}
            3: bad["observer_contacts"]["UKR_S1"]["UKR_S2"] = record.duplicate(true)
            4: record["position"] = [999,245]
            5: record["position"] = [230,160]
            6: record["seen_at"] = 4
            7: record["seen_at"] = 2.5
            8: record["kind"] = "unknown"
            9: record["extra"] = 0
            10: record["seen_at"] = "3"
            11: bad["observer_contacts"]["UKR_S2"] = []
            12: record["kind"] = "lost"
        check(not Battle.validate(bad,PAYLOAD), "Malformed observer map/record/time/position/ID must reject: %d" % corruption)
    var current = fixture()
    var legacy = fixture()
    legacy.state["version"] = 18
    legacy.state.erase("observer_contacts")
    legacy.state.erase("facing_orders")
    legacy.state.erase("area_fire")
    check(Battle.validate(legacy.state,PAYLOAD), "Old v18 shape remains valid without migration.")
    for battle in [current,legacy]:
        battle.squad_by_id("UKR_S1")["ammo"] = 360
        battle.squad_by_id("RU_S1")["ammo"] = 360
        finish(battle)
    var authoritative: Dictionary = current.state.duplicate(true)
    authoritative["version"] = 18
    authoritative.erase("observer_contacts")
    authoritative.erase("facing_orders")
    authoritative.erase("area_fire")
    check(same(authoritative,legacy.state) and same(current.result(),legacy.result()), "Added observer knowledge cannot alter any legacy authoritative combat field or RNG outcome.")
    check(current.remembered_contacts("UKR_S1").is_empty(), "Finished battle hides uncertain contacts.")
    # Actual campaign disk continuation with acquired local memory and a packet.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://observer_memory_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    battle.squad_by_id("UKR_S1")["position"] = [180,245]
    battle.squad_by_id("RU_S1")["position"] = [240,245]
    battle.execute()
    for tick in range(4): battle.step()
    check(not battle.state["observer_contacts"]["UKR_S1"].is_empty() and game._save_campaign()["ok"], "Actual campaign saves acquired observer knowledge.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()), "Disk restart restores each observer memory exactly.")
    for tick in range(400):
        if battle.state["phase"] == "finished": break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning": running.execute()
            running.step()
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events), "Every restarted tick preserves knowledge, shot events and combat.")
    check(same(battle.result(),resumed.tactical_simulation.result()), "Full disk continuation results are identical.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty(): print("PASS: bilateral observer knowledge, local/report recency, unseen death isolation, ordered elimination, strict v19 saves, v18 outcomes and actual disk restart.")
    quit(0 if failures.is_empty() else 1)
