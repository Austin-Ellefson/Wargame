extends "res://tests/terrain_probe_smoke.gd"
# Reuse only the input/frame/assertion helpers; this overrides the base test run.
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
    frame(view,Vector2(210,245))
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    check(not view.los_from_waypoint and view.los_origin_button.disabled and view.los_origin_button.text.contains("NO QUEUED ROUTE"), "No route disables hypothetical mode without removing the current-position probe.")
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    click(view.movement_buttons["hunt"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(210,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    var first_path: Array = sim.state["orders"]["UKR_S1"].duplicate(true)
    click(screen(view,Vector2(240,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.pause_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["orders"]["UKR_S1"].size() > first_path.size() and sim.movement_mode("UKR_S1") == "hunt" and sim.state["pause_remaining"]["UKR_S1"] == 15, "Actual HUNT, right/Shift-right and PAUSE create the multi-leg order fixture.")
    var waypoint: Vector2 = view._los_waypoint()
    var before: Dictionary = sim.state.duplicate(true)
    var events: Array = sim.last_events.duplicate(true)
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_LEFT,true)
    await process_frame
    var current: Dictionary = view._terrain_probe(view.los_point)
    click(view.los_origin_button.get_global_rect().get_center())
    await process_frame
    var probe: Dictionary = view._terrain_probe(view.los_point)
    check(view.los_from_waypoint and probe["origin"] == waypoint and probe["distance"] < current["distance"], "Actual origin toggle uses the final queued point, not the first path point or actual squad.")
    check(is_equal_approx(probe["distance"],waypoint.distance_to(view.los_point)) and view._terrain_probe(waypoint).is_empty(), "Range and near-coincident rejection are relative to the hypothetical origin.")
    check(view.los_origin_button.text.contains("HYPOTHETICAL") and view.los_label.text.contains("HYPOTHETICAL TERRAIN") and view.los_label.text.contains("Assumes S1 STAND") and view.los_label.text.contains("not spotting"), "Hypothetical origin, current posture assumption and terrain-only limits are explicit.")
    check(same(before,sim.state) and same(events,sim.last_events), "Switching origin and Shift-click probing change no commands, knowledge, positions, clocks, RNG or events.")
    check(view.los_label.get_global_rect().end.y <= view.los_panel.get_global_rect().end.y, "Full hypothetical readout fits inside its panel.")
    await capture("waypoint-clear-preview")
    var endpoint: Vector2 = view.los_point
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_WHEEL_DOWN)
    await process_frame
    var pan := InputEventMouseMotion.new()
    pan.position = Vector2(700,460)
    pan.relative = Vector2(7,-4)
    pan.button_mask = MOUSE_BUTTON_MASK_MIDDLE
    Input.parse_input_event(pan)
    await process_frame
    check(view.los_point == endpoint and same(probe,view._terrain_probe(endpoint)) and same(before,sim.state), "Actual camera input preserves hypothetical origin/endpoint and state.")
    escape()
    await process_frame
    check(not view.los_armed and not view.los_from_waypoint and not view.los_origin_button.visible and same(before,sim.state), "Escape resets the mode without canceling actual queued movement.")
    # Change the real saved route, not the real squad position, for geometry cases.
    check(sim.order_move("UKR_S1",Vector2(200,168)), "Replacement route to building-side waypoint is legal.")
    view._refresh()
    frame(view,Vector2(240,168),220)
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(view.los_origin_button.get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(280,168)))
    await process_frame
    check(view._terrain_probe(view.los_point)["origin"] == Vector2(200,168) and view.los_label.text.contains("TERRAIN BLOCKED"), "A replaced final waypoint supplies the actual sampled building LOS without moving the squad.")
    await capture("waypoint-blocked-preview")
    var hill_found := false
    for y in range(60,230,10):
        if hill_found: break
        for x in range(40,240,10):
            var a := Vector2(x,y)
            var b := a + Vector2(140,0)
            if not Battle.inside_building(a,5) and not Battle.inside_building(b,5) and Battle.visible(a,b,1.6,0.3) and not Battle.visible(a,b,0.35,0.3) and sim.order_move("UKR_S1",a):
                view.los_point = b
                frame(view,(a+b)*0.5,270)
                hill_found = true
                break
    check(hill_found, "A legal queued destination has posture-dependent sampled hill LOS.")
    view._refresh()
    check(view.los_label.text.contains("TERRAIN CLEAR"), "Changed final destination immediately replaces the old origin while retaining the endpoint.")
    click(view.posture_buttons["prone"].get_global_rect().get_center())
    await process_frame
    check(view.los_label.text.contains("TERRAIN BLOCKED") and view.los_label.text.contains("Assumes S1 PRONE eyes 0.35m") and Battle.position(sim.squad_by_id("UKR_S1")) == Vector2(180,245), "Actual posture order changes the hypothetical assumption without moving the squad to the waypoint.")
    await capture("waypoint-posture-preview")
    probe = view._terrain_probe(view.los_point)
    before = sim.state.duplicate(true)
    for squad in sim.state["squads"]:
        if squad["faction"] == "RU": squad["position"] = [490,490]
    var hidden: Dictionary = sim.state.duplicate(true)
    seed(41720)
    var first_random := randi()
    for repeat in range(20):
        view._refresh_los_probe()
        check(same(probe,view._terrain_probe(view.los_point)), "Hidden positions never affect hypothetical terrain clearance.")
    var second_random := randi()
    seed(41720)
    check(first_random == randi() and second_random == randi() and same(hidden,sim.state), "Repeated hypothetical queries leave global RNG and complete authority unchanged.")
    sim.restore(before)
    check(sim.order_move("UKR_S1",Vector2(120,100),true,"move",true), "A new queued leg can be appended legally.")
    before = sim.state.duplicate(true)
    view._refresh()
    check(view._terrain_probe(view.los_point)["origin"] == Vector2(120,100) and view.los_origin_button.text.contains("120.0, 100.0") and same(before,sim.state), "Appending a route refreshes the hypothetical origin with no cached previous waypoint.")
    click(view.hold_button.get_global_rect().get_center())
    await process_frame
    check(view.los_from_waypoint and view._terrain_probe(view.los_point).is_empty() and view.los_preview.get_child_count() == 0 and view.los_label.text.contains("NO QUEUED DESTINATION"), "Actual HOLD removes stale geometry instead of silently falling back to actual position.")
    check(not view.los_origin_button.disabled, "After route removal the user can still switch back to current position.")
    await capture("waypoint-cleared-preview")
    before = sim.state.duplicate(true)
    click(view.los_origin_button.get_global_rect().get_center())
    await process_frame
    check(not view.los_from_waypoint and not view._terrain_probe(view.los_point).is_empty() and same(before,sim.state), "Current-position mode remains available after the queued route is removed.")
    click(screen(view,Vector2(280,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    check(sim.order_move("UKR_S1",Vector2(210,245)), "Disk fixture has a valid queued route.")
    view._refresh()
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(view.los_origin_button.get_global_rect().get_center())
    await process_frame
    view.los_point = Vector2(280,245)
    view._refresh_los_probe()
    check(Battle.validate(sim.state,PAYLOAD), "Hypothetical preview leaves a valid tactical snapshot.")
    var save_path := "user://waypoint_probe_%d.json" % Time.get_ticks_usec()
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(sim.state))
    file.close()
    var restored = Battle.new()
    restored.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
    DirAccess.remove_absolute(save_path)
    check(same(sim.state,restored.state), "Queued path and complete authority survive actual disk round trip.")
    view.queue_free()
    await process_frame
    view = View.new()
    view.simulation = restored
    root.add_child(view)
    await process_frame
    view.set_process(false)
    check(not view.los_from_waypoint and not view.los_armed and not view.los_origin_button.visible, "Reopen restores neither mode nor hypothetical measurement.")
    view.queue_free()
    await process_frame
    # Complete actual combat; presentation must not alter a single simulated tick.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(210,245)) and combat.order_pause("UKR_S1",15), "Real combat begins with a queued destination and wait, not a relocated preview actor.")
    var twin = Battle.new()
    twin.restore(combat.state)
    view = View.new()
    view.simulation = combat
    root.add_child(view)
    await process_frame
    view.set_process(false)
    var captured_shot := false
    for tick in range(400):
        if combat.state["phase"] == "finished": break
        if combat.state["phase"] == "planning":
            click(view.los_button.get_global_rect().get_center())
            await process_frame
            if not view.los_origin_button.disabled:
                click(view.los_origin_button.get_global_rect().get_center())
                await process_frame
            view.los_point = Vector2(280,245)
            before = combat.state.duplicate(true)
            view._refresh_los_probe()
            check(same(before,combat.state), "Planning mode queries cannot advance authoritative combat.")
            twin.execute()
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
            check(not view.los_from_waypoint and not view.los_origin_button.visible and not view.los_panel.visible, "Actual EXECUTE clears hypothetical mode and every probe control.")
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state), "Every actual execution tick matches a twin without the hypothetical view.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(210,245),140)
            await capture("waypoint-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Complete actual combat has the same valid result after hypothetical planning queries.")
    view._reset_camera()
    check(view.completed_report_panel.visible and not view.los_origin_button.visible and not view.los_panel.visible, "Completed report has no stale hypothetical controls or measurement.")
    await capture("waypoint-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: actual queued-route origin toggle, range/building/posture geometry, route replacement/append/removal, hidden/RNG/state purity, disk reopen and full actual-combat twin/report equality.")
    quit(0 if failures.is_empty() else 1)
