extends "res://tests/route_leg_modes_smoke.gd"
# Reuse actual input/render/disk helpers; override the inherited v27 run.

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    var untouched: Dictionary = sim.state.duplicate(true)
    check(not sim.order_leg_pause("UKR_S1",15) and same(untouched,sim.state), "A leg wait requires an editable authored route and rejects atomically.")

    var view = View.new()
    view.simulation = sim
    root.add_child(view)
    await process_frame
    view.set_process(false)
    frame(view,Vector2(230,245),180)

    # Actual mode, route, initial-wait and per-leg-wait controls author a route
    # whose delays begin at the current position and two later gold nodes.
    click(view.movement_buttons["hunt"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(210,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    click(view.pause_button.get_global_rect().get_center())
    await process_frame
    click(view.movement_buttons["quick"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(250,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.leg_pause_button.get_global_rect().get_center())
    await process_frame
    click(view.movement_buttons["move"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.leg_pause_button.get_global_rect().get_center())
    await process_frame
    click(view.leg_pause_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["version"] == 28 and sim.state["route_modes"]["UKR_S1"] == ["hunt","quick","move"], "Fresh v28 retains one mode for every authored leg.")
    check(sim.state["route_pauses"]["UKR_S1"] == [15,15,30] and int(sim.state["pause_remaining"]["UKR_S1"]) == 15, "Initial and later leg-start waits remain distinct and bounded.")
    check(authored_labels(view) == ["LEG 1 HUNT\nWAIT 15s","LEG 2 QUICK\nWAIT 30s","LEG 3 MOVE"], "Gold authored nodes visibly name each queued future delay.")
    check(view.pause_button.text == "START 15s" and view.leg_pause_button.text == "LEG 30s" and view.remove_waypoint_button.text == "REMOVE LEG", "The compact command row distinguishes the start wait, newest-leg wait and whole-leg removal.")
    check(view.hold_button.position.x + view.hold_button.size.x < view.pause_button.position.x and view.pause_button.position.x + view.pause_button.size.x < view.leg_pause_button.position.x and view.leg_pause_button.position.x + view.leg_pause_button.size.x < view.remove_waypoint_button.position.x and view.remove_waypoint_button.position.x + view.remove_waypoint_button.size.x <= 1234.0, "All four v28 route controls remain separate inside the 720p command panel.")
    check("LEG WAIT: pause at prior gold node" in view.report_label.text, "Planning help explains where the newest leg delay begins.")
    await capture("route-pauses-planning-preview")

    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_leg_pause("UKR_S1",61) and not sim.order_leg_pause("UKR_S1",1.5) and not sim.order_leg_pause("UKR_S1",15,3) and not sim.order_leg_pause("RU_S1",15) and same(intact,sim.state), "Invalid, fractional, out-of-range and enemy leg waits reject without mutation.")
    seed(73228)
    var first_random := randi()
    click(view.remove_waypoint_button.get_global_rect().get_center())
    await process_frame
    var second_random := randi()
    seed(73228)
    check(first_random == randi() and second_random == randi(), "Removing a pause-bearing leg consumes no global RNG.")
    check(sim.state["route_modes"]["UKR_S1"] == ["hunt","quick"] and sim.state["route_pauses"]["UKR_S1"] == [15,15], "Whole-leg removal drops only the paired final mode and delay.")
    check(authored_labels(view) == ["LEG 1 HUNT\nWAIT 15s","LEG 2 QUICK"] and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 5, "Removal retains the active start wait, earlier node delay and unearned response time.")

    check(Battle.validate(sim.state,PAYLOAD), "The authored pause route is a strict valid v28 save.")
    for index in range(12):
        var bad: Dictionary = sim.state.duplicate(true)
        match index:
            0: bad.erase("route_pauses")
            1: bad["route_pauses"].erase("UKR_S1")
            2: bad["route_pauses"]["UKR_S1"] = []
            3: bad["route_pauses"]["UKR_S1"] = [15]
            4: bad["route_pauses"]["UKR_S1"] = [15,15,30]
            5: bad["route_pauses"]["UKR_S1"] = [15,-1]
            6: bad["route_pauses"]["UKR_S1"] = [15,61]
            7: bad["route_pauses"]["UKR_S1"] = [15,1.5]
            8: bad["route_pauses"]["UKR_S1"] = [0,15]
            9: bad["route_pauses"]["UNKNOWN"] = [0]
            10: bad["route_pauses"]["RU_S1"] = [0]
            11: bad["route_pauses"]["UKR_S1"] = "wait"
        check(not Battle.validate(bad,PAYLOAD), "Malformed v28 route-pause state rejects case%d." % index)

    # V27 keeps its original global PAUSE behavior and exact field shape.
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 27
    legacy.state.erase("route_pauses")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"hunt") and legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and legacy.order_pause("UKR_S1",15), "V27 still authors mixed modes with its original single route-start wait.")
    check(int(legacy.state["pause_remaining"]["UKR_S1"]) == 15 and not legacy.state.has("route_pauses") and Battle.validate(legacy.state,PAYLOAD), "V27 validates without invented per-leg pauses.")
    var legacy_restart = Battle.new()
    legacy_restart.restore(JSON.parse_string(JSON.stringify(legacy.state)))
    check(same(legacy.state,legacy_restart.state) and not legacy_restart.state.has("route_pauses"), "A v27 JSON restart remains exact and unmigrated.")

    # Short segments prove waits activate only after reaching their prior authored
    # node, count exact execution seconds and block leftover distance at boundaries.
    var pacing = Battle.new()
    pacing.setup(PAYLOAD)
    for squad in pacing.state["squads"]: squad["ammo"] = 0
    pacing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    pacing.state["orders"]["UKR_S1"] = [[102.0,100.0],[105.0,100.0],[112.0,100.0]]
    pacing.state["movement_modes"]["UKR_S1"] = "move"
    pacing.state["route_legs"]["UKR_S1"] = [1,1,1]
    pacing.state["route_modes"]["UKR_S1"] = ["move","quick","hunt"]
    pacing.state["route_pauses"]["UKR_S1"] = [0,2,3]
    pacing.state["command_remaining"]["UKR_S1"] = 0
    check(Battle.validate(pacing.state,PAYLOAD) and pacing.execute(), "Boundary fixture starts from a strict mixed-mode/mixed-wait v28 route.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.movement_mode("UKR_S1") == "quick" and pacing.state["route_pauses"]["UKR_S1"] == [2,3] and int(pacing.state["pause_remaining"]["UKR_S1"]) == 2, "Arrival at LEG1 activates its queued two-second wait without entering QUICK.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.state["route_pauses"]["UKR_S1"] == [1,3], "The first exact node-wait second decrements without movement.")
    var resumed = Battle.new()
    resumed.restore(JSON.parse_string(JSON.stringify(pacing.state)))
    check(same(pacing.state,resumed.state) and Battle.validate(resumed.state,PAYLOAD), "A partial node wait survives JSON restart exactly.")
    pacing.step(); resumed.step()
    check(same(pacing.state,resumed.state) and Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and int(pacing.state["pause_remaining"]["UKR_S1"]) == 0, "The second wait tick reaches zero on disk-identical twins without moving.")
    pacing.step(); resumed.step()
    check(same(pacing.state,resumed.state) and Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(105,100) and pacing.movement_mode("UKR_S1") == "hunt" and pacing.state["route_pauses"]["UKR_S1"] == [3], "QUICK reaches LEG2 and activates its three-second HUNT-boundary wait with no leftover travel.")
    for remaining in [2,1,0]:
        pacing.step(); resumed.step()
        check(same(pacing.state,resumed.state) and Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(105,100) and int(pacing.state["pause_remaining"]["UKR_S1"]) == remaining, "Each resumed HUNT-boundary wait tick remains stationary and exact.")
    pacing.squad_by_id("UKR_S1")["suppression"] = 0.3
    resumed.squad_by_id("UKR_S1")["suppression"] = 0.3
    pacing.step(); resumed.step()
    check(same(pacing.state,resumed.state) and Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(105,100) and pacing.hunt_paused(pacing.squad_by_id("UKR_S1")), "After the timed wait, the newly active HUNT leg still applies its own pressure gate.")
    pacing.squad_by_id("UKR_S1")["suppression"] = 0.0
    resumed.squad_by_id("UKR_S1")["suppression"] = 0.0
    pacing.step(); resumed.step()
    check(same(pacing.state,resumed.state) and Battle.position(pacing.squad_by_id("UKR_S1")).distance_to(Vector2(105,100)) > 1.0 and Battle.validate(pacing.state,PAYLOAD), "Recovered HUNT advances at its own pace with exact resumed state.")

    # Real file I/O reconstructs the paired delays and their node labels.
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://route_pauses_%d.json" % Time.get_ticks_usec()
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
    check(same(disk_snapshot,restored.state) and authored_labels(view) == ["LEG 1 HUNT\nWAIT 15s","LEG 2 QUICK"], "Disk reopen reconstructs every remaining authored node delay without transient data.")
    print("ROUTE PAUSES DISK: waits=",restored.state["route_pauses"]["UKR_S1"]," active=",restored.state["pause_remaining"]["UKR_S1"]," response=",restored.state["command_remaining"]["UKR_S1"])
    check(same(restored.state["route_pauses"]["UKR_S1"],[15,15]) and int(restored.state["pause_remaining"]["UKR_S1"]) == 15 and int(restored.state["command_remaining"]["UKR_S1"]) == 5, "Disk reopen preserves start wait, future node wait and response exactly.")
    view.queue_free()
    await process_frame

    # Rendered and headless instances execute real delayed mixed-mode combat in
    # lockstep through the readable completed report.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_pause("UKR_S1",15) and combat.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and combat.order_leg_pause("UKR_S1",15) and combat.order_move("UKR_S1",Vector2(280,245),true,"hunt",true) and combat.order_leg_pause("UKR_S1",30), "Combat fixture queues real start, node, mode and HUNT delays.")
    check(Battle.validate(combat.state,PAYLOAD), "The real per-leg-pause combat fixture validates before execution.")
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
            check(twin.execute(), "Twin begins the next per-leg-pause interval.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every delayed mixed-mode execution tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(220,245),145)
            print("ROUTE PAUSES EXECUTION: elapsed=",combat.state["elapsed"]," active=",combat.movement_mode("UKR_S1")," waits=",combat.state["route_pauses"].get("UKR_S1",[])," shots=",view.shot_cues.size())
            await capture("route-pauses-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Per-leg-pause execution reaches the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Per-leg-pause execution retains the readable completed battle report.")
    await capture("route-pauses-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: v28 start/per-leg waits, visible node labels, strict saves, v27 compatibility, exact boundary timing, disk restart and full combat parity.")
    quit(0 if failures.is_empty() else 1)
