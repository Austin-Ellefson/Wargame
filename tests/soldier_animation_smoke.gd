extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id": "ANIMATION", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80}, "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []
var capture := ""
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant, b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func snapshot(body: Node3D) -> Array:
    var result: Array = []
    for key in body.parts: result.append([body.parts[key].transform,body.parts[key].mesh.size])
    return result
func capture_frame(name: String) -> void:
    if not capture.is_empty() and DisplayServer.get_name() != "headless":
        await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png(capture.get_base_dir().path_join(name+".png")) == OK, "Actual animation frame must save.")
func fixture() -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    for squad in battle.state["squads"]:
        squad["position"] = [100,250] if squad["id"] == "UKR_S1" else ([40,40] if squad["faction"] == "UKR" else [470,470])
        squad["ammo"] = 0
    return battle
func open_view(battle: RefCounted) -> Control:
    var view = View.new()
    view.simulation = battle
    root.add_child(view)
    await process_frame
    view.set_process(false)
    view.inspect_button.pressed.emit()
    return view
func _run() -> void:
    root.size = Vector2i(1280,720)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="): capture=argument.trim_prefix("--capture=")
    for posture in ["stand","crouch","prone"]:
        var battle = fixture()
        battle.order_posture("UKR_S1",posture)
        battle.order_move("UKR_S1",Vector2(180,250),true,"quick")
        var view = await open_view(battle)
        var body = view.bodies["UKR_S1"][0]
        var idle: Array = snapshot(body)
        battle.execute()
        for tick in range(5):
            battle.step()
            view._refresh()
            view._animate_soldiers(0.1)
            check(snapshot(body) == idle and not view.motions["UKR_S1"]["moving"], "Real command-response wait must not animate a queued route.")
        battle.step()
        view._refresh()
        var before: Dictionary = battle.state.duplicate(true)
        view._animate_soldiers(0.06)
        var stride: Array = snapshot(body)
        check(view.motions["UKR_S1"]["moving"] and stride != idle and is_equal_approx(body.rotation.y, atan2(-(Battle.position(battle.squad_by_id("UKR_S1")).x-100), -(Battle.position(battle.squad_by_id("UKR_S1")).y-250))), "Actual movement must face travel and articulate walking/crouching/crawling legs.")
        await capture_frame("soldiers-"+posture+"-motion-a")
        view._animate_soldiers(0.06)
        check(snapshot(body) != stride and same(before,battle.state), "Two rendered phases must differ without modifying authoritative state/RNG.")
        await capture_frame("soldiers-"+posture+"-motion-b")
        # Actual execution halt, not cleared route: suppression pins the next tick.
        battle.squad_by_id("UKR_S1")["suppression"] = 0.9
        battle.step()
        view._refresh()
        view._animate_soldiers(0.1)
        check(not view.motions["UKR_S1"]["moving"] and snapshot(body) == idle, "Actual pinned halt must restore complete idle geometry despite retained route.")
        view.queue_free()
        await process_frame
    var battle = fixture()
    battle.squad_by_id("RU_S1")["position"]=[220,250]
    battle.squad_by_id("UKR_S1")["ammo"]=360
    var view = await open_view(battle)
    battle.execute()
    for tick in range(3):
        battle.step()
        view._refresh()
        view._show_shot_events(battle.consume_events())
    var body = view.bodies["UKR_S1"][0]
    check(body.recoil_remaining > 0 and body.muzzle.visible and is_equal_approx(body.rotation.y,-PI/2), "Real visible rifle shot must trigger a facing recoil and muzzle flash.")
    var before: Dictionary = battle.state.duplicate(true)
    view.selected="UKR_S2"
    view._refresh()
    check(body.recoil_remaining == 0 and not body.muzzle.visible and same(before,battle.state), "Changing to an unwitnessing squad must clear an actually active recoil without changing the battle.")
    view.selected="UKR_S1"
    view._refresh()
    check(not body.muzzle.visible, "Re-selecting the observer must not replay a past shot.")
    for speed in [1.0,4.0,8.0]:
        view.speed=speed
        # Another actual shot at cadence; no synthetic fire() event fixture.
        for tick in range(3):
            battle.step()
            view._refresh()
            view._show_shot_events(battle.consume_events())
        check(body.recoil_remaining == 0.42, "Actual shots must start readable wall-time recoil at every supported speed.")
        view._animate_soldiers(0.12)
        check(body.muzzle.visible and body.parts["rifle"].position.z > body.rest_transforms["rifle"].origin.z, "Shot flash and recoil must remain readable after a rendered frame.")
        await capture_frame("soldiers-recoil-"+str(int(speed))+"x")
        view._animate_soldiers(0.31)
        check(not body.muzzle.visible and body.recoil_remaining == 0, "Shot flash/recoil must expire without extra simulated seconds.")
    before=battle.state.duplicate(true)
    view.selected="UKR_S2"
    view._refresh()
    check(not body.muzzle.visible, "Switching to a squad that did not witness the shot must clear firing animation.")
    var hidden_before: Array = snapshot(body)
    view._show_shot_events([{"type":"shot","player_visible":false,"shooter":"UKR_S1","target":"RU_S1"}])
    check(not body.muzzle.visible and snapshot(body)==hidden_before and same(before,battle.state), "Hidden shots must not trigger rig cues or change the simulation.")
    view.queue_free()
    await process_frame
    # Match production event-before-refresh ordering for a newly acquired red shooter.
    battle = fixture()
    battle.squad_by_id("RU_S1")["position"]=[220,250]
    battle.squad_by_id("RU_S1")["ammo"]=9
    view = await open_view(battle)
    battle.execute()
    for tick in range(3):
        battle.step()
        view._show_shot_events(battle.consume_events())
        view._refresh()
    var enemy = view.bodies["RU_S1"][0]
    check(view.actors["RU_S1"].visible and enemy.muzzle.visible, "Newly acquired enemy's actual witnessed firing must survive first observation initialization.")
    view.selected="UKR_S2"
    view._refresh()
    check(not view.actors["RU_S1"].visible and not enemy.muzzle.visible and not view.motions.has("RU_S1"), "Loss of selected local sight must discard enemy animation and its motion history.")
    view.queue_free()
    await process_frame
    if failures.is_empty(): print("PASS: actual walk/crouch/crawl, queued wait/pinned stop, real recoil at 1/4/8x and visibility/RNG isolation")
    quit(0 if failures.is_empty() else 1)
