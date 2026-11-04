extends "res://tests/route_leg_insert_smoke.gd"
# Reuse the authored-route input/render/disk helpers; override the inherited run.

func set_arrival_facing(view: Control, leg_index: int, direction: Vector2) -> bool:
    var destinations := route_destinations(view.simulation, "UKR_S1")
    if leg_index < 0 or leg_index >= destinations.size():
        return false
    click(screen(view, destinations[leg_index]))
    await process_frame
    if view.route_leg_edit_index != leg_index:
        return false
    click(view.facing_button.get_global_rect().get_center())
    await process_frame
    if not view.facing_armed:
        return false
    # A long cardinal ray keeps projection/terrain rounding below the one-degree
    # whole-bearing threshold while still exercising the real ground picker.
    click(screen(view, destinations[leg_index] + direction * 80.0))
    await process_frame
    return not view.facing_armed

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
    frame(view,Vector2(250,255),200)

    # Real route input plus the contextual FACE control authors three arrival
    # bearings. Planning changes metadata only; the squad keeps its live bearing.
    click(view.movement_buttons["move"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(210,245)),MOUSE_BUTTON_RIGHT)
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
    var authority_before: Dictionary = sim.state.duplicate(true)
    var events_before: Array = sim.last_events.duplicate(true)
    seed(73911)
    var first_random := randi()
    check(await set_arrival_facing(view,0,Vector2.RIGHT), "Actual marker/FACE/ground input assigns LEG 1's east arrival bearing.")
    check(await set_arrival_facing(view,1,Vector2.DOWN), "Actual marker/FACE/ground input assigns LEG 2's south arrival bearing.")
    check(await set_arrival_facing(view,2,Vector2.LEFT), "Actual marker/FACE/ground input assigns LEG 3's west arrival bearing.")
    var west_heading := int(sim.state["route_facings"]["UKR_S1"][2])
    var second_random := randi()
    check(sim.state["version"] == 29 and sim.state["route_facings"]["UKR_S1"] == [90,180,west_heading] and abs(west_heading - 270) <= 1, "Fresh v29 stores one optional whole-degree arrival bearing per authored leg.")
    check(sim.facing("UKR_S1") == 0 and sim.state["orders"] == authority_before["orders"] and sim.state["route_legs"] == authority_before["route_legs"] and sim.state["route_modes"] == authority_before["route_modes"] and sim.state["route_pauses"] == authority_before["route_pauses"] and sim.last_events == events_before, "Authoring arrival bearings does not move, reroute, retime or emit combat events.")
    seed(73911)
    check(first_random == randi() and second_random == randi(), "Arrival-facing planning consumes no global RNG.")
    check(authored_labels(view) == ["LEG 1 MOVE\nFACE 090°\nWAIT 15s","LEG 2 QUICK\nFACE 180°","LEG 3 HUNT [EDIT]\nFACE %03d°" % west_heading], "Gold nodes visibly pair each arrival bearing with its exact authored destination.")
    check(view.facing_button.text == "CLEAR %03d°" % west_heading and "ARRIVE %03d°" % west_heading in view.report_label.text, "Selected-leg controls distinguish its queued arrival bearing from the squad's current FACE order.")

    # An existing contextual bearing clears explicitly, then can be replaced.
    click(view.facing_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["route_facings"]["UKR_S1"] == [90,180,-1] and view.facing_button.text == "ARRIVAL FACE", "The numbered arrival bearing can be cleared back to KEEP without touching current facing.")
    click(view.facing_button.get_global_rect().get_center())
    await process_frame
    check(view.facing_armed and "Activates only when that node is reached" in view.report_label.text, "The empty arrival-facing control clearly enters a node-relative direction cursor.")
    var selected_destination: Vector2 = route_destinations(sim,"UKR_S1")[2]
    click(screen(view,selected_destination + Vector2.LEFT * 80.0))
    await process_frame
    west_heading = int(sim.state["route_facings"]["UKR_S1"][2])
    check(sim.state["route_facings"]["UKR_S1"].slice(0,2) == [90,180] and abs(west_heading - 270) <= 1 and not view.facing_armed, "A replacement direction is measured from the authored destination, not the squad's current position.")
    await capture("route-facing-planning-preview")

    # Retarget preserves the selected intent's facing; insertion creates KEEP;
    # removal then deletes only the matching metadata entry.
    var destinations := route_destinations(sim,"UKR_S1")
    var route_before: Array = sim.state["orders"]["UKR_S1"].duplicate(true)
    check(sim.order_retarget_leg("UKR_S1",Vector2(250,280),1) and sim.state["route_facings"]["UKR_S1"] == [90,180,west_heading], "Retargeting carries the facing with the same authored intent.")
    check(sim.order_insert_leg("UKR_S1",Vector2(230,270),1) and sim.state["route_facings"]["UKR_S1"] == [90,-1,180,west_heading], "Insertion adds KEEP while every original destination retains its paired bearing.")
    check(sim.order_remove_leg("UKR_S1",1) and sim.state["route_facings"]["UKR_S1"] == [90,180,west_heading], "Selected-leg removal drops only the inserted KEEP entry and reconnects later intent.")
    check(route_destinations(sim,"UKR_S1")[0] == destinations[0] and route_destinations(sim,"UKR_S1")[1].distance_to(Vector2(250,280)) < 5.0 and not same(route_before,sim.state["orders"]["UKR_S1"]), "Route edits change only their established geometry while destination-facing ownership remains stable.")
    check(Battle.validate(sim.state,PAYLOAD), "The edited arrival-facing command is a strict valid v29 snapshot.")

    for index in range(11):
        var bad: Dictionary = sim.state.duplicate(true)
        match index:
            0: bad.erase("route_facings")
            1: bad["route_facings"].erase("UKR_S1")
            2: bad["route_facings"]["UKR_S1"] = []
            3: bad["route_facings"]["UKR_S1"] = [90,180]
            4: bad["route_facings"]["UKR_S1"] = [90,180,270,-1]
            5: bad["route_facings"]["UKR_S1"] = [90,-2,270]
            6: bad["route_facings"]["UKR_S1"] = [90,360,270]
            7: bad["route_facings"]["UKR_S1"] = [90,180.5,270]
            8: bad["route_facings"]["UKR_S1"] = [90,"south",270]
            9: bad["route_facings"]["UNKNOWN"] = [-1]
            10: bad["route_facings"]["RU_S1"] = [-1]
        check(not Battle.validate(bad,PAYLOAD), "Malformed v29 route-facing state rejects case%d." % index)

    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_leg_facing("UKR_S1",Vector2(250,280),1) and not sim.order_leg_facing("UKR_S1",Vector2(260,280),-1) and not sim.order_leg_facing("UKR_S1",Vector2(260,280),3) and not sim.order_leg_facing("RU_S1",Vector2(350,300),0) and same(intact,sim.state), "Coincident, bad-index and enemy arrival-facing commands reject atomically.")

    # V28 retains its exact field shape and never invents a boundary facing.
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 28
    legacy.state.erase("route_facings")
    legacy.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    check(legacy.order_move("UKR_S1",Vector2(102,100),true,"move") and Battle.validate(legacy.state,PAYLOAD), "V28 authors its original route without route-facing metadata.")
    var legacy_before: Dictionary = legacy.state.duplicate(true)
    check(not legacy.order_leg_facing("UKR_S1",Vector2(120,100),0) and same(legacy_before,legacy.state), "V28 rejects arrival facing without migration.")
    legacy.state["command_remaining"]["UKR_S1"] = 0
    check(legacy.execute(), "V28 boundary fixture begins execution.")
    legacy.step()
    check(legacy.facing("UKR_S1") == 0 and not legacy.state.has("route_facings") and Battle.validate(legacy.state,PAYLOAD), "A V28 arrival keeps the original current bearing and exact saved shape.")

    # Controlled one-point legs prove KEEP and explicit bearings activate only
    # at their own exact authored boundaries, including the final destination.
    var pacing = Battle.new()
    pacing.setup(PAYLOAD)
    for squad in pacing.state["squads"]: squad["ammo"] = 0
    pacing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    pacing.state["orders"]["UKR_S1"] = [[102.0,100.0],[105.0,100.0],[107.0,100.0]]
    pacing.state["movement_modes"]["UKR_S1"] = "move"
    pacing.state["route_legs"]["UKR_S1"] = [1,1,1]
    pacing.state["route_modes"]["UKR_S1"] = ["move","quick","move"]
    pacing.state["route_pauses"]["UKR_S1"] = [0,0,0]
    pacing.state["route_facings"]["UKR_S1"] = [90,-1,270]
    pacing.state["command_remaining"]["UKR_S1"] = 0
    check(Battle.validate(pacing.state,PAYLOAD) and pacing.execute(), "Boundary fixture starts from a strict mixed-facing v29 route.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.facing("UKR_S1") == 90 and pacing.state["route_facings"]["UKR_S1"] == [-1,270], "LEG 1 applies east facing only on exact arrival.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(105,100) and pacing.facing("UKR_S1") == 90 and pacing.state["route_facings"]["UKR_S1"] == [270], "KEEP at LEG 2 preserves the arrived east bearing.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(107,100) and pacing.facing("UKR_S1") == 270 and not pacing.state["route_facings"].has("UKR_S1") and Battle.validate(pacing.state,PAYLOAD), "The final LEG 3 applies west facing before canonical route cleanup.")

    # Arrival facing is active before this same second's attack collection.
    var firing = Battle.new()
    firing.setup(PAYLOAD)
    for squad in firing.state["squads"]: squad["ammo"] = 0
    firing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    firing.squad_by_id("UKR_S1")["ammo"] = 9
    firing.squad_by_id("RU_S1")["position"] = [160.0,100.0]
    firing.state["orders"]["UKR_S1"] = [[102.0,100.0]]
    firing.state["movement_modes"]["UKR_S1"] = "move"
    firing.state["route_legs"]["UKR_S1"] = [1]
    firing.state["route_modes"]["UKR_S1"] = ["move"]
    firing.state["route_pauses"]["UKR_S1"] = [0]
    firing.state["route_facings"]["UKR_S1"] = [90]
    firing.state["facing_orders"]["UKR_S1"] = {"heading":0,"width":90}
    firing.state["command_remaining"]["UKR_S1"] = 0
    check(firing.execute(), "Same-tick fire fixture begins execution.")
    firing.state["elapsed"] = 2
    firing.state["remaining"] = 58
    firing.state["acquisition"]["UKR_S1"]["RU_S1"] = 2
    check(Battle.validate(firing.state,PAYLOAD), "Same-tick fire fixture remains strict immediately before the boundary.")
    firing.step()
    var boundary_shot := false
    for event in firing.last_events:
        if event.get("type") == "shot" and event.get("shooter") == "UKR_S1": boundary_shot = true
    check(firing.facing("UKR_S1") == 90 and boundary_shot and int(firing.squad_by_id("UKR_S1")["ammo"]) == 0, "Arrival facing opens the east 90° arc before that boundary second's real rifle volley.")

    # Real disk I/O retains authority while transient marker/cursor state clears.
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://route_facings_%d.json" % Time.get_ticks_usec()
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
    check(same(disk_snapshot,restored.state) and Battle.validate(restored.state,PAYLOAD) and view.route_leg_edit_index == -1 and not view.facing_armed, "Disk reopen preserves v29 route facings exactly and discards transient edit/cursor state.")
    check(authored_labels(view) == ["LEG 1 MOVE\nFACE 090°\nWAIT 15s","LEG 2 QUICK\nFACE 180°","LEG 3 HUNT\nFACE %03d°" % west_heading], "Reopened gold nodes reconstruct the exact destination-facing metadata.")
    view.queue_free()
    await process_frame

    # Complete real combat with arrival bearings and compare every rendered tick
    # to an unrendered twin through witnessed fire and the readable report.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and combat.order_leg_pause("UKR_S1",15,1) and combat.order_move("UKR_S1",Vector2(280,245),true,"hunt",true), "Combat fixture authors three mixed legs.")
    check(combat.order_leg_facing("UKR_S1",Vector2(230,245),0) and combat.order_leg_facing("UKR_S1",Vector2(250,280),1) and combat.order_leg_facing("UKR_S1",Vector2(256,245),2) and Battle.validate(combat.state,PAYLOAD), "Combat fixture pairs east/south/west arrival bearings without changing its route.")
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
            check(twin.execute(), "Twin begins the next arrival-facing interval.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every arrival-facing combat tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(225,255),150)
            print("ROUTE FACING EXECUTION: elapsed=",combat.state["elapsed"]," facing=",combat.facing("UKR_S1")," queued=",combat.state["route_facings"].get("UKR_S1",[])," shots=",view.shot_cues.size())
            await capture("route-facing-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Arrival-facing orders reach the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Arrival-facing execution retains the readable completed battle report.")
    await capture("route-facing-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: v29 optional per-leg arrival facing, actual input/labels, strict saves, route-edit ownership, exact same-tick boundary activation, v28 isolation, disk restart and full combat parity.")
    quit(0 if failures.is_empty() else 1)
