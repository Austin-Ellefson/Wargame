extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"COMBAT_ZOOM","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
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
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK, "Execution zoom capture saves.")
func open_view(sim: RefCounted) -> Control:
    var view = View.new()
    view.simulation = sim
    root.add_child(view)
    await process_frame
    view.set_process(false)
    return view
func inspection(view: Control, distance: float = 80.0) -> void:
    view.camera_focus = Vector2(374,244)
    view.camera_distance = distance
    view.camera_pitch = deg_to_rad(50)
    view.camera_yaw = 0
    view.camera.fov = 52
    view._update_camera()
func area_label(view: Control) -> Label3D:
    for child in view.area_preview.get_children():
        if child is Label3D: return child
    return null
func sizes(view: Control) -> Array:
    return [view.labels["UKR_S1"].pixel_size,view.labels["UKR_S1"].position.y,
        area_label(view).pixel_size,area_label(view).position.y,
        view.arc_preview.get_child(0).mesh.size.x,view._zoom_size(0.18,3.0),view._zoom_size(0.035,0.9)]
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1","UKR_S2","RU_S1"]: squad["alive"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [354,244]
    sim.squad_by_id("UKR_S2")["position"] = [32,32]
    sim.squad_by_id("RU_S1")["position"] = [394,244]
    sim.squad_by_id("UKR_S1")["ammo"] = 360
    check(sim.order_facing("UKR_S1",Vector2(394,244)) and sim.order_arc("UKR_S1",90) and sim.order_area_fire("UKR_S1",Vector2(394,244)), "Fictional close engagement has legal facing, arc and ground-fire orders.")
    var view = await open_view(sim)
    var original: Dictionary = sim.state.duplicate(true)
    # Distance is exercised directly because the existing wheel zoom changes FOV.
    # Actual wheel/button input below covers the supported user controls.
    for fov in [30.0,52.0,70.0]:
        var previous := 0.0
        for distance in [24.0,65.0,79.99,80.0,80.01,140.0,300.0,652.5,950.0]:
            inspection(view,distance)
            view.camera.fov = fov
            view._update_camera()
            var size: float = view.labels["UKR_S1"].pixel_size
            check(size >= 0.035-0.000001 and size <= 0.35+0.000001 and size >= previous, "World text stays bounded and monotonic throughout distance/FOV zoom.")
            previous = size
    inspection(view,79.99)
    var below: Array = sizes(view)
    inspection(view,80.01)
    var above: Array = sizes(view)
    for index in range(below.size()):
        check(absf(above[index]-below[index]) < 0.002, "Label/height/arc/muzzle/tracer has no 80 m size jump: %d" % index)
    check(same(original,sim.state), "Changing distance/FOV cannot advance planning, acquisition or saved rules.")
    # Actual INSPECT/RESET input preserves known endpoint sizes.
    click(view.inspect_button.get_global_rect().get_center())
    await process_frame
    check(view.camera_distance == 24 and is_equal_approx(view.labels["UKR_S1"].pixel_size,0.035), "Actual INSPECT input keeps the close-view text scale.")
    click(view.reset_camera_button.get_global_rect().get_center())
    await process_frame
    check(is_equal_approx(view.camera_distance,Vector2(520,394).length()) and is_equal_approx(view.labels["UKR_S1"].pixel_size,0.35), "Actual RESET input preserves the default overview scale.")
    inspection(view)
    var size_before: float = view.labels["UKR_S1"].pixel_size
    seed(91820)
    var first_random := randi()
    click(Vector2(700,460),MOUSE_BUTTON_WHEEL_UP)
    await process_frame
    check(view.camera.fov == 49 and view.camera_distance == 80 and view.labels["UKR_S1"].pixel_size < size_before and area_label(view).pixel_size < size_before, "Actual wheel input immediately resizes existing squad/area text while keeping the FOV zoom contract.")
    for index in range(20):
        click(Vector2(700,460),MOUSE_BUTTON_WHEEL_UP)
        await process_frame
    check(view.camera.fov == 30, "Actual wheel zoom respects the narrow FOV bound.")
    for index in range(20):
        click(Vector2(700,460),MOUSE_BUTTON_WHEEL_DOWN)
        await process_frame
    check(view.camera.fov == 70 and same(original,sim.state), "Actual wheel zoom respects the wide FOV bound without changing authoritative state.")
    var second_random := randi()
    seed(91820)
    check(first_random == randi() and second_random == randi(), "Camera scaling consumes no global random samples.")
    inspection(view)
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]: sim.state["command_remaining"][id] = 0
    var twin = Battle.new()
    twin.restore(sim.state)
    for speed in [1.0,4.0,8.0]:
        while view.speed != speed:
            click(view.speed_button.get_global_rect().get_center())
            await process_frame
        for tick in range(3):
            twin.step()
            view._process(1.0/speed)
            check(same(sim.state,twin.state), "Actual playback with zoom retains each complete authoritative tick at %dx." % speed)
        check(not view.shot_cues.is_empty() and view.actors["RU_S1"].visible, "Actual acquired ground-fire volley creates a visible shot at %dx." % speed)
        if view.shot_cues.is_empty(): continue
        var cue: Dictionary = view.shot_cues.back()
        var node: Node3D = cue["node"]
        var flash: SphereMesh = node.get_child(0).mesh
        var trail: BoxMesh = node.get_child(1).mesh
        var radius: float = flash.radius
        var thickness: float = trail.size.x
        var length: float = trail.size.z
        var transform: Transform3D = node.get_child(1).transform
        var ttl: float = cue["ttl"]
        var event_count: int = view.observed_shot_events.size()
        var cue_count: int = view.shot_cues.size()
        var recoil: float = view.bodies["UKR_S1"][0].recoil_remaining
        original = sim.state.duplicate(true)
        print("ZOOM FIRE: speed=",speed," tick=",sim.state["elapsed"]," rounds=",sim.squad_by_id("UKR_S1")["ammo"]," radius=",radius," width=",thickness)
        await capture_frame("zoom-fire-%dx-preview" % speed)
        click(Vector2(700,460),MOUSE_BUTTON_WHEEL_DOWN)
        await process_frame
        check(flash.radius > radius and trail.size.x > thickness, "An existing live muzzle/tracer resizes immediately on actual wheel input.")
        click(Vector2(700,460),MOUSE_BUTTON_WHEEL_UP)
        await process_frame
        check(is_equal_approx(flash.radius,radius) and is_equal_approx(trail.size.x,thickness) and trail.size.z == length and node.get_child(1).transform == transform, "Reversing zoom restores widths without changing shot endpoints/direction/length.")
        check(view.shot_cues.size() == cue_count and cue["node"] == node and cue["ttl"] == ttl and ttl == 0.42 and view.observed_shot_events.size() == event_count and view.bodies["UKR_S1"][0].recoil_remaining == recoil and same(original,sim.state), "Camera resizing never recreates a shot, resets lifetime/recoil, samples combat RNG or changes state.")
        inspection(view,79.99)
        radius = flash.radius
        thickness = trail.size.x
        inspection(view,80.01)
        check(absf(flash.radius-radius) < 0.001 and absf(trail.size.x-thickness) < 0.001, "A real live shot also crosses 80 m continuously.")
        inspection(view)
        if speed == 4:
            for index in range(14):
                click(Vector2(700,460),MOUSE_BUTTON_WHEEL_UP)
                await process_frame
            await capture_frame("zoom-fire-narrow-preview")
            for index in range(14):
                click(Vector2(700,460),MOUSE_BUTTON_WHEEL_DOWN)
                await process_frame
            await capture_frame("zoom-fire-wide-preview")
            inspection(view)
        view._age_shot_cues(0.43)
        view._animate_soldiers(0.43)
        view._update_camera()
        check(view.shot_cues.is_empty() and not view.bodies["UKR_S1"][0].muzzle.visible and same(original,sim.state), "Shot cues expire normally at every speed and zoom never resurrects them.")
    # A real delivered report is display knowledge, not a live hidden location.
    view.selected = "UKR_S2"
    view._refresh()
    check(view.contact_markers.has("RU_S1") and view.contact_markers["RU_S1"].visible and not view.actors["RU_S1"].visible, "Switching to an unwitnessing squad shows an actual delayed report, not the live enemy.")
    if view.contact_markers.has("RU_S1"):
        var marker: Node3D = view.contact_markers["RU_S1"]
        var label: Label3D = view.contact_labels["RU_S1"]
        var remembered_position: Vector3 = marker.position
        sim.squad_by_id("RU_S1")["position"] = [490,490]
        original = sim.state.duplicate(true)
        view._refresh()
        inspection(view,79.99)
        var remembered_size := label.pixel_size
        inspection(view,80.01)
        check(absf(label.pixel_size-remembered_size) < 0.001 and label.pixel_size < 0.1 and marker.position == remembered_position and label.text.begins_with("? REPORT") and same(original,sim.state), "Remembered labels scale continuously without tracking hidden movement or rewriting saved knowledge.")
        await capture_frame("zoom-memory-preview")
        click(Vector2(700,460),MOUSE_BUTTON_WHEEL_DOWN)
        await process_frame
        check(not view.actors["RU_S1"].visible and view.shot_cues.is_empty() and marker.position == remembered_position, "Actual zoom cannot reveal hidden actors, new positions or unwitnessed shots.")
    view.queue_free()
    await process_frame
    # Full real combat, not just area fire: zoom through all speeds each tick.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    var combat_twin = Battle.new()
    combat_twin.restore(combat.state)
    var combat_view = await open_view(combat)
    for tick in range(400):
        if combat.state["phase"] == "finished": break
        for running in [combat,combat_twin]:
            if running.state["phase"] == "planning": running.execute()
        combat_view.camera_distance = [24.0,79.99,80.01,200.0,652.407847][tick % 5]
        combat_view.camera.fov = [30.0,52.0,70.0][tick % 3]
        combat_view._update_camera()
        combat_view.speed = [1.0,4.0,8.0][tick % 3]
        combat_twin.step()
        combat_view._process(1.0/combat_view.speed)
        check(same(combat.state,combat_twin.state), "Camera/geometry changes leave every complete real-combat tick unchanged.")
    check(combat.state["phase"] == "finished" and same(combat.result(),combat_twin.result()) and Battle.validate(combat.state,PAYLOAD), "Complete firing/casualty/objective results validate and match the unrendered twin exactly.")
    combat_view._reset_camera()
    check(combat_view.completed_report_panel.visible and combat_view.completed_report_label.text.contains("SURVIVING") and combat_view.completed_report_label.text.contains("CAMPAIGN CONSEQUENCES"), "Zoom leaves the completed two-sided report available.")
    await capture_frame("zoom-report-preview")
    combat_view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: continuous bounded distance/FOV sizes, actual wheel/inspect/reset input, live 1x/4x/8x shot resize/expiry, hidden-memory safety and complete real-combat/RNG isolation.")
    quit(0 if failures.is_empty() else 1)
