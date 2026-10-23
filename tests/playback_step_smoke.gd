extends "res://tests/playback_pause_smoke.gd"
# Reuse the actual input/render/disk helpers from playback pause; override its run.
var step_checkpoints := 0

func _count_step_checkpoint() -> void:
    step_checkpoints += 1

func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1","RU_S1"]:
            squad["alive"] = 0
    sim.squad_by_id("UKR_S1")["position"] = [354,244]
    sim.squad_by_id("RU_S1")["position"] = [394,244]
    sim.squad_by_id("UKR_S1")["ammo"] = 360
    sim.squad_by_id("RU_S1")["ammo"] = 360
    var view = await open_view(sim)
    var before: Dictionary = sim.state.duplicate(true)
    check(view.playback_step_button.disabled and not view.playback_paused, "STEP starts disabled during planning.")
    click(view.playback_step_button.get_global_rect().get_center())
    await process_frame
    check(same(before,sim.state) and view.playback_step_button.disabled, "Disabled planning input cannot step or change authority.")

    click(view.execute_button.get_global_rect().get_center())
    await process_frame
    before = sim.state.duplicate(true)
    check(sim.state["phase"] == "execution" and view.playback_step_button.disabled, "STEP remains disabled while execution playback runs.")
    click(view.playback_step_button.get_global_rect().get_center())
    await process_frame
    check(same(before,sim.state), "Disabled running input cannot advance a tick.")
    view._process(0.37/view.speed)
    check(is_equal_approx(view.accumulator,0.37) and same(before,sim.state), "A partial automatic second is retained before pausing.")
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(view.playback_paused and not view.playback_step_button.disabled and view.playback_step_button.text == "STEP +1s", "Actual PAUSE input enables the distinct one-second step control.")
    check("STEP +1s advances 1s" in view.report_label.text, "Paused help identifies STEP as deliberate battle-time advancement.")

    var twin = Battle.new()
    twin.restore(sim.state)
    var frozen_accumulator: float = view.accumulator
    var initial_ammo: int = sim.squad_by_id("UKR_S1")["ammo"]
    seed(82317)
    var first_random := randi()
    # One actual button press at each playback rate. Speed is purely presentation:
    # every press must advance the same single authoritative second.
    for expected_speed in [1.0,4.0,8.0]:
        while view.speed != expected_speed:
            click(view.speed_button.get_global_rect().get_center())
            await process_frame
        var elapsed_before: int = sim.state["elapsed"]
        twin.step()
        var expected_events: Array = twin.consume_events()
        var visible_before: int = view.observed_shot_events.size()
        click(view.playback_step_button.get_global_rect().get_center())
        await process_frame
        check(int(sim.state["elapsed"]) == elapsed_before + 1 and same(sim.state,twin.state), "Actual STEP input advances exactly one twin tick at %dx." % int(expected_speed))
        check(view.playback_paused and not view.playback_step_button.disabled and is_equal_approx(view.accumulator,frozen_accumulator), "STEP at %dx remains paused without consuming the frozen fraction." % int(expected_speed))
        if not expected_events.is_empty():
            check(view.observed_shot_events.size() > visible_before and not view.shot_cues.is_empty(), "A stepped real volley enters the existing visible event/cue path.")
    check(int(sim.state["elapsed"]) == 3 and sim.squad_by_id("UKR_S1")["ammo"] < initial_ammo and not view.shot_cues.is_empty(), "The third deliberate second produces real acquisition fire and ammunition feedback.")
    check("LATEST VOLLEY" in view.combat_label.text and "-" in view.combat_label.text, "Stepped fire updates the ordinary readable combat-change panel.")
    var cue: Dictionary = view.shot_cues.back()
    var cue_node: Node = cue["node"]
    var cue_ttl: float = cue["ttl"]
    var body: Node3D = view.bodies["UKR_S1"][0]
    var recoil: float = body.recoil_remaining
    twin.step()
    click(view.playback_step_button.get_global_rect().get_center())
    await process_frame
    check(same(sim.state,twin.state) and int(sim.state["elapsed"]) == 4 and is_equal_approx(view.accumulator,frozen_accumulator), "A second press advances one more tick rather than replaying or double-counting the fraction.")
    check(view.shot_cues.has(cue) and cue["node"] == cue_node and is_equal_approx(cue["ttl"],cue_ttl) and is_equal_approx(body.recoil_remaining,recoil), "An instantaneous non-firing step does not age the paused wall-time cue or recoil presentation.")
    var second_random := randi()
    seed(82317)
    check(first_random == randi() and second_random == randi(), "Speed, pause and step UI consume no global random samples.")
    print("PLAYBACK STEP: tick=",sim.state["elapsed"]," speed=",int(view.speed)," rounds=",sim.squad_by_id("UKR_S1")["ammo"]," fraction=",view.accumulator)
    await capture_frame("playback-step-execution-preview")

    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    check(not view.playback_paused and view.playback_step_button.disabled, "RESUME disables manual STEP immediately.")
    twin.step()
    view._process((1.0-frozen_accumulator)/view.speed)
    check(same(sim.state,twin.state) and is_zero_approx(view.accumulator), "Resume counts the preserved partial second exactly once after deliberate steps.")

    # Pause UI and its fractional accumulator remain intentionally transient. A
    # valid execution save reopens unpaused but preserves all stepped authority.
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    var save_path := "user://playback_step_%d.json" % Time.get_ticks_usec()
    var file := FileAccess.open(save_path,FileAccess.WRITE)
    file.store_string(JSON.stringify(sim.state))
    file.close()
    var restored = Battle.new()
    restored.restore(JSON.parse_string(FileAccess.get_file_as_string(save_path)))
    DirAccess.remove_absolute(save_path)
    check(same(restored.state,sim.state) and Battle.validate(restored.state,PAYLOAD), "State after manual stepping survives an actual valid disk round trip.")
    view.queue_free()
    await process_frame
    sim = restored
    view = await open_view(sim)
    check(not view.playback_paused and view.playback_step_button.disabled and not is_equal_approx(view.accumulator,frozen_accumulator), "Reopening restores no stale pause, STEP enablement or frozen fractional UI time.")
    check(same(sim.state,twin.state) and view.shot_cues.is_empty(), "Reopening fabricates no stepped cue and retains exact twin authority.")

    # Finish this battle using the same manual one-tick path. Direct calls keep
    # the regression fast; actual button dispatch was proven above at all speeds.
    for tick in range(500):
        if sim.state["phase"] == "finished": break
        if sim.state["phase"] == "planning":
            check(twin.execute(), "Twin starts a later interval during full-result stepping.")
            click(view.execute_button.get_global_rect().get_center())
            await process_frame
        if not view.playback_paused:
            click(view.playback_pause_button.get_global_rect().get_center())
            await process_frame
        twin.step()
        view._step_playback()
        check(same(sim.state,twin.state), "Every manually stepped authoritative tick matches the uninterrupted twin.")
    check(sim.state["phase"] == "finished" and same(sim.result(),twin.result()) and Battle.validate(sim.state,PAYLOAD), "Manual stepping completes with the exact valid twin result.")
    check(not view.playback_paused and view.playback_step_button.disabled and view.completed_report_panel.visible and view.completed_report_label.text.contains("SURVIVING") and view.completed_report_label.text.contains("OBJECTIVE CONTROL") and view.completed_report_label.text.contains("CAMPAIGN CONSEQUENCES"), "Completion clears STEP and retains the complete two-sided report.")
    await capture_frame("playback-step-report-preview")
    view.queue_free()
    await process_frame

    # Independently force a clean interval boundary with living, disarmed forces.
    # The final step must take the ordinary planning/checkpoint cleanup route.
    var boundary = Battle.new()
    boundary.setup(PAYLOAD)
    for squad in boundary.state["squads"]: squad["ammo"] = 0
    check(boundary.execute(), "Boundary fixture starts execution.")
    for tick in range(59): boundary.step()
    check(boundary.state["phase"] == "execution" and boundary.state["remaining"] == 1, "Boundary fixture reaches its final execution second.")
    var boundary_twin = Battle.new()
    boundary_twin.restore(boundary.state)
    view = await open_view(boundary)
    # The helper necessarily renders one frame before disabling processing; make
    # this fixture's deliberately frozen partial second explicit.
    view.accumulator = 0.0
    view._process(0.61/view.speed)
    click(view.playback_pause_button.get_global_rect().get_center())
    await process_frame
    var boundary_fraction: float = view.accumulator
    check(boundary.state["phase"] == "execution" and view.playback_paused and not view.playback_step_button.disabled, "Boundary fixture pauses with STEP enabled before its final second.")
    step_checkpoints = 0
    check(view.checkpoint.connect(_count_step_checkpoint) == OK, "Boundary fixture observes the normal checkpoint signal.")
    boundary_twin.step()
    click(view.playback_step_button.get_global_rect().get_center())
    await process_frame
    check(same(boundary.state,boundary_twin.state) and boundary.state["phase"] == "planning", "STEP across second 60 reaches the normal planning boundary exactly.")
    check(not view.playback_paused and view.playback_step_button.disabled, "Boundary stepping clears pause and disables STEP.")
    check(step_checkpoints == 1, "Boundary stepping emits exactly one normal checkpoint.")
    check(is_equal_approx(view.accumulator,boundary_fraction), "Boundary stepping does not consume its frozen fractional accumulator.")
    check(Battle.validate(boundary.state,PAYLOAD), "The stepped interval-boundary state remains valid.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: actual STEP +1s input at 1x/4x/8x advances exactly one normal tick with real shots/cues/feedback, preserves frozen fractions, handles disk/boundary/completion cleanup, and retains every-tick/result/RNG parity.")
    quit(0 if failures.is_empty() else 1)
