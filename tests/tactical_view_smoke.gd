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
