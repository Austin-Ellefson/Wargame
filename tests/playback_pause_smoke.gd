extends "res://tests/camera_follow_smoke.gd"
# Reuse real input, rendering and camera-drag helpers; this overrides the base run.

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    check(sim.order_move("UKR_S1",Vector2(230,245)), "Pause fixture queues real movement into a close engagement.")
    var view = await open_view(sim)
    var before: Dictionary = sim.state.duplicate(true)
    check(view.playback_pause_button.disabled and not view.playback_paused and view.playback_pause_button.text == "PAUSE PLAYBACK", "Playback pause starts clear and disabled during planning.")
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(not view.playback_paused and same(before,sim.state), "Disabled planning input cannot pause or change the battle.")
    click(view.execute_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["phase"] == "execution" and not view.playback_pause_button.disabled, "Actual EXECUTE input enables the distinct playback control.")
    var twin = Battle.new()
    twin.restore(sim.state)
    var start := Battle.position(sim.squad_by_id("UKR_S1"))
    var found_live_frame := false
    for tick in range(30):
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Pre-pause actual playback matches its authoritative twin every tick.")
        if Battle.position(sim.squad_by_id("UKR_S1")).distance_to(start) > 1.0 and not view.shot_cues.is_empty():
            found_live_frame = true
            break
    check(found_live_frame and sim.state["phase"] == "execution", "Fixture reaches an actual moving/firing execution frame before pausing.")
    if not found_live_frame:
        view.queue_free()
        await process_frame
        quit(1)
        return

    # Preserve a fractional simulated second too: pause must freeze and resume it,
    # not silently round forward/back to the nearest authoritative tick.
    view._process(0.37/view.speed)
    check(same(sim.state,twin.state) and is_equal_approx(view.accumulator,0.37), "A partial playback frame has no authoritative tick before pause.")
    var cue: Dictionary = view.shot_cues.back()
    var cue_node: Node = cue["node"]
    var cue_ttl: float = cue["ttl"]
    var event_count: int = view.observed_shot_events.size()
    var motion_phase: float = view.motions["UKR_S1"]["phase"]
    var body: Node3D = view.bodies["UKR_S1"][0]
    var recoil: float = body.recoil_remaining
    var muzzle_visible: bool = body.muzzle.visible
    var rifle_transform: Transform3D = body.parts["rifle"].transform
    var leg_transform: Transform3D = body.parts["left_thigh"].transform
    var frozen_accumulator: float = view.accumulator
    before = sim.state.duplicate(true)
    seed(74291)
    var first_random := randi()
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(view.playback_paused and view.playback_pause_button.text == "RESUME PLAYBACK" and "PLAYBACK PAUSED" in view.phase_label.text, "Actual PAUSE PLAYBACK input visibly freezes execution.")
    check("Time/cues frozen" in view.report_label.text and same(before,sim.state), "Paused status explains the viewing-only freeze without changing authority.")

    # Exercise every supported playback rate while paused. Even deliberately large
    # frame deltas cannot advance time, cue TTL, recoil or locomotion phase.
    for expected_speed in [8.0,1.0,4.0]:
        click(view.speed_button.get_global_rect().get_center())
        await process_frame
        check(view.speed == expected_speed, "Speed control remains available while paused at %dx." % int(expected_speed))
        view._process(9.0)
        check(same(before,sim.state) and is_equal_approx(view.accumulator,frozen_accumulator), "Paused %dx playback advances no tick or partial accumulator." % int(expected_speed))
        check(view.shot_cues.has(cue) and cue["node"] == cue_node and is_equal_approx(cue["ttl"],cue_ttl) and view.observed_shot_events.size() == event_count, "Paused %dx playback freezes the actual shot cue and event history." % int(expected_speed))
        check(is_equal_approx(body.recoil_remaining,recoil) and body.muzzle.visible == muzzle_visible and body.parts["rifle"].transform == rifle_transform and body.parts["left_thigh"].transform == leg_transform and is_equal_approx(view.motions["UKR_S1"]["phase"],motion_phase), "Paused %dx playback freezes recoil and soldier animation." % int(expected_speed))

    # Camera operations stay live. FOLLOW is re-armed after pan/orbit because those
    # controls intentionally disengage it, matching the validated follow contract.
    click(view.follow_button.get_global_rect().get_center())
    await process_frame
    var old_fov: float = view.camera.fov
    click(Vector2(700,460),MOUSE_BUTTON_WHEEL_DOWN)
    await process_frame
    check(view.follow_target == "UKR_S1" and view.camera.fov > old_fov and view.camera_focus == Battle.position(sim.squad_by_id("UKR_S1")), "Wheel zoom and FOLLOW remain usable while playback is paused.")
    var followed_point: Vector2 = view.camera_focus
    drag_camera(Vector2(700,460),Vector2(-35,18))
    await process_frame
    check(view.follow_target.is_empty() and view.camera_focus != followed_point, "Paused middle-drag keeps free camera pan behavior.")
    var old_yaw: float = view.camera_yaw
    drag_camera(Vector2(700,460),Vector2(45,-12),true)
    await process_frame
    check(view.camera_yaw != old_yaw, "Paused Shift-middle-drag keeps free camera orbit behavior.")
    click(view.follow_button.get_global_rect().get_center())
    await process_frame
    check(view.follow_target == "UKR_S1" and same(before,sim.state) and is_equal_approx(cue["ttl"],cue_ttl) and is_equal_approx(body.recoil_remaining,recoil), "Paused camera use and re-follow leave combat and firing lifetimes frozen.")
    var second_random := randi()
    seed(74291)
    check(first_random == randi() and second_random == randi(), "Pause, speed and camera controls consume no global random samples.")
    print("PLAYBACK PAUSED: tick=",sim.state["elapsed"]," speed=",int(view.speed)," rounds=",sim.squad_by_id("UKR_S1")["ammo"]," cue_ttl=",cue["ttl"]," recoil=",body.recoil_remaining)
    await capture_frame("playback-pause-execution-preview")

    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(not view.playback_paused and view.playback_pause_button.text == "PAUSE PLAYBACK", "Actual RESUME PLAYBACK input releases the freeze.")
    twin.step()
    view._process((1.0-frozen_accumulator)/view.speed)
    check(same(sim.state,twin.state) and is_zero_approx(view.accumulator), "Resume preserves the frozen fractional time and lands on the exact next authoritative twin tick.")

    # A pause is UI-only. An authoritative disk checkpoint does not serialize it,
    # and reopening an executing battle starts safely unpaused.
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(view.playback_paused, "Playback can pause again before an execution checkpoint.")
    var save_path := "user://playback_pause_%d.json" % Time.get_ticks_usec()
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(sim.state))
    file.close()
    var restored = Battle.new()
    restored.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
    DirAccess.remove_absolute(save_path)
    check(same(restored.state,sim.state), "Paused authoritative state survives an actual disk round trip exactly.")
    view.queue_free()
    await process_frame
    sim = restored
    view = await open_view(sim)
    check(not view.playback_paused and not view.playback_pause_button.disabled and view.playback_pause_button.text == "PAUSE PLAYBACK" and "PLAYBACK PAUSED" not in view.phase_label.text, "Reopening an executing battle restores no stale playback pause.")
    check(view.shot_cues.is_empty() and same(sim.state,twin.state), "Transient cues are not fabricated on reopen and authority still matches the twin.")

    var saw_interval_reset := false
    for tick in range(500):
        if sim.state["phase"] == "finished": break
        if sim.state["phase"] == "planning":
            saw_interval_reset = true
            check(not view.playback_paused and view.playback_pause_button.disabled and view.playback_pause_button.text == "PAUSE PLAYBACK", "Interval completion clears pause and disables the viewing control in planning.")
            check(twin.execute(), "Twin starts the next interval.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
            check(sim.state["phase"] == "execution" and not view.playback_paused and not view.playback_pause_button.disabled, "A later actual EXECUTE starts unpaused.")
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Every post-reopen/resume authoritative tick matches the uninterrupted twin.")
    check(saw_interval_reset, "Fixture crosses at least one execution-to-planning interval after pause.")
    check(sim.state["phase"] == "finished" and same(sim.result(),twin.result()) and Battle.validate(sim.state,PAYLOAD), "Paused/resumed/reopened playback completes with the exact valid twin result.")
    check(not view.playback_paused and view.playback_pause_button.disabled and view.completed_report_panel.visible and view.completed_report_label.text.contains("SURVIVING") and view.completed_report_label.text.contains("CAMPAIGN CONSEQUENCES"), "Completion clears pause and retains the readable two-sided campaign report.")
    await capture_frame("playback-pause-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: actual playback pause/resume freezes ticks, fractional time, cues, recoil and animation at 1x/4x/8x; keeps camera/follow live; clears on planning/completion/reopen; and preserves disk/every-tick/result/RNG parity.")
    quit(0 if failures.is_empty() else 1)
