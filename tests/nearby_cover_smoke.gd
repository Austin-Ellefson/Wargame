extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"NEARBY_COVER","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
const GROUND := Vector2(330,214)
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(hidden: bool = true) -> RefCounted:
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S2","RU_S1","RU_S2"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S2")["position"] = [212,290] if hidden else [380,214]
    sim.state["postures"]["UKR_S2"] = "prone" if hidden else "stand"
    sim.squad_by_id("RU_S1")["position"] = [GROUND.x,GROUND.y]
    sim.squad_by_id("RU_S2")["position"] = [470,470]
    return sim
func start(sim: RefCounted) -> void:
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
func press(sim: RefCounted,ticks: int) -> void:
    for tick in range(ticks):
        sim.squad_by_id("RU_S1")["suppression"] = 0.335
        sim.step()
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished": return
        if sim.state["phase"] == "planning": sim.execute()
        sim.step()
func capture_frame(name: String) -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK,"Actual cover response capture saves.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = fixture()
    sim.squad_by_id("UKR_S2")["ammo"] = 360
    check(sim.state["version"] == 23 and sim.order_area_fire("UKR_S2",GROUND),"Fresh v23 permits actual ground suppression from concealed support.")
    start(sim)
    var shots := 0
    for tick in range(12):
        sim.step()
        shots += sim.last_events.size()
        check(not sim.can_spot(sim.squad_by_id("RU_S1"),sim.squad_by_id("UKR_S2")) and sim.state["observer_contacts"]["RU_S1"].is_empty(),"Cover reaction cannot reveal the concealed source.")
    var response: Dictionary = sim.state["cover_responses"]["RU_S1"]
    check(shots == 6 and sim.seeking_cover("RU_S1") and Battle.position(sim.squad_by_id("RU_S1")).distance_to(GROUND) > 0 and response["goal"] == [324.0,212.0],"Six real support volleys cause a bounded deterministic move to nearby woods.")
    check(sim.posture("UKR_S2") == "prone" and sim.squad_by_id("RU_S1")["alive"] == 9 and sim.squad_by_id("UKR_S2")["ammo"] == 252,"Cover response retains manual blue posture and real rounds without invented losses.")
    var active: Dictionary = sim.state.duplicate(true)
    check(Battle.validate(active,PAYLOAD),"Actual partially traversed cover response validates.")
    var twin = Battle.new()
    twin.restore(JSON.parse_string(JSON.stringify(active)))
    var arrived := false
    var released := false
    for tick in range(85):
        for running in [sim,twin]:
            if running.state["phase"] == "planning": running.execute()
            running.step()
        arrived = arrived or (sim.seeking_cover("RU_S1") and sim.state["cover_responses"]["RU_S1"]["path"].is_empty())
        released = released or not sim.seeking_cover("RU_S1")
        check(same(sim.state,twin.state) and same(sim.last_events,twin.last_events) and Battle.validate(sim.state,PAYLOAD),"Actual cover arrival/holding/recovery persists across ticks and intervals.")
    check(arrived and released,"After real pressure eases red reaches woods, holds, then releases the reaction.")
    # Only own pressure and known local terrain may choose the destination.
    var unseen_a = fixture()
    var unseen_b = fixture()
    unseen_b.squad_by_id("UKR_S2")["position"] = [40,450]
    unseen_b.state["contacts"]["RU"]["UKR_S2"] = {"position":[440,40],"seen_at":0}
    for running in [unseen_a,unseen_b]:
        start(running)
        press(running,3)
    check(not unseen_a.seeking_cover("RU_S1") and unseen_a.state["cover_responses"]["RU_S1"]["pressure_ticks"] == 3,"A brief burst does not immediately rewrite movement.")
    var partial = Battle.new()
    partial.restore(JSON.parse_string(JSON.stringify(unseen_a.state)))
    for running in [unseen_a,unseen_b,partial]: press(running,3)
    check(same(unseen_a.state["cover_responses"]["RU_S1"],unseen_b.state["cover_responses"]["RU_S1"]) and same(unseen_a.state,partial.state),"Hidden enemy moves/reports cannot change cover selection; partial pressure timer resumes exactly.")
    var before: Dictionary = unseen_a.state.duplicate(true)
    for repeat in range(5): unseen_a.seeking_cover("RU_S1")
    check(same(before,unseen_a.state),"Cover queries cannot advance timers or mutate saved arrays.")
    var planning = fixture()
    planning.squad_by_id("RU_S1")["suppression"] = 0.9
    before = planning.state.duplicate(true)
    planning.step()
    check(same(before,planning.state),"Planning time does not react to pressure.")
    var interrupted = fixture()
    start(interrupted)
    press(interrupted,5)
    interrupted.squad_by_id("RU_S1")["suppression"] = 0.334999
    interrupted.step()
    check(interrupted.state["cover_responses"]["RU_S1"]["pressure_ticks"] == 0,"A recovered pressure just below30% interrupts sustained-pressure timing.")
    press(interrupted,5)
    check(not interrupted.seeking_cover("RU_S1"),"Interrupted bursts must earn six consecutive pressure ticks again.")
    for condition in ["dead","broken"]:
        var cancelled = Battle.new()
        cancelled.restore(active)
        if condition == "dead": cancelled.squad_by_id("RU_S1")["alive"] = 0
        else:
            cancelled.squad_by_id("RU_S1")["morale"] = 20
            cancelled.squad_by_id("RU_S1")["suppression"] = 0.9
        cancelled.step()
        check(not cancelled.seeking_cover("RU_S1") and cancelled.state["cover_responses"]["RU_S1"]["pressure_ticks"] == 0 and Battle.validate(cancelled.state,PAYLOAD),"An active detour clears immediately on "+condition+" without invalid saved state.")
    # Preserve the queued route while seeking cover and reconnect safely later.
    var queue = fixture(false)
    start(queue)
    queue._assign_route("RU_S1",Vector2(360,214),"move")
    queue._assign_route("RU_S1",Vector2(360,270),"move",true)
    queue.state["pause_remaining"]["RU_S1"] = 15
    var original: Array = queue.state["orders"]["RU_S1"].duplicate(true)
    press(queue,6)
    check(queue.seeking_cover("RU_S1") and same(original,queue.state["orders"]["RU_S1"]) and Battle.position(queue.squad_by_id("RU_S1")) == GROUND and queue.state["pause_remaining"]["RU_S1"] == 9 and queue.command_delay("RU_S1") == 0,"Cover preserves full waypoints and honors the executing pause/command countdown.")
    queue.state["pause_remaining"]["RU_S1"] = 0
    queue.state["command_remaining"]["RU_S1"] = 2
    press(queue,1)
    check(Battle.position(queue.squad_by_id("RU_S1")) == GROUND and queue.command_delay("RU_S1") == 1,"Pending command response still holds a selected cover move.")
    queue.state["command_remaining"]["RU_S1"] = 0
    queue.state["movement_modes"]["RU_S1"] = "hunt"
    press(queue,1)
    check(Battle.position(queue.squad_by_id("RU_S1")) == GROUND,"Explicit HUNT pressure hold remains stronger than cover movement.")
    queue.state["movement_modes"]["RU_S1"] = "move"
    queue.squad_by_id("RU_S1")["suppression"] = 1.0
    queue.step()
    check(Battle.position(queue.squad_by_id("RU_S1")) == GROUND and queue.seeking_cover("RU_S1"),"Pinning holds the detour without losing its goal.")
    queue.squad_by_id("RU_S1")["ammo"] = 9
    queue.state["acquisition"]["RU_S1"]["UKR_S2"] = 3
    press(queue,1)
    check(queue.opponent_engaging(queue.squad_by_id("RU_S1")) and Battle.position(queue.squad_by_id("RU_S1")) != GROUND,"A local contact cannot strand a pressure-driven cover move in the open.")
    queue.squad_by_id("RU_S1")["ammo"] = 0
    press(queue,12)
    check(same(original,queue.state["orders"]["RU_S1"]),"Actual cover traversal retains all original waypoints verbatim.")
    queue.squad_by_id("RU_S1")["suppression"] = 0.18
    queue.step()
    check(not queue.seeking_cover("RU_S1") and queue.state["orders"]["RU_S1"].back() == original.back(),"Below15% recovery rejoins the original final destination.")
    var rejoined: Array = queue.state["orders"]["RU_S1"]
    check(same(rejoined.slice(rejoined.size()-original.size()+1),original.slice(1)) and Battle.validate(queue.state,PAYLOAD),"Terrain-safe rejoin preserves every remaining queued leg and valid state.")
    # No distant searches, blocked detours, unnecessary relocations or priority theft.
    for condition in ["remote","covered","blocked","full_queue","blue","dead","broken"]:
        var case = fixture()
        start(case)
        var red: Dictionary = case.squad_by_id("RU_S1")
        match condition:
            "remote": red["position"] = [470,470]
            "covered": red["position"] = [298,210]
            "blocked":
                for y in range(64):
                    for x in range(64):
                        var cell := Vector2i(x,y)
                        if Battle.cover(case.cover_navigation.get_point_position(cell)) > 0.2: case.cover_navigation.set_point_solid(cell,true)
            "full_queue":
                case.state["orders"]["RU_S1"] = []
                for point in range(128): case.state["orders"]["RU_S1"].append([360,214])
                case.state["movement_modes"]["RU_S1"] = "move"
                case.state["pause_remaining"]["RU_S1"] = 60
            "blue": case.squad_by_id("UKR_S2")["suppression"] = 1
            "dead": red["alive"] = 0
            "broken":
                red["morale"] = 20
                red["suppression"] = 0.8
                case.step()
        if condition == "blue":
            for tick in range(6): case.step()
            check(not case.seeking_cover("UKR_S2") and case.state["cover_responses"]["UKR_S2"]["pressure_ticks"] == 0,"Blue movement remains player-controlled.")
        else:
            press(case,6)
            check(not case.seeking_cover("RU_S1"),"Cover selection respects "+condition+" boundary.")
        if condition == "broken": check(case.posture("RU_S1") == "stand" and case.morale_state("RU_S1") == "broken" and case.state["orders"]["RU_S1"].back()[0] == 480,"Standing rearward withdrawal retains its route and priority.")
    var legacy = fixture()
    legacy.state["version"] = 22
    legacy.state.erase("cover_responses")
    start(legacy)
    press(legacy,12)
    check(Battle.position(legacy.squad_by_id("RU_S1")) == GROUND and legacy.posture("RU_S1") == "crouch" and Battle.validate(legacy.state,PAYLOAD),"V22 still ducks in place with its original field shape and rules.")
    var quiet = fixture()
    var quiet_old = fixture()
    quiet_old.state["version"] = 22
    quiet_old.state.erase("cover_responses")
    finish(quiet)
    finish(quiet_old)
    var normalized: Dictionary = quiet.state.duplicate(true)
    normalized.erase("cover_responses")
    normalized["version"] = 22
    check(same(normalized,quiet_old.state) and same(quiet.result(),quiet_old.result()),"Complete quiet v23 and v22 outcomes/authoritative fields remain identical.")
    for index in range(14):
        var bad: Dictionary = active.duplicate(true)
        match index:
            0: bad.erase("cover_responses")
            1: bad["cover_responses"].erase("RU_S2")
            2: bad["cover_responses"]["UNKNOWN"] = {"pressure_ticks":0,"goal":[],"path":[]}
            3: bad["cover_responses"]["RU_S1"]["pressure_ticks"] = 6.5
            4: bad["cover_responses"]["RU_S1"]["pressure_ticks"] = 7
            5: bad["cover_responses"]["RU_S1"]["pressure_ticks"] = "6"
            6: bad["cover_responses"]["RU_S1"]["extra"] = true
            7: bad["cover_responses"]["RU_S1"]["goal"] = [450,450]
            8: bad["cover_responses"]["RU_S1"]["path"] = [[NAN,212]]
            9: bad["cover_responses"]["RU_S1"]["path"] = [[232,168],[324,212]]
            10: bad["cover_responses"]["RU_S1"]["path"] = []
            11: bad["cover_responses"]["RU_S1"]["goal"] = []
            12: bad["cover_responses"]["UKR_S2"] = bad["cover_responses"]["RU_S1"].duplicate(true)
            13: bad["cover_responses"]["RU_S1"]["path"] = [[500,500],[324,212]]
        check(not Battle.validate(bad,PAYLOAD),"Malformed cover save rejects case %d." % index)
    # A genuine campaign disk checkpoint while real fire drives a moving detour.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://nearby_cover_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    for squad in battle.state["squads"]: squad["ammo"] = 0
    battle.squad_by_id("UKR_S2")["position"] = [380,214]
    battle.squad_by_id("RU_S1")["position"] = [330,214]
    battle.squad_by_id("UKR_S2")["ammo"] = 360
    battle.order_area_fire("UKR_S2",GROUND)
    start(battle)
    for tick in range(12): battle.step()
    check(battle.seeking_cover("RU_S1") and game._save_campaign()["ok"],"Campaign saves an actual partially traversed cover detour after real firing.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()),"Disk load restores cover timer/goal/path and campaign snapshot exactly.")
    for tick in range(400):
        if battle.state["phase"] == "finished": break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning": running.execute()
            running.step()
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events),"Every resumed campaign tick/event matches through cover and recovery.")
    check(same(battle.result(),resumed.tactical_simulation.result()),"Complete campaign cover-response outcomes match after disk restart.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    # Render real received fire and acquired movement, compared to an unseen twin.
    var visible = fixture(false)
    visible.squad_by_id("UKR_S2")["ammo"] = 360
    visible.order_area_fire("UKR_S2",GROUND)
    var view = View.new()
    view.simulation = visible
    view.selected = "UKR_S2"
    root.add_child(view)
    await process_frame
    view.set_process(false)
    view.camera_focus = Vector2(326,214)
    view.camera_distance = 50
    view.camera_pitch = deg_to_rad(40)
    view._update_camera()
    start(visible)
    var unrendered = Battle.new()
    unrendered.restore(visible.state)
    var captured_arrival := false
    for tick in range(75):
        for running in [visible,unrendered]:
            if running.state["phase"] == "planning": running.execute()
        unrendered.step()
        # Exercise the real 4x playback path, including cue expiry. Arrival must
        # not show accumulated, expired volleys from earlier test ticks.
        view._process(0.25)
        check(same(visible.state,unrendered.state),"Rendered movement/shot/cover observation cannot alter authoritative state.")
        if tick == 11:
            check(visible.seeking_cover("RU_S1") and view.actors["RU_S1"].visible and not view.shot_cues.is_empty(),"Actually acquired cover movement accompanies a real support volley.")
            await capture_frame("nearby-cover-moving-preview")
        if not captured_arrival and visible.seeking_cover("RU_S1") and visible.state["cover_responses"]["RU_S1"]["path"].is_empty():
            captured_arrival = true
            check(view.actors["RU_S1"].visible and Battle.cover(Battle.position(visible.squad_by_id("RU_S1"))) > 0.2,"Acquired red infantry actually reaches wooded cover.")
            check(visible.squad_by_id("UKR_S2")["ammo"] == 0 and view.shot_cues.is_empty(),"Arrival after fire ceases has no stale muzzle/tracer cues.")
            await capture_frame("nearby-cover-arrival-preview")
    check(captured_arrival,"Real-fire rendering captures arrival, not just a planning destination.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: actual-fire nearby cover/arrival/recovery, hidden-source isolation, bounded terrain paths, retained queue/gates, legacy parity, strict validation, exact campaign disk continuation and rendered twin purity.")
    quit(0 if failures.is_empty() else 1)
