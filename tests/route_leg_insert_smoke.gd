extends "res://tests/route_leg_remove_smoke.gd"
# Reuse the route/input/render helpers; override the inherited run.

func ctrl_click(point: Vector2, button: int = MOUSE_BUTTON_RIGHT) -> void:
    var event := InputEventMouseButton.new()
    event.position = point
    event.global_position = point
    event.button_index = button
    event.ctrl_pressed = true
    event.pressed = true
    Input.parse_input_event(event)
    event = event.duplicate()
    event.pressed = false
    Input.parse_input_event(event)

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
    frame(view,Vector2(250,265),200)

    # Author three mixed legs through real controls, select the middle gold
    # marker and Ctrl-right a new destination immediately before that intent.
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

    click(screen(view,before_destinations[1]))
    await process_frame
    check(view.route_leg_edit_index == 1 and "Ctrl-right inserts QUICK/0s before" in view.report_label.text, "Selecting an earlier marker exposes the inherited-mode, zero-wait insertion interaction.")
    seed(73703)
    var first_random := randi()
    ctrl_click(screen(view,Vector2(250,300)))
    await process_frame
    var second_random := randi()
    var after_destinations := route_destinations(sim,"UKR_S1")
    check(view.route_leg_edit_index == 1 and after_destinations.size() == 4 and after_destinations[1].distance_to(Vector2(250,300)) < 5.0, "Actual Ctrl-right inserts a new selected authored destination at the requested index.")
    check(after_destinations[0] == before_destinations[0] and after_destinations[2] == before_destinations[1] and after_destinations[3] == before_destinations[2], "Every original authored destination keeps its order and exact coordinates after insertion.")
    check(sim.state["orders"]["UKR_S1"].slice(0,prefix_size) == before_path.slice(0,prefix_size) and int(sim.state["route_legs"]["UKR_S1"][0]) == int(before_legs[0]), "All geometry before the insertion point remains byte-shape exact.")
    check(not same(before_path,sim.state["orders"]["UKR_S1"]) and sim.state["route_legs"]["UKR_S1"].size() == 4, "The inserted and later segments are deterministically spliced under four strict boundaries.")
    var expected: Dictionary = before.duplicate(true)
    expected["orders"]["UKR_S1"] = sim.state["orders"]["UKR_S1"].duplicate(true)
    expected["route_legs"]["UKR_S1"] = sim.state["route_legs"]["UKR_S1"].duplicate()
    expected["route_modes"]["UKR_S1"] = ["move","quick","quick","hunt"]
    expected["route_pauses"]["UKR_S1"] = [15,0,15,30]
    expected["route_facings"]["UKR_S1"] = [-1,-1,-1,-1]
    check(same(expected,sim.state) and same(before_events,sim.last_events), "Insertion changes only route geometry/boundaries and inserts inherited mode/zero-wait metadata.")
    check(sim.movement_mode("UKR_S1") == "move" and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 2, "A later insertion preserves active mode, active wait and earned response exactly.")
    check(authored_labels(view) == ["LEG 1 MOVE","LEG 2 QUICK [EDIT]\nWAIT 15s","LEG 3 QUICK\nWAIT 30s","LEG 4 HUNT"] and Battle.validate(sim.state,PAYLOAD), "Gold markers show the inserted intent and all shifted metadata in a strict v29 save.")
    seed(73703)
    check(first_random == randi() and second_random == randi(), "Authored-leg insertion consumes no global RNG.")
    print("ROUTE INSERT: points=",before_path.size()," -> ",sim.state["orders"]["UKR_S1"].size()," legs=",before_legs," -> ",sim.state["route_legs"]["UKR_S1"]," inserted=",after_destinations[1]," response=",sim.state["command_remaining"]["UKR_S1"])
    await capture("route-insert-planning-preview")

    # Invalid requests and old rules reject atomically. A valid full queue proves
    # that insertion never truncates existing intent to fit the 128-point bound.
    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_insert_leg("UKR_S1",Vector2(230,160),1) and not sim.order_insert_leg("UKR_S1",Vector2(240,260),-1) and not sim.order_insert_leg("UKR_S1",Vector2(240,260),4) and not sim.order_insert_leg("RU_S1",Vector2(350,300),0) and same(intact,sim.state), "Blocked ground, bad indexes and enemy routes reject insertion atomically.")
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 27
    legacy.state.erase("route_pauses")
    legacy.state.erase("route_facings")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"move") and legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true), "V27 isolation fixture authors its original mixed route.")
    var legacy_before: Dictionary = legacy.state.duplicate(true)
    check(not legacy.order_insert_leg("UKR_S1",Vector2(230,280),1) and same(legacy_before,legacy.state) and Battle.validate(legacy.state,PAYLOAD), "V27 rejects insertion without migration or field changes.")

    var limit = Battle.new()
    limit.setup(PAYLOAD)
    limit.squad_by_id("UKR_S1")["position"] = [12.0,12.0]
    var full_path: Array = []
    for index in range(126): full_path.append([12.0,12.0])
    full_path.append([20.0,12.0])
    full_path.append([480.0,480.0])
    limit.state["orders"]["UKR_S1"] = full_path
    limit.state["movement_modes"]["UKR_S1"] = "move"
    limit.state["route_legs"]["UKR_S1"] = [126,1,1]
    limit.state["route_modes"]["UKR_S1"] = ["move","quick","hunt"]
    limit.state["route_pauses"]["UKR_S1"] = [0,15,30]
    limit.state["route_facings"]["UKR_S1"] = [-1,-1,-1]
    limit.state["pause_remaining"]["UKR_S1"] = 0
    limit.state["command_remaining"]["UKR_S1"] = 2
    check(Battle.validate(limit.state,PAYLOAD), "The 128-point insertion fixture is a strict v29 save.")
    var limit_before: Dictionary = limit.state.duplicate(true)
    check(not limit.order_insert_leg("UKR_S1",Vector2(500,500),1) and same(limit_before,limit.state), "An insertion exceeding 128 points rejects without truncating later intent or metadata.")

    # Inserting before LEG 1 activates the inherited mode with zero wait while
    # the original first leg keeps its own wait after the new destination.
    var first = Battle.new()
    first.setup(PAYLOAD)
    for squad in first.state["squads"]: squad["ammo"] = 0
    first.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    check(first.order_move("UKR_S1",Vector2(108,100),true,"quick") and first.order_pause("UKR_S1",15) and first.order_move("UKR_S1",Vector2(116,100),true,"hunt",true) and first.order_leg_pause("UKR_S1",30,1), "First-leg fixture authors two mixed legs and waits.")
    first.state["command_remaining"]["UKR_S1"] = 2
    check(first.order_insert_leg("UKR_S1",Vector2(104,100),0), "A new destination can be inserted before the active first intent.")
    check(route_destinations(first,"UKR_S1") == [Vector2(104,100),Vector2(108,100),Vector2(116,100)] and first.state["route_modes"]["UKR_S1"] == ["quick","quick","hunt"] and first.state["route_pauses"]["UKR_S1"] == [0,15,30], "First insertion inherits QUICK/0s while both original destinations keep paired metadata.")
    check(first.movement_mode("UKR_S1") == "quick" and int(first.state["pause_remaining"]["UKR_S1"]) == 0 and int(first.state["command_remaining"]["UKR_S1"]) == 2 and Battle.validate(first.state,PAYLOAD), "The inserted first leg mirrors strict active fields without resetting earned response.")
    first.state["command_remaining"]["UKR_S1"] = 0
    check(first.execute(), "First-insertion fixture begins execution.")
    var saw_shifted_wait := false
    for tick in range(20):
        first.step()
        if route_destinations(first,"UKR_S1").size() == 2 and int(first.state["pause_remaining"]["UKR_S1"]) > 0:
            saw_shifted_wait = Battle.position(first.squad_by_id("UKR_S1")) == Vector2(104,100) and first.movement_mode("UKR_S1") == "quick" and int(first.state["pause_remaining"]["UKR_S1"]) == 15
            break
    check(saw_shifted_wait, "The original LEG 1 wait begins only after arrival at the newly inserted destination.")

    # Disk stores only authoritative v29 arrays; the selected inserted marker is
    # transient. Reopening must reconstruct the exact four authored destinations.
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://route_insert_%d.json" % Time.get_ticks_usec()
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
    check(same(disk_snapshot,restored.state) and Battle.validate(restored.state,PAYLOAD) and view.route_leg_edit_index == -1, "Disk reopen preserves the inserted route exactly and forgets transient selection.")
    check(route_destinations(restored,"UKR_S1") == after_destinations and authored_labels(view) == ["LEG 1 MOVE","LEG 2 QUICK\nWAIT 15s","LEG 3 QUICK\nWAIT 30s","LEG 4 HUNT"], "Reopened gold markers reconstruct inserted and original intent with exact metadata.")
    view.queue_free()
    await process_frame

    # Complete real combat on an inserted mixed route and compare every rendered
    # tick to an unrendered twin, including actual shots and the final report.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and combat.order_leg_pause("UKR_S1",15,1) and combat.order_move("UKR_S1",Vector2(280,245),true,"hunt",true) and combat.order_leg_pause("UKR_S1",30,2), "Combat fixture starts with three authored legs and later metadata.")
    check(combat.order_insert_leg("UKR_S1",Vector2(250,280),1) and route_destinations(combat,"UKR_S1") == [Vector2(205,245),Vector2(250,280),Vector2(250,245),Vector2(280,245)] and combat.state["route_modes"]["UKR_S1"] == ["move","quick","quick","hunt"] and combat.state["route_pauses"]["UKR_S1"] == [0,0,15,30] and Battle.validate(combat.state,PAYLOAD), "Combat fixture inserts a QUICK/0s leg while preserving later QUICK/15s and HUNT/30s intent.")
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
            check(twin.execute(), "Twin begins the next interval after authored-leg insertion.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every inserted-route combat tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(225,255),150)
            print("ROUTE INSERT EXECUTION: elapsed=",combat.state["elapsed"]," active=",combat.movement_mode("UKR_S1")," shots=",view.shot_cues.size())
            await capture("route-insert-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Inserted orders reach the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Inserted-route execution retains the readable completed battle report.")
    await capture("route-insert-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: selected authored-leg insertion, deterministic splicing, inherited zero-wait metadata, first-leg activation, atomic bounds, v27 isolation, disk restart and full combat parity.")
    quit(0 if failures.is_empty() else 1)
