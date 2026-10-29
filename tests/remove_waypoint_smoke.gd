extends "res://tests/terrain_probe_smoke.gd"
# Reuse actual input/render/disk helpers; override the inherited run.

func authored_labels(view: Control) -> Array[String]:
    var labels: Array[String] = []
    for child in view.order_preview.get_children():
        if child is Label3D and child.text.begins_with("LEG "):
            labels.append(child.text)
    return labels

func v26(sim: RefCounted) -> void:
    sim.state["version"] = 26
    sim.state.erase("route_modes")
    sim.state.erase("route_pauses")

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    v26(sim)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    var view = View.new()
    view.simulation = sim
    root.add_child(view)
    await process_frame
    view.set_process(false)
    frame(view,Vector2(220,245),170)

    check(view.remove_waypoint_button.text == "REMOVE LAST WAYPOINT", "The planning command names the exact route operation.")
    check(view.remove_waypoint_button.disabled, "Remove is disabled when the selected friendly has no editable route.")
    print("COMMAND ROW: hold=",view.hold_button.position,"/",view.hold_button.size," pause=",view.pause_button.position,"/",view.pause_button.size," remove=",view.remove_waypoint_button.position,"/",view.remove_waypoint_button.size)
    check(view.hold_button.position.x + view.hold_button.size.x < view.pause_button.position.x + 1.0 and view.pause_button.position.x + view.pause_button.size.x < view.remove_waypoint_button.position.x + 1.0 and view.remove_waypoint_button.position.x + view.remove_waypoint_button.size.x <= 1234.0, "HOLD, PAUSE and REMOVE remain separate inside the 720p command panel.")

    # Exercise the actual replace, Shift-append, pause and removal controls.
    click(view.movement_buttons["hunt"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(210,245)),MOUSE_BUTTON_RIGHT)
    await process_frame
    var replaced: Array = sim.state["orders"]["UKR_S1"].duplicate(true)
    click(screen(view,Vector2(250,245)),MOUSE_BUTTON_RIGHT,true)
    await process_frame
    click(view.pause_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["orders"]["UKR_S1"].size() > replaced.size() and sim.state["route_legs"]["UKR_S1"] == [replaced.size(),sim.state["orders"]["UKR_S1"].size()-replaced.size()] and sim.movement_mode("UKR_S1") == "hunt" and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 5, "Actual right/Shift-right HUNT plus PAUSE stores two exact authored legs.")
    check(authored_labels(view) == ["LEG 1","LEG 2"], "Both authored destinations have distinct numbered planning markers.")
    var intact_append: Dictionary = sim.state.duplicate(true)
    check(not sim.order_move("UKR_S1",Vector2(270,245),true,"quick",true) and same(intact_append,sim.state), "A mismatched-mode append rejects without corrupting authored boundaries.")
    check(not sim.order_move("UKR_S1",Vector2(230,160),true,"hunt",true) and same(intact_append,sim.state), "A blocked append rejects atomically with both prior legs intact.")
    check(not view.remove_waypoint_button.disabled, "A selected friendly route enables removal.")
    sim.state["command_remaining"]["UKR_S1"] = 2
    view._refresh()
    var full_path: Array = sim.state["orders"]["UKR_S1"].duplicate(true)
    var full_legs: Array = sim.state["route_legs"]["UKR_S1"].duplicate()
    var expected_path: Array = full_path.slice(0,full_path.size()-int(full_legs.back()))
    var expected: Dictionary = sim.state.duplicate(true)
    expected["orders"]["UKR_S1"] = expected_path
    expected["route_legs"]["UKR_S1"] = [int(full_legs[0])]
    var position_before: Vector2 = Battle.position(sim.squad_by_id("UKR_S1"))
    var events: Array = sim.last_events.duplicate(true)
    seed(73041)
    var first_random := randi()
    click(view.remove_waypoint_button.get_global_rect().get_center())
    await process_frame
    var second_random := randi()
    seed(73041)
    check(first_random == randi() and second_random == randi(), "Actual removal consumes no global RNG samples.")
    check(same(expected,sim.state) and same(events,sim.last_events), "Removal changes exactly the stored final leg and no other authority or event.")
    check(sim.state["orders"]["UKR_S1"] == replaced and sim.state["route_legs"]["UKR_S1"] == [replaced.size()] and Battle.position(sim.squad_by_id("UKR_S1")) == position_before, "The complete appended click-leg is removed without rerouting or moving the squad.")
    check(sim.movement_mode("UKR_S1") == "hunt" and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 2, "Earlier route, HUNT, timed pause and earned response time survive removal.")
    var retained := Vector2(float(expected_path.back()[0]),float(expected_path.back()[1]))
    check(authored_labels(view) == ["LEG 1"], "The removed authored node disappears while the retained node stays distinct.")
    var preview_end: Vector3 = view.order_preview.get_child(view.order_preview.get_child_count()-1).position
    check(Vector2(preview_end.x,preview_end.z).distance_to(retained) < 0.1, "The live dotted route and authored marker end at the retained previous destination.")
    print("REMOVE ROUTE LEG: points=",full_path.size()," -> ",expected_path.size()," legs=",full_legs," -> ",sim.state["route_legs"]["UKR_S1"]," final=",retained," mode=",sim.movement_mode("UKR_S1")," pause=",sim.state["pause_remaining"]["UKR_S1"]," response=",sim.state["command_remaining"]["UKR_S1"])
    await capture("remove-waypoint-planning-preview")

    # A live hypothetical LOS origin follows the shortened route rather than a
    # cached removed point. Removing the final remaining leg uses HOLD cleanup.
    click(view.los_button.get_global_rect().get_center())
    await process_frame
    click(view.los_origin_button.get_global_rect().get_center())
    await process_frame
    view.los_point = Vector2(300,245)
    view._refresh_los_probe()
    check(view.los_from_waypoint and view._terrain_probe(view.los_point)["origin"] == retained, "Hypothetical LOS immediately derives from the shortened route.")
    check(sim.state["route_legs"]["UKR_S1"].size() == 1 and sim.state["orders"]["UKR_S1"].size() > 1 and not view.remove_waypoint_button.disabled, "One authored leg remains editable even when pathfinding stored several points.")
    click(view.remove_waypoint_button.get_global_rect().get_center())
    await process_frame
    check(not sim.state["orders"].has("UKR_S1") and not sim.state["movement_modes"].has("UKR_S1") and not sim.state["route_legs"].has("UKR_S1") and int(sim.state["pause_remaining"]["UKR_S1"]) == 0 and int(sim.state["command_remaining"]["UKR_S1"]) == 0, "One-leg removal reuses complete HOLD cleanup semantics.")
    check(view.remove_waypoint_button.disabled and view.order_preview.get_child_count() == 0 and view.los_from_waypoint and view.los_preview.get_child_count() == 0 and view.los_label.text.contains("NO QUEUED DESTINATION"), "The final removal clears route geometry and any stale hypothetical probe without falling back to the squad.")

    # Direct boundary/rejection coverage proves bad contexts are no-ops.
    var boundary = Battle.new()
    boundary.setup(PAYLOAD)
    v26(boundary)
    var untouched: Dictionary = boundary.state.duplicate(true)
    check(not boundary.order_remove_last_waypoint("UKR_S1") and same(untouched,boundary.state), "An absent route rejects without mutation.")
    check(not boundary.order_remove_last_waypoint("UNKNOWN") and same(untouched,boundary.state), "An unknown squad rejects without mutation.")
    check(boundary.order_move("RU_S1",Vector2(350,350),false), "Enemy rejection fixture can receive its normal AI route.")
    untouched = boundary.state.duplicate(true)
    check(not boundary.order_remove_last_waypoint("RU_S1") and same(untouched,boundary.state), "A player cannot edit an enemy route.")
    boundary.state["phase"] = "execution"
    boundary.state["remaining"] = 60
    untouched = boundary.state.duplicate(true)
    check(not boundary.order_remove_last_waypoint("RU_S1") and same(untouched,boundary.state), "Execution rejects removal without mutation.")
    boundary.setup(PAYLOAD)
    v26(boundary)
    check(boundary.order_move("UKR_S1",Vector2(210,245)), "Elimination and morale rejection fixture has a friendly route.")
    boundary.squad_by_id("UKR_S1")["alive"] = 0
    untouched = boundary.state.duplicate(true)
    check(not boundary.order_remove_last_waypoint("UKR_S1") and same(untouched,boundary.state), "An eliminated squad's route cannot be edited.")
    boundary.squad_by_id("UKR_S1")["alive"] = 9
    boundary.state["morale_states"]["UKR_S1"] = "broken"
    untouched = boundary.state.duplicate(true)
    check(not boundary.order_remove_last_waypoint("UKR_S1") and same(untouched,boundary.state), "A broken squad's withdrawal route cannot be edited.")
    boundary.state["morale_states"]["UKR_S1"] = "steady"
    boundary.state["orders"]["UKR_S1"] = []
    boundary.state["movement_modes"].erase("UKR_S1")
    boundary.state["route_legs"].erase("UKR_S1")
    untouched = boundary.state.duplicate(true)
    check(not boundary.order_remove_last_waypoint("UKR_S1") and same(untouched,boundary.state), "An empty malformed route rejects without expanding the mutation surface.")
    boundary.state["orders"]["UKR_S1"] = []
    for index in range(128):
        boundary.state["orders"]["UKR_S1"].append([200.0,245.0])
    boundary.state["movement_modes"]["UKR_S1"] = "quick"
    boundary.state["route_legs"]["UKR_S1"] = [64,64]
    boundary.state["pause_remaining"]["UKR_S1"] = 30
    boundary.state["command_remaining"]["UKR_S1"] = 0
    check(Battle.validate(boundary.state,PAYLOAD) and boundary.order_remove_last_waypoint("UKR_S1") and boundary.state["orders"]["UKR_S1"].size() == 64 and boundary.state["route_legs"]["UKR_S1"] == [64] and Battle.validate(boundary.state,PAYLOAD), "The 128-point boundary removes its complete 64-point tail leg and remains strictly valid.")
    check(boundary.movement_mode("UKR_S1") == "quick" and int(boundary.state["pause_remaining"]["UKR_S1"]) == 30 and int(boundary.state["command_remaining"]["UKR_S1"]) == 0, "A fully earned response time remains earned at the path boundary.")

    # Strict v26 validation rejects missing, extra, non-integral, zero and
    # inconsistent route-leg metadata before a restore can infer boundaries.
    var valid_route: Dictionary = boundary.state.duplicate(true)
    for index in range(9):
        var bad: Dictionary = valid_route.duplicate(true)
        match index:
            0: bad.erase("route_legs")
            1: bad["route_legs"].erase("UKR_S1")
            2: bad["route_legs"]["UKR_S1"] = []
            3: bad["route_legs"]["UKR_S1"] = [0]
            4: bad["route_legs"]["UKR_S1"] = [63]
            5: bad["route_legs"]["UKR_S1"] = [64.5]
            6: bad["route_legs"]["UNKNOWN"] = [1]
            7: bad["route_legs"]["RU_S1"] = [1]
            8: bad["route_legs"]["UKR_S1"] = [129]
        check(not Battle.validate(bad,PAYLOAD), "Malformed v26 route-leg state rejects case%d." % index)

    # V25 retains its exact field shape and single-stored-point removal rules.
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 25
    legacy.state.erase("route_modes")
    legacy.state.erase("route_pauses")
    if int(legacy.state["version"]) < 26: legacy.state.erase("route_legs")
    if int(legacy.state["version"]) < 27: legacy.state.erase("route_modes")
    legacy.state.erase("route_legs")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"quick") and legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true), "Legacy v25 fixture builds its original flattened route.")
    var legacy_size: int = legacy.state["orders"]["UKR_S1"].size()
    check(Battle.validate(legacy.state,PAYLOAD) and legacy.order_remove_last_waypoint("UKR_S1") and legacy.state["orders"]["UKR_S1"].size() == legacy_size - 1 and not legacy.state.has("route_legs") and Battle.validate(legacy.state,PAYLOAD), "V25 removal still pops one stored coordinate without silent migration.")
    var legacy_restart = Battle.new()
    legacy_restart.restore(JSON.parse_string(JSON.stringify(legacy.state)))
    check(same(legacy.state,legacy_restart.state) and legacy_restart.state["version"] == 25 and not legacy_restart.state.has("route_legs"), "A v25 JSON restart remains byte-shape compatible and unmigrated.")

    # Persist a shortened multi-point route and verify a fresh view reconstructs
    # the button lifecycle, authored marker and preview solely from saved v26 data.
    sim.setup(PAYLOAD)
    v26(sim)
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    check(sim.order_move("UKR_S1",Vector2(210,245),true,"quick") and sim.order_move("UKR_S1",Vector2(250,245),true,"quick",true) and sim.order_pause("UKR_S1",30), "Disk fixture has a multi-point QUICK route and pause.")
    sim.state["command_remaining"]["UKR_S1"] = 1
    check(sim.order_remove_last_waypoint("UKR_S1") and Battle.validate(sim.state,PAYLOAD), "Disk fixture is shortened and strictly valid.")
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://remove_waypoint_%d.json" % Time.get_ticks_usec()
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
    check(same(disk_snapshot,restored.state) and not view.remove_waypoint_button.disabled and authored_labels(view) == ["LEG 1"] and view.order_preview.get_child_count() > 0, "Disk reopen preserves the shortened route and reconstructs its exact authored marker/UI state.")
    check(restored.movement_mode("UKR_S1") == "quick" and int(restored.state["pause_remaining"]["UKR_S1"]) == 30 and int(restored.state["command_remaining"]["UKR_S1"]) == 1, "Disk reopen preserves mode, pause and earned response time exactly.")
    view.queue_free()
    await process_frame

    # Resume the edited route through actual execution and full combat. The
    # rendered view must remain tick-identical to a headless twin.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    v26(combat)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(210,245),true,"hunt") and combat.order_move("UKR_S1",Vector2(250,245),true,"hunt",true) and combat.order_pause("UKR_S1",15) and combat.order_remove_last_waypoint("UKR_S1"), "Combat fixture starts from a genuinely shortened HUNT route.")
    check(Battle.validate(combat.state,PAYLOAD), "The resumed combat candidate is a strict valid save.")
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
            check(twin.execute(), "Twin begins the next interval after route editing.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
            check(view.remove_waypoint_button.disabled, "Removal is disabled throughout execution.")
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every resumed execution tick validates and matches the unrendered edited-route twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(210,245),140)
            print("REMOVE WAYPOINT EXECUTION: elapsed=",combat.state["elapsed"]," shots=",view.shot_cues.size()," blue=",combat.alive("UKR")," red=",combat.alive("RU"))
            await capture("remove-waypoint-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Edited route reaches the exact valid full battle result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible and view.remove_waypoint_button.disabled, "The readable completed report has no editable route control.")
    await capture("remove-waypoint-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: v26 authored-leg replace/append/remove/HOLD, numbered planning markers, strict boundaries, v25 compatibility, RNG isolation, disk reopen and full execution/result twin parity.")
    quit(0 if failures.is_empty() else 1)
