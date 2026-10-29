extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"COVER_SPACING","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
const RED_IDS = ["RU_S1", "RU_S2"]
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
    sim.state["version"] = 24 # Preserve the original no-retry spacing rules.
    if int(sim.state["version"]) < 26: sim.state.erase("route_legs")
    if int(sim.state["version"]) < 27: sim.state.erase("route_modes")
    if int(sim.state["version"]) < 28: sim.state.erase("route_pauses")
    for response in sim.state["cover_responses"].values(): response.erase("retry_remaining")
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S2", "RU_S1", "RU_S2"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S2")["position"] = [380, 212]
    sim.squad_by_id("RU_S1")["position"] = [338, 208]
    sim.squad_by_id("RU_S2")["position"] = [338, 216]
    return sim
func start(sim: RefCounted) -> void:
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
func press(sim: RefCounted, ticks: int) -> void:
    for tick in range(ticks):
        if sim.state["phase"] == "planning": sim.execute()
        for id in RED_IDS: sim.squad_by_id(id)["suppression"] = 0.335
        sim.step()
func goal(sim: RefCounted, id: String) -> Vector2:
    var point: Array = sim.state["cover_responses"][id]["goal"]
    return Vector2(point[0], point[1]) if not point.is_empty() else Vector2.INF
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished": return
        if sim.state["phase"] == "planning": sim.execute()
        sim.step()
func capture_frame(name: String) -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK, "Actual spaced cover capture saves.")
func _run() -> void:
    root.size = Vector2i(1280, 720)
    var sim = fixture()
    check(sim.state["version"] == 24, "Fresh engagements use versioned cover-spacing rules.")
    start(sim)
    press(sim, 3)
    var partial = Battle.new()
    partial.restore(JSON.parse_string(JSON.stringify(sim.state)))
    for running in [sim, partial]: press(running, 3)
    check(sim.seeking_cover("RU_S1") and sim.seeking_cover("RU_S2") and goal(sim,"RU_S1").distance_to(goal(sim,"RU_S2")) >= 12, "Simultaneously pressured squads reserve separate nearby wooded destinations.")
    check(same(sim.state,partial.state) and Battle.validate(sim.state,PAYLOAD), "Roster-order reservations continue exactly after a partial-timer restart.")
    var reserved: Dictionary = sim.state["cover_responses"].duplicate(true)
    var active: Dictionary = sim.state.duplicate(true)
    press(sim, 35)
    for id in RED_IDS:
        check(sim.seeking_cover(id) and sim.state["cover_responses"][id]["path"].is_empty() and same(sim.state["cover_responses"][id]["goal"],reserved[id]["goal"]), "Both squads actually reach and hold their independently reserved cover: "+id)
    check(Battle.position(sim.squad_by_id("RU_S1")).distance_to(Battle.position(sim.squad_by_id("RU_S2"))) >= 12, "Arrived squad centers remain separated.")
    # V23 retains the original convergence rather than silently changing old saves.
    var legacy = fixture()
    legacy.state["version"] = 23
    if int(legacy.state["version"]) < 26: legacy.state.erase("route_legs")
    if int(legacy.state["version"]) < 27: legacy.state.erase("route_modes")
    if int(legacy.state["version"]) < 28: legacy.state.erase("route_pauses")
    for id in RED_IDS: legacy.squad_by_id(id)["position"] = [338,212]
    start(legacy)
    press(legacy, 6)
    check(goal(legacy,"RU_S1") == goal(legacy,"RU_S2") and Battle.validate(legacy.state,PAYLOAD), "V23 still accepts and executes its original overlapping cover goals.")
    var bad: Dictionary = legacy.state.duplicate(true)
    bad["version"] = 24
    check(not Battle.validate(bad,PAYLOAD), "V24 rejects overlapping saved reservations without migrating v23.")
    bad = active.duplicate(true)
    var first_goal: Array = bad["cover_responses"]["RU_S1"]["goal"]
    for distance in [8,12]:
        bad["cover_responses"]["RU_S2"]["goal"] = [first_goal[0]-distance,first_goal[1]]
        bad["cover_responses"]["RU_S2"]["path"] = [bad["cover_responses"]["RU_S2"]["goal"].duplicate()]
        check(Battle.validate(bad,PAYLOAD) == (distance == 12), "Save reservation boundary distinguishes8m from exact12m.")
    # Current friendly occupants count, including one survivor or a withdrawing squad.
    for condition in ["living", "one_survivor", "broken", "dead", "enemy"]:
        var occupied = fixture()
        var blocker: Dictionary = occupied.squad_by_id("RU_S2" if condition != "enemy" else "UKR_S2")
        blocker["position"] = [324,212]
        if condition == "enemy": occupied.squad_by_id("RU_S2")["position"] = [470,470]
        if condition == "dead": blocker["alive"] = 0
        if condition == "one_survivor": blocker["alive"] = 1
        if condition == "broken":
            occupied.state["morale_states"]["RU_S2"] = "broken"
            blocker["morale"] = 20
        start(occupied)
        # Freeze the occupant to isolate selection, without removing its footprint.
        if condition == "broken":
            occupied._assign_route("RU_S2",Vector2(480,212),"quick")
            occupied.state["pause_remaining"]["RU_S2"] = 60
        press(occupied, 6)
        var distance := goal(occupied,"RU_S1").distance_to(Vector2(324,212))
        check(occupied.seeking_cover("RU_S1") and (distance == 0 if condition in ["dead","enemy"] else distance >= 12), "Cover occupancy uses only living friendly positions: "+condition)
    # Exact 12m boundary is allowed. Enemy state/reports and pure queries cannot reserve space.
    var boundary = fixture()
    var candidate := Vector2(324,212)
    boundary.squad_by_id("RU_S2")["position"] = [336,212]
    check(boundary._cover_goal_available(boundary.squad_by_id("RU_S1"),candidate), "Exactly12m is eligible.")
    boundary.squad_by_id("RU_S2")["position"] = [335.99,212]
    check(not boundary._cover_goal_available(boundary.squad_by_id("RU_S1"),candidate), "Inside12m is occupied.")
    var hidden = fixture()
    hidden.squad_by_id("UKR_S2")["position"] = [324,212]
    hidden.state["shared_contacts"]["RU"]["UKR_S2"] = {"position":[316,196],"seen_at":0}
    start(hidden)
    press(hidden,6)
    check(same(reserved,hidden.state["cover_responses"]), "Enemy positions and remembered/shared reports do not affect reservations.")
    var before: Dictionary = sim.state.duplicate(true)
    for repeat in range(5): sim._cover_goal_available(sim.squad_by_id("RU_S1"),candidate)
    check(same(before,sim.state), "Availability queries do not mutate saved reservations or simulation.")
    # A congested bounded search retains the old queue; it cannot evict the first arrival.
    var crowded = fixture()
    start(crowded)
    crowded._assign_route("RU_S2",Vector2(380,260),"hunt")
    crowded.state["pause_remaining"]["RU_S2"] = 60
    var queue: Array = crowded.state["orders"]["RU_S2"].duplicate(true)
    for y in range(64):
        for x in range(64):
            var cell := Vector2i(x,y)
            var point: Vector2 = crowded.cover_navigation.get_point_position(cell)
            if Battle.cover(point) > 0.2 and point != candidate: crowded.cover_navigation.set_point_solid(cell,true)
    press(crowded,6)
    check(crowded.seeking_cover("RU_S1") and not crowded.seeking_cover("RU_S2") and same(queue,crowded.state["orders"]["RU_S2"]) and crowded.movement_mode("RU_S2") == "hunt" and crowded.state["pause_remaining"]["RU_S2"] == 54, "Unavailable space keeps the original HUNT queue and running pause; no fallback to occupied ground.")
    crowded.squad_by_id("RU_S1")["alive"] = 0
    press(crowded,6)
    check(not crowded.seeking_cover("RU_S2"), "A failed search stays bounded until pressure drops below30%.")
    crowded.squad_by_id("RU_S2")["suppression"] = 0.2
    crowded.step()
    press(crowded,6)
    check(crowded.seeking_cover("RU_S2") and goal(crowded,"RU_S2") == candidate, "Death releases the reservation and a rearmed squad can use the space.")
    # Goals release on recovery/break, but a living body still occupies its actual position.
    for condition in ["recovery", "broken"]:
        var release = Battle.new()
        release.restore(active)
        var first: Vector2 = goal(release,"RU_S1")
        if condition == "recovery": release.squad_by_id("RU_S1")["suppression"] = 0.18
        else:
            release.squad_by_id("RU_S1")["suppression"] = 0.9
            release.squad_by_id("RU_S1")["morale"] = 20
        release.step()
        check(not release.seeking_cover("RU_S1") and release._cover_goal_available(release.squad_by_id("RU_S2"),first) and Battle.validate(release.state,PAYLOAD), "Unused reserved destination releases on "+condition)
    var quiet = fixture()
    var quiet_old = fixture()
    quiet_old.state["version"] = 23
    if int(quiet_old.state["version"]) < 26: quiet_old.state.erase("route_legs")
    if int(quiet_old.state["version"]) < 27: quiet_old.state.erase("route_modes")
    if int(quiet_old.state["version"]) < 28: quiet_old.state.erase("route_pauses")
    finish(quiet)
    finish(quiet_old)
    var normalized: Dictionary = quiet.state.duplicate(true)
    normalized["version"] = 23
    normalized.erase("route_legs")
    normalized.erase("route_modes")
    normalized.erase("route_pauses")
    check(same(normalized,quiet_old.state) and same(quiet.result(),quiet_old.result()), "Without cover competition, complete v24 and v23 quiet states/results match.")
    # Actual campaign disk checkpoint after real support volleys cause two detours.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://cover_spacing_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    for squad in battle.state["squads"]: squad["ammo"] = 0
    battle.squad_by_id("RU_S1")["position"] = [330,208]
    battle.squad_by_id("RU_S2")["position"] = [330,216]
    battle.squad_by_id("UKR_S2")["position"] = [380,212]
    battle.squad_by_id("UKR_S2")["ammo"] = 360
    battle.order_area_fire("UKR_S2",Vector2(330,212))
    start(battle)
    for tick in range(16): battle.step()
    check(battle.seeking_cover("RU_S1") and battle.seeking_cover("RU_S2") and game._save_campaign()["ok"], "Actual campaign persists two reservations after real suppressive fire.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()), "Disk load restores the complete campaign and reservations.")
    for tick in range(400):
        if battle.state["phase"] == "finished": break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning": running.execute()
            running.step()
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events) and Battle.validate(battle.state,game.battle_payload), "Every campaign tick/event validates and matches through arrival, release and final result.")
    check(same(battle.result(),resumed.tactical_simulation.result()), "Complete campaign outcomes match after reservation restart.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    # Real received area fire drives acquired spacing; render at actual4x playback.
    var visible = fixture()
    visible.squad_by_id("RU_S1")["position"] = [330,208]
    visible.squad_by_id("RU_S2")["position"] = [330,216]
    visible.squad_by_id("UKR_S2")["ammo"] = 360
    check(visible.order_area_fire("UKR_S2",Vector2(330,212)), "Observed-ground support fire order is legal.")
    var view = View.new()
    view.simulation = visible
    view.selected = "UKR_S2"
    root.add_child(view)
    await process_frame
    view.set_process(false)
    view.camera_focus = Vector2(322,210)
    view.camera_distance = 65
    view.camera_pitch = deg_to_rad(55)
    view.camera_yaw = deg_to_rad(75)
    view._update_camera()
    start(visible)
    var twin = Battle.new()
    twin.restore(visible.state)
    var captured := false
    var arrivals := {}
    for tick in range(110):
        for running in [visible,twin]:
            if running.state["phase"] == "planning": running.execute()
        twin.step()
        view._process(0.25)
        check(same(visible.state,twin.state), "4x playback and visible reservations never alter authoritative state.")
        for id in RED_IDS:
            if visible.seeking_cover(id) and visible.state["cover_responses"][id]["path"].is_empty(): arrivals[id] = true
        if not captured and visible.seeking_cover("RU_S1") and visible.seeking_cover("RU_S2") and not view.shot_cues.is_empty():
            captured = true
            check(goal(visible,"RU_S1").distance_to(goal(visible,"RU_S2")) >= 12 and view.actors["RU_S1"].visible and view.actors["RU_S2"].visible, "Actual support fire sends two acquired squads toward separate cover.")
            print("SPACING FIRE: tick=",visible.state["elapsed"]," rounds=",visible.squad_by_id("UKR_S2")["ammo"]," goals=",goal(visible,"RU_S1")," / ",goal(visible,"RU_S2"))
            await capture_frame("cover-spacing-execution-preview")
        if arrivals.size() == 2:
            check(visible.seeking_cover("RU_S1") and visible.seeking_cover("RU_S2") and Battle.position(visible.squad_by_id("RU_S1")).distance_to(Battle.position(visible.squad_by_id("RU_S2"))) >= 12, "Both acquired squads hold separated wooded positions together.")
            check(view.actors["RU_S1"].visible and view.actors["RU_S2"].visible and visible.squad_by_id("UKR_S2")["ammo"] == 0 and view.shot_cues.is_empty(), "Arrival is actually acquired and has no expired shot cues after ammunition runs out.")
            print("SPACING ARRIVAL: tick=",visible.state["elapsed"]," positions=",Battle.position(visible.squad_by_id("RU_S1"))," / ",Battle.position(visible.squad_by_id("RU_S2")))
            await capture_frame("cover-spacing-arrival-preview")
            break
    check(captured and arrivals.size() == 2, "Real fire drives both cover choices and actual arrivals, not just planning targets.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: simultaneous spaced cover/arrival, friendly occupancy, bounded congestion/rearming, released reservations, legacy/quiet parity, strict saves, exact campaign disk continuation and actual-fire rendered twin purity.")
    quit(0 if failures.is_empty() else 1)
