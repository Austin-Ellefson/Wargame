extends "res://tests/playback_step_smoke.gd"
# Reuse actual input/render/disk helpers; override the inherited run.
var review_checkpoints := 0

func _count_review_checkpoint() -> void:
    review_checkpoints += 1

func review_unit(frame: Dictionary, id: String) -> Dictionary:
    for unit in frame["units"]:
        if unit["id"] == id:
            return unit
    return {}

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
    # An eliminated, never-observed squad retains a distinctive authoritative
    # coordinate. Neither its ID nor coordinate may enter the public recording.
    sim.squad_by_id("RU_S4")["position"] = [470,470]
    sim.squad_by_id("RU_S4")["alive"] = 0
    check(sim.order_move("UKR_S1",Vector2(230,245)), "Review fixture queues real movement into a close engagement.")
    check(Battle.validate(sim.state,PAYLOAD), "Review fixture begins as a valid tactical state.")
    var view = await open_view(sim)
    check(view.checkpoint.connect(_count_review_checkpoint) == OK, "Review fixture observes ordinary checkpoints.")
    click(view.execute_button.get_global_rect().get_center())
    await process_frame
    check(sim.state["phase"] == "execution" and view.interval_review_recording and view.interval_review_frames.size() == 1, "Actual EXECUTE begins a bounded recording with the genuinely visible second-zero frame.")
    var twin = Battle.new()
    twin.restore(sim.state)
    for tick in range(60):
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Recorded execution tick matches the unrecorded authoritative twin.")
    check(sim.state["phase"] == "planning" and int(sim.state["elapsed"]) == 60, "Fixture reaches an ordinary execution-to-planning boundary.")
    check(view.interval_review_frames.size() == 61 and not view.interval_review_recording, "Review retains exactly second zero plus the 60 completed public frames.")
    check(view.interval_review_button.visible and view.playback_pause_button.disabled and review_checkpoints == 2, "Boundary exposes REVIEW LAST INTERVAL after only the normal execute/boundary checkpoints.")
    var moved_from: Dictionary = review_unit(view.interval_review_frames[0],"UKR_S1")
    var moved_to: Dictionary = review_unit(view.interval_review_frames.back(),"UKR_S1")
    check(not moved_from.is_empty() and not moved_to.is_empty() and moved_from["position"] != moved_to["position"], "Recorded public frames contain actual simulated squad movement.")
    var recorded_shots := 0
    for frame in view.interval_review_frames:
        recorded_shots += frame["shots"].size()
        for shot in frame["shots"]:
            check(shot.keys().size() == 3 and shot.has("from") and shot.has("to") and shot.has("support"), "Review shot records contain rendered endpoints/profile only.")
    check(recorded_shots > 0, "The completed interval contains witnessed simulated shots for review.")
    var public_json := JSON.stringify(view.interval_review_frames)
    check("RU_S4" not in public_json and "[470.0,470.0]" not in public_json and "[470,470]" not in public_json, "Unobserved actor identity and position never enter the public review buffer.")

    var planning_snapshot: Dictionary = sim.state.duplicate(true)
    var planning_events: Array = sim.last_events.duplicate(true)
    seed(91573)
    var first_random := randi()
    click(view.interval_review_button.get_global_rect().get_center())
    await process_frame
    check(view.reviewing_interval and view.review_index == 0 and not view.review_paused and "RECORDED PUBLIC VIEW" in view.phase_label.text, "Actual REVIEW input starts a clearly labeled forward playback at its first frame.")
    check(view.execute_button.disabled and view.back_button.text.contains("EXIT REVIEW") and same(planning_snapshot,sim.state), "Review freezes planning controls and provides an explicit unchanged-state exit.")
    check(view.report_label.get_global_rect().end.y < 691, "Two-line review guidance stays above the 720p footer.")
    check(not view.actors["RU_S4"].visible and review_unit(view.interval_review_frames[0],"RU_S4").is_empty(), "The replay cannot display its current hidden actor.")

    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(view.review_paused and view.playback_pause_button.text == "RESUME REVIEW" and not view.playback_step_button.disabled, "Actual PAUSE REVIEW freezes recorded playback and enables one-frame stepping.")
    var frozen_fraction: float = view.review_accumulator
    for expected_speed in [4.0,8.0,1.0]:
        while view.speed != expected_speed:
            click(view.speed_button.get_global_rect().get_center())
            await process_frame
        var old_index: int = view.review_index
        click(view.playback_step_button.get_global_rect().get_center())
        await process_frame
        check(view.review_index == old_index + 1 and is_equal_approx(view.review_accumulator,frozen_fraction), "Paused review STEP advances one recorded second at %dx without consuming its fraction." % int(expected_speed))
        check(same(planning_snapshot,sim.state) and same(planning_events,sim.last_events), "Review step at %dx changes no authoritative state or live event queue." % int(expected_speed))
    var found_review_shot: bool = not view.shot_cues.is_empty()
    var found_review_movement := false
    for tick in range(20):
        var unit: Dictionary = review_unit(view.interval_review_frames[view.review_index],"UKR_S1")
        if not unit.is_empty() and unit["position"] != moved_from["position"]:
            found_review_movement = true
        if not view.interval_review_frames[view.review_index]["shots"].is_empty() and not view.shot_cues.is_empty():
            found_review_shot = true
        if found_review_shot and found_review_movement:
            break
        click(view.playback_step_button.get_global_rect().get_center())
        await process_frame
    check(found_review_shot and not view.shot_cues.is_empty(), "Forward review recreates cues from witnessed recorded shots without rerunning combat.")
    check(found_review_movement and view.actors["UKR_S1"].position.x != float(moved_from["position"][0]), "Forward review visibly reaches recorded simulated movement.")
    check("LATEST VOLLEY" in view.combat_label.text, "Review restores the readable combat feedback that was public on the recorded frame.")
    check(not view.actors["RU_S4"].visible and same(planning_snapshot,sim.state), "Movement and shot review still reveal no hidden actor and leave authority frozen.")
    print("INTERVAL REVIEW: frame=",view.review_index,"/",view.interval_review_frames.size()-1," public_shots=",recorded_shots," cues=",view.shot_cues.size())
    await capture_frame("interval-review-execution-preview")

    # Resume uses the selected presentation speed and preserves the paused
    # fractional review time, but still advances records rather than Battle.step.
    var before_resume_index: int = view.review_index
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    view._process(0.4/view.speed)
    check(view.review_index == before_resume_index and is_equal_approx(view.review_accumulator,0.4), "Running review retains a fractional recorded second without touching authority.")
    view._process(0.6/view.speed)
    check(view.review_index == before_resume_index + 1 and is_zero_approx(view.review_accumulator) and same(planning_snapshot,sim.state), "Running review advances one public frame at the selected speed only.")
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    var second_random := randi()
    seed(91573)
    check(first_random == randi() and second_random == randi(), "Record/review/pause/step/speed controls consume no global RNG samples.")
    var checkpoints_before_exit := review_checkpoints
    click(view.back_button.get_global_rect().get_center())
    await process_frame
    check(not view.reviewing_interval and view.interval_review_button.visible and sim.state["phase"] == "planning", "EXIT REVIEW returns to the ordinary planning UI and keeps the review available.")
    check(same(planning_snapshot,sim.state) and same(planning_events,sim.last_events) and review_checkpoints == checkpoints_before_exit, "Review exit restores the exact planning snapshot without a checkpoint or fabricated event.")
    check(view.actors["UKR_S1"].position.x == Battle.position(sim.squad_by_id("UKR_S1")).x and view.execute_button.text == "EXECUTE 60 SECONDS" and not view.inspect_button.disabled, "Exit restores authoritative actor placement and every planning/inspection control.")
    await capture_frame("interval-review-planning-preview")

    click(view.interval_review_button.get_global_rect().get_center())
    await process_frame
    for frame_index in range(80):
        if view.review_complete: break
        view._process(1.0/view.speed)
    check(view.review_complete and view.review_paused and view.review_index == 60 and view.playback_pause_button.text == "REVIEW COMPLETE" and view.playback_pause_button.disabled and view.playback_step_button.disabled, "Forward playback stops on the recorded final frame without spilling into planning authority.")
    check(same(planning_snapshot,sim.state) and review_checkpoints == checkpoints_before_exit, "A complete review still emits no tick, RNG or checkpoint side effect.")
    click(view.back_button.get_global_rect().get_center())
    await process_frame
    check(not view.reviewing_interval and same(planning_snapshot,sim.state), "Explicit exit also restores planning from the completed review frame.")

    # The buffer is deliberately transient. A valid disk reopen retains only the
    # authoritative checkpoint and must not fabricate a review history.
    var save_path := "user://interval_review_%d.json" % Time.get_ticks_usec()
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
    check(same(planning_snapshot,sim.state) and view.interval_review_frames.is_empty() and not view.interval_review_button.visible, "Disk reopen preserves authority but intentionally restores no transient review buffer.")

    # Finish from the reviewed/reopened checkpoint against the untouched twin.
    # Recording later intervals must remain presentation-only through the result.
    for tick in range(500):
        if sim.state["phase"] == "finished": break
        if sim.state["phase"] == "planning":
            check(twin.execute(), "Twin begins the next interval after review.")
            view._execute()
        twin.step()
        view._process(1.0/view.speed)
        check(same(sim.state,twin.state), "Every post-review tick remains identical to the unreviewed twin.")
    check(sim.state["phase"] == "finished" and same(sim.result(),twin.result()) and Battle.validate(sim.state,PAYLOAD), "Review/reopen reaches the exact valid unreviewed battle result.")
    check(view.interval_review_frames.is_empty() and not view.interval_review_button.visible and view.completed_report_panel.visible, "Battle completion discards ordinary-interval review and retains the complete report.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: a bounded public-only last-interval review shows actual recorded movement and witnessed shots, supports forward speed/pause/step, reveals no hidden actor, mutates no state/RNG/checkpoint, discards on reopen, and preserves exact final parity.")
    quit(0 if failures.is_empty() else 1)
