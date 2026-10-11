extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func click(point: Vector2, button: int, shift: bool = false) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = button
    event.pressed = true
    event.shift_pressed = shift
    Input.parse_input_event(event)
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)

func drag_camera(point: Vector2, relative: Vector2, rotate: bool = false) -> void:
    var press := InputEventMouseButton.new()
    press.position = point
    press.global_position = point
    press.button_index = MOUSE_BUTTON_MIDDLE
    press.pressed = true
    Input.parse_input_event(press)
    var motion := InputEventMouseMotion.new()
    motion.position = point + relative
    motion.global_position = motion.position
    motion.relative = relative
    motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
    motion.shift_pressed = rotate
    Input.parse_input_event(motion)
    press.position = motion.position
    press.global_position = motion.position
    press.pressed = false
    Input.parse_input_event(press)

func _run() -> void:
    root.size = Vector2i(1280, 720)
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    var directory := "user://view_test_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    await process_frame
    await process_frame
    var view = game.tactical_view
    check(is_instance_valid(view), "Contact must automatically open the native 3D view.")
    if not is_instance_valid(view):
        quit(1)
        return
    check(view.actors.size() == 8 and view.viewport.own_world_3d, "3D world must contain both detachments in its own viewport.")
    check(view.execute_button.text == "EXECUTE 60 SECONDS", "Planning controls must be available.")
    for id in ["RU_S1", "RU_S2", "RU_S3", "RU_S4"]:
        check(not view.actors[id].visible and view.labels[id].text.is_empty(), "Initial unspotted enemies must have no visible actor or label.")
    check("0 enemy contacts" in view.summary_label.text and "Red" not in view.summary_label.text, "The live HUD must not reveal total enemy strength or enemy objective score.")
    var hidden_before: int = view.shot_cues.size()
    view._show_shot_events([{"type": "shot", "player_visible": false, "shooter": "RU_S1", "target": "UKR_S1"}])
    check(view.shot_cues.size() == hidden_before and view.observed_shot_events.is_empty(), "Unobserved shot events must not create cues or recorded visible endpoints.")
    click(Vector2(1110, 483), MOUSE_BUTTON_LEFT)
    await process_frame
    check(game.tactical_simulation.fire_mode("UKR_S1") == "hold" and "HOLD FIRE" in view.selection_label.text, "Actual HOLD FIRE input must set and display the selected squad's fire rule.")
    click(Vector2(1040, 483), MOUSE_BUTTON_LEFT)
    await process_frame
    check(game.tactical_simulation.fire_mode("UKR_S1") == "auto", "Actual AUTO input must restore fire.")
    var intended := Vector3(210, Battle.terrain_height(210, 245), 245)
    var local: Vector2 = view.camera.unproject_position(intended)
    var hit: Vector2 = view._ground_point(local)
    check(hit.distance_to(Vector2(210, 245)) < 6, "Projected ground picking must agree with terrain coordinates.")
    var before_mode: Dictionary = game.tactical_simulation.state.duplicate(true)
    click(Vector2(1110, 449), MOUSE_BUTTON_LEFT)
    await process_frame
    check(view.command_mode == "quick" and same(before_mode, game.tactical_simulation.state), "Selecting QUICK must only change the next-command mode.")
    click(local + Vector2(24, 112), MOUSE_BUTTON_RIGHT)
    await process_frame
    check(game.tactical_simulation.state["orders"].has("UKR_S1"), "Actual viewport mouse input must issue a movement order.")
    check(game.tactical_simulation.movement_mode("UKR_S1") == "quick" and "Order: QUICK" in view.selection_label.text, "Actual map input must queue the selected mode and show it.")
    var ordered_state: Dictionary = game.tactical_simulation.state.duplicate(true)
    view._refresh()
    check(view.order_preview.get_child_count() >= 2, "Selected movement orders must draw a multi-dot route preview.")
    check(same(game.tactical_simulation.state, ordered_state), "Route preview rendering must not change authoritative tactical state.")
    var path_capture := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--path-capture="):
            path_capture = argument.trim_prefix("--path-capture=")
    var default_camera: Transform3D = view.camera.transform
    drag_camera(Vector2(710, 470), Vector2(-40, 20))
    await process_frame
    check(view.camera_focus.distance_to(Vector2(256, 256)) > 10, "Actual middle drag must pan the camera focus.")
    drag_camera(Vector2(710, 470), Vector2(65, -20), true)
    await process_frame
    check(absf(view.camera_yaw) > 0.1 and view.camera.transform != default_camera, "Actual Shift-middle drag must rotate the camera.")
    check(same(game.tactical_simulation.state, ordered_state), "Pan and rotation must leave the authoritative simulation unchanged.")
    var rotated_screen: Vector2 = view.camera.unproject_position(intended)
    check(view._ground_point(rotated_screen).distance_to(Vector2(210, 245)) < 6, "Ground picking must remain correct after pan and rotation.")
    game.tactical_simulation.order_hold("UKR_S1")
    click(rotated_screen + Vector2(24, 112), MOUSE_BUTTON_RIGHT)
    await process_frame
    check(game.tactical_simulation.state["orders"].has("UKR_S1"), "Movement commands must remain available from a rotated camera.")
    if not path_capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(path_capture.get_base_dir().path_join("camera-preview.png")) == OK, "Rendered pan/orbit preview must save.")
    var extreme := InputEventMouseMotion.new()
    extreme.button_mask = MOUSE_BUTTON_MASK_MIDDLE
    extreme.relative = Vector2(10000, 10000)
    extreme.shift_pressed = true
    view._map_input(extreme)
    check(view.camera_pitch <= deg_to_rad(75), "Orbit must clamp before a vertical or underground view.")
    extreme.shift_pressed = false
    view._map_input(extreme)
    check(view.camera_focus.x >= 32 and view.camera_focus.y >= 32 and view.camera_focus.x <= Battle.SIZE - 32 and view.camera_focus.y <= Battle.SIZE - 32, "Panning must keep the focus on the battlefield.")
    click(Vector2(860, 85), MOUSE_BUTTON_LEFT)
    await process_frame
    check(view.camera.transform.is_equal_approx(default_camera) and is_equal_approx(view.camera.fov, 52), "Reset-camera button must restore the original overview.")
    click(Vector2(1190, 449), MOUSE_BUTTON_LEFT)
    await process_frame
    click(view.camera.unproject_position(intended) + Vector2(24, 112), MOUSE_BUTTON_RIGHT)
    await process_frame
    check(game.tactical_simulation.movement_mode("UKR_S1") == "hunt" and "Order: HUNT" in view.selection_label.text, "HUNT button plus map click must replace the queued mode.")
    if not path_capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        var path_image := root.get_texture().get_image()
        check(path_image.save_png(path_capture) == OK, "Rendered route preview must save.")
    var queued_prefix: Array = game.tactical_simulation.state["orders"]["UKR_S1"].duplicate(true)
    var queued_point := Vector3(320, Battle.terrain_height(320, 300), 300)
    click(view.camera.unproject_position(queued_point) + Vector2(24, 112), MOUSE_BUTTON_RIGHT, true)
    await process_frame
    var queued_path: Array = game.tactical_simulation.state["orders"]["UKR_S1"]
    check(queued_path.size() > queued_prefix.size() and same(queued_path.slice(0, queued_prefix.size()), queued_prefix) and game.tactical_simulation.movement_mode("UKR_S1") == "hunt", "Actual Shift-right input must append from the queued endpoint while preserving the route and mode.")
    if not path_capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(path_capture.get_base_dir().path_join("queued-waypoints-preview.png")) == OK, "Queued-route capture must save.")
    var planning_checkpoint: Dictionary = game.tactical_simulation.state.duplicate(true)
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    view._refresh()
    var contact_screen: Vector2 = view.camera.unproject_position(view.actors["RU_S1"].position)
    click(contact_screen + Vector2(24, 112), MOUSE_BUTTON_LEFT, true)
    await process_frame
    check(game.tactical_simulation.state["fire_targets"]["UKR_S1"] == "RU_S1" and "Focus: ready" in view.report_label.text, "Actual Shift-click must set an eligible observed preferred target.")
    click(Vector2(1190, 483), MOUSE_BUTTON_LEFT)
    await process_frame
    check(game.tactical_simulation.state["fire_targets"]["UKR_S1"] == "", "Clear-target button must reset preference.")
    click(contact_screen + Vector2(24, 112), MOUSE_BUTTON_LEFT, true)
    await process_frame
    game.tactical_simulation.restore(planning_checkpoint)
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    game.tactical_simulation.order_target("UKR_S1", "RU_S1")
    view._refresh()
    # Button and execution must carry the same scene/model instance through a checkpoint.
    view._execute()
    for button in view.movement_buttons.values() + view.fire_buttons.values():
        check(button.disabled, "Movement-mode controls must freeze during execution.")
    check(view.execute_button.disabled and view.back_button.disabled, "Execution must freeze turn/back controls.")
    check(view.order_preview.get_child_count() == 0, "Route preview must clear when execution begins.")
    view.set_process(false)
    var executing_state: Dictionary = game.tactical_simulation.state.duplicate(true)
    drag_camera(Vector2(710, 470), Vector2(-30, 0))
    await process_frame
    check(view.camera_focus != Vector2(256, 256) and same(game.tactical_simulation.state, executing_state), "Camera navigation during execution must not advance or change simulation state.")
    view._reset_camera()
    # Put one opposing pair in close, unobstructed range. Advance only until an
    # actual casualty occurs so the rendered execution fixture shows personnel,
    # ammunition and suppression feedback together with real shot cues.
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
    game.tactical_simulation.squad_by_id("RU_S4")["position"] = [470, 470]
    # A separate high-pressure survivor exercises the pinned HUD alongside the
    # real-shot/casualty fixture. Incoming-fire pinning is tested in suppression_smoke.
    game.tactical_simulation.squad_by_id("UKR_S2")["suppression"] = 1.0
    view.selected = "UKR_S2"
    var starting_personnel: int = game.tactical_simulation.alive("UKR") + game.tactical_simulation.alive("RU")
    var executed_ticks := 0
    while executed_ticks < 30 and game.tactical_simulation.alive("UKR") + game.tactical_simulation.alive("RU") == starting_personnel:
        var before: Dictionary = view._status_snapshot()
        game.tactical_simulation.step()
        var tick_events: Array = game.tactical_simulation.consume_events()
        view._show_shot_events(tick_events)
        view._show_combat_changes(before)
        executed_ticks += 1
    view._refresh()
    check("PINNED" in view.selection_label.text and "PINNED" in view.squad_buttons["UKR_S2"].text and "PINNED" in view.labels["UKR_S2"].text, "Pinned status must be visible in selection, roster and world labels.")
    check(view.actors["RU_S1"].visible and view.labels["RU_S1"].text == "ENEMY CONTACT", "Acquired enemies must show a contact label without exact personnel/ammunition/status.")
    check(not view.actors["RU_S4"].visible and view.labels["RU_S4"].text.is_empty() and not view.markers["RU_S4"].visible, "Unspotted enemies must remain hidden during actual execution.")
    check("RU" not in view.combat_label.text, "Live feedback must not reveal exact enemy casualty/ammunition/suppression changes.")
    check(game.tactical_simulation.alive("UKR") + game.tactical_simulation.alive("RU") < starting_personnel, "Rendered feedback fixture must reach an actual simulated casualty.")
    check(not view.shot_cues.is_empty(), "Actual firing events must create visible transient cues for eligible shooters.")
    check("P" in view.combat_label.text and "R" in view.combat_label.text and "SUP" in view.combat_label.text, "Live combat feedback must identify personnel, ammunition and suppression changes.")
    check("P" in view.labels["UKR_S1"].text and "R" in view.labels["UKR_S1"].text and "SUP" in view.labels["UKR_S1"].text, "World labels must expose current personnel, ammunition and suppression.")
    var capture := ""
    var report_capture := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):
            capture = argument.trim_prefix("--capture=")
        elif argument.begins_with("--report-capture="):
            report_capture = argument.trim_prefix("--report-capture=")
    if not capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        var image := root.get_texture().get_image()
        var terrain_pixels := 0
        for y in range(112, 684, 4):
            for x in range(24, 944, 4):
                var color := image.get_pixel(x, y)
                if color.g > color.r * 1.03 and color.g > color.b * 1.15:
                    terrain_pixels += 1
        check(terrain_pixels > 2500, "Rendered ground must occupy a substantial visible area, not just trees against a blank viewport.")
        var background := image.get_pixel(10, 100)
        check(background.r < 0.15 and background.g < 0.2, "The battle canvas must cover the campaign viewport.")
        check(game.tactical_simulation.state["phase"] == "execution" and not view.observed_shot_events.is_empty(), "Rendered execution must contain an actual observed shot event.")
        check(image.save_png(capture) == OK, "Rendered preview must save.")
    view.selected = "UKR_S1"
    view._refresh()
    check("Order: HUNT PAUSED" in view.selection_label.text, "A locally observed enemy must produce readable HUNT PAUSED feedback.")
    if not capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(capture.get_base_dir().path_join("movement-orders-preview.png")) == OK, "HUNT execution preview must save.")
    view.selected = "UKR_S2"
    view._refresh()
    # The observed execution contact becomes stale without tracking hidden motion.
    var memory_checkpoint: Dictionary = game.tactical_simulation.state.duplicate(true)
    var remembered: Dictionary = memory_checkpoint["contacts"]["UKR"]["RU_S1"]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [470, 470]
    game.tactical_simulation.state["orders"].erase("RU_S1")
    game.tactical_simulation.state["movement_modes"].erase("RU_S1")
    game.tactical_simulation.step()
    view._age_shot_cues(1.0)
    view._refresh()
    check(not view.actors["RU_S1"].visible and view.contact_markers["RU_S1"].visible, "Lost contact must replace the hidden actor with an uncertain marker.")
    var ghost: Node3D = view.contact_markers["RU_S1"]
    check(ghost.position.x == remembered["position"][0] and ghost.position.z == remembered["position"][1] and "LAST SEEN" in view.contact_labels["RU_S1"].text, "Marker must show the saved location and observation age.")
    var memory_state: Dictionary = game.tactical_simulation.state.duplicate(true)
    view._refresh()
    check(same(memory_state, game.tactical_simulation.state), "Contact rendering must not mutate simulation state.")
    if not capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(capture.get_base_dir().path_join("contact-memory-preview.png")) == OK, "Lost-contact preview must save.")
    game.tactical_simulation.restore(memory_checkpoint)
    view._refresh()
    check(not view.contact_markers["RU_S1"].visible, "Current contact must hide its uncertain marker.")
    for index in range(60 - executed_ticks):
        game.tactical_simulation.step()
    view._refresh()
    view.checkpoint.emit()
    check(not view.back_button.disabled, "Planning or result controls must return after execution.")
    var selected_alive: int = game.tactical_simulation.squad_by_id("UKR_S1")["alive"]
    game.tactical_simulation.squad_by_id("UKR_S1")["alive"] = 0
    view.selected = "UKR_S1"
    view._refresh()
    check(view.squad_buttons["UKR_S1"].disabled and view.hold_button.disabled, "Dead squads must be visibly disabled and unable to receive orders.")
    for button in view.movement_buttons.values() + view.fire_buttons.values():
        check(button.disabled, "Dead squads must have disabled movement-mode controls.")
    game.tactical_simulation.squad_by_id("UKR_S1")["alive"] = selected_alive
    view._refresh()
    view._back()
    check(not is_instance_valid(game.tactical_view), "Save/back must restore the campaign view.")
    check(not game.battle_payload.is_empty(), "Save/back must preserve the unresolved battle lock.")
    game._open_tactical_battle()
    check(is_instance_valid(game.tactical_view), "Pending battle must reopen without resetting the simulation.")
    view = game.tactical_view
    view.set_process(false)
    var guard := 0
    while game.tactical_simulation.state["phase"] != "finished" and guard < 500:
        if game.tactical_simulation.state["phase"] == "planning":
            for squad in game.tactical_simulation.state["squads"]:
                if squad["faction"] == "UKR" and int(squad["alive"]) > 0:
                    var lane := int(str(squad["id"]).right(1)) - 1
                    game.tactical_simulation.order_move(squad["id"], Vector2(242, 218 + lane * 24))
            game.tactical_simulation.execute()
        var before: Dictionary = view._status_snapshot()
        game.tactical_simulation.step()
        view._show_shot_events(game.tactical_simulation.consume_events())
        view._show_combat_changes(before)
        guard += 1
    view._refresh()
    var completed_result: Dictionary = game.tactical_simulation.result()
    check(not completed_result.is_empty() and view.completed_report_panel.visible, "A finished battle must display its completed report.")
    for phrase in ["DEPLOYED", "SURVIVING", "LOST", "OBJECTIVE CONTROL", "CAMPAIGN CONSEQUENCES", "commits once"]:
        check(phrase in view.completed_report_label.text, "Completed report must include %s." % phrase)
    for faction in ["UKR", "RU"]:
        var force: Dictionary = completed_result["forces"][faction]
        check(str(force["id"]) in view.completed_report_label.text, "Completed report must identify both campaign formations.")
    if not report_capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        var report_image := root.get_texture().get_image()
        check(report_image.save_png(report_capture) == OK, "Rendered completed report must save.")
    var completed_id := str(completed_result["battle_id"])
    view._back()
    check(not is_instance_valid(game.tactical_view) and game.battle_payload.is_empty(), "Apply must close the report and unlock the campaign.")
    check(game.resolved_battle_ids.count(completed_id) == 1 and same(game.last_battle_result, completed_result), "Apply must record the completed report exactly once.")
    var applied_snapshot: Dictionary = game._snapshot()
    check(not game._apply_tactical_result(completed_result)["ok"] and same(game._snapshot(), applied_snapshot), "A repeated report apply must be rejected without changing campaign state.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"], "Campaign must reload after applying the completed report.")
    check(resumed.battle_payload.is_empty() and not is_instance_valid(resumed.tactical_view), "Reload must resume the unlocked campaign without a stale report.")
    var resumed_snapshot: Dictionary = resumed._snapshot()
    check(not resumed._apply_tactical_result(completed_result)["ok"] and same(resumed._snapshot(), resumed_snapshot), "Reloaded campaign must reject the already applied report.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty():
        print("PASS: 3D view, projected picking, actual mouse orders, execution controls, checkpoint and reopen.")
    quit(0 if failures.is_empty() else 1)
