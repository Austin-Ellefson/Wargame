extends "res://tests/interval_review_smoke.gd"
# Reuse the public-review input, render and disk helpers; override its run.
var navigation_checkpoints := 0

func _count_navigation_checkpoint() -> void:
    navigation_checkpoints += 1

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [180,245]
    sim.squad_by_id("RU_S1")["position"] = [240,245]
    sim.squad_by_id("UKR_S1")["ammo"] = 360
    sim.squad_by_id("RU_S1")["ammo"] = 360
    sim.squad_by_id("RU_S4")["position"] = [470,470]
    sim.squad_by_id("RU_S4")["alive"] = 0
    check(sim.order_move("UKR_S1",Vector2(230,245)), "Navigation fixture queues real movement into a close engagement.")
    var view = await open_view(sim)
    check(view.checkpoint.connect(_count_navigation_checkpoint) == OK, "Navigation fixture observes ordinary checkpoints.")
    click(view.execute_button.get_global_rect().get_center())
    await process_frame
    var twin = Battle.new()
    twin.restore(sim.state)
    for tick in range(60):
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Recording for navigation matches the authoritative twin every tick.")
    check(sim.state["phase"] == "planning" and view.interval_review_frames.size() == 61 and navigation_checkpoints == 2, "Fixture reaches one ordinary boundary with the bounded public buffer and only normal checkpoints.")
    var public_json := JSON.stringify(view.interval_review_frames)
    check("RU_S4" not in public_json and "[470.0,470.0]" not in public_json and "[470,470]" not in public_json, "Navigation receives the same public-only buffer without the distinctive hidden actor.")
    var shot_index := -1
    for index in range(1,view.interval_review_frames.size()):
        if not view.interval_review_frames[index]["shots"].is_empty():
            shot_index = index
            break
    check(shot_index > 0, "Recorded navigation fixture contains a witnessed simulated volley after frame zero.")

    var planning_snapshot: Dictionary = sim.state.duplicate(true)
    var planning_events: Array = sim.last_events.duplicate(true)
    seed(64183)
    var first_random := randi()
    click(view.interval_review_button.get_global_rect().get_center())
    await process_frame
    check(view.reviewing_interval and view.review_index == 0 and not view.review_paused, "Actual REVIEW input starts at the first recorded frame.")
    check(view.review_previous_button.visible and view.review_restart_button.visible and not view.execute_button.visible, "Review replaces the execute row with explicit backward navigation.")
    check(view.review_previous_button.disabled and view.review_restart_button.disabled, "PREVIOUS and RESTART are bounded off at frame zero while review is running.")
    check(view.report_label.get_global_rect().end.y < 691, "Two-line navigation guidance stays above the 720p footer.")
    check(view.review_previous_button.get_global_rect().end.x < view.review_restart_button.get_global_rect().position.x + 1.0, "Review navigation controls stay separated in the command row.")
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(view.review_paused and view.review_previous_button.disabled and view.review_restart_button.disabled, "Pausing at the first frame keeps both backward controls safely bounded.")
    var initial_state: Dictionary = sim.state.duplicate(true)
    click(view.review_previous_button.get_global_rect().get_center())
    click(view.review_restart_button.get_global_rect().get_center())
    await process_frame
    check(view.review_index == 0 and same(initial_state,sim.state), "Disabled start-bound inputs cannot move the review or authority.")

    # Exercise actual forward/back/restart input at every supported display rate.
    # Restart deliberately leaves review paused so the user chooses when to run.
    for expected_speed in [4.0,8.0,1.0]:
        while view.speed != expected_speed:
            click(view.speed_button.get_global_rect().get_center())
            await process_frame
        click(view.playback_step_button.get_global_rect().get_center())
        await process_frame
        check(view.review_index == 1 and not view.review_previous_button.disabled and not view.review_restart_button.disabled, "STEP exposes bounded backward controls at %dx." % int(expected_speed))
        click(view.review_previous_button.get_global_rect().get_center())
        await process_frame
        check(view.review_index == 0 and view.review_paused and is_zero_approx(view.review_accumulator) and view.shot_cues.is_empty(), "PREVIOUS snaps to the prior public frame and clears cues at %dx." % int(expected_speed))
        click(view.playback_step_button.get_global_rect().get_center())
        await process_frame
        click(view.review_restart_button.get_global_rect().get_center())
        await process_frame
        check(view.review_index == 0 and view.review_paused and is_zero_approx(view.review_accumulator) and view.shot_cues.is_empty(), "RESTART returns paused to public frame zero without replaying a shot at %dx." % int(expected_speed))
        check(same(planning_snapshot,sim.state) and same(planning_events,sim.last_events), "Mixed navigation at %dx leaves state and live events untouched." % int(expected_speed))

    # Reaching a recorded volley forward may show it once. Moving backward must
    # immediately remove that transient witness; stepping forward may show the
    # same recorded event again without any simulator query or inverse tick.
    for index in range(shot_index):
        view._step_interval_review()
    var shot_count: int = view.interval_review_frames[shot_index]["shots"].size()
    check(view.review_index == shot_index and view.shot_cues.size() == shot_count and shot_count > 0, "Forward navigation displays only the reached frame's recorded volley.")
    click(view.review_previous_button.get_global_rect().get_center())
    await process_frame
    var rewound_unit: Dictionary = review_unit(view.interval_review_frames[view.review_index],"UKR_S1")
    check(view.review_index == shot_index - 1 and view.shot_cues.is_empty() and not view.review_complete, "PREVIOUS removes the reached volley instead of carrying a stale cue backward.")
    check(not rewound_unit.is_empty() and is_equal_approx(view.actors["UKR_S1"].position.x,float(rewound_unit["position"][0])) and not view.actors["RU_S4"].visible, "The rewound frame applies recorded public placement and never reveals the hidden actor.")
    print("REVIEW REWOUND: frame=",view.review_index,"/",view.interval_review_frames.size()-1," shots_cleared=",shot_count," speed=",int(view.speed))
    await capture_frame("review-navigation-rewound-preview")
    click(view.playback_step_button.get_global_rect().get_center())
    await process_frame
    check(view.review_index == shot_index and view.shot_cues.size() == shot_count, "A later forward crossing displays the recorded volley exactly once again.")

    # Backward navigation from a fractional running frame snaps to an exact
    # recorded second and clears the fraction rather than guessing an in-between
    # reverse state.
    click(view.review_restart_button.get_global_rect().get_center())
    await process_frame
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    view._process(2.4/view.speed)
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(view.review_index == 2 and is_equal_approx(view.review_accumulator,0.4) and view.review_paused, "Running review can pause on a fractional public frame before rewind.")
    click(view.review_previous_button.get_global_rect().get_center())
    await process_frame
    check(view.review_index == 1 and is_zero_approx(view.review_accumulator) and view.shot_cues.is_empty(), "PREVIOUS resolves fractional playback to the exact prior recorded second.")

    # Completion is still navigable: PREVIOUS reopens the final second and
    # RESTART returns to zero, both paused and without a stale final-frame cue.
    click(view.review_restart_button.get_global_rect().get_center())
    await process_frame
    for index in range(60):
        view._step_interval_review()
    check(view.review_complete and view.review_index == 60 and not view.review_previous_button.disabled and not view.review_restart_button.disabled, "Completed review exposes backward navigation at the upper bound.")
    click(view.review_previous_button.get_global_rect().get_center())
    await process_frame
    check(view.review_index == 59 and not view.review_complete and view.review_paused and view.playback_pause_button.text == "RESUME REVIEW", "PREVIOUS leaves DONE at the exact prior frame and remains paused.")
    click(view.review_restart_button.get_global_rect().get_center())
    await process_frame
    check(view.review_index == 0 and not view.review_complete and view.review_paused and view.review_previous_button.disabled and view.shot_cues.is_empty(), "RESTART from the end returns to the bounded first frame without a cue.")
    var second_random := randi()
    seed(64183)
    check(first_random == randi() and second_random == randi(), "Forward/back/restart navigation consumes no global RNG samples.")
    var checkpoints_before_exit := navigation_checkpoints
    click(view.back_button.get_global_rect().get_center())
    await process_frame
    check(not view.reviewing_interval and view.execute_button.visible and not view.review_previous_button.visible and not view.review_restart_button.visible, "EXIT removes review navigation and restores the planning execute row.")
    check(same(planning_snapshot,sim.state) and same(planning_events,sim.last_events) and navigation_checkpoints == checkpoints_before_exit and not view.inspect_button.disabled, "Navigation exit restores exact planning with no event, checkpoint or inspection leak.")
    await capture_frame("review-navigation-planning-preview")

    # Review/navigation remains transient across a real disk round trip.
    var save_path := "user://review_navigation_%d.json" % Time.get_ticks_usec()
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(sim.state))
    file.close()
    var restored = Battle.new()
    restored.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
    DirAccess.remove_absolute(save_path)
    view.queue_free()
    await process_frame
    sim = restored
    view = await open_view(sim)
    check(same(planning_snapshot,sim.state) and view.interval_review_frames.is_empty() and not view.interval_review_button.visible and not view.review_previous_button.visible and not view.review_restart_button.visible, "Disk reopen restores no replay buffer or navigation UI.")

    # Finish the reopened authoritative battle against the untouched twin.
    for tick in range(500):
        if sim.state["phase"] == "finished": break
        if sim.state["phase"] == "planning":
            check(twin.execute(), "Twin begins the next interval after navigation review.")
            view._execute()
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Every post-navigation tick remains identical to the unreviewed twin.")
    check(sim.state["phase"] == "finished" and same(sim.result(),twin.result()) and Battle.validate(sim.state,PAYLOAD), "Review navigation reaches the exact valid unreviewed battle result.")
    check(view.interval_review_frames.is_empty() and not view.interval_review_button.visible and view.completed_report_panel.visible, "Completion keeps the readable report and no stale navigation history.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: paused PREVIOUS and RESTART navigate only bounded public frames, clear stale/fractional cues, preserve hidden-data/RNG/state/checkpoint/disk purity, restore planning, and retain exact final parity.")
    quit(0 if failures.is_empty() else 1)
