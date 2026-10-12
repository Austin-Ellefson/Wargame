extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"AREA_FIRE","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(id: String = "UKR_S1") -> RefCounted:
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.state["version"] = 21
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in [id,"RU_S1","RU_S2"]: squad["alive"] = 0
    sim.squad_by_id(id)["position"] = [180,210]
    sim.squad_by_id("RU_S1")["position"] = [298,210]
    sim.state["postures"]["RU_S1"] = "prone"
    sim.squad_by_id("RU_S2")["position"] = [470,470]
    return sim
func execute_stationary(sim: RefCounted) -> void:
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished":return
        if sim.state["phase"] == "planning":sim.execute()
        sim.step()
func click(point: Vector2,button: int) -> void:
    var e := InputEventMouseButton.new()
    e.position = point
    e.global_position = point
    e.button_index = button
    e.pressed = true
    Input.parse_input_event(e)
    e = e.duplicate()
    e.pressed = false
    Input.parse_input_event(e)
func capture_frame(name: String) -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK,"Rendered area evidence saves.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = fixture()
    check(sim.state["version"] == 21 and sim.order_area_fire("UKR_S1",Vector2(298,210)),"Reachable ground area requires no enemy identification.")
    var before: Dictionary = sim.state.duplicate(true)
    var copy: Array = sim.area_target("UKR_S1")
    copy[0] = 999
    check(same(before,sim.state) and not sim.order_area_fire("UKR_S1",Vector2(NAN,210)) and not sim.order_area_fire("UKR_S1",Vector2(180,210)) and not sim.order_area_fire("UKR_S1",Vector2(470,470)) and not sim.order_area_fire("RU_S1",Vector2(180,210)) and not sim.order_area_fire("UKR_S2",Vector2(298,210)),"Deep-copy query and invalid/nonfinite/coincident/range/enemy/dead orders cannot mutate state.")
    sim.squad_by_id("UKR_S1")["ammo"] = 9
    execute_stationary(sim)
    for tick in range(3):sim.step()
    var event: Dictionary = sim.last_events[0] if not sim.last_events.is_empty() else {}
    check(event.get("area",false) and event.get("target","BAD") == "" and event.get("losses",-1) == 0 and event.get("rounds",0) == 9 and same(event.get("to",[]),[298,210]) and not event.has("affected") and event.get("player_visible",false),"Actual area volley exposes only chosen ground point/rounds, never affected target IDs or hits.")
    check(sim.squad_by_id("UKR_S1")["ammo"] == 0 and sim.squad_by_id("RU_S1")["suppression"] > 0 and sim.squad_by_id("RU_S1")["alive"] == 9 and sim.squad_by_id("RU_S2")["suppression"] == 0 and not sim.can_spot(sim.squad_by_id("UKR_S1"),sim.squad_by_id("RU_S1")) and sim.state["observer_contacts"]["UKR_S1"].is_empty(),"Real ammunition suppresses nearby concealed opposition without casualties, distant pressure or contact revelation.")
    check(not sim.order_area_fire("UKR_S1",Vector2(298,210)),"Execution freezes area orders.")
    for tick in range(3):sim.step()
    check(sim.last_events.is_empty(),"Empty ammunition produces no area shot events.")
    for tick in range(54):sim.step()
    check(sim.state["phase"] == "planning" and not sim.order_target("UKR_S1","RU_S1"),"Area pressure grants no real next-planning entity target permission.")
    var memory = fixture()
    memory.state["postures"]["RU_S1"] = "stand"
    execute_stationary(memory)
    for tick in range(60):memory.step()
    check(memory.order_posture("RU_S1","prone",false) and memory.order_area_fire("UKR_S1",Vector2(298,210)) and not memory.order_target("UKR_S1","RU_S1"),"A real posture command hides an identified squad; remembered point allows area fire but not a direct target command.")
    var remembered: Array = memory.remembered_contacts("UKR_S1")
    memory.squad_by_id("UKR_S1")["ammo"] = 9
    execute_stationary(memory)
    for tick in range(3):memory.step()
    check(same(remembered,memory.remembered_contacts("UKR_S1")) and memory.last_events[0]["target"] == "" and not memory.can_spot(memory.squad_by_id("UKR_S1"),memory.squad_by_id("RU_S1")),"Firing at real last-known ground retains stale observation time and reveals no current identity/hit.")
    var falloff = fixture()
    falloff.squad_by_id("RU_S2")["position"] = [306,210]
    falloff.squad_by_id("UKR_S1")["ammo"] = 9
    falloff.order_area_fire("UKR_S1",Vector2(298,210))
    execute_stationary(falloff)
    for tick in range(3):falloff.step()
    check(is_equal_approx(falloff.squad_by_id("RU_S2")["suppression"]*2.0,falloff.squad_by_id("RU_S1")["suppression"]),"Real pressure falls linearly with distance from selected point.")
    var edge = fixture()
    edge.squad_by_id("RU_S2")["position"] = [314,210]
    edge.squad_by_id("UKR_S1")["ammo"] = 9
    edge.order_area_fire("UKR_S1",Vector2(298,210))
    execute_stationary(edge)
    for tick in range(3):edge.step()
    check(edge.squad_by_id("RU_S2")["suppression"] == 0,"Exactly16m boundary receives no pressure.")
    var support = fixture("UKR_S2")
    support.squad_by_id("UKR_S2")["ammo"] = 360
    support.order_area_fire("UKR_S2",Vector2(298,210))
    execute_stationary(support)
    for tick in range(18):support.step()
    check(support.is_pinned(support.squad_by_id("RU_S1")) and support.squad_by_id("RU_S1")["alive"] == 9 and support.squad_by_id("UKR_S2")["ammo"] == 198 and not support.can_spot(support.squad_by_id("UKR_S2"),support.squad_by_id("RU_S1")),"Actual support area volleys pin a concealed squad without casualty or omniscient contact.")
    var hidden_red = fixture()
    hidden_red.squad_by_id("UKR_S1")["position"] = [40,450]
    hidden_red.squad_by_id("RU_S1")["position"] = [400,210]
    hidden_red.state["postures"]["RU_S1"] = "stand"
    hidden_red.squad_by_id("RU_S1")["ammo"] = 9
    check(hidden_red.order_area_fire("RU_S1",Vector2(298,210),false),"Red can receive explicit nonplayer area order using the same rules.")
    execute_stationary(hidden_red)
    for tick in range(3):hidden_red.step()
    check(hidden_red.last_events.size() == 1 and not hidden_red.last_events[0]["player_visible"] and hidden_red.last_events[0]["local_observers"].is_empty(),"An actual hidden enemy area shot provides no player witnesses or disclosed endpoint.")
    var held = fixture()
    held.order_area_fire("UKR_S1",Vector2(298,210))
    held.order_fire("UKR_S1","hold")
    held.squad_by_id("UKR_S1")["ammo"] = 360
    execute_stationary(held)
    for tick in range(3):held.step()
    check(held.last_events.is_empty() and held.squad_by_id("UKR_S1")["ammo"] == 360 and not held.area_target("UKR_S1").is_empty(),"HOLD FIRE retains area order while withholding rounds and cues.")
    var arc = fixture()
    arc.order_area_fire("UKR_S1",Vector2(298,210))
    arc.order_facing("UKR_S1",Vector2(180,110))
    arc.order_arc("UKR_S1",90)
    arc.squad_by_id("UKR_S1")["ammo"] = 360
    execute_stationary(arc)
    for tick in range(3):arc.step()
    check(arc.last_events.is_empty() and arc.squad_by_id("UKR_S1")["ammo"] == 360 and "waiting" in arc.target_status("UKR_S1"),"Later arc excludes area without spending rounds or falling back to targeted fire.")
    var blocked = fixture()
    blocked.squad_by_id("UKR_S1")["position"] = [210,167]
    check(not blocked.order_area_fire("UKR_S1",Vector2(270,167)) and not blocked.order_area_fire("UKR_S1",Vector2(230,167)),"Building-blocked LOS and building-interior points reject.")
    var transitions = fixture()
    transitions.order_area_fire("UKR_S1",Vector2(298,210))
    check(transitions.order_target("UKR_S1","") and transitions.area_target("UKR_S1").is_empty(),"CLEAR FIRE cancels area via the existing clear-target command.")
    transitions.squad_by_id("RU_S1")["position"] = [240,210]
    transitions.state["postures"]["RU_S1"] = "stand"
    execute_stationary(transitions)
    for tick in range(60):transitions.step()
    transitions.order_area_fire("UKR_S1",Vector2(298,210))
    check(transitions.order_target("UKR_S1","RU_S1") and transitions.area_target("UKR_S1").is_empty(),"Real identified preferred target replaces area order exclusively.")
    check(transitions.order_area_fire("UKR_S1",Vector2(298,210)) and transitions.state["fire_targets"]["UKR_S1"] == "","Area command replaces a real accepted target without retaining an enemy ID.")
    var broken = fixture()
    broken.order_area_fire("UKR_S1",Vector2(298,210))
    broken.squad_by_id("UKR_S1")["morale"] = 20
    broken.squad_by_id("UKR_S1")["suppression"] = 0.8
    execute_stationary(broken)
    broken.step()
    check(broken.area_target("UKR_S1").is_empty() and Battle.validate(broken.state,PAYLOAD),"Automatic morale withdrawal cancels area order and validates.")
    var valid = fixture()
    valid.order_area_fire("UKR_S1",Vector2(298,210))
    check(Battle.validate(valid.state,PAYLOAD),"Planning area state validates.")
    for corruption in range(10):
        var bad: Dictionary = valid.state.duplicate(true)
        match corruption:
            0:bad.erase("area_fire")
            1:bad["area_fire"].erase("UKR_S2")
            2:bad["area_fire"]["UNKNOWN"] = []
            3:bad["area_fire"]["UKR_S1"] = [999,210]
            4:bad["area_fire"]["UKR_S1"] = [230,160]
            5:bad["area_fire"]["UKR_S1"] = [298,210,0]
            6:bad["area_fire"]["UKR_S1"] = ["298",210]
            7:bad["fire_targets"]["UKR_S1"] = "RU_S1"
            8:bad["area_fire"]["UKR_S1"] = {}
            9:
                bad["morale_states"]["UKR_S1"] = "broken"
                bad["rally_remaining"]["UKR_S1"] = 30
        check(not Battle.validate(bad,PAYLOAD),"Malformed/mixed/broken area save rejects: %d" % corruption)
    var current = fixture()
    var legacy = fixture()
    legacy.state["version"] = 20
    legacy.state.erase("area_fire")
    check(Battle.validate(legacy.state,PAYLOAD) and not legacy.order_area_fire("UKR_S1",Vector2(298,210)),"V20 retains original fields and cannot receive new orders.")
    for battle in [current,legacy]:
        battle.squad_by_id("RU_S1")["position"] = [240,210]
        battle.state["postures"]["RU_S1"] = "stand"
        battle.squad_by_id("UKR_S1")["ammo"] = 360
        battle.squad_by_id("RU_S1")["ammo"] = 360
        finish(battle)
    var authoritative: Dictionary = current.state.duplicate(true)
    authoritative["version"] = 20
    authoritative.erase("area_fire")
    check(same(authoritative,legacy.state) and same(current.result(),legacy.result()),"No-area v21 reproduces all v20 authoritative combat fields/results without extra RNG.")
    # Actual campaign disk continuation includes expenditure/suppression/history locks.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://area_fire_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    battle.squad_by_id("UKR_S1")["position"] = [180,210]
    battle.squad_by_id("RU_S1")["position"] = [298,210]
    battle.state["postures"]["RU_S1"] = "prone"
    battle.order_area_fire("UKR_S1",Vector2(298,210))
    battle.execute()
    for tick in range(4):battle.step()
    check(game._save_campaign()["ok"],"Actual area-fire execution saves to disk.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()),"Real disk restart restores area point/expenditure and campaign state exactly.")
    for tick in range(400):
        if battle.state["phase"] == "finished":break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning":running.execute()
            running.step()
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events),"Every area continuation tick/event remains exact after restart.")
    check(same(battle.result(),resumed.tactical_simulation.result()),"Full area-fire campaign battle results match after restart.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    var gui = fixture()
    gui.squad_by_id("UKR_S1")["ammo"] = 360
    var view = View.new()
    view.simulation = gui
    root.add_child(view)
    await process_frame
    view.set_process(false)
    click(Vector2(303,88),MOUSE_BUTTON_LEFT)
    await process_frame
    var aim := Vector2(298,210)
    var screen: Vector2 = view.camera.unproject_position(Vector3(aim.x,Battle.terrain_height(aim.x,aim.y),aim.y))
    click(screen+Vector2(24,112),MOUSE_BUTTON_LEFT)
    await process_frame
    check(not view.area_armed and not gui.area_target("UKR_S1").is_empty() and view.area_preview.get_child_count() == 2 and gui.state["fire_targets"]["UKR_S1"] == "","Real AREA FIRE and projected ground click save point and show explicit area preview.")
    before = gui.state.duplicate(true)
    view._refresh()
    check(same(before,gui.state),"Area preview queries never change state or acquisition.")
    await capture_frame("area-fire-planning-preview")
    var twin = Battle.new()
    twin.restore(gui.state)
    execute_stationary(gui)
    execute_stationary(twin)
    for tick in range(3):
        var status_before: Dictionary = view._status_snapshot()
        gui.step()
        twin.step()
        view._refresh()
        view._show_shot_events(gui.consume_events())
        view._show_combat_changes(status_before)
    check(not view.actors["RU_S1"].visible and not view.shot_cues.is_empty() and view.observed_shot_events.back()["area"] and "RU" not in view.combat_label.text and gui.squad_by_id("UKR_S1")["ammo"] == 351 and view.area_button.disabled,"Actual area cue and rounds are readable while impacted hidden actors/pressure stay confidential; execution locks controls.")
    check(same(gui.state,twin.state),"Actual area muzzle/cue/combat rendering leaves full authoritative twin state unchanged.")
    view._show_shot_events(hidden_red.last_events)
    check(view.observed_shot_events.size() == 1,"Actual hidden red area volley cannot enter visible event history.")
    await capture_frame("area-fire-shot-preview")
    for tick in range(57):gui.step()
    view._refresh()
    click(Vector2(1190,489),MOUSE_BUTTON_LEFT)
    await process_frame
    check(gui.area_target("UKR_S1").is_empty() and view.area_preview.get_child_count() == 0,"Actual CLEAR FIRE removes persistent area order/preview.")
    before = gui.state.duplicate(true)
    click(Vector2(303,88),MOUSE_BUTTON_LEFT)
    await process_frame
    click(screen+Vector2(24,112),MOUSE_BUTTON_RIGHT)
    await process_frame
    check(not view.area_armed and same(before,gui.state),"Right-click cancels area cursor without a movement order.")
    view.queue_free()
    await process_frame
    if failures.is_empty():print("PASS: actual area expenditure/suppression/cues, hidden knowledge isolation, hold/arc/clear controls, strict v21 saves, v20 outcomes and exact full disk restart.")
    quit(0 if failures.is_empty() else 1)
