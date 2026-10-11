extends Control
## Presentation and input only; simulation ticks are independent of frame rate.

signal checkpoint
signal leave_battle
signal commit_result(result: Dictionary)

const Soldier = preload("res://scripts/soldier_visual.gd")
const Battle = preload("res://scripts/tactical_battle.gd")
var simulation: RefCounted
var selected := "UKR_S1"
var speed := 4.0
var accumulator := 0.0
var viewport: SubViewport
var camera: Camera3D
var camera_focus := Vector2(256, 256)
var camera_yaw := 0.0
var camera_pitch := atan2(520.0, 394.0)
var camera_distance := Vector2(520, 394).length()
var inspect_button: Button
var reset_camera_button: Button
var world: Node3D
var actors := {}
var motions := {}
var labels := {}
var markers := {}
var contact_markers := {}
var contact_labels := {}
var order_preview: Node3D
var shot_cues: Array = []
var observed_shot_events: Array = []
var phase_label: Label
var summary_label: Label
var selection_label: Label
var combat_panel: Panel
var combat_label: Label
var completed_report_panel: Panel
var completed_report_label: Label
var report_label: Label
var execute_button: Button
var back_button: Button
var speed_button: Button
var pause_button: Button
var clear_target_button: Button
var fire_buttons := {}
var movement_buttons := {}
var posture_buttons := {}
var bodies := {}
var command_mode := "move"
var hold_button: Button
var squad_buttons := {}

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # The campaign parent is Node2D; give this fixed-design canvas an explicit size.
    size = Vector2(1280, 720)
    _build_interface()
    _build_world()
    _refresh()

func _panel(rect: Rect2, color: Color) -> Panel:
    var panel := Panel.new()
    panel.position = rect.position
    panel.size = rect.size
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    return panel

func _label(text: String, point: Vector2, size_value: int = 16, width: float = 0) -> Label:
    var label := Label.new()
    label.text = text
    label.position = point
    label.add_theme_font_size_override("font_size", size_value)
    label.add_theme_color_override("font_color", Color("d8e4e8"))
    if width > 0:
        label.size.x = width
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(label)
    return label

func _button(text: String, rect: Rect2, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.position = rect.position
    button.size = rect.size
    button.add_theme_font_size_override("font_size", 15)
    button.pressed.connect(action)
    add_child(button)
    return button

func _build_interface() -> void:
    var background := ColorRect.new()
    background.color = Color("101b22")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    _label("TACTICAL ENGAGEMENT", Vector2(24, 16), 13)
    _label(str(simulation.state["battle_id"]) + "  /  INFANTRY DETACHMENTS", Vector2(24, 36), 24)
    phase_label = _label("", Vector2(24, 70), 15)
    reset_camera_button = _button("RESET CAMERA", Rect2(776, 70, 168, 30), _reset_camera)
    _panel(Rect2(966, 112, 290, 572), Color("1a2b34"))
    var container := SubViewportContainer.new()
    container.position = Vector2(24, 112)
    container.size = Vector2(920, 572)
    container.stretch = true
    add_child(container)
    viewport = SubViewport.new()
    viewport.size = Vector2i(920, 572)
    viewport.own_world_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    container.add_child(viewport)
    container.gui_input.connect(_map_input)
    combat_panel = _panel(Rect2(36, 126, 500, 116), Color(0.04, 0.08, 0.1, 0.88))
    combat_label = _label("LIVE COMBAT\nWaiting for contact...", Vector2(50, 138), 13, 472)
    completed_report_panel = _panel(Rect2(150, 145, 670, 450), Color(0.04, 0.08, 0.1, 0.96))
    completed_report_label = _label("", Vector2(180, 167), 16, 610)
    completed_report_panel.visible = false
    completed_report_label.visible = false
    _label("BLUE DETACHMENT", Vector2(986, 130), 13)
    summary_label = _label("", Vector2(986, 155), 16, 245)
    for index in range(4):
        var id := "UKR_S%d" % (index + 1)
        var button := _button("", Rect2(986, 208 + index * 34, 248, 32), func():
            selected = id
            _refresh())
        button.add_theme_font_size_override("font_size", 13)
        squad_buttons[id] = button
    selection_label = _label("", Vector2(986, 350), 13, 244)
    selection_label.add_theme_constant_override("line_spacing", -2)
    for index in range(3):
        var value: String = ["stand", "crouch", "prone"][index]
        var button := _button(value.to_upper(), Rect2(986 + index * 84, 414, 80, 26), func():
            simulation.order_posture(selected, value)
            _refresh())
        button.add_theme_font_size_override("font_size", 12)
        button.tooltip_text = "Lower posture reduces speed, observation range and exposure. Changes immediately during planning."
        posture_buttons[value] = button
    for index in range(3):
        var mode: String = ["move", "quick", "hunt"][index]
        var button := _button(mode.to_upper(), Rect2(986 + index * 84, 444, 80, 26), func():
            command_mode = mode
            _refresh())
        button.add_theme_font_size_override("font_size", 12)
        button.tooltip_text = {"move": "2.4 m/s normal movement", "quick": "4 m/s before fatigue/posture/suppression; tires fastest", "hunt": "1.2 m/s; pauses on local contact or SUP >= 25%"}[mode]
        movement_buttons[mode] = button
    for index in range(2):
        var mode: String = ["auto", "hold"][index]
        var button := _button("", Rect2(986 + index * 84, 476, 80, 26), func():
            simulation.order_fire(selected, mode)
            _refresh())
        button.add_theme_font_size_override("font_size", 12)
        button.tooltip_text = "HOLD FIRE also withholds return fire; movement and spotting continue." if mode == "hold" else "Automatic fire at locally visible targets."
        fire_buttons[mode] = button
    clear_target_button = _button("CLEAR TARGET", Rect2(1154, 476, 80, 26), func():
        simulation.order_target(selected, "")
        _refresh())
    clear_target_button.add_theme_font_size_override("font_size", 10)
    hold_button = _button("HOLD POSITION", Rect2(986, 508, 122, 26), func():
        simulation.order_hold(selected)
        _refresh())
    pause_button = _button("PAUSE +15s", Rect2(1112, 508, 122, 26), func():
        var current := int(simulation.state["pause_remaining"].get(selected, 0))
        var following := 15 if current == 0 else (30 if current == 15 else (60 if current == 30 else 0))
        simulation.order_pause(selected, following)
        _refresh())
    pause_button.add_theme_font_size_override("font_size", 12)
    pause_button.tooltip_text = "Cycle 0/15/30/60 seconds. Delays movement only; firing continues."
    execute_button = _button("EXECUTE 60 SECONDS", Rect2(986, 540, 248, 32), _execute)
    speed_button = _button("PLAYBACK 4x", Rect2(986, 578, 248, 28), func():
        speed = {1.0: 4.0, 4.0: 8.0, 8.0: 1.0}[speed]
        speed_button.text = "PLAYBACK %dx" % int(speed))
    back_button = _button("SAVE & CAMPAIGN", Rect2(986, 614, 248, 30), _back)
    report_label = _label("", Vector2(986, 650), 12, 244)
    _label("Left: select  /  Right: move  /  Wheel: zoom  /  Middle-drag: pan  /  Shift + middle-drag: rotate", Vector2(24, 691), 13)

func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
    return material

func _mesh(mesh: Mesh, point: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = point
    instance.material_override = material
    (world if parent == null else parent).add_child(instance)
    return instance

func _build_world() -> void:
    world = Node3D.new()
    viewport.add_child(world)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color("a5bdc6")
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color("e3e4d4")
    environment.environment.ambient_light_energy = 0.8
    world.add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-65, -35, 0)
    sun.light_energy = 1.4
    world.add_child(sun)
    camera = Camera3D.new()
    camera.position = Vector3(256, 520, 650)
    camera.fov = 52
    camera.far = 2000
    world.add_child(camera)
    camera.look_at(Vector3(256, 0, 256))
    camera.current = true
    _update_camera()
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for z in range(64):
        for x in range(64):
            for offset in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
                var px: float = (x + offset.x) * Battle.CELL
                var pz: float = (z + offset.y) * Battle.CELL
                var color := Color("828e60").lerp(Color("b0a47b"), Battle.terrain_height(px, pz) / 6.0)
                if absf(pz - 256) < 8:
                    color = Color("a3a098")
                elif Battle.cover(Vector2(px, pz)) > 0.3:
                    color = Color("46634a")
                surface.set_color(color)
                var slope_x := (Battle.terrain_height(px + 0.5, pz) - Battle.terrain_height(px - 0.5, pz))
                var slope_z := (Battle.terrain_height(px, pz + 0.5) - Battle.terrain_height(px, pz - 0.5))
                surface.set_normal(Vector3(-slope_x, 1, -slope_z).normalized())
                surface.add_vertex(Vector3(px, Battle.terrain_height(px, pz), pz))
    var terrain_material := _material(Color.WHITE)
    terrain_material.vertex_color_use_as_albedo = true
    terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _mesh(surface.commit(), Vector3.ZERO, terrain_material)
    for building in Battle.BUILDINGS:
        var center: Vector2 = building.get_center()
        var box := BoxMesh.new()
        box.size = Vector3(building.size.x, 8, building.size.y)
        _mesh(box, Vector3(center.x, Battle.terrain_height(center.x, center.y) + 4, center.y), _material(Color("c1b69b")))
        var roof := PrismMesh.new()
        roof.size = Vector3(building.size.x + 2, 5, building.size.y + 2)
        _mesh(roof, Vector3(center.x, Battle.terrain_height(center.x, center.y) + 10, center.y), _material(Color("766254")))
    var random := RandomNumberGenerator.new()
    random.seed = 7331
    for wood in Battle.WOODS:
        for index in range(10):
            var angle := random.randf() * TAU
            var radius: float = random.randf() * (wood.z - 3)
            var point := Vector2(wood.x + cos(angle) * radius, wood.y + sin(angle) * radius)
            var tree := CylinderMesh.new()
            tree.top_radius = 0
            tree.bottom_radius = 5
            tree.height = 14
            _mesh(tree, Vector3(point.x, Battle.terrain_height(point.x, point.y) + 7, point.y), _material(Color("355346")))
    inspect_button = _button("INSPECT SQUAD", Rect2(594, 70, 170, 36), func():
        var squad: Dictionary = simulation.squad_by_id(selected)
        if not squad.is_empty():
            camera_focus = Battle.position(squad)
            camera_distance = 24.0
            camera_pitch = deg_to_rad(32)
            camera.fov = 52
            _update_camera()
            _refresh())
    var objective := CylinderMesh.new()
    objective.top_radius = 52
    objective.bottom_radius = 52
    objective.height = 0.2
    var objective_material := _material(Color(0.96, 0.76, 0.3, 0.23), true)
    objective_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mesh(objective, Vector3(256, Battle.terrain_height(256, 256) + 0.3, 256), objective_material)
    var pole := CylinderMesh.new()
    pole.top_radius = 0.6
    pole.bottom_radius = 0.6
    pole.height = 22
    _mesh(pole, Vector3(256, 11 + Battle.terrain_height(256, 256), 256), _material(Color("eee0a7")))
    var flag := BoxMesh.new()
    flag.size = Vector3(14, 8, 0.5)
    _mesh(flag, Vector3(263, 19 + Battle.terrain_height(256, 256), 256), _material(Color("eac568")))
    for squad in simulation.state["squads"]:
        var actor := Node3D.new()
        world.add_child(actor)
        actors[squad["id"]] = actor
        var color := Color("459ddb") if squad["faction"] == "UKR" else Color("c56556")
        bodies[squad["id"]] = []
        for index in range(int(squad["initial"])):
            var body := Soldier.new()
            actor.add_child(body)
            body.setup(color, simulation.weapon_role(squad["id"]) == "support" and index == 0)
            body.rotation.y = PI if squad["faction"] == "RU" else 0.0
            body.position = Vector3((index % 3 - 1) * 3.0, 0, (index / 3) * 3.0 - 3.0)
            bodies[squad["id"]].append(body)
        var label := Label3D.new()
        label.font_size = 28
        label.pixel_size = 0.35
        label.position = Vector3(0, 14, 0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        actor.add_child(label)
        labels[squad["id"]] = label
        var marker := CylinderMesh.new()
        marker.top_radius = 5
        marker.bottom_radius = 5
        marker.height = 0.4
        markers[squad["id"]] = _mesh(marker, Vector3.ZERO, _material(color, true))
    order_preview = Node3D.new()
    world.add_child(order_preview)

func _map_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
        if event.shift_pressed:
            camera_yaw = wrapf(camera_yaw - event.relative.x * 0.008, -PI, PI)
            camera_pitch = clampf(camera_pitch + event.relative.y * 0.006, deg_to_rad(25), deg_to_rad(75))
        else:
            var scale := 0.9 * (camera_distance / Vector2(520, 394).length()) * tan(deg_to_rad(camera.fov * 0.5)) / tan(deg_to_rad(26))
            var right := Vector2(cos(camera_yaw), -sin(camera_yaw))
            var forward := Vector2(-sin(camera_yaw), -cos(camera_yaw))
            camera_focus += (-right * event.relative.x + forward * event.relative.y) * scale
            camera_focus = camera_focus.clamp(Vector2(32, 32), Vector2(Battle.SIZE - 32, Battle.SIZE - 32))
        _update_camera()
        return
    if not event is InputEventMouseButton or not event.pressed:
        return
    if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        camera.fov = clampf(camera.fov + (-3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3), 30, 70)
        return
    if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed and simulation.state["phase"] == "planning" and int(simulation.state["version"]) >= 7:
        var best := 30.0
        var target_id := ""
        for squad in simulation.state["squads"]:
            if squad["faction"] == "UKR" or not _player_observes(squad) or int(squad["alive"]) <= 0:
                continue
            var distance := camera.unproject_position(actors[squad["id"]].position).distance_to(event.position)
            if distance < best:
                best = distance
                target_id = squad["id"]
        if not target_id.is_empty():
            simulation.order_target(selected, target_id)
        _refresh()
        return
    if event.button_index == MOUSE_BUTTON_LEFT:
        var best := 30.0
        for squad in simulation.state["squads"]:
            if squad["faction"] != "UKR" or int(squad["alive"]) <= 0:
                continue
            var point: Vector3 = actors[squad["id"]].position
            var distance := camera.unproject_position(point).distance_to(event.position)
            if distance < best:
                best = distance
                selected = squad["id"]
        _refresh()
    elif event.button_index == MOUSE_BUTTON_RIGHT and simulation.state["phase"] == "planning":
        var target := _ground_point(event.position)
        var mode: String = simulation.movement_mode(selected) if event.shift_pressed and simulation.state["orders"].has(selected) else command_mode
        if target.x >= 0 and simulation.order_move(selected, target, true, mode, event.shift_pressed):
            _refresh()

func _update_camera() -> void:
    var focus := Vector3(camera_focus.x, Battle.terrain_height(camera_focus.x, camera_focus.y), camera_focus.y)
    var horizontal := camera_distance * cos(camera_pitch)
    camera.position = focus + Vector3(sin(camera_yaw) * horizontal, camera_distance * sin(camera_pitch), cos(camera_yaw) * horizontal)
    camera.look_at(focus)

func _reset_camera() -> void:
    camera_focus = Vector2(256, 256)
    camera_yaw = 0
    camera_pitch = atan2(520.0, 394.0)
    camera.fov = 52
    camera_distance = Vector2(520, 394).length()
    _update_camera()
    _refresh()

func _ground_point(screen: Vector2) -> Vector2:
    var origin := camera.project_ray_origin(screen)
    var direction := camera.project_ray_normal(screen)
    for index in range(1, 501):
        var point := origin + direction * index * 4.0
        if point.x < 0 or point.x > Battle.SIZE or point.z < 0 or point.z > Battle.SIZE:
            continue
        if point.y <= Battle.terrain_height(point.x, point.z):
            return Vector2(point.x, point.z)
    return Vector2(-1, -1)

func _execute() -> void:
    if simulation.execute():
        accumulator = 0
        checkpoint.emit()
        _refresh()

func _process(delta: float) -> void:
    _age_shot_cues(delta)
    if simulation == null: return
    if simulation.state["phase"] != "execution":
        _animate_soldiers(delta)
        return
    accumulator += delta * speed
    while accumulator >= 1.0 and simulation.state["phase"] == "execution":
        var before := _status_snapshot()
        simulation.step()
        _show_shot_events(simulation.consume_events())
        _show_combat_changes(before)
        accumulator -= 1.0
    _refresh()
    _animate_soldiers(delta)
    if simulation.state["phase"] != "execution":
        checkpoint.emit()

func _show_shot_events(events: Array) -> void:
    for event in events:
        if event.get("type") != "shot":
            continue
        if simulation.limited_visibility() and not event.get("player_visible", false):
            continue
        if int(simulation.state["version"]) >= 18 and selected not in event.get("local_observers", []): continue
        observed_shot_events.append(event.duplicate(true))
        if observed_shot_events.size() > 64:
            observed_shot_events.pop_front()
        var start := Vector2(float(event["from"][0]), float(event["from"][1]))
        var finish := Vector2(float(event["to"][0]), float(event["to"][1]))
        var start_3d := Vector3(start.x, Battle.terrain_height(start.x, start.y) + 0.75 * simulation.posture_height(event["shooter"]), start.y)
        var finish_3d := Vector3(finish.x, Battle.terrain_height(finish.x, finish.y) + simulation.posture_height(event["target"]), finish.y)
        var heading := atan2(-(finish.x - start.x), -(finish.y - start.y))
        for body in bodies.get(event["shooter"], []):
            body.rotation.y = heading
            body.fire(event.get("local_observers", []))
            body.animate(0.0, false, 0.0)
        var cue := Node3D.new()
        world.add_child(cue)
        var flash := SphereMesh.new()
        var cue_radius := 0.18 if camera_distance < 80 else 3.0
        flash.radius = cue_radius
        flash.height = cue_radius * 2.0
        var support: bool = event.get("weapon_role", "rifle") == "support"
        _mesh(flash, start_3d, _shot_material(Color("ffcc8a") if support else Color("fff2a8")), cue)
        var trail := BoxMesh.new()
        trail.size = Vector3(0.035 if camera_distance < 80 else 0.9, 0.035 if camera_distance < 80 else 0.9, start_3d.distance_to(finish_3d))
        var tracer := _mesh(trail, (start_3d + finish_3d) * 0.5, _shot_material(Color("ffb43b")), cue)
        tracer.look_at(finish_3d, Vector3.UP)
        shot_cues.append({"node": cue, "ttl": 0.42, "local_observers": event.get("local_observers", []).duplicate()})

func _record_motion(squad: Dictionary, observed: bool) -> void:
    var id: String = squad["id"]
    if not observed:
        motions.erase(id)
        for body in bodies[id]: body.clear_shot()
        return
    var point: Vector2 = Battle.position(squad)
    var elapsed: int = simulation.state["elapsed"]
    var previous: Dictionary = motions.get(id, {})
    if previous.is_empty() or elapsed < int(previous["elapsed"]):
        if not previous.is_empty():
            for body in bodies[id]: body.clear_shot()
        motions[id] = {"point": point, "elapsed": elapsed, "moving": false, "phase": 0.0, "rate": 0.0, "heading": 0.0 if squad["faction"] == "UKR" else PI}
    elif elapsed != int(previous["elapsed"]):
        var travel: Vector2 = point - previous["point"]
        previous["moving"] = travel.length() > 0.0001
        previous["rate"] = travel.length() / maxi(1, elapsed - int(previous["elapsed"]))
        if previous["moving"]: previous["heading"] = atan2(-travel.x, -travel.y)
        previous["point"] = point
        previous["elapsed"] = elapsed
    if simulation.state["phase"] != "execution" or int(squad["alive"]) <= 0:
        motions[id]["moving"] = false

func _animate_soldiers(delta: float) -> void:
    for squad in simulation.state["squads"]:
        var id: String = squad["id"]
        var motion: Dictionary = motions.get(id, {})
        var moving: bool = not motion.is_empty() and motion["moving"] and simulation.state["phase"] == "execution" and actors[id].visible
        if moving: motion["phase"] += delta * speed * float(motion["rate"]) * 2.5
        for index in range(bodies[id].size()):
            var body: Node3D = bodies[id][index]
            if int(simulation.state["version"]) >= 18 and body.recoil_remaining > 0 and selected not in body.shot_witnesses:
                body.clear_shot()
            if not actors[id].visible: body.clear_shot()
            if moving and body.recoil_remaining <= 0: body.rotation.y = motion["heading"]
            body.animate(delta, moving, float(motion.get("phase", 0.0)) + index * 0.7)

func _status_snapshot() -> Dictionary:
    var snapshot := {}
    for squad in simulation.state["squads"]:
        snapshot[squad["id"]] = {"alive": int(squad["alive"]), "ammo": int(squad["ammo"]),
            "suppression": int(round(float(squad["suppression"]) * 100.0)), "status": simulation.combat_status(squad)}
    return snapshot

func _show_combat_changes(before: Dictionary) -> void:
    var casualty_lines: Array[String] = []
    var other_lines: Array[String] = []
    for squad in simulation.state["squads"]:
        if simulation.limited_visibility() and squad["faction"] != "UKR":
            continue
        var previous: Dictionary = before.get(squad["id"], {})
        if previous.is_empty():
            continue
        var personnel_change := int(previous["alive"]) - int(squad["alive"])
        var ammunition_change := int(previous["ammo"]) - int(squad["ammo"])
        var suppression_change := int(round(float(squad["suppression"]) * 100.0)) - int(previous["suppression"])
        var status: String = simulation.combat_status(squad)
        var status_changed: bool = status != previous.get("status", status)
        if personnel_change <= 0 and ammunition_change <= 0 and suppression_change <= 0 and not status_changed:
            continue
        var changes: Array[String] = []
        if personnel_change > 0:
            changes.append("-%dP" % personnel_change)
        if ammunition_change > 0:
            changes.append("-%dR" % ammunition_change)
        if suppression_change > 0:
            changes.append("SUP+%d" % suppression_change)
        if status_changed:
            changes.append(status)
        var line := "%s  %s" % [str(squad["id"]).replace("_", " "), "  ".join(changes)]
        if int(simulation.state["version"]) >= 15:
            line = "%s %s  %s" % [str(squad["id"]).replace("_", " "), "SUPPORT" if simulation.weapon_role(squad["id"]) == "support" else "RIFLE", "  ".join(changes)]
        if personnel_change > 0:
            casualty_lines.append(line)
        else:
            other_lines.append(line)
    var lines: Array[String] = casualty_lines + other_lines
    if not lines.is_empty():
        combat_label.text = "LATEST VOLLEY  •  P personnel  R rounds  SUP suppression\n" + "\n".join(lines.slice(0, 4))

func _shot_material(color: Color) -> StandardMaterial3D:
    var material := _material(color, true)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 3.5
    material.no_depth_test = true
    return material

func _age_shot_cues(delta: float) -> void:
    for index in range(shot_cues.size() - 1, -1, -1):
        shot_cues[index]["ttl"] = float(shot_cues[index]["ttl"]) - delta
        if shot_cues[index]["ttl"] <= 0 or (int(simulation.state["version"]) >= 18 and selected not in shot_cues[index]["local_observers"]):
            var node: Node = shot_cues[index]["node"]
            if is_instance_valid(node):
                node.queue_free()
            shot_cues.remove_at(index)

func _clear_order_preview() -> void:
    for child in order_preview.get_children():
        order_preview.remove_child(child)
        child.queue_free()

func _refresh_order_preview() -> void:
    _clear_order_preview()
    if simulation.state["phase"] != "planning":
        return
    var squad: Dictionary = simulation.squad_by_id(selected)
    var path: Array = simulation.state["orders"].get(selected, [])
    if squad.is_empty() or squad["faction"] != "UKR" or int(squad["alive"]) <= 0 or path.is_empty():
        return
    var material := _material(Color(0.28, 0.78, 1.0, 0.86), true)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var previous := Battle.position(squad)
    for waypoint in path:
        var finish := Vector2(float(waypoint[0]), float(waypoint[1]))
        var distance := previous.distance_to(finish)
        var dots := maxi(1, int(ceil(distance / 14.0)))
        for index in range(1, dots + 1):
            var point := previous.lerp(finish, float(index) / dots)
            var dot := CylinderMesh.new()
            dot.top_radius = 1.7
            dot.bottom_radius = 1.7
            dot.height = 0.25
            _mesh(dot, Vector3(point.x, Battle.terrain_height(point.x, point.y) + 0.8, point.y), material, order_preview)
        previous = finish

func _player_observes(squad: Dictionary) -> bool:
    if squad.is_empty(): return false
    if int(simulation.state["version"]) < 18: return simulation.is_observed("UKR", squad)
    return squad["faction"] == "UKR" or simulation.can_spot(simulation.squad_by_id(selected), squad)

func _player_contact_count() -> int:
    var count := 0
    for squad in simulation.state["squads"]:
        if squad["faction"] != "UKR" and _player_observes(squad): count += 1
    return count

func _refresh_contact_markers() -> void:
    for marker in contact_markers.values():
        marker.visible = false
    var contacts: Array = simulation.shared_reports("UKR", selected) if int(simulation.state["version"]) >= 18 else simulation.last_known_contacts("UKR")
    for contact in contacts:
        var id: String = contact["id"]
        if not contact_markers.has(id):
            var marker := Node3D.new()
            world.add_child(marker)
            contact_markers[id] = marker
            var disk := CylinderMesh.new()
            disk.top_radius = 6.0
            disk.bottom_radius = 6.0
            disk.height = 0.4
            _mesh(disk, Vector3.ZERO, _material(Color("e2b859"), true), marker)
            var label := Label3D.new()
            label.font_size = 40
            label.pixel_size = 0.5
            label.position = Vector3(0, 30, 0)
            label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            label.no_depth_test = true
            label.modulate = Color("ffe0a0")
            marker.add_child(label)
            contact_labels[id] = label
        var point := Vector2(float(contact["position"][0]), float(contact["position"][1]))
        contact_markers[id].position = Vector3(point.x, Battle.terrain_height(point.x, point.y) + 0.6, point.y)
        contact_markers[id].visible = true
        contact_labels[id].text = ("? REPORT %ds" if int(simulation.state["version"]) >= 18 else "? LAST SEEN %ds") % (int(simulation.state["elapsed"]) - int(contact["seen_at"]))

func _back() -> void:
    if simulation.state["phase"] == "finished":
        commit_result.emit(simulation.result())
    elif simulation.state["phase"] == "planning":
        leave_battle.emit()

func _supply_cost(force: Dictionary) -> int:
    return int(ceil(float(force["ammunition_used"]) / maxi(1, int(force["deployed"]) * Battle.ROUNDS_PER_PERSON) * 5.0))

func _battle_report(result: Dictionary) -> String:
    var blue: Dictionary = result["forces"]["UKR"]
    var red: Dictionary = result["forces"]["RU"]
    var blue_survivors := int(blue["deployed"]) - int(blue["losses"])
    var red_survivors := int(red["deployed"]) - int(red["losses"])
    var retreating := "UKR" if result["winner"] in ["RU", "draw"] else "RU"
    var retreat_force: Dictionary = result["forces"][retreating]
    var retreat_text := "%s withdraws to a legal origin/adjacent sector." % retreat_force["id"]
    if int(retreat_force["deployed"]) - int(retreat_force["losses"]) <= 0:
        retreat_text = "%s was eliminated; no withdrawal." % retreat_force["id"]
    return "BATTLE COMPLETE  •  %s\n%s  •  %02d:%02d elapsed\n\nFORCE             DEPLOYED     SURVIVING     LOST\nBLUE %-10s     %2d             %2d            %2d\nRED  %-10s     %2d             %2d            %2d\n\nOBJECTIVE CONTROL\nBlue %d seconds  •  Red %d seconds\n\nCAMPAIGN CONSEQUENCES ON APPLY\n%s: -%d personnel  •  morale cap %d  •  supply -%d\n%s: -%d personnel  •  morale cap %d  •  supply -%d\n%s\nResult commits once, autosaves, and unlocks campaign turns." % [str(result["winner"]).to_upper(), result["battle_id"], int(result["elapsed"]) / 60, int(result["elapsed"]) % 60, blue["id"], blue["deployed"], blue_survivors, blue["losses"], red["id"], red["deployed"], red_survivors, red["losses"], result["objective"]["UKR"], result["objective"]["RU"], blue["id"], blue["losses"], blue["morale"], _supply_cost(blue), red["id"], red["losses"], red["morale"], _supply_cost(red), retreat_text]

func _refresh() -> void:
    _age_shot_cues(0.0)
    var state: Dictionary = simulation.state
    phase_label.text = "%s  |  %02d:%02d elapsed  |  512 x 512 m generated test terrain" % [str(state["phase"]).to_upper(), int(state["elapsed"]) / 60, int(state["elapsed"]) % 60]
    summary_label.text = "Blue %dP / Red %dP\nObjective: %ds / %ds" % [simulation.alive("UKR"), simulation.alive("RU"), state["objective"]["UKR"], state["objective"]["RU"]]
    if simulation.limited_visibility() and state["phase"] != "finished":
        summary_label.text = "Blue %dP / %d enemy contacts\nYour objective: %ds" % [simulation.alive("UKR"), _player_contact_count(), state["objective"]["UKR"]]
    if int(state["version"]) >= 18 and state["phase"] != "finished":
        summary_label.text = "Blue %dP / S%s local %d\nReports %d / Your objective %ds" % [simulation.alive("UKR"), selected.right(1), _player_contact_count(), simulation.shared_reports("UKR", selected).size(), state["objective"]["UKR"]]
    summary_label.size = Vector2(245, 0)
    for id in squad_buttons:
        var squad: Dictionary = simulation.squad_by_id(id)
        squad_buttons[id].disabled = squad.is_empty() or int(squad.get("alive", 0)) == 0
        squad_buttons[id].text = "S%s  %dP  %dR  SUP%d%%%s" % [str(id).right(1), int(squad.get("alive", 0)), int(squad.get("ammo", 0)), int(float(squad.get("suppression", 0)) * 100), "  <" if id == selected else ""]
    var selected_squad: Dictionary = simulation.squad_by_id(selected)
    if not selected_squad.is_empty():
        selection_label.text = "S%s  |  %s\n%d rounds  /  Morale %d  /  SUP%d%%" % [selected.right(1), simulation.combat_status(selected_squad), selected_squad["ammo"], selected_squad["morale"], int(float(selected_squad["suppression"]) * 100)]
        if int(state["version"]) >= 12:
            selection_label.text = selection_label.text.replace("\n", " | FAT%d%%\n" % int(round(simulation.fatigue(selected) * 100)))
            selection_label.tooltip_text = "FAT: movement fatigue. QUICK tires fastest; fatigue reduces speed. Stationary execution seconds restore it. Planning time does not."
    if int(state["version"]) >= 15 and not selected_squad.is_empty() and int(selected_squad["alive"]) > 0:
        var role: String = simulation.weapon_role(selected)
        selection_label.text = selection_label.text.replace("S" + selected.right(1) + "  |", "S" + selected.right(1) + (" SUPPORT" if role == "support" else " RIFLE") + " |")
        selection_label.tooltip_text += "\nRIFLE: 1 round per survivor every 3s. SUPPORT: 2 per survivor every 2s, lower per-round hit chance; uses rounds faster. Both require local sight."
    if int(state["version"]) >= 5 and not selected_squad.is_empty():
        selection_label.text += "\nOrder: " + simulation.movement_status(selected_squad)
    if int(state["version"]) >= 14 and not selected_squad.is_empty():
        selection_label.text += " | " + simulation.posture(selected).to_upper()
    if int(state["version"]) >= 6 and not selected_squad.is_empty():
        selection_label.text += " | " + ("NO FIRE" if simulation.morale_state(selected) == "broken" else "HOLD FIRE" if simulation.fire_mode(selected) == "hold" else "AUTO")
    if int(state["version"]) >= 17:
        selection_label.tooltip_text += "\nNew movement orders wait 5 executed seconds; pauses count concurrently. Fire/spotting continue. Appending keeps the existing response timer; HOLD cancels it."
    if int(state["version"]) >= 18:
        selection_label.tooltip_text += "\nSelected squad local contacts are live. Amber REPORT markers arrive 5s after observation and never grant fire permission."
    clear_target_button.visible = int(state["version"]) >= 7
    clear_target_button.disabled = state["phase"] != "planning" or selected_squad.is_empty() or int(selected_squad.get("alive", 0)) <= 0 or simulation.morale_state(selected) == "broken"
    for mode in fire_buttons:
        fire_buttons[mode].visible = int(state["version"]) >= 6
        fire_buttons[mode].disabled = state["phase"] != "planning" or selected_squad.is_empty() or int(selected_squad.get("alive", 0)) <= 0 or simulation.morale_state(selected) == "broken"
        fire_buttons[mode].text = ("AUTO" if mode == "auto" else "HOLD FIRE") + (" *" if simulation.fire_mode(selected) == mode else "")
    for value in posture_buttons:
        posture_buttons[value].visible = int(state["version"]) >= 14
        posture_buttons[value].disabled = (state["phase"] != "planning" or selected_squad.is_empty() or int(selected_squad.get("alive", 0)) <= 0 or simulation.morale_state(selected) == "broken")
        posture_buttons[value].text = value.to_upper() + (" *" if simulation.posture(selected) == value else "")
    for mode in movement_buttons:
        movement_buttons[mode].visible = int(state["version"]) >= 5
        movement_buttons[mode].disabled = state["phase"] != "planning" or selected_squad.is_empty() or int(selected_squad.get("alive", 0)) <= 0 or simulation.morale_state(selected) == "broken"
        movement_buttons[mode].text = mode.to_upper() + (" *" if command_mode == mode else "")
    for id in squad_buttons:
        var squad: Dictionary = simulation.squad_by_id(id)
        if int(squad.get("alive", 0)) <= 0: continue
        if simulation.morale_state(id) == "broken":
            squad_buttons[id].text += " BROKEN"
        elif simulation.is_pinned(squad):
            squad_buttons[id].text += " PINNED"
        elif simulation.morale_state(id) != "steady": squad_buttons[id].text += " " + simulation.morale_state(id).to_upper()
    hold_button.disabled = state["phase"] != "planning" or selected_squad.is_empty() or int(selected_squad.get("alive", 0)) <= 0 or simulation.morale_state(selected) == "broken"
    pause_button.visible = int(state["version"]) >= 8
    pause_button.disabled = hold_button.disabled or not state["orders"].has(selected)
    pause_button.text = "PAUSE %ds" % int(state["pause_remaining"].get(selected, 0)) if int(state["version"]) >= 8 and int(state["pause_remaining"].get(selected, 0)) > 0 else "PAUSE +15s"
    execute_button.disabled = state["phase"] != "planning"
    execute_button.text = "%d SECONDS REMAINING" % state["remaining"] if state["phase"] == "execution" else "EXECUTE 60 SECONDS"
    back_button.disabled = state["phase"] == "execution"
    back_button.text = "APPLY & CAMPAIGN" if state["phase"] == "finished" else "SAVE & CAMPAIGN"
    combat_panel.visible = state["phase"] != "finished"
    combat_label.visible = state["phase"] != "finished"
    completed_report_panel.visible = state["phase"] == "finished"
    completed_report_label.visible = state["phase"] == "finished"
    report_label.text = "Capture the gold circle. Fire is automatic when enemies are visible and in range. Six intervals maximum."
    if simulation.limited_visibility():
        report_label.text = "Spot before firing. Woods conceal distant squads. Contacts show current sight."
    if int(state["version"]) >= 4:
        report_label.text = "Amber ? = last seen, not current. Woods conceal distant squads."
    if int(state["version"]) >= 5:
        report_label.text = "Mode + right-click. Amber = last seen."
    if int(state["version"]) >= 7:
        report_label.text = simulation.target_status(selected) + " | Shift-click target\nShift-right: append route"
    if not selected_squad.is_empty() and simulation.morale_state(selected) == "broken":
        report_label.text = "BROKEN: automatic withdrawal.\n30 quiet rear seconds to rally."
    if state["phase"] == "finished":
        var result: Dictionary = simulation.result()
        completed_report_label.text = _battle_report(result)
        report_label.text = "APPLY commits once and unlocks the campaign."
    _refresh_order_preview()
    _refresh_contact_markers()
    for squad in state["squads"]:
        var point: Vector2 = Battle.position(squad)
        actors[squad["id"]].position = Vector3(point.x, Battle.terrain_height(point.x, point.y), point.y)
        var value: String = simulation.posture(squad["id"])
        var observed: bool = state["phase"] == "finished" or _player_observes(squad)
        _record_motion(squad, observed)
        var known_losses: bool = squad["faction"] == "UKR" or state["phase"] == "finished"
        for index in range(bodies[squad["id"]].size()):
            var body: Node3D = bodies[squad["id"]][index]
            body.pose(value, known_losses and index >= int(squad["alive"]))
            body.position.y = Battle.terrain_height(point.x + body.position.x, point.y + body.position.z) - Battle.terrain_height(point.x, point.y)
        actors[squad["id"]].visible = observed and (int(squad["alive"]) > 0 or known_losses)
        labels[squad["id"]].position.y = 3.2 if camera_distance < 80 else 14.0
        labels[squad["id"]].pixel_size = 0.035 if camera_distance < 80 else 0.35
        labels[squad["id"]].text = "%s %dP %dR SUP%d%s" % [str(squad["id"]).replace("_", " "), squad["alive"], squad["ammo"], int(float(squad["suppression"]) * 100), " *" if squad["id"] == selected else ""]
        if simulation.morale_state(squad["id"]) == "broken":
            labels[squad["id"]].text += "\nBROKEN"
        elif simulation.is_pinned(squad):
            labels[squad["id"]].text += "\nPINNED"
        if simulation.limited_visibility() and squad["faction"] != "UKR" and state["phase"] != "finished":
            labels[squad["id"]].text = "ENEMY CONTACT" if observed and int(squad["alive"]) > 0 else ""
        var path: Array = state["orders"].get(squad["id"], [])
        markers[squad["id"]].visible = not path.is_empty() and squad["faction"] == "UKR" and state["phase"] == "planning"
        if not path.is_empty():
            var target := Vector2(path.back()[0], path.back()[1])
            markers[squad["id"]].position = Vector3(target.x, Battle.terrain_height(target.x, target.y) + 0.7, target.y)

    _animate_soldiers(0.0)
