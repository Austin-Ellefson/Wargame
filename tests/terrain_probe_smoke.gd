extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"TERRAIN_PROBE","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = button
    event.shift_pressed = shift
    event.pressed = true
    Input.parse_input_event(event)
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)
func escape() -> void:
    var event := InputEventKey.new()
    event.keycode = KEY_ESCAPE
    event.pressed = true
    Input.parse_input_event(event)
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)
func screen(view: Control, point: Vector2) -> Vector2:
    return Vector2(24,112) + view.camera.unproject_position(Vector3(point.x,Battle.terrain_height(point.x,point.y),point.y))
func frame(view: Control, focus: Vector2, distance: float = 200.0) -> void:
    view.camera_focus = focus
    view.camera_distance = distance
    view.camera_pitch = deg_to_rad(50)
    view.camera_yaw = 0
    view.camera.fov = 52
    view._update_camera()
func capture(name: String) -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK, "Terrain probe render saves.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    var view = View.new()
    view.simulation = sim
    root.add_child(view)
    await process_frame
    view.set_process(false)
    frame(view,Vector2(210,245))
    var before: Dictionary = sim.state.duplicate(true)
    var events: Array = sim.last_events.duplicate(true)
    check(view._terrain_probe(Vector2(240,245))["clear"] and is_equal_approx(view._terrain_probe(Vector2(240,245))["distance"],60.0), "Probe reuses terrain LOS and measures exact ground-plane distance.")
    for point in [Vector2(-1,245),Vector2(513,245),Vector2(180,245),Vector2(180.5,245),Vector2(NAN,245),Vector2(INF,245)]:
        check(view._terrain_probe(point).is_empty(), "Invalid, out-of-map and near-coincident ground endpoints reject.")
    check(not view._terrain_probe(Vector2(181,245)).is_empty() and not view._terrain_probe(Vector2(512,512)).is_empty(), "Exact 1m and map bounds are supported without imposing weapon range.")
    seed(72819)
    var first_random := randi()
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    check(view.los_armed and view.los_panel.visible and not view.facing_armed and not view.area_armed, "Actual LOS button arms a separate planning cursor.")
    click(screen(view,Vector2(240,245)),MOUSE_BUTTON_LEFT,true)
    await process_frame
    check(view.los_preview.get_child_count() == 2 and view.los_label.text.contains("TERRAIN CLEAR") and view.los_label.text.contains("GROUND RANGE") and view.los_label.text.contains("not spotting"), "Actual Shift-ground click displays terrain-only status without a preferred-target order.")
    check(view.los_point.distance_to(Vector2(240,245)) < 5, "Terrain picking uses the actual ground near the clicked point, not a unit position.")
    check(same(before,sim.state) and same(events,sim.last_events), "Actual probe clicks preserve every saved field and unconsumed event.")
    await capture("los-clear-preview")
    var point_before: Vector2 = view.los_point
    var length_before: float = view.los_preview.get_child(0).mesh.size.z
    click(screen(view,Vector2(240,245)),MOUSE_BUTTON_WHEEL_DOWN)
    await process_frame
    var motion := InputEventMouseMotion.new()
    motion.position = Vector2(700,460)
    motion.relative = Vector2(8,-5)
    motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
    Input.parse_input_event(motion)
    await process_frame
    check(view.los_point == point_before and view.los_preview.get_child(0).mesh.size.z == length_before and same(before,sim.state), "Actual zoom/pan retain the fixed ground measurement without state changes.")
    click(screen(view,Vector2(240,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    check(not view.los_armed and not view.los_panel.visible and view.los_preview.get_child_count() == 0 and same(before,sim.state), "Right-click cancels probe without accidentally moving or clearing orders.")
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    escape()
    await process_frame
    check(not view.los_armed and same(before,sim.state), "Actual Escape cancels without touching the simulation.")
    var second_random := randi()
    seed(72819)
    check(first_random == randi() and second_random == randi(), "Terrain probing and camera input consume no global RNG.")
    # Existing queued/area/facing commands survive probing, including cancellation.
    check(sim.order_move("UKR_S1",Vector2(190,245)) and sim.order_pause("UKR_S1",15) and sim.order_area_fire("UKR_S1",Vector2(240,245)), "Existing order fixture is legal.")
    before = sim.state.duplicate(true)
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(240,245)))
    await process_frame
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    check(not view.los_armed and same(before,sim.state), "Toggling probe preserves route, pause, response and area order.")
    for button in [view.facing_button,view.area_button]:
        click(view.los_button.get_global_rect().get_center())
        await process_frame
        click(button.get_global_rect().get_center())
        await process_frame
        check(not view.los_armed and view.los_preview.get_child_count() == 0 and same(before,sim.state), "Another cursor mode cancels terrain probe without issuing a command.")
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(view.squad_buttons["UKR_S2"].get_global_rect().get_center())
    await process_frame
    check(not view.los_armed and view.selected == "UKR_S2", "Actual roster selection clears the old observer's measurement.")
    view.selected = "RU_S1"
    check(view._terrain_probe(Vector2(240,245)).is_empty(), "Probe cannot use an enemy observer.")
    view.selected = "UNKNOWN"
    check(view._terrain_probe(Vector2(240,245)).is_empty(), "Unknown observer rejects safely.")
    view.selected = "UKR_S1"
    sim.squad_by_id("UKR_S1")["alive"] = 0
    check(view._terrain_probe(Vector2(240,245)).is_empty(), "Eliminated observer has no probe.")
    sim.squad_by_id("UKR_S1")["alive"] = 9
    # Building crossing and endpoints use existing static terrain, not actor tests.
    sim.squad_by_id("UKR_S1")["position"] = [200,168]
    check(not view._terrain_probe(Vector2(280,168))["clear"] and not view._terrain_probe(Vector2(235,168))["clear"], "Building crossing and a point inside a building report blocked.")
    frame(view,Vector2(240,168),220)
    view._refresh()
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(280,168)))
    await process_frame
    check(view.los_label.text.contains("TERRAIN BLOCKED"), "Actual ground click behind a building displays blocked terrain.")
    await capture("los-blocked-preview")
    # A real sampled hill segment changes with friendly eye height, not target posture.
    var hill_found := false
    for y in range(60,230,10):
        if hill_found: break
        for x in range(40,240,10):
            var a := Vector2(x,y)
            var b := a + Vector2(140,0)
            if not Battle.inside_building(a,5) and not Battle.inside_building(b,5) and Battle.visible(a,b,1.6,0.3) and not Battle.visible(a,b,0.35,0.3):
                sim.squad_by_id("UKR_S1")["position"] = [a.x,a.y]
                view.los_point = b
                hill_found = true
                frame(view,(a+b)*0.5,270)
                break
    check(hill_found, "A real terrain segment distinguishes standing from prone eyes to the same low ground endpoint.")
    view._refresh()
    check(view.los_label.text.contains("TERRAIN CLEAR"), "Standing hill measurement is clear.")
    click(view.posture_buttons["prone"].get_global_rect().get_center())
    await process_frame
    check(view.los_label.text.contains("TERRAIN BLOCKED") and view.los_label.text.contains("PRONE eyes 0.35m"), "Actual posture input immediately recalculates the same ground probe.")
    await capture("los-posture-preview")
    var measurement: Dictionary = view._terrain_probe(view.los_point)
    before = sim.state.duplicate(true)
    var knowledge: Dictionary = sim.state["observer_contacts"].duplicate(true)
    for squad in sim.state["squads"]:
        if squad["faction"] == "RU": squad["position"] = [490,490]
    var hidden: Dictionary = sim.state.duplicate(true)
    for repeat in range(20):
        check(same(measurement,view._terrain_probe(view.los_point)), "Hidden enemy positions cannot affect terrain measurement.")
        view._refresh_los_probe()
    check(same(hidden,sim.state) and same(knowledge,sim.state["observer_contacts"]), "Repeated probes never acquire contacts or update saved knowledge.")
    sim.restore(before)
    # Save the actual authoritative snapshot while the measurement is visible.
    check(Battle.validate(sim.state,PAYLOAD), "The probed snapshot is a valid tactical save, not just a serializable fixture.")
    var save_path := "user://terrain_probe_%d.json" % Time.get_ticks_usec()
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(sim.state))
    file.close()
    var resumed = Battle.new()
    resumed.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
    DirAccess.remove_absolute(save_path)
    check(same(sim.state,resumed.state), "Disk restart preserves the same battle with no probe/camera fields.")
    view.queue_free()
    await process_frame
    view = View.new()
    view.simulation = resumed
    root.add_child(view)
    await process_frame
    view.set_process(false)
    check(not view.los_armed and not view.los_panel.visible and view.los_preview.get_child_count() == 0, "Reopening resets transient probe instead of restoring a stale measurement.")
    view.queue_free()
    await process_frame
    # Real combat through completion: probe at every planning interval, compare
    # each tick to an unrendered twin, and capture real fire/report after clearing.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    var twin = Battle.new()
    twin.restore(combat.state)
    view = View.new()
    view.simulation = combat
    root.add_child(view)
    await process_frame
    view.set_process(false)
    var captured_shot := false
    for tick in range(400):
        if combat.state["phase"] == "finished": break
        if combat.state["phase"] == "planning":
            view.los_armed = true
            view.los_observer = view.selected
            view.los_point = Vector2(280,245)
            view._refresh()
            before = combat.state.duplicate(true)
            for repeat in range(5): view._refresh_los_probe()
            check(same(before,combat.state), "Repeated planning previews preserve the authoritative state.")
            twin.execute()
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
            check(not view.los_armed and not view.los_panel.visible and view.los_preview.get_child_count() == 0 and view.los_button.disabled, "Actual EXECUTE clears and disables the probe immediately.")
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and (combat.state["phase"] == "planning" or view._terrain_probe(Vector2(280,245)).is_empty()), "Execution cannot probe and retains exact twin state each tick.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(210,245),140)
            check(not view.los_label.visible and not view.combat_label.text.is_empty(), "Real firing has live feedback and no stale probe overlay.")
            await capture("los-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Complete real combat after planning probes has identical valid outcomes.")
    view._reset_camera()
    check(view.completed_report_panel.visible and view.los_button.disabled and not view.los_panel.visible, "Completed report cannot be obscured by a stale probe.")
    await capture("los-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: terrain-only clear/building/hill/posture/range probe, actual cursor/camera/cancel/selection input, hidden-information and RNG isolation, disk reopen, execution cleanup and complete twin combat outcomes.")
    quit(0 if failures.is_empty() else 1)
