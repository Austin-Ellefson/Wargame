extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

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
    var intended := Vector3(210, Battle.terrain_height(210, 245), 245)
    var local: Vector2 = view.camera.unproject_position(intended)
    var hit: Vector2 = view._ground_point(local)
    check(hit.distance_to(Vector2(210, 245)) < 6, "Projected ground picking must agree with terrain coordinates.")
    click(local + Vector2(24, 112), MOUSE_BUTTON_RIGHT)
    await process_frame
    check(game.tactical_simulation.state["orders"].has("UKR_S1"), "Actual viewport mouse input must issue a movement order.")
    # Button and execution must carry the same scene/model instance through a checkpoint.
    view._execute()
    check(view.execute_button.disabled and view.back_button.disabled, "Execution must freeze turn/back controls.")
    view.set_process(false)
    # Put one opposing pair in close, unobstructed range. Advance only until an
    # actual casualty occurs so the rendered execution fixture shows personnel,
    # ammunition and suppression feedback together with real shot cues.
    game.tactical_simulation.squad_by_id("UKR_S1")["position"] = [180, 245]
    game.tactical_simulation.squad_by_id("RU_S1")["position"] = [240, 245]
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
    check(game.tactical_simulation.alive("UKR") + game.tactical_simulation.alive("RU") < starting_personnel, "Rendered feedback fixture must reach an actual simulated casualty.")
    check(not view.shot_cues.is_empty(), "Actual firing events must create visible transient cues for eligible shooters.")
    check("P" in view.combat_label.text and "R" in view.combat_label.text and "SUP" in view.combat_label.text, "Live combat feedback must identify personnel, ammunition and suppression changes.")
    check("P" in view.labels["UKR_S1"].text and "R" in view.labels["UKR_S1"].text and "SUP" in view.labels["UKR_S1"].text, "World labels must expose current personnel, ammunition and suppression.")
    var capture := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):
            capture = argument.trim_prefix("--capture=")
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
    for index in range(60 - executed_ticks):
        game.tactical_simulation.step()
    view._refresh()
    view.checkpoint.emit()
    check(not view.back_button.disabled, "Planning or result controls must return after execution.")
    game.tactical_simulation.squad_by_id("UKR_S1")["alive"] = 0
    view.selected = "UKR_S1"
    view._refresh()
    check(view.squad_buttons["UKR_S1"].disabled and view.hold_button.disabled, "Dead squads must be visibly disabled and unable to receive orders.")
    view._back()
    check(not is_instance_valid(game.tactical_view), "Save/back must restore the campaign view.")
    check(not game.battle_payload.is_empty(), "Save/back must preserve the unresolved battle lock.")
    game._open_tactical_battle()
    check(is_instance_valid(game.tactical_view), "Pending battle must reopen without resetting the simulation.")
    game.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty():
        print("PASS: 3D view, projected picking, actual mouse orders, execution controls, checkpoint and reopen.")
    quit(0 if failures.is_empty() else 1)
