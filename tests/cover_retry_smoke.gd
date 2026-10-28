extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"COVER_RETRY","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
const ORIGIN := Vector2(354,212)
class CountingBattle extends "res://scripts/tactical_battle.gd":
    var path_calls := 0
    func _terrain_path(origin: Vector2, target: Vector2) -> Array:
        path_calls += 1
        return super._terrain_path(origin,target)
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var sim = CountingBattle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S2","RU_S1","RU_S2"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S2")["position"] = [402,212]
    sim.squad_by_id("RU_S1")["position"] = [354,212]
    sim.squad_by_id("RU_S2")["position"] = [324,212]
    return sim
func response(sim: RefCounted) -> Dictionary: return sim.state["cover_responses"]["RU_S1"]
func start(sim: RefCounted) -> void:
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
func press(sim: RefCounted, count: int) -> void:
    for tick in range(count):
        if sim.state["phase"] == "planning": sim.execute()
        sim.squad_by_id("RU_S1")["suppression"] = 0.335
        sim.step()
func real_fire_setup(sim: RefCounted) -> void:
    for squad in sim.state["squads"]: squad["ammo"] = 0
    sim.squad_by_id("UKR_S2")["position"] = [402,212]
    sim.squad_by_id("RU_S1")["position"] = [354,212]
    sim.squad_by_id("RU_S2")["position"] = [324,212]
    sim.squad_by_id("UKR_S2")["ammo"] = 180
    sim.order_area_fire("UKR_S2",ORIGIN)
    start(sim)
    # The initially occupying friendly actually moves after a saved explicit wait.
    sim._assign_route("RU_S2",Vector2(292,212),"move")
    sim.state["pause_remaining"]["RU_S2"] = 13
func legacy(sim: RefCounted) -> void:
    sim.state["version"] = 24
    if int(sim.state["version"]) < 26: sim.state.erase("route_legs")
    if int(sim.state["version"]) < 27: sim.state.erase("route_modes")
    for record in sim.state["cover_responses"].values(): record.erase("retry_remaining")
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished": return
        if sim.state["phase"] == "planning": sim.execute()
        sim.step()
func capture_frame(name: String) -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK,"Actual retry capture saves.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = fixture()
    check(sim.state["version"] == 27 and Battle.validate(sim.state,PAYLOAD),"Fresh v27 has valid retry, authored-route and per-leg-mode fields.")
    start(sim)
    sim._assign_route("RU_S1",Vector2(390,260),"hunt")
    sim.state["pause_remaining"]["RU_S1"] = 60
    var queue: Array = sim.state["orders"]["RU_S1"].duplicate(true)
    press(sim,6)
    check(not sim.seeking_cover("RU_S1") and response(sim)["retry_remaining"] == 12 and sim.path_calls > 0,"Viable woods blocked by a friendly arm a twelve-second cooldown.")
    check(same(queue,sim.state["orders"]["RU_S1"]) and sim.movement_mode("RU_S1") == "hunt" and sim.state["pause_remaining"]["RU_S1"] == 54,"Congestion retains the original queue, HUNT mode and running wait.")
    var calls: int = sim.path_calls
    press(sim,11)
    check(response(sim)["retry_remaining"] == 1 and sim.path_calls == calls,"No path search occurs during the first eleven cooldown seconds.")
    press(sim,1)
    check(response(sim)["retry_remaining"] == 12 and sim.path_calls > calls and not sim.seeking_cover("RU_S1"),"Still-occupied terrain retries exactly after twelve seconds, without stealing space.")
    # Snapshot late in the interval: planning must not consume retry time.
    press(sim,41) # t59: search cadence6,18,30,42,54, then five cooldown seconds.
    check(response(sim)["retry_remaining"] == 7,"Repeat searches keep a bounded cadence without frame-driven retries.")
    sim.squad_by_id("RU_S2")["position"] = [292,212]
    press(sim,1) # interval boundary t60, six seconds remain.
    var checkpoint: Dictionary = sim.state.duplicate(true)
    for tick in range(20):
        sim.step()
        sim.seeking_cover("RU_S1")
        sim._cover_goal_available(sim.squad_by_id("RU_S1"),Vector2(324,212))
    check(same(checkpoint,sim.state),"Planning and availability queries do not tick the cooldown.")
    var twin = CountingBattle.new()
    twin.restore(JSON.parse_string(JSON.stringify(checkpoint)))
    for tick in range(6):
        for running in [sim,twin]: press(running,1)
        check(same(sim.state,twin.state),"Partial cooldown resumes exactly across an interval checkpoint.")
        if tick < 5: check(not sim.seeking_cover("RU_S1"),"Freed cover is not claimed before the saved cooldown expires.")
    check(sim.seeking_cover("RU_S1") and response(sim)["retry_remaining"] == 0 and same(response(sim)["goal"],[324.0,212.0]),"Persistent pressure claims newly free cover when the countdown expires.")
    check(same(queue,sim.state["orders"]["RU_S1"]),"Interval planning preserves the queued route while a retry is pending.")
    check(sim.movement_mode("RU_S1") == "hunt" and Battle.position(sim.squad_by_id("RU_S1")) == ORIGIN,"HUNT pressure still halts a successful retry without dropping its goal.")
    # Successful retry respects pending commands, explicit wait and pinning too.
    sim.state["movement_modes"]["RU_S1"] = "move"
    sim.state["command_remaining"]["RU_S1"] = 2
    press(sim,2)
    check(Battle.position(sim.squad_by_id("RU_S1")) == ORIGIN,"Command response still holds a retried detour.")
    sim.state["pause_remaining"]["RU_S1"] = 2
    press(sim,2)
    check(Battle.position(sim.squad_by_id("RU_S1")) == ORIGIN,"Explicit wait still holds a retried detour.")
    sim.squad_by_id("RU_S1")["suppression"] = 0.95
    sim.step()
    check(Battle.position(sim.squad_by_id("RU_S1")) == ORIGIN,"Pinning still holds a retried detour.")
    sim.state["postures"]["RU_S1"] = "crouch"
    press(sim,35)
    check(sim.seeking_cover("RU_S1") and response(sim)["path"].is_empty() and Battle.position(sim.squad_by_id("RU_S1")) == Vector2(324,212),"Retried route actually reaches free wooded cover while pressure persists.")
    # No retry for a non-congestion failure, nor for ineligible squads.
    for condition in ["remote","covered","unreachable","queue_full","blue","dead","broken"]:
        var other = fixture()
        start(other)
        match condition:
            "remote": other.squad_by_id("RU_S1")["position"] = [480,480]
            "covered": other.squad_by_id("RU_S1")["position"] = [300,212]
            "unreachable":
                for y in range(64):
                    for x in range(64):
                        var cell := Vector2i(x,y)
                        if Battle.cover(other.cover_navigation.get_point_position(cell)) > 0.2: other.cover_navigation.set_point_solid(cell,true)
            "queue_full":
                other.state["orders"]["RU_S1"] = []
                for index in range(128): other.state["orders"]["RU_S1"].append([390,260])
                other.state["movement_modes"]["RU_S1"] = "move"
                other.state["pause_remaining"]["RU_S1"] = 60
            "blue": other.squad_by_id("UKR_S2")["suppression"] = 1
            "dead": other.squad_by_id("RU_S1")["alive"] = 0
            "broken":
                other.state["morale_states"]["RU_S1"] = "broken"
                other.squad_by_id("RU_S1")["morale"] = 20
        press(other,6)
        var id: String = "UKR_S2" if condition == "blue" else "RU_S1"
        check(other.state["cover_responses"][id]["retry_remaining"] == 0,"No congestion retry for "+condition)
    var blocked = fixture()
    start(blocked)
    press(blocked,6)
    var pending: Dictionary = blocked.state.duplicate(true)
    for condition in ["low_pressure","recovery","death","break"]:
        var cleared = Battle.new()
        cleared.restore(pending)
        var red: Dictionary = cleared.squad_by_id("RU_S1")
        match condition:
            "low_pressure": red["suppression"] = 0.334999
            "recovery": red["suppression"] = 0.18
            "death": red["alive"] = 0
            "break":
                red["morale"] = 20
                red["suppression"] = 0.9
        cleared.step()
        check(response(cleared)["retry_remaining"] == 0 and response(cleared)["pressure_ticks"] == 0 and Battle.validate(cleared.state,PAYLOAD),"Cooldown cancels cleanly on "+condition)
    var hidden = fixture()
    hidden.squad_by_id("UKR_S2")["position"] = [470,40]
    hidden.state["shared_contacts"]["RU"]["UKR_S2"] = {"position":[324,212],"seen_at":0}
    start(hidden)
    press(hidden,6)
    check(same(response(blocked),response(hidden)),"Hidden enemy coordinates/reports cannot alter congestion or retry timing.")
    var old = fixture()
    legacy(old)
    start(old)
    press(old,6)
    old.squad_by_id("RU_S2")["position"] = [292,212]
    press(old,30)
    check(not old.seeking_cover("RU_S1") and Battle.validate(old.state,PAYLOAD),"V24 keeps its no-retry behavior and original fields.")
    var quiet = fixture()
    var quiet_old = fixture()
    legacy(quiet_old)
    finish(quiet)
    finish(quiet_old)
    var normalized: Dictionary = quiet.state.duplicate(true)
    normalized["version"] = 24
    normalized.erase("route_legs")
    normalized.erase("route_modes")
    for record in normalized["cover_responses"].values(): record.erase("retry_remaining")
    check(same(normalized,quiet_old.state) and same(quiet.result(),quiet_old.result()),"Quiet v27 and v24 complete states/results are identical except their versioned fields.")
    for index in range(9):
        var bad: Dictionary = pending.duplicate(true)
        var record: Dictionary = bad["cover_responses"]["RU_S1"]
        match index:
            0: record.erase("retry_remaining")
            1: record["retry_remaining"] = -1
            2: record["retry_remaining"] = 13
            3: record["retry_remaining"] = 0.5
            4: record["retry_remaining"] = "12"
            5: record["retry_remaining"] = NAN
            6: record["pressure_ticks"] = 5
            7:
                record["goal"] = [324,212]
                record["path"] = [[324,212]]
            8: bad["cover_responses"]["UKR_S2"] = record.duplicate(true)
        check(not Battle.validate(bad,PAYLOAD),"Malformed retry state rejects case%d." % index)
    # Genuine campaign disk save during a retry armed by real support fire.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://cover_retry_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    real_fire_setup(battle)
    for tick in range(16): battle.step()
    check(response(battle)["retry_remaining"] > 0 and game._save_campaign()["ok"],"Actual fire creates a partially elapsed retry that saves through the campaign.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()),"Actual disk load restores the exact partial retry and friendly route/wait.")
    var retried := false
    for tick in range(400):
        if battle.state["phase"] == "finished": break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning": running.execute()
            running.step()
        retried = retried or battle.seeking_cover("RU_S1")
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events) and Battle.validate(battle.state,game.battle_payload),"Every actual campaign tick/event validates and matches after partial retry restart.")
    check(retried and same(battle.result(),resumed.tactical_simulation.result()),"Actual moving friendly frees cover and complete restarted outcomes match.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    var visible = fixture()
    real_fire_setup(visible)
    var view = View.new()
    view.simulation = visible
    view.selected = "UKR_S2"
    root.add_child(view)
    await process_frame
    view.set_process(false)
    view.camera_focus = Vector2(344,212)
    # Use the established close-inspection scale; overview labels jump at 80 m.
    view.camera_distance = 65
    view.camera_pitch = deg_to_rad(50)
    view.camera_yaw = deg_to_rad(75)
    view._update_camera()
    var unrendered = Battle.new()
    unrendered.restore(visible.state)
    var captured_fire := false
    var captured_retry := false
    for tick in range(55):
        unrendered.step()
        view._process(0.25)
        check(same(visible.state,unrendered.state),"Real4x playback cannot change retry timing or authoritative outcomes.")
        if not captured_fire and response(visible)["retry_remaining"] > 0 and not view.shot_cues.is_empty():
            captured_fire = true
            check(view.actors["RU_S1"].visible and not visible.seeking_cover("RU_S1"),"An acquired crowded squad receives actual support fire while retrying.")
            print("RETRY FIRE: tick=",visible.state["elapsed"]," rounds=",visible.squad_by_id("UKR_S2")["ammo"]," retry=",response(visible)["retry_remaining"])
            await capture_frame("cover-retry-fire-preview")
        if not captured_retry and visible.seeking_cover("RU_S1") and Battle.position(visible.squad_by_id("RU_S1")).distance_to(ORIGIN) >= 4.0:
            captured_retry = true
            check(response(visible)["retry_remaining"] == 0 and view.actors["RU_S1"].visible and visible.squad_by_id("UKR_S2")["ammo"] == 0 and view.shot_cues.is_empty(),"Freed cover causes acquired actual movement after ammunition/old cues expire.")
            print("RETRY MOVE: tick=",visible.state["elapsed"]," position=",Battle.position(visible.squad_by_id("RU_S1"))," goal=",response(visible)["goal"]," blocker=",Battle.position(visible.squad_by_id("RU_S2")))
            await capture_frame("cover-retry-move-preview")
    check(captured_fire and captured_retry,"Actual fire and friendly movement produce a visible retried cover move.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: bounded congestion-only retries, no cooldown pathfinding, saved clocks/gates, release/legacy/validation, actual-fire disk continuation and rendered twin purity.")
    quit(0 if failures.is_empty() else 1)
