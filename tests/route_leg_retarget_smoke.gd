extends "res://tests/route_leg_edit_smoke.gd"
# Reuse the route/input/render helpers; override the inherited run.

func route_destinations(sim: RefCounted, id: String) -> Array[Vector2]:
    var destinations: Array[Vector2] = []
    var path: Array = sim.state["orders"].get(id, [])
    var legs: Array = sim.state["route_legs"].get(id, [])
    var cursor := 0
    for length in legs:
        cursor += int(length)
        var point: Array = path[cursor - 1]
        destinations.append(Vector2(float(point[0]), float(point[1])))
    return destinations

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    var view = View.new()
    view.simulation = sim
    root.add_child(view)
    await process_frame
    view.set_process(false)
    frame(view,Vector2(240,265),190)

    # Author three distinct legs through actual controls, then select the middle
    # gold marker and right-click its replacement destination.
    click(view.movement_buttons["move"].get_global_rect().get_center())
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
    click(view.movement_buttons["hunt"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.leg_pause_button.get_global_rect().get_center())
    await process_frame
    click(view.leg_pause_button.get_global_rect().get_center())
    await process_frame
    sim.state["command_remaining"]["UKR_S1"] = 2
    view._refresh()
    var before: Dictionary = sim.state.duplicate(true)
    var before_path: Array = sim.state["orders"]["UKR_S1"].duplicate(true)
    var before_legs: Array = sim.state["route_legs"]["UKR_S1"].duplicate()
    var before_destinations := route_destinations(sim,"UKR_S1")
    var prefix_size := int(before_legs[0])
    var before_events: Array = sim.last_events.duplicate(true)
    seed(73511)
    var first_random := randi()

    click(screen(view,before_destinations[1]))
    await process_frame
    check(view.route_leg_edit_index == 1 and "Right-click retargets" in view.report_label.text, "Selecting an earlier gold marker exposes the explicit retarget interaction.")
    click(screen(view,Vector2(250,300)),MOUSE_BUTTON_RIGHT)
    await process_frame
    var after_destinations := route_destinations(sim,"UKR_S1")
    var retargeted: Vector2 = after_destinations[1]
    check(retargeted.distance_to(Vector2(250,300)) < 5.0 and view.route_leg_edit_index == 1, "Actual right-click moves the selected authored destination and keeps it selected for review.")
    check(after_destinations[0] == before_destinations[0] and after_destinations[2] == before_destinations[2], "Retargeting preserves every earlier and later authored destination exactly.")
    check(sim.state["orders"]["UKR_S1"].slice(0,prefix_size) == before_path.slice(0,prefix_size) and int(sim.state["route_legs"]["UKR_S1"][0]) == int(before_legs[0]), "The complete earlier routed segment remains byte-shape exact.")
    check(not same(before_path,sim.state["orders"]["UKR_S1"]) and sim.state["route_legs"]["UKR_S1"].size() == 3, "The selected-and-later segments are deterministically rerouted under the same authored boundaries.")
    var expected: Dictionary = before.duplicate(true)
    expected["orders"]["UKR_S1"] = sim.state["orders"]["UKR_S1"].duplicate(true)
    expected["route_legs"]["UKR_S1"] = sim.state["route_legs"]["UKR_S1"].duplicate()
    check(same(expected,sim.state) and same(before_events,sim.last_events), "Retargeting changes only route geometry/boundary counts, preserving modes, waits, response, events and all other authority.")
    check(sim.state["route_modes"]["UKR_S1"] == ["move","quick","hunt"] and sim.state["route_pauses"]["UKR_S1"] == [15,15,30] and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 2, "Per-leg modes/waits, active wait and earned response survive the reroute exactly.")
    check(Battle.validate(sim.state,PAYLOAD) and "LEG 2 QUICK [EDIT]\nWAIT 30s" in authored_labels(view), "The retargeted planning state remains a strict v29 save with a visible selected marker.")
    var second_random := randi()
    seed(73511)
    check(first_random == randi() and second_random == randi(), "Route retargeting consumes no global RNG.")
    print("ROUTE RETARGET: points=",before_path.size()," -> ",sim.state["orders"]["UKR_S1"].size()," legs=",before_legs," -> ",sim.state["route_legs"]["UKR_S1"]," middle=",retargeted," final=",after_destinations[2]," response=",sim.state["command_remaining"]["UKR_S1"])
    await capture("route-retarget-planning-preview")

    # Invalid contexts and an over-budget deterministic rebuild reject before
    # changing any route field. Older rules never gain the command silently.
    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_retarget_leg("UKR_S1",Vector2(230,160),1) and not sim.order_retarget_leg("UKR_S1",Vector2(240,260),-1) and not sim.order_retarget_leg("UKR_S1",Vector2(240,260),3) and not sim.order_retarget_leg("RU_S1",Vector2(350,300),0) and same(intact,sim.state), "Blocked ground, bad indexes and enemy routes reject retargeting atomically.")
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 27
    legacy.state.erase("route_pauses")
    legacy.state.erase("route_facings")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"move") and legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true), "V27 isolation fixture authors its original mixed route.")
    var legacy_before: Dictionary = legacy.state.duplicate(true)
    check(not legacy.order_retarget_leg("UKR_S1",Vector2(250,300),1) and same(legacy_before,legacy.state) and Battle.validate(legacy.state,PAYLOAD), "V27 rejects retargeting without migration or field changes.")

    var limit = Battle.new()
    limit.setup(PAYLOAD)
    limit.squad_by_id("UKR_S1")["position"] = [12.0,12.0]
    var full_path: Array = []
    for index in range(128): full_path.append([12.0,12.0])
    limit.state["orders"]["UKR_S1"] = full_path
    limit.state["movement_modes"]["UKR_S1"] = "move"
    limit.state["route_legs"]["UKR_S1"] = [127,1]
    limit.state["route_modes"]["UKR_S1"] = ["move","quick"]
    limit.state["route_pauses"]["UKR_S1"] = [0,15]
    limit.state["route_facings"]["UKR_S1"] = [-1,-1]
    limit.state["pause_remaining"]["UKR_S1"] = 0
    limit.state["command_remaining"]["UKR_S1"] = 2
    check(Battle.validate(limit.state,PAYLOAD), "The 128-point atomicity fixture is a strict v29 save.")
    var limit_before: Dictionary = limit.state.duplicate(true)
    check(not limit.order_retarget_leg("UKR_S1",Vector2(500,500),1) and same(limit_before,limit.state), "A reroute exceeding 128 points rejects without truncating or corrupting later intent.")

    # A no-ammunition execution proves that the rerouted leg still activates its
    # own wait/mode at exact authored nodes and then reaches the retained final.
    var pacing = Battle.new()
    pacing.setup(PAYLOAD)
    for squad in pacing.state["squads"]: squad["ammo"] = 0
    pacing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    check(pacing.order_move("UKR_S1",Vector2(108,100),true,"move") and pacing.order_move("UKR_S1",Vector2(116,100),true,"quick",true) and pacing.order_leg_pause("UKR_S1",2) and pacing.order_move("UKR_S1",Vector2(128,100),true,"move",true), "Boundary fixture authors three ordinary legs.")
    check(pacing.order_retarget_leg("UKR_S1",Vector2(116,116),1), "Boundary fixture retargets the selected middle destination.")
    var pacing_destinations := route_destinations(pacing,"UKR_S1")
    pacing.state["command_remaining"]["UKR_S1"] = 0
    check(pacing.execute(), "The strict retargeted route starts execution.")
    var saw_wait := false
    var saw_middle := false
    for tick in range(60):
        pacing.step()
        var remaining_legs: Array = pacing.state["route_legs"].get("UKR_S1",[])
        if remaining_legs.size() == 2 and int(pacing.state["pause_remaining"]["UKR_S1"]) > 0:
            saw_wait = saw_wait or Battle.position(pacing.squad_by_id("UKR_S1")) == pacing_destinations[0] and pacing.movement_mode("UKR_S1") == "quick"
        if remaining_legs.size() == 1:
            saw_middle = saw_middle or Battle.position(pacing.squad_by_id("UKR_S1")) == pacing_destinations[1] and pacing.movement_mode("UKR_S1") == "move"
        if not pacing.state["orders"].has("UKR_S1"): break
    check(saw_wait and saw_middle and Battle.position(pacing.squad_by_id("UKR_S1")) == pacing_destinations[2] and not pacing.state["orders"].has("UKR_S1"), "Retargeted execution waits at the prior node, reaches the new middle node, then reaches the retained later destination with exact modes.")

    # Existing v29 fields round-trip through real disk I/O; transient selection
    # deliberately does not. The new geometry remains deterministic on reopen.
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://route_retarget_%d.json" % Time.get_ticks_usec()
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
    check(same(disk_snapshot,restored.state) and Battle.validate(restored.state,PAYLOAD) and view.route_leg_edit_index == -1, "Disk reopen preserves the retargeted route exactly and forgets transient selection.")
    check(route_destinations(restored,"UKR_S1") == after_destinations, "Reopened authored markers retain the new middle and exact later destinations.")
    view.queue_free()
    await process_frame

    # Complete real combat on a retargeted route and compare every rendered tick
    # to an unrendered twin, including actual shots and the final report.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and combat.order_leg_pause("UKR_S1",15) and combat.order_move("UKR_S1",Vector2(280,245),true,"move",true), "Combat fixture starts with three authored legs.")
    check(combat.order_retarget_leg("UKR_S1",Vector2(250,280),1) and route_destinations(combat,"UKR_S1")[2] == Vector2(280,245) and Battle.validate(combat.state,PAYLOAD), "Combat fixture reroutes its middle leg while preserving its later authored endpoint.")
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
            check(twin.execute(), "Twin begins the next interval after route retargeting.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every retargeted-route combat tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(225,255),150)
            print("ROUTE RETARGET EXECUTION: elapsed=",combat.state["elapsed"]," active=",combat.movement_mode("UKR_S1")," shots=",view.shot_cues.size())
            await capture("route-retarget-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Retargeted orders reach the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Retargeted-route execution retains the readable completed battle report.")
    await capture("route-retarget-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: selected authored-leg retargeting, affected-segment rerouting, later-intent preservation, atomic bounds, v27 isolation, exact boundary/disk behavior and full combat parity.")
    quit(0 if failures.is_empty() else 1)
