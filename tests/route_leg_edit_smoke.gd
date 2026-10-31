extends "res://tests/route_leg_pauses_smoke.gd"
# Reuse actual input/render/disk helpers; override the inherited v28 run.

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
    frame(view,Vector2(230,245),180)

    # Author three mixed legs through real controls. The last chosen HUNT mode
    # remains the selector for a future append and must not be changed by edits.
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
    check(sim.state["route_modes"]["UKR_S1"] == ["move","quick","hunt"] and sim.state["route_pauses"]["UKR_S1"] == [15,15,30] and view.command_mode == "hunt", "Actual input builds the three-leg edit fixture without changing v28 authority.")

    # Clicking the middle gold destination selects its corresponding authored leg.
    # Selection itself is transient and consumes neither events nor RNG.
    var before_edit: Dictionary = sim.state.duplicate(true)
    var before_events: Array = sim.last_events.duplicate(true)
    seed(73419)
    var first_random := randi()
    click(screen(view,Vector2(250,245)))
    await process_frame
    check(view.route_leg_edit_index == 1 and "LEG 2 QUICK [EDIT]\nWAIT 30s" in authored_labels(view), "A real click on the earlier gold node selects LEG 2 and visibly highlights it for editing.")
    check("EDIT LEG 2: QUICK | WAIT BEFORE 15s" in view.report_label.text and view.movement_buttons["quick"].text.ends_with("*") and view.leg_pause_button.text == "L2 15s", "Planning feedback names the selected leg's own mode and pre-leg wait.")
    check(same(before_edit,sim.state) and same(before_events,sim.last_events), "Selecting an authored leg is presentation-only and changes no saved state or event.")

    # Existing buttons now revise the selected leg rather than the next-append
    # selector. Path coordinates, boundaries, later legs and response stay exact.
    click(view.movement_buttons["move"].get_global_rect().get_center())
    await process_frame
    click(view.leg_pause_button.get_global_rect().get_center())
    await process_frame
    var expected: Dictionary = before_edit.duplicate(true)
    expected["route_modes"]["UKR_S1"][1] = "move"
    expected["route_pauses"]["UKR_S1"][1] = 30
    check(same(expected,sim.state) and same(before_events,sim.last_events), "Editing LEG 2 changes exactly its existing mode/wait entries without rerouting, time, events or later-leg mutation.")
    check(view.command_mode == "hunt" and sim.state["route_modes"]["UKR_S1"] == ["move","move","hunt"] and sim.state["route_pauses"]["UKR_S1"] == [15,30,30], "The future append selector and later HUNT/30s leg remain intact after the earlier edit.")
    check(authored_labels(view) == ["LEG 1 MOVE\nWAIT 30s","LEG 2 MOVE [EDIT]\nWAIT 30s","LEG 3 HUNT"], "Gold labels immediately show the changed inbound mode and the wait at its actual prior node.")
    var second_random := randi()
    seed(73419)
    check(first_random == randi() and second_random == randi(), "Selecting and editing an earlier leg consumes no global RNG.")

    # LEG 1 uses START for its before-leg wait and must also update the active
    # execution-facing mode while preserving every later leg.
    click(screen(view,Vector2(210,245)))
    await process_frame
    check(view.route_leg_edit_index == 0 and view.leg_pause_button.disabled and view.leg_pause_button.text == "L1=START", "Selecting LEG 1 directs its pre-leg wait to the existing START control without an ambiguous second button.")
    var route_before: Array = sim.state["orders"]["UKR_S1"].duplicate(true)
    var legs_before: Array = sim.state["route_legs"]["UKR_S1"].duplicate()
    click(view.movement_buttons["hunt"].get_global_rect().get_center())
    await process_frame
    click(view.pause_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["route_modes"]["UKR_S1"] == ["hunt","move","hunt"] and sim.movement_mode("UKR_S1") == "hunt", "Editing the first leg keeps its saved and execution-facing modes synchronized.")
    check(sim.state["route_pauses"]["UKR_S1"] == [30,30,30] and int(sim.state["pause_remaining"]["UKR_S1"]) == 30, "START edits the selected first leg's saved and active wait together.")
    check(same(route_before,sim.state["orders"]["UKR_S1"]) and same(legs_before,sim.state["route_legs"]["UKR_S1"]) and int(sim.state["command_remaining"]["UKR_S1"]) == 5, "First-leg editing leaves route geometry, boundaries and earned command response exact.")
    check(Battle.validate(sim.state,PAYLOAD), "The in-place edited route remains a strict valid tactical v28 save.")
    print("ROUTE EDIT: modes=",sim.state["route_modes"]["UKR_S1"]," waits=",sim.state["route_pauses"]["UKR_S1"]," points=",sim.state["orders"]["UKR_S1"].size()," response=",sim.state["command_remaining"]["UKR_S1"])
    await capture("route-edit-planning-preview")

    # Escape exits edit mode without undoing the authored change. Invalid direct
    # commands and older v27 saves retain their established behavior atomically.
    var edited_snapshot: Dictionary = sim.state.duplicate(true)
    escape()
    await process_frame
    check(view.route_leg_edit_index == -1 and not "[EDIT]" in "\n".join(authored_labels(view)) and same(edited_snapshot,sim.state), "Escape clears only transient edit selection and leaves the route edits committed.")
    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_leg_mode("UKR_S1","warp",1) and not sim.order_leg_mode("UKR_S1","move",-1) and not sim.order_leg_mode("UKR_S1","move",3) and not sim.order_leg_mode("RU_S1","move",0) and same(intact,sim.state), "Unknown modes, invalid indexes and enemy routes reject without mutation.")
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 27
    legacy.state.erase("route_pauses")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"move") and legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true), "V27 compatibility fixture authors its original mixed route.")
    var legacy_before: Dictionary = legacy.state.duplicate(true)
    check(not legacy.order_leg_mode("UKR_S1","hunt",1) and same(legacy_before,legacy.state) and Battle.validate(legacy.state,PAYLOAD), "V27 retains its original command behavior and exact field shape without silent editing support.")

    # A controlled route proves the edited wait and HUNT gate activate at the
    # selected earlier boundary rather than at planning time or a later node.
    var pacing = Battle.new()
    pacing.setup(PAYLOAD)
    for squad in pacing.state["squads"]: squad["ammo"] = 0
    pacing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    pacing.state["orders"]["UKR_S1"] = [[102.0,100.0],[110.0,100.0],[118.0,100.0]]
    pacing.state["movement_modes"]["UKR_S1"] = "move"
    pacing.state["route_legs"]["UKR_S1"] = [1,1,1]
    pacing.state["route_modes"]["UKR_S1"] = ["move","move","move"]
    pacing.state["route_pauses"]["UKR_S1"] = [0,0,0]
    pacing.state["command_remaining"]["UKR_S1"] = 0
    check(pacing.order_leg_mode("UKR_S1","hunt",1) and pacing.order_leg_pause("UKR_S1",2,1) and pacing.execute(), "Boundary fixture accepts an in-place earlier HUNT/2s edit before execution.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.movement_mode("UKR_S1") == "hunt" and int(pacing.state["pause_remaining"]["UKR_S1"]) == 2, "The edited leg activates at its exact authored boundary with no leftover movement.")
    pacing.step(); pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and int(pacing.state["pause_remaining"]["UKR_S1"]) == 0, "The edited two-second pre-leg wait counts down at the prior node.")
    pacing.squad_by_id("UKR_S1")["suppression"] = 0.3
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.hunt_paused(pacing.squad_by_id("UKR_S1")), "The edited HUNT leg applies its own pressure gate after the edited wait.")

    # Disk stores only the existing v28 arrays. Reopening deliberately forgets
    # edit selection while retaining the exact authored changes and labels.
    var save_path := "user://route_edit_%d.json" % Time.get_ticks_usec()
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
    check(same(edited_snapshot,restored.state) and restored.state["version"] == 28 and view.route_leg_edit_index == -1, "Disk reopen retains v28 authority exactly and discards transient leg selection.")
    check(authored_labels(view) == ["LEG 1 HUNT\nWAIT 30s","LEG 2 MOVE\nWAIT 30s","LEG 3 HUNT"], "A fresh view reconstructs every edited mode/wait without a new save field.")
    view.queue_free()
    await process_frame

    # Complete real combat with edited earlier orders and compare every rendered
    # tick to an unrendered twin, including actual shots and the final report.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and combat.order_leg_pause("UKR_S1",15) and combat.order_move("UKR_S1",Vector2(280,245),true,"move",true), "Combat fixture begins with three ordinary authored legs.")
    check(combat.order_leg_mode("UKR_S1","hunt",1) and combat.order_leg_pause("UKR_S1",30,1) and Battle.validate(combat.state,PAYLOAD), "Combat fixture revises its earlier middle leg without rerouting or invalidating the save.")
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
            check(twin.execute(), "Twin begins the next interval after in-place leg editing.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every edited-route execution tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(220,245),145)
            print("ROUTE EDIT EXECUTION: elapsed=",combat.state["elapsed"]," active=",combat.movement_mode("UKR_S1")," waits=",combat.state["route_pauses"].get("UKR_S1",[])," shots=",view.shot_cues.size())
            await capture("route-edit-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Edited earlier orders reach the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Edited-route execution retains the readable completed battle report.")
    await capture("route-edit-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: transient earlier-leg selection, in-place mode/wait editing, v27 isolation, exact boundary behavior, disk restart and full combat parity.")
    quit(0 if failures.is_empty() else 1)
