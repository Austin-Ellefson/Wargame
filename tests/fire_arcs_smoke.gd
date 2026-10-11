extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"FIRE_ARCS","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture() -> RefCounted:
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1","RU_S1","RU_S2"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [220,245]
    sim.squad_by_id("RU_S2")["position"] = [180,305]
    return sim
func execute_stationary(sim: RefCounted) -> void:
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished": return
        if sim.state["phase"] == "planning": sim.execute()
        sim.step()
func click(point: Vector2, button: int) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = button
    event.pressed = true
    Input.parse_input_event(event)
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)
func capture_frame(name: String) -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            var path := argument.trim_prefix("--capture=").get_base_dir().path_join(name + ".png")
            check(root.get_texture().get_image().save_png(path) == OK, "Actual rendered fire arc frame saves.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = fixture()
    check(sim.state["version"] == 20 and sim.order_facing("UKR_S1",Vector2(180,305)) and sim.facing("UKR_S1") == 180 and sim.order_arc("UKR_S1",90), "Planning can face south and create a 90-degree arc.")
    check(not sim.order_facing("UKR_S1",Vector2(180,245)) and not sim.order_facing("UKR_S1",Vector2(NAN,245)) and not sim.order_arc("UKR_S1",90.5) and not sim.order_arc("UKR_S1","90") and not sim.order_arc("UNKNOWN",90) and not sim.order_arc("RU_S1",90) and not sim.order_arc("UKR_S2",90), "Invalid/coincident/nonfinite/fractional/string/unknown/enemy/dead orders reject.")
    sim.squad_by_id("UKR_S1")["ammo"] = 9
    execute_stationary(sim)
    for tick in range(3): sim.step()
    check(sim.can_spot(sim.squad_by_id("UKR_S1"),sim.squad_by_id("RU_S1")) and not sim.can_engage(sim.squad_by_id("UKR_S1"),sim.squad_by_id("RU_S1")) and sim.last_events.size() == 1 and sim.last_events[0]["target"] == "RU_S2" and sim.last_events[0]["rounds"] == 9, "Actually acquired nearer out-of-arc focus stays visible but real fire chooses the eligible in-arc enemy.")
    check(not sim.order_arc("UKR_S1",0) and not sim.order_facing("UKR_S1",Vector2(200,245)), "Execution freezes facing/arc orders.")
    var snapshot: Dictionary = sim.state.duplicate(true)
    for repeat in range(20): sim.within_fire_arc(sim.squad_by_id("UKR_S1"),sim.squad_by_id("RU_S1"))
    check(same(snapshot,sim.state), "Arc queries are pure and cannot advance acquisition or response.")
    for tick in range(57): sim.step()
    check(not sim.order_target("UKR_S1","RU_S1") and sim.order_arc("UKR_S1",0) and sim.order_target("UKR_S1","RU_S1"), "Actual next planning interval rejects out-of-arc target, then clearing arc restores local target permission.")
    check(sim.order_arc("UKR_S1",90) and sim.target_status("UKR_S1") == "Focus: outside arc", "A real accepted focus cannot override a later arc; feedback is truthful.")
    sim.squad_by_id("UKR_S1")["ammo"] = 9
    execute_stationary(sim)
    for tick in range(3): sim.step()
    check(sim.last_events.size() == 1 and sim.last_events[0]["target"] == "RU_S2", "Real fire after planning retains old focus but selects eligible in-arc enemy instead.")
    var edges = fixture()
    var blue: Dictionary = edges.squad_by_id("UKR_S1")
    var red: Dictionary = edges.squad_by_id("RU_S1")
    edges.order_facing("UKR_S1",Vector2(179,185))
    edges.order_arc("UKR_S1",90)
    red["position"] = [180,185]
    check(edges.facing("UKR_S1") == 359 and edges.within_fire_arc(blue,red), "Bearing wrap around north keeps zero-degree contact inside 359-degree arc.")
    edges.order_facing("UKR_S1",Vector2(180,185))
    red["position"] = [240,185]
    check(edges.within_fire_arc(blue,red), "Exact 90-degree arc edge is inclusive.")
    red["position"] = [241,185]
    check(not edges.within_fire_arc(blue,red), "Contact beyond bounded edge is excluded.")
    edges.order_arc("UKR_S1",180)
    red["position"] = [120,245]
    check(edges.within_fire_arc(blue,red), "180-degree edge includes west at north facing.")
    red["position"] = [180,305]
    check(not edges.within_fire_arc(blue,red), "180-degree arc excludes rearward fire.")
    check(edges.order_facing("RU_S1",Vector2(180,245),false) and edges.order_arc("RU_S1",90,false) and edges.within_fire_arc(red,blue), "Both factions use identical facing/arc rules; manual player cannot command red.")
    var hidden = fixture()
    hidden.order_facing("UKR_S1",Vector2(470,470))
    hidden.order_arc("UKR_S1",90)
    hidden.squad_by_id("RU_S1")["position"] = [470,470]
    execute_stationary(hidden)
    hidden.state["fire_targets"]["UKR_S1"] = "RU_S1"
    hidden.step()
    check(hidden.target_status("UKR_S1") == "Focus: waiting for sight", "Hidden target bearing cannot leak through focus status.")
    check(not hidden.can_spot(hidden.squad_by_id("UKR_S1"),hidden.squad_by_id("RU_S1")) and not hidden.can_engage(hidden.squad_by_id("UKR_S1"),hidden.squad_by_id("RU_S1")), "Facing a hidden point grants no sight, acquisition or fire permission.")
    var broken = fixture()
    broken.order_arc("UKR_S1",90)
    broken.squad_by_id("UKR_S1")["morale"] = 20
    broken.squad_by_id("UKR_S1")["suppression"] = 0.8
    execute_stationary(broken)
    broken.step()
    check(broken.morale_state("UKR_S1") == "broken" and broken.arc_width("UKR_S1") == 0 and not broken.order_arc("UKR_S1",90) and Battle.validate(broken.state,PAYLOAD), "Morale withdrawal clears fire arc without blocking retreat and validates.")
    var moving = fixture()
    moving.order_facing("UKR_S1",Vector2(180,305))
    moving.order_arc("UKR_S1",90)
    moving.order_move("UKR_S1",Vector2(210,245),true,"quick")
    moving.execute()
    for id in moving.state["orders"].keys():
        if id != "UKR_S1":
            moving.state["orders"].erase(id)
            moving.state["movement_modes"].erase(id)
            moving.state["command_remaining"][id] = 0
    for tick in range(10): moving.step()
    check(moving.squad_by_id("UKR_S1")["position"][0] > 180 and moving.facing("UKR_S1") == 180 and moving.arc_width("UKR_S1") == 90 and moving.can_engage(moving.squad_by_id("UKR_S1"),moving.squad_by_id("RU_S2")) and not moving.can_engage(moving.squad_by_id("UKR_S1"),moving.squad_by_id("RU_S1")), "Actual route displacement moves arc origin while retaining ordered world bearing and local target bounds.")
    var valid = fixture()
    valid.order_facing("UKR_S1",Vector2(240,245))
    valid.order_arc("UKR_S1",90)
    check(Battle.validate(valid.state,PAYLOAD), "Real planning facing/arc state validates.")
    for corruption in range(11):
        var bad: Dictionary = valid.state.duplicate(true)
        var record: Dictionary = bad["facing_orders"]["UKR_S1"]
        match corruption:
            0: bad.erase("facing_orders")
            1: bad["facing_orders"].erase("RU_S1")
            2: bad["facing_orders"]["UNKNOWN"] = record.duplicate(true)
            3: record["heading"] = 360
            4: record["heading"] = -1
            5: record["heading"] = 90.5
            6: record["width"] = 45
            7: record["width"] = "90"
            8: record["extra"] = 0
            9: record["heading"] = INF
            10:
                bad["morale_states"]["UKR_S1"] = "broken"
                bad["rally_remaining"]["UKR_S1"] = 30
        check(not Battle.validate(bad,PAYLOAD), "Malformed facing/arc map/angle/width/broken state must reject: %d" % corruption)
    var current = fixture()
    var legacy = fixture()
    legacy.state["version"] = 19
    legacy.state.erase("facing_orders")
    check(Battle.validate(legacy.state,PAYLOAD) and not legacy.order_arc("UKR_S1",90), "V19 retains old fields and unrestricted fire; orders do not migrate saves.")
    for battle in [current,legacy]:
        battle.squad_by_id("UKR_S1")["ammo"] = 360
        battle.squad_by_id("RU_S1")["ammo"] = 360
        finish(battle)
    var authoritative: Dictionary = current.state.duplicate(true)
    authoritative["version"] = 19
    authoritative.erase("facing_orders")
    check(same(authoritative,legacy.state) and same(current.result(),legacy.result()), "Default unrestricted v20 reproduces complete v19 combat fields/results exactly.")
    # Real campaign disk continuation with changed facing/arc and live firing.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://fire_arcs_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    battle.squad_by_id("UKR_S1")["position"] = [180,245]
    battle.squad_by_id("RU_S1")["position"] = [240,245]
    battle.order_facing("UKR_S1",Vector2(240,245))
    battle.order_arc("UKR_S1",90)
    battle.execute()
    for tick in range(4): battle.step()
    check(game._save_campaign()["ok"], "Actual campaign saves active fire arc and acquired sight mid-execution.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()), "Disk restart restores facing and fire arc exactly.")
    for tick in range(400):
        if battle.state["phase"] == "finished": break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning": running.execute()
            running.step()
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events), "Every resumed tick matches arc-restricted shots/state.")
    check(same(battle.result(),resumed.tactical_simulation.result()), "Full bounded-arc disk combat outcomes are identical.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    var gui = fixture()
    var view = View.new()
    view.simulation = gui
    root.add_child(view)
    await process_frame
    view.set_process(false)
    click(Vector2(532,88),MOUSE_BUTTON_LEFT)
    await process_frame
    check(gui.arc_width("UKR_S1") == 90 and view.arc_button.text == "ARC 90°", "Actual ARC button cycles to saved bounded width.")
    var before: Dictionary = gui.state.duplicate(true)
    click(Vector2(422,88),MOUSE_BUTTON_LEFT)
    await process_frame
    var aim := Vector2(260,245)
    var screen: Vector2 = view.camera.unproject_position(Vector3(aim.x,Battle.terrain_height(aim.x,aim.y),aim.y))
    click(screen + Vector2(24,112),MOUSE_BUTTON_LEFT)
    await process_frame
    check(not view.facing_armed and absi(gui.facing("UKR_S1") - 90) <= 1 and view.arc_preview.get_child_count() == 14 and "FACE" in view.facing_button.text, "Actual FACE and projected ground click persist bearing and show arc wedge.")
    var after: Dictionary = gui.state.duplicate(true)
    before.erase("facing_orders")
    after.erase("facing_orders")
    check(same(before,after), "Facing click changes only facing order; no route, timer, acquisition, memory or RNG change.")
    view._animate_soldiers(0.01)
    check(is_equal_approx(view.bodies["UKR_S1"][0].rotation.y,-deg_to_rad(gui.facing("UKR_S1"))), "Stationary living figures obey ordered facing.")
    before = gui.state.duplicate(true)
    view._refresh()
    check(same(before,gui.state), "Arc preview refresh remains pure.")
    await capture_frame("fire-arc-planning-preview")
    click(Vector2(679,88),MOUSE_BUTTON_LEFT)
    await process_frame
    check(view.camera_distance == 24 and is_equal_approx(view.arc_preview.get_child(0).mesh.size.x,0.035) and same(before,gui.state), "Actual INSPECT uses a thin arc outline without changing orders or state.")
    await capture_frame("fire-arc-inspection-preview")
    click(Vector2(863,88),MOUSE_BUTTON_LEFT)
    await process_frame
    check(is_equal_approx(view.arc_preview.get_child(0).mesh.size.x,0.65), "RESET restores readable overview outline width.")
    click(Vector2(422,88),MOUSE_BUTTON_LEFT)
    await process_frame
    click(screen + Vector2(24,112),MOUSE_BUTTON_RIGHT)
    await process_frame
    check(not view.facing_armed and same(before,gui.state), "Right-click cancels FACE without accidentally issuing a movement order.")
    gui.squad_by_id("UKR_S1")["ammo"] = 9
    execute_stationary(gui)
    for tick in range(3):
        var status_before: Dictionary = view._status_snapshot()
        gui.step()
        view._refresh()
        view._show_shot_events(gui.consume_events())
        view._show_combat_changes(status_before)
    check(view.facing_button.disabled and view.arc_button.disabled and view.actors["RU_S2"].visible and not gui.can_engage(gui.squad_by_id("UKR_S1"),gui.squad_by_id("RU_S2")) and not view.shot_cues.is_empty(), "Actual execution preserves visible outside-arc enemy while firing at eligible east contact, locking arc controls.")
    await capture_frame("fire-arc-shot-preview")
    var fallen = view.bodies["UKR_S1"][8]
    gui.squad_by_id("UKR_S1")["alive"] = 8
    view._refresh()
    var fallen_heading: float = fallen.rotation.y
    view._animate_soldiers(0.5)
    view._animate_soldiers(0.01)
    check(fallen.current_pose == "casualty" and fallen.rotation.y == fallen_heading, "Facing preview/idle orders do not turn a known casualty.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: real bounded-arc shots, local-only targeting, bearing boundaries/wrap, frozen commands, strict v20 saves, v19 outcome parity and full disk restart.")
    quit(0 if failures.is_empty() else 1)
