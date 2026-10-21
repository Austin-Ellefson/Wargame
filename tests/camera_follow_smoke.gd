extends "res://tests/combat_zoom_smoke.gd"
# Reuse the battle/view/input/assertion helpers; this overrides the base test run.

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
    var release := press.duplicate()
    release.position = motion.position
    release.global_position = motion.position
    release.pressed = false
    Input.parse_input_event(release)

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    check(sim.order_move("UKR_S1",Vector2(230,245)), "Follow fixture queues a real movement order.")
    var view = await open_view(sim)
    var before: Dictionary = sim.state.duplicate(true)
    check(view.follow_target.is_empty() and view.follow_button.disabled and view.follow_button.text == "FOLLOW S1", "Follow starts empty and disabled during planning.")
    click(view.follow_button.get_global_rect().get_center())
    await process_frame
    check(view.follow_target.is_empty() and same(before,sim.state), "Disabled planning input cannot arm execution follow or change authority.")
    click(view.execute_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["phase"] == "execution" and not view.follow_button.disabled, "Actual EXECUTE input enables follow for the selected living friendly.")
    var waypoint := Vector2(sim.state["orders"]["UKR_S1"].back()[0],sim.state["orders"]["UKR_S1"].back()[1])
    before = sim.state.duplicate(true)
    seed(62031)
    var first_random := randi()
    click(view.follow_button.get_global_rect().get_center())
    await process_frame
    check(view.follow_target == "UKR_S1" and view.follow_button.text == "FOLLOWING S1", "Actual follow-button input arms the selected squad.")
    check(view.camera_focus == Battle.position(sim.squad_by_id("UKR_S1")) and view.camera_focus != waypoint, "Follow centers the real current squad, never its queued destination.")
    var second_random := randi()
    seed(62031)
    check(first_random == randi() and second_random == randi() and same(before,sim.state), "Arming follow consumes no RNG and changes no tactical state.")
    var twin = Battle.new()
    twin.restore(sim.state)
    var start := Battle.position(sim.squad_by_id("UKR_S1"))
    var captured_execution := false
    var tested_controls := false
    for tick in range(500):
        if sim.state["phase"] == "finished": break
        if sim.state["phase"] == "planning":
            twin.execute()
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
            if view._can_follow_selected():
                click(view.follow_button.get_global_rect().get_center())
                await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Every actual followed execution tick matches an unfollowed twin.")
        if not view.follow_target.is_empty():
            check(view.camera_focus == Battle.position(sim.squad_by_id(view.follow_target)), "Each refresh follows the squad's authoritative current position exactly.")
        if not tested_controls and Battle.position(sim.squad_by_id("UKR_S1")).distance_to(start) > 1.0 and not view.shot_cues.is_empty():
            check(view.follow_target == "UKR_S1" and view.camera_focus == Battle.position(sim.squad_by_id("UKR_S1")), "A real moving/firing frame remains centered on the actual squad.")
            await capture_frame("camera-follow-execution-preview")
            var cue: Dictionary = view.shot_cues.back()
            var cue_node: Node = cue["node"]
            var cue_ttl: float = cue["ttl"]
            before = sim.state.duplicate(true)
            var old_fov: float = view.camera.fov
            click(Vector2(700,460),MOUSE_BUTTON_WHEEL_DOWN)
            await process_frame
            check(view.follow_target == "UKR_S1" and view.camera.fov > old_fov and view.camera_focus == Battle.position(sim.squad_by_id("UKR_S1")), "Wheel zoom remains available while follow stays armed.")
            check(view.shot_cues.has(cue) and cue["node"] == cue_node and cue["ttl"] == cue_ttl and same(before,sim.state), "Follow zoom never recreates/ages a shot or changes authority.")
            var followed_point: Vector2 = view.camera_focus
            drag_camera(Vector2(700,460),Vector2(-35,18))
            await process_frame
            check(view.follow_target.is_empty() and view.camera_focus != followed_point and same(before,sim.state), "Actual middle-drag pan disengages follow and preserves free navigation/state.")
            click(view.follow_button.get_global_rect().get_center())
            await process_frame
            var old_yaw: float = view.camera_yaw
            drag_camera(Vector2(700,460),Vector2(45,-12),true)
            await process_frame
            check(view.follow_target.is_empty() and view.camera_yaw != old_yaw and same(before,sim.state), "Actual Shift-middle orbit disengages follow without changing combat.")
            click(view.follow_button.get_global_rect().get_center())
            await process_frame
            click(view.squad_buttons["UKR_S2"].get_global_rect().get_center())
            await process_frame
            check(view.selected == "UKR_S2" and view.follow_target.is_empty(), "Changing selection stops follow instead of silently transferring its target.")
            click(view.squad_buttons["UKR_S1"].get_global_rect().get_center())
            await process_frame
            click(view.follow_button.get_global_rect().get_center())
            await process_frame
            click(view.inspect_button.get_global_rect().get_center())
            await process_frame
            check(view.follow_target.is_empty() and view.camera_distance == 24.0 and view.camera_focus == Battle.position(sim.squad_by_id("UKR_S1")), "INSPECT stops follow and keeps its explicit close-view behavior.")
            click(view.follow_button.get_global_rect().get_center())
            await process_frame
            click(view.reset_camera_button.get_global_rect().get_center())
            await process_frame
            check(view.follow_target.is_empty() and view.camera_focus == Vector2(256,256) and is_equal_approx(view.camera_distance,Vector2(520,394).length()), "RESET stops follow and restores the exact overview.")
            click(view.follow_button.get_global_rect().get_center())
            await process_frame
            var live_snapshot: Dictionary = sim.state.duplicate(true)
            sim.squad_by_id("UKR_S1")["alive"] = 0
            view._refresh()
            check(view.follow_target.is_empty() and view.follow_button.disabled, "An eliminated selected squad cannot leave a stale follow target.")
            sim.restore(live_snapshot)
            view._refresh()
            check(not view.follow_button.disabled and same(live_snapshot,sim.state) and same(sim.state,twin.state), "Restoring the valid fixture after the lifecycle guard retains exact twin authority.")
            click(view.follow_button.get_global_rect().get_center())
            await process_frame
            var save_path := "user://camera_follow_%d.json" % Time.get_ticks_usec()
            var file := FileAccess.open(save_path,FileAccess.WRITE)
            file.store_string(JSON.stringify(sim.state))
            file.close()
            var restored = Battle.new()
            restored.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
            DirAccess.remove_absolute(save_path)
            check(same(restored.state,sim.state), "Authoritative execution state survives an actual disk round trip while follow is active.")
            view.queue_free()
            await process_frame
            sim = restored
            view = await open_view(sim)
            check(view.follow_target.is_empty() and view.camera_focus == Vector2(256,256) and view.follow_button.text == "FOLLOW S1", "Reopening restores no transient follow target or camera position.")
            check(same(sim.state,twin.state), "Reopening after follow preserves the exact authoritative twin state.")
            if view._can_follow_selected():
                click(view.follow_button.get_global_rect().get_center())
                await process_frame
            tested_controls = true
            captured_execution = true
    check(tested_controls and captured_execution, "Fixture produced an actual moving/firing followed frame for control and render validation.")
    check(sim.state["phase"] == "finished" and same(sim.result(),twin.result()) and Battle.validate(sim.state,PAYLOAD), "Follow completes with the same valid battle result as the unfollowed twin.")
    check(view.follow_target.is_empty() and view.follow_button.disabled and view.completed_report_panel.visible and view.completed_report_label.text.contains("SURVIVING") and view.completed_report_label.text.contains("CAMPAIGN CONSEQUENCES"), "Completion clears follow and leaves the full report readable.")
    await capture_frame("camera-follow-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: selected-friendly actual-position follow, wheel retention, pan/orbit/selection/inspect/reset/elimination/completion/reopen cleanup, disk/twin purity and real firing/report evidence.")
    quit(0 if failures.is_empty() else 1)
