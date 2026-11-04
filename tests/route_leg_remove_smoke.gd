extends "res://tests/route_leg_retarget_smoke.gd"
# Reuse the route/input/render helpers; override the inherited run.

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

    # Author four mixed legs through real controls, select the earlier second
    # gold marker, and remove that exact leg through the numbered button.
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
    click(view.movement_buttons["move"].get_global_rect().get_center())
    await process_frame
    click(screen(view,Vector2(315,270)),MOUSE_BUTTON_RIGHT,true)
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
    check(view.route_leg_edit_index == 1 and view.remove_waypoint_button.text == "REMOVE L2", "Selecting an earlier marker names the exact leg that REMOVE will delete.")
    check("REMOVE L2 deletes" in view.report_label.text and "selected LEG 2" in view.remove_waypoint_button.tooltip_text, "Planning help and tooltip make selected-leg deletion explicit before mutation.")
    await capture("route-remove-planning-preview")
    seed(73617)
    var first_random := randi()
    click(view.remove_waypoint_button.get_global_rect().get_center())
    await process_frame
    var second_random := randi()
    var after_destinations := route_destinations(sim,"UKR_S1")
    check(view.route_leg_edit_index == -1 and view.remove_waypoint_button.text == "REMOVE LEG", "Successful selected removal clears only transient edit selection.")
    check(after_destinations == [before_destinations[0],before_destinations[2],before_destinations[3]], "The selected destination disappears while every earlier and later authored destination stays exact.")
    check(sim.state["orders"]["UKR_S1"].slice(0,prefix_size) == before_path.slice(0,prefix_size) and int(sim.state["route_legs"]["UKR_S1"][0]) == int(before_legs[0]), "All geometry before the removed leg remains byte-shape exact.")
    check(not same(before_path,sim.state["orders"]["UKR_S1"]) and sim.state["route_legs"]["UKR_S1"].size() == 3, "The gap and retained later segments reconnect deterministically under three new boundaries.")
    var expected: Dictionary = before.duplicate(true)
    expected["orders"]["UKR_S1"] = sim.state["orders"]["UKR_S1"].duplicate(true)
    expected["route_legs"]["UKR_S1"] = sim.state["route_legs"]["UKR_S1"].duplicate()
    expected["route_modes"]["UKR_S1"] = ["move","hunt","move"]
    expected["route_pauses"]["UKR_S1"] = [15,30,15]
    expected["route_facings"]["UKR_S1"] = [-1,-1,-1]
    check(same(expected,sim.state) and same(before_events,sim.last_events), "Removal changes only route geometry/boundaries and the selected paired mode/wait entries.")
    check(sim.movement_mode("UKR_S1") == "move" and int(sim.state["pause_remaining"]["UKR_S1"]) == 15 and int(sim.state["command_remaining"]["UKR_S1"]) == 2, "The retained active mode, start wait and earned response remain exact.")
    check(authored_labels(view) == ["LEG 1 MOVE\nWAIT 30s","LEG 2 HUNT\nWAIT 15s","LEG 3 MOVE"] and Battle.validate(sim.state,PAYLOAD), "The refreshed gold nodes visibly pair retained modes and waits in a strict v29 save.")
    seed(73617)
    check(first_random == randi() and second_random == randi(), "Selected-leg removal consumes no global RNG.")
    print("ROUTE REMOVE: points=",before_path.size()," -> ",sim.state["orders"]["UKR_S1"].size()," legs=",before_legs," -> ",sim.state["route_legs"]["UKR_S1"]," retained=",after_destinations," response=",sim.state["command_remaining"]["UKR_S1"])
    await capture("route-remove-result-preview")

    # Invalid contexts and older rules reject atomically. A valid 128-point
    # fixture proves a reconnect that would exceed the cap cannot truncate state.
    var intact: Dictionary = sim.state.duplicate(true)
    check(not sim.order_remove_leg("UKR_S1",-1) and not sim.order_remove_leg("UKR_S1",3) and not sim.order_remove_leg("RU_S1",0) and same(intact,sim.state), "Bad indexes and enemy routes reject selected removal atomically.")
    var legacy = Battle.new()
    legacy.setup(PAYLOAD)
    legacy.state["version"] = 27
    legacy.state.erase("route_pauses")
    legacy.state.erase("route_facings")
    legacy.squad_by_id("UKR_S1")["position"] = [180,245]
    check(legacy.order_move("UKR_S1",Vector2(210,245),true,"move") and legacy.order_move("UKR_S1",Vector2(250,245),true,"quick",true), "V27 isolation fixture authors its original mixed route.")
    var legacy_before: Dictionary = legacy.state.duplicate(true)
    check(not legacy.order_remove_leg("UKR_S1",0) and same(legacy_before,legacy.state) and Battle.validate(legacy.state,PAYLOAD), "V27 rejects selected removal without migration or field changes.")

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
    check(Battle.validate(limit.state,PAYLOAD), "The 128-point reconnect fixture is a strict v29 save.")
    var limit_before: Dictionary = limit.state.duplicate(true)
    check(not limit.order_remove_leg("UKR_S1",1) and same(limit_before,limit.state), "A reconnect exceeding 128 points rejects without truncating later intent or metadata.")

    # Removing LEG 1 promotes the next retained leg's mode and wait to the
    # execution-facing fields; removing the tail stays exactly equivalent to the
    # established last-leg command, and a one-leg route still uses HOLD cleanup.
    var first = Battle.new()
    first.setup(PAYLOAD)
    for squad in first.state["squads"]: squad["ammo"] = 0
    first.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    check(first.order_move("UKR_S1",Vector2(108,100),true,"move") and first.order_pause("UKR_S1",15) and first.order_move("UKR_S1",Vector2(116,100),true,"quick",true) and first.order_leg_pause("UKR_S1",30,1) and first.order_move("UKR_S1",Vector2(128,100),true,"hunt",true), "First-leg fixture authors three mixed legs and waits.")
    var first_destinations := route_destinations(first,"UKR_S1")
    first.state["command_remaining"]["UKR_S1"] = 2
    check(first.order_remove_leg("UKR_S1",0), "The active first authored leg can be removed in planning.")
    check(route_destinations(first,"UKR_S1") == [first_destinations[1],first_destinations[2]] and first.state["route_modes"]["UKR_S1"] == ["quick","hunt"] and first.state["route_pauses"]["UKR_S1"] == [30,0], "LEG 1 removal retains both later destinations and their paired metadata.")
    check(first.movement_mode("UKR_S1") == "quick" and int(first.state["pause_remaining"]["UKR_S1"]) == 30 and int(first.state["command_remaining"]["UKR_S1"]) == 2 and Battle.validate(first.state,PAYLOAD), "The promoted first mode/wait mirror strict v29 active fields without resetting response.")
    first.state["command_remaining"]["UKR_S1"] = 0
    check(first.execute(), "Promoted first-leg fixture begins execution.")
    first.step()
    check(Battle.position(first.squad_by_id("UKR_S1")) == Vector2(100,100) and int(first.state["pause_remaining"]["UKR_S1"]) == 29, "The retained later wait now counts down at the current position before its promoted QUICK leg.")

    var tail_a = Battle.new()
    tail_a.restore(sim.state)
    var tail_b = Battle.new()
    tail_b.restore(sim.state)
    check(tail_a.order_remove_leg("UKR_S1",2) and tail_b.order_remove_last_waypoint("UKR_S1") and same(tail_a.state,tail_b.state), "Selecting the final leg remains exactly equivalent to established tail removal.")
    var single = Battle.new()
    single.setup(PAYLOAD)
    check(single.order_move("UKR_S1",Vector2(210,245),true,"hunt") and single.order_pause("UKR_S1",15) and single.order_remove_leg("UKR_S1",0), "A one-leg selected route delegates to canonical HOLD cleanup.")
    check(not single.state["orders"].has("UKR_S1") and not single.state["route_legs"].has("UKR_S1") and not single.state["route_modes"].has("UKR_S1") and not single.state["route_pauses"].has("UKR_S1") and not single.state["route_facings"].has("UKR_S1") and int(single.state["pause_remaining"]["UKR_S1"]) == 0 and int(single.state["command_remaining"]["UKR_S1"]) == 0, "Final selected removal clears every route field, wait and response exactly like HOLD.")

    # A controlled no-ammunition route proves the retained later wait/mode
    # activates at the prior retained node after the removed gap is reconnected.
    var pacing = Battle.new()
    pacing.setup(PAYLOAD)
    for squad in pacing.state["squads"]: squad["ammo"] = 0
    pacing.squad_by_id("UKR_S1")["position"] = [100.0,100.0]
    pacing.state["orders"]["UKR_S1"] = [[102.0,100.0],[110.0,100.0],[118.0,100.0]]
    pacing.state["movement_modes"]["UKR_S1"] = "move"
    pacing.state["route_legs"]["UKR_S1"] = [1,1,1]
    pacing.state["route_modes"]["UKR_S1"] = ["move","quick","hunt"]
    pacing.state["route_pauses"]["UKR_S1"] = [0,2,3]
    pacing.state["route_facings"]["UKR_S1"] = [-1,-1,-1]
    pacing.state["command_remaining"]["UKR_S1"] = 0
    check(Battle.validate(pacing.state,PAYLOAD) and pacing.order_remove_leg("UKR_S1",1) and pacing.execute(), "Boundary fixture removes its middle leg and begins from a strict reconnected route.")
    pacing.step()
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and pacing.movement_mode("UKR_S1") == "hunt" and int(pacing.state["pause_remaining"]["UKR_S1"]) == 3, "Arrival at the retained prior node activates the retained later HUNT/3s wait without entering the reconnected leg.")
    for remaining in [2,1,0]:
        pacing.step()
        check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(102,100) and int(pacing.state["pause_remaining"]["UKR_S1"]) == remaining, "Each retained wait second remains stationary at the correct boundary.")
    for tick in range(30):
        pacing.step()
        if not pacing.state["orders"].has("UKR_S1"): break
    check(Battle.position(pacing.squad_by_id("UKR_S1")) == Vector2(118,100) and not pacing.state["orders"].has("UKR_S1"), "The reconnected HUNT leg reaches the unchanged later destination and completes normally.")

    # Existing v29 fields round-trip through real disk I/O; selection does not.
    var disk_snapshot: Dictionary = sim.state.duplicate(true)
    var save_path := "user://route_remove_%d.json" % Time.get_ticks_usec()
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
    check(same(disk_snapshot,restored.state) and Battle.validate(restored.state,PAYLOAD) and view.route_leg_edit_index == -1, "Disk reopen preserves the reconnected route exactly and forgets transient selection.")
    check(route_destinations(restored,"UKR_S1") == after_destinations and authored_labels(view) == ["LEG 1 MOVE\nWAIT 30s","LEG 2 HUNT\nWAIT 15s","LEG 3 MOVE"], "Reopened gold markers reconstruct only retained authored intent and metadata.")
    view.queue_free()
    await process_frame

    # Complete real combat on a route with its middle leg removed and compare
    # every rendered tick to an unrendered twin, including shots and final report.
    var combat = Battle.new()
    combat.setup(PAYLOAD)
    combat.squad_by_id("UKR_S1")["position"] = [180,245]
    combat.squad_by_id("RU_S1")["position"] = [240,245]
    check(combat.order_move("UKR_S1",Vector2(205,245),true,"move") and combat.order_move("UKR_S1",Vector2(250,280),true,"quick",true) and combat.order_leg_pause("UKR_S1",15) and combat.order_move("UKR_S1",Vector2(280,245),true,"hunt",true) and combat.order_leg_pause("UKR_S1",30), "Combat fixture starts with three authored legs and visible later metadata.")
    check(combat.order_remove_leg("UKR_S1",1) and route_destinations(combat,"UKR_S1") == [Vector2(205,245),Vector2(280,245)] and combat.state["route_modes"]["UKR_S1"] == ["move","hunt"] and combat.state["route_pauses"]["UKR_S1"] == [0,30] and Battle.validate(combat.state,PAYLOAD), "Combat fixture removes its middle leg while preserving the final endpoint and paired HUNT wait.")
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
            check(twin.execute(), "Twin begins the next interval after selected-leg removal.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._process(1.0/view.speed)
        check(same(combat.state,twin.state) and Battle.validate(combat.state,PAYLOAD), "Every reconnected-route combat tick validates and matches the unrendered twin.")
        if not captured_shot and not view.shot_cues.is_empty():
            frame(view,Vector2(225,255),150)
            print("ROUTE REMOVE EXECUTION: elapsed=",combat.state["elapsed"]," active=",combat.movement_mode("UKR_S1")," shots=",view.shot_cues.size())
            await capture("route-remove-execution-preview")
            captured_shot = true
    check(captured_shot and combat.state["phase"] == "finished" and same(combat.result(),twin.result()) and Battle.validate(combat.state,PAYLOAD), "Reconnected orders reach the exact valid completed result with real firing feedback.")
    view._reset_camera()
    check(view.completed_report_panel.visible, "Selected-leg removal retains the readable completed battle report.")
    await capture("route-remove-report-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: selected authored-leg removal, deterministic later reconnection, paired metadata, promoted first-leg fields, atomic bounds, v27 isolation, disk restart and full combat parity.")
    quit(0 if failures.is_empty() else 1)
