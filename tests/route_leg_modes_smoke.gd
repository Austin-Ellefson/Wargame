extends "res://tests/remove_waypoint_smoke.gd"
# Reuse actual input/render/disk helpers; override the inherited v26 run.

func v27(sim: RefCounted) -> void:
    sim.state["version"] = 27
    sim.state.erase("route_pauses")

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    v27(sim)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    var view = View.new()
    view.simulation = sim
    root.add_child(view)
    await process_frame
    view.set_process(false)
    frame(view,Vector2(230,245),180)

    # Actual mode buttons plus right/Shift-right input author three differently
    # paced legs. Selecting a later mode must not rewrite the active first leg.
    click(view.movement_buttons["hunt"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(210,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    click(view.movement_buttons["quick"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(250,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.movement_buttons["move"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.pause_button.get_global_rect().get_center())
    await process_frame
    var lengths: Array = sim.state["route_legs"]["UKR_S1"]
    var covered := 0
    for length in lengths: covered += int(length)
    check(sim.state["version"] == 27 and lengths.size() == 3 and covered == sim.state["orders"]["UKR_S1"].size(), "Fresh v27 stores three exact authored route boundaries.")
    check(sim.state["route_modes"]["UKR_S1"] == ["hunt","quick","move"] and sim.movement_mode("UKR_S1") == "hunt", "Each appended leg stores its selected mode without changing the active first leg.")
    check(int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 5, "Mixed-mode appends preserve the existing pause and command-response semantics.")
    check(authored_labels(view) == ["LEG 1 HUNT","LEG 2 QUICK","LEG 3 MOVE"], "Every authored planning node visibly names its saved movement mode.")
    check("Order: WAIT 15s (HUNT)" in view.selection_label.text and "Mode + Shift-right" in view.report_label.text, "Planning feedback distinguishes the active leg from the selector used for the next append.")
    await capture("route-modes-planning-preview")

    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_move("UKR_S1",Vector2(230,160),true,"quick",true) and same(intact,sim.state), "A blocked mixed-mode append preserves every existing leg and mode atomically.")
    seed(73127)
    var first_random := randi()
    click(view.remove_waypoint_button.get_global_rect().get_center())
    await process_frame
    var second_random := randi()
    seed(73127)
    check(first_random == randi() and second_random == randi(), "Removing a mode-bearing leg consumes no global RNG.")
    check(sim.state["route_modes"]["UKR_S1"] == ["hunt","quick"] and sim.state["route_legs"]["UKR_S1"].size() == 2 and sim.movement_mode("UKR_S1") == "hunt", "Whole-leg removal drops only the matching final mode and retains the active leg.")
    check(authored_labels(view) == ["LEG 1 HUNT","LEG 2 QUICK"] and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 5, "Removal refreshes mode labels while retaining pause and unearned response time.")

    # Strict v27 validation requires one legal mode for every stored leg and the
    # first mode must mirror the execution-facing movement_modes entry.
    check(Battle.validate(sim.state,PAYLOAD), "The mixed-mode planning state is a strict valid v27 save.")
    for index in range(9):
        var bad: Dictionary = sim.state.duplicate(true)
        match index:
            0: bad.erase("route_modes")
            1: bad["route_modes"].erase("UKR_S1")
            2: bad["route_modes"]["UKR_S1"] = []
            3: bad["route_modes"]["UKR_S1"] = ["hunt"]
            4: bad["route_modes"]["UKR_S1"] = ["hunt","warp"]
            5: bad["route_modes"]["UKR_S1"] = ["quick","hunt"]
            6: bad["route_modes"]["UNKNOWN"] = ["move"]
            7: bad["route_modes"]["UKR_S1"] = ["hunt",1]
            8: bad["route_modes"]["RU_S1"] = ["move"]
        check(not Battle.validate(bad,PAYLOAD), "Malformed v27 route-mode state rejects case%d." % index)

    # V26 remains one-mode-per-route with its exact field shape and rejection of
    # a mismatched append; loading never invents per-leg modes.
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 26
    legacy.state.erase("route_modes")
    legacy.state.erase("route_pauses")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"hunt"), "V26 accepts its original first route mode.")
    var legacy_before: Dictionary = legacy.state.duplicate(true)
    check(not legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and same(legacy_before,legacy.state), "V26 still rejects a different appended mode without mutation.")
    check(legacy.order_move("UKR_S1",Vector2(250,245),true,"hunt",true) and Battle.validate(legacy.state,PAYLOAD) and not legacy.state.has("route_modes"), "V26 same-mode append retains its exact valid field shape.")
    var legacy_restart = Battle.new()
    legacy_restart.restore(JSON.parse_string(JSON.stringify(legacy.state)))
    check(same(legacy.state,legacy_restart.state) and not legacy_restart.state.has("route_modes"), "A v26 JSON restart remains exact and unmigrated.")

    # Controlled short segments prove that a changed mode activates at the
    # authored boundary on the following whole tick. This prevents HUNT from
    # being entered using leftover QUICK movement in the boundary tick.
    var pacing = Battle.new()
    pacing.setup(PAYLOAD)
    v27(pacing)
    for squad in pacing.state["squads"]: squad["ammo"] = 0
    pacing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    pacing.state["orders"]["UKR_S1"] = [[102.0,100.0],[105.0,100.0],[112.0,100.0]]
    pacing.state["movement_modes"]["UKR_S1"] = "move"
    pacing.state["route_legs"]["UKR_S1"] = [1,1,1]
    pacing.state["route_modes"]["UKR_S1"] = ["move","quick","hunt"]
    pacing.state["command_remaining"]["UKR_S1"] = 0
    check(Battle.validate(pacing.state,PAYLOAD) and pacing.execute(), "Boundary fixture starts from a strict mixed-mode v27 route.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.movement_mode("UKR_S1") == "quick" and pacing.state["route_modes"]["UKR_S1"] == ["quick","hunt"], "MOVE reaches its authored node and activates QUICK without spending leftover distance past the boundary.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(105,100) and pacing.movement_mode("UKR_S1") == "hunt" and pacing.state["route_modes"]["UKR_S1"] == ["hunt"], "QUICK reaches the next authored node and activates HUNT for the next tick.")
    pacing.squad_by_id("UKR_S1")["suppression"] = 0.3
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(105,100) and pacing.hunt_paused(pacing.squad_by_id("UKR_S1")), "The newly active HUNT leg applies its pressure halt before entering the leg.")
    pacing.squad_by_id("UKR_S1")["suppression"] = 0.0
    pacing.step()
    var hunt_distance := Battle.position(pacing.squad_by_id("UKR_S1")).distance_to(Vector2(105,100))
    check(hunt_distance > 1.0 and hunt_distance < 1.3 and Battle.validate(pacing.state,PAYLOAD), "Recovered HUNT advances at its own slower pace and retains a valid remaining mode.")

    # Real file I/O must reconstruct the exact mode-bearing nodes and authority.
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://route_modes_%d.json" % Time.get_ticks_usec()
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(sim.state))
    file.close()
    var restored = Battle.new()
    restored.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
    DirAccess.remove_absolute(save_path)
    view.queue_free()
    await process_frame
    view = View.new()
    view.simulation = restored
    root.add_child(view)
    await process_frame
    view.set_process(false)
    check(same(disk_snapshot,restored.state) and authored_labels(view) == ["LEG 1 HUNT","LEG 2 QUICK"], "Disk reopen reconstructs the exact mixed-mode authored nodes without transient data.")
    check(restored.movement_mode("UKR_S1") == "hunt" and int(restored.state["pause_remaining"]["UKR_S1"]) == 15 and int(restored.state["command_remaining"]["UKR_S1"]) == 5, "Disk reopen preserves active mode, pause and command response exactly.")
    view.queue_free()
    await process_frame

    # Run a real mixed-mode battle through every tick and the completed report,
    # comparing the rendered instance to an unrendered authoritative twin.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    v27(combat)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and combat.order_move("UKR_S1",Vector2(280,245),true,"hunt",true), "Combat fixture queues real MOVE, QUICK and HUNT legs.")
    check(Battle.validate(combat.state,PAYLOAD), "The real mixed-mode combat fixture validates before execution.")
    var twin = Battle.new()
    twin.restore(combat.state)
    view = View.new()
    view.simulation = combat
    root.add_child(view)
    await process_frame
    view.set_process(false)
    var captured_shot := false
    for tick in range(500):
        if combat.state["phase"] == "finished": break
        if combat.state["phase"] == "planning":
            check(twin.execute(), "Twin begins the next mixed-mode interval.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every mixed-mode execution tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(220,245),145)
            print("ROUTE MODES EXECUTION: elapsed=",combat.state["elapsed"]," active=",combat.movement_mode("UKR_S1")," modes=",combat.state["route_modes"].get("UKR_S1",[])," shots=",view.shot_cues.size())
            await capture("route-modes-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Mixed-mode execution reaches the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Mixed-mode execution retains the readable completed battle report.")
    await capture("route-modes-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: v27 per-leg MOVE/QUICK/HUNT input, labels, strict saves, v26 compatibility, boundary pacing, disk restart and full combat parity.")
    quit(0 if failures.is_empty() else 1)
