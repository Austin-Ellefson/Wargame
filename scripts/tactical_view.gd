extends Control
## Presentation and input only; simulation ticks are independent of frame rate.

signal checkpoint
signal leave_battle
signal commit_result(result: Dictionary)

const Battle = preload("res://scripts/tactical_battle.gd")
var simulation: RefCounted
var selected := "UKR_S1"
var speed := 4.0
var accumulator := 0.0
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var actors := {}
var labels := {}
var markers := {}
var shot_cues: Array = []
var observed_shot_events: Array = []
var phase_label: Label
var summary_label: Label
var selection_label: Label
var combat_label: Label
var report_label: Label
var execute_button: Button
var back_button: Button
var speed_button: Button
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
    _panel(Rect2(36, 126, 500, 116), Color(0.04, 0.08, 0.1, 0.88))
    combat_label = _label("LIVE COMBAT\nWaiting for contact...", Vector2(50, 138), 13, 472)
    _label("BLUE DETACHMENT", Vector2(986, 130), 13)
    summary_label = _label("", Vector2(986, 155), 16, 245)
    for index in range(4):
        var id := "UKR_S%d" % (index + 1)
        var button := _button("", Rect2(986, 212 + index * 38, 248, 32), func():
            selected = id
            _refresh())
        button.add_theme_font_size_override("font_size", 13)
        squad_buttons[id] = button
    selection_label = _label("", Vector2(986, 374), 14, 244)
    hold_button = _button("HOLD POSITION", Rect2(986, 426, 248, 32), func():
        simulation.order_hold(selected)
        _refresh())
    execute_button = _button("EXECUTE 60 SECONDS", Rect2(986, 470, 248, 44), _execute)
    speed_button = _button("PLAYBACK 4x", Rect2(986, 524, 248, 32), func():
        speed = 8.0 if speed == 4.0 else 4.0
        speed_button.text = "PLAYBACK %dx" % int(speed))
    back_button = _button("SAVE & CAMPAIGN", Rect2(986, 566, 248, 38), _back)
    report_label = _label("", Vector2(986, 615), 13, 244)
    _label("Left-click a blue squad  /  Right-click ground to move  /  Wheel to zoom", Vector2(24, 691), 14)

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
        for offset in [Vector3(-4, 0, 2), Vector3(0, 0, -3), Vector3(4, 0, 2)]:
            var body := CapsuleMesh.new()
            body.radius = 1.8
            body.height = 6
            _mesh(body, offset + Vector3(0, 3, 0), _material(color), actor)
        var label := Label3D.new()
        label.font_size = 34
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

func _map_input(event: InputEvent) -> void:
    if not event is InputEventMouseButton or not event.pressed:
        return
    if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
        camera.fov = clampf(camera.fov + (-3 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3), 30, 70)
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
        if target.x >= 0 and simulation.order_move(selected, target):
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
    if simulation == null or simulation.state["phase"] != "execution":
        return
    accumulator += delta * speed
    while accumulator >= 1.0 and simulation.state["phase"] == "execution":
        var before := _status_snapshot()
        simulation.step()
        _show_shot_events(simulation.consume_events())
        _show_combat_changes(before)
        accumulator -= 1.0
    _refresh()
    if simulation.state["phase"] != "execution":
        checkpoint.emit()

func _show_shot_events(events: Array) -> void:
    for event in events:
        if event.get("type") != "shot":
            continue
        observed_shot_events.append(event.duplicate(true))
        if observed_shot_events.size() > 64:
            observed_shot_events.pop_front()
        var start := Vector2(float(event["from"][0]), float(event["from"][1]))
        var finish := Vector2(float(event["to"][0]), float(event["to"][1]))
        var start_3d := Vector3(start.x, Battle.terrain_height(start.x, start.y) + 7.0, start.y)
        var finish_3d := Vector3(finish.x, Battle.terrain_height(finish.x, finish.y) + 5.0, finish.y)
        var cue := Node3D.new()
        world.add_child(cue)
        var flash := SphereMesh.new()
        flash.radius = 3.0
        flash.height = 6.0
        _mesh(flash, start_3d, _shot_material(Color("fff2a8")), cue)
        var trail := BoxMesh.new()
        trail.size = Vector3(0.9, 0.9, start_3d.distance_to(finish_3d))
        var tracer := _mesh(trail, (start_3d + finish_3d) * 0.5, _shot_material(Color("ffb43b")), cue)
        tracer.look_at(finish_3d, Vector3.UP)
        shot_cues.append({"node": cue, "ttl": 0.42})

func _status_snapshot() -> Dictionary:
    var snapshot := {}
    for squad in simulation.state["squads"]:
        snapshot[squad["id"]] = {"alive": int(squad["alive"]), "ammo": int(squad["ammo"]),
            "suppression": int(round(float(squad["suppression"]) * 100.0))}
    return snapshot

func _show_combat_changes(before: Dictionary) -> void:
    var casualty_lines: Array[String] = []
    var other_lines: Array[String] = []
    for squad in simulation.state["squads"]:
        var previous: Dictionary = before.get(squad["id"], {})
        if previous.is_empty():
            continue
        var personnel_change := int(previous["alive"]) - int(squad["alive"])
        var ammunition_change := int(previous["ammo"]) - int(squad["ammo"])
        var suppression_change := int(round(float(squad["suppression"]) * 100.0)) - int(previous["suppression"])
        if personnel_change <= 0 and ammunition_change <= 0 and suppression_change <= 0:
            continue
        var changes: Array[String] = []
        if personnel_change > 0:
            changes.append("-%dP" % personnel_change)
        if ammunition_change > 0:
            changes.append("-%dR" % ammunition_change)
        if suppression_change > 0:
            changes.append("SUP+%d" % suppression_change)
        var line := "%s  %s" % [str(squad["id"]).replace("_", " "), "  ".join(changes)]
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
        if shot_cues[index]["ttl"] <= 0:
            var node: Node = shot_cues[index]["node"]
            if is_instance_valid(node):
                node.queue_free()
            shot_cues.remove_at(index)

func _back() -> void:
    if simulation.state["phase"] == "finished":
        commit_result.emit(simulation.result())
    elif simulation.state["phase"] == "planning":
        leave_battle.emit()

func _refresh() -> void:
    var state: Dictionary = simulation.state
    phase_label.text = "%s  |  %02d:%02d elapsed  |  512 x 512 m generated test terrain" % [str(state["phase"]).to_upper(), int(state["elapsed"]) / 60, int(state["elapsed"]) % 60]
    summary_label.text = "Blue %d / Red %d personnel\nObjective control: %d / %d seconds" % [simulation.alive("UKR"), simulation.alive("RU"), state["objective"]["UKR"], state["objective"]["RU"]]
    for id in squad_buttons:
        var squad: Dictionary = simulation.squad_by_id(id)
        squad_buttons[id].disabled = squad.is_empty() or int(squad.get("alive", 0)) == 0
        squad_buttons[id].text = "S%s  %dP  %dR  SUP%d%%%s" % [str(id).right(1), int(squad.get("alive", 0)), int(squad.get("ammo", 0)), int(float(squad.get("suppression", 0)) * 100), "  <" if id == selected else ""]
    var selected_squad: Dictionary = simulation.squad_by_id(selected)
    if not selected_squad.is_empty():
        selection_label.text = "Squad %s  |  %d rounds\nSuppression %d%%  /  Morale %d" % [selected.right(1), selected_squad["ammo"], int(float(selected_squad["suppression"]) * 100), selected_squad["morale"]]
    hold_button.disabled = state["phase"] != "planning" or selected_squad.is_empty() or int(selected_squad.get("alive", 0)) <= 0
    execute_button.disabled = state["phase"] != "planning"
    execute_button.text = "%d SECONDS REMAINING" % state["remaining"] if state["phase"] == "execution" else "EXECUTE 60 SECONDS"
    back_button.disabled = state["phase"] == "execution"
    back_button.text = "APPLY & CAMPAIGN" if state["phase"] == "finished" else "SAVE & CAMPAIGN"
    report_label.text = "Capture the gold circle. Fire is automatic when enemies are visible and in range. Six intervals maximum."
    if state["phase"] == "finished":
        var result: Dictionary = simulation.result()
        report_label.text = "%s result. Losses: blue %d / red %d. Apply to resume the campaign." % [str(state["winner"]).to_upper(), result["forces"]["UKR"]["losses"], result["forces"]["RU"]["losses"]]
    for squad in state["squads"]:
        var point: Vector2 = Battle.position(squad)
        actors[squad["id"]].position = Vector3(point.x, Battle.terrain_height(point.x, point.y), point.y)
        actors[squad["id"]].visible = int(squad["alive"]) > 0
        labels[squad["id"]].text = "%s | %dP | %dR | SUP%d%%%s" % [str(squad["id"]).replace("_", " "), squad["alive"], squad["ammo"], int(float(squad["suppression"]) * 100), " *" if squad["id"] == selected else ""]
        var path: Array = state["orders"].get(squad["id"], [])
        markers[squad["id"]].visible = not path.is_empty() and squad["faction"] == "UKR" and state["phase"] == "planning"
        if not path.is_empty():
            var target := Vector2(path.back()[0], path.back()[1])
            markers[squad["id"]].position = Vector3(target.x, Battle.terrain_height(target.x, target.y) + 0.7, target.y)
