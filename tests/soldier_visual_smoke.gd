extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id": "SOLDIERS", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
var capture := ""
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func save_capture(name: String) -> void:
    if not capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(capture.get_base_dir().path_join(name + ".png")) == OK, "Soldier execution/pose capture must save.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="): capture = argument.trim_prefix("--capture=")
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    for squad in battle.state["squads"]:
        squad["position"] = [100,250] if squad["id"] == "UKR_S1" else ([220,250] if squad["id"] == "RU_S1" else ([40,40] if squad["faction"] == "UKR" else [470,470]))
        if squad["id"] not in ["UKR_S1", "RU_S1"]: squad["ammo"] = 0
    var view = View.new()
    view.simulation = battle
    root.add_child(view)
    await process_frame
    view.set_process(false)
    check(view.bodies["UKR_S1"].size() == 9 and view.bodies["RU_S1"].size() == 9, "Full squads must create nine individual rigs rather than three symbolic capsules.")
    check(not view.actors["RU_S1"].visible, "Unacquired enemy soldiers must remain hidden.")
    var before: Dictionary = battle.state.duplicate(true)
    view.inspect_button.pressed.emit()
    check(view.camera_distance == 24 and view.camera_focus == Vector2(100,250), "Inspect must focus selected squad close enough to read individual figures.")
    check(same(before,battle.state), "Camera inspection must not mutate authoritative state.")
    for value in ["stand", "crouch", "prone"]:
        battle.order_posture("UKR_S1", value)
        view._refresh()
        var soldier = view.bodies["UKR_S1"][0]
        check(soldier.current_pose == value and soldier.parts.size() == 13, "Each posture must articulate helmet, rifle, torso, arms and separate legs.")
        var head_height: float = soldier.parts["head"].position.y
        check(head_height > 1.5 if value == "stand" else (head_height < 1.4 and head_height > 1.0 if value == "crouch" else head_height < 0.5), "Pose head height must distinguish standing, crouched and horizontal prone geometry.")
        before = battle.state.duplicate(true)
        view._refresh()
        check(same(before,battle.state), "Rendering a pose must not mutate saved state/RNG.")
        await save_capture("soldiers-" + value + "-preview")
    var twin = Battle.new()
    twin.restore(battle.state)
    battle.execute()
    twin.execute()
    for tick in range(3):
        battle.step()
        twin.step()
        view._show_shot_events(battle.consume_events())
        view._refresh()
    check(not view.shot_cues.is_empty(), "Actual acquired prone fire must create a shot cue beside soldier geometry.")
    await save_capture("soldiers-shot-preview")
    var saw_loss := false
    for tick in range(400):
        if battle.state["phase"] == "finished": break
        if battle.state["phase"] == "planning":
            battle.execute()
            twin.execute()
        var status_before: Dictionary = view._status_snapshot()
        view._age_shot_cues(1.0)
        battle.step()
        twin.step()
        view._show_shot_events(battle.consume_events())
        view._show_combat_changes(status_before)
        view._refresh()
        check(same(battle.state,twin.state), "Rendered soldier battle must remain exactly equal to an unrendered deterministic twin.")
        var alive: int = battle.squad_by_id("UKR_S1")["alive"]
        var lost := 0
        for body in view.bodies["UKR_S1"]:
            if body.current_pose == "casualty": lost += 1
        check(lost == 9 - alive, "Friendly casualty figures must match actual simulated losses, including zero survivors.")
        if lost > 0 and not saw_loss:
            saw_loss = true
            await save_capture("soldiers-casualties-preview")
        if battle.state["phase"] != "finished" and view.actors["RU_S1"].visible:
            for body in view.bodies["RU_S1"]:
                check(body.current_pose != "casualty", "Live enemy figures must not expose exact casualty counts.")
    check(saw_loss and same(battle.result(),twin.result()), "Real combat must produce casualties and identical complete results with/without figures.")
    view.reset_camera_button.pressed.emit()
    check(is_equal_approx(view.camera_distance,Vector2(520,394).length()), "Reset camera must restore overview distance after inspection.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: individual soldier poses, actual casualties/shot, hidden counts, camera and full outcome isolation")
    quit(0 if failures.is_empty() else 1)
