extends SceneTree
const Battle = preload("res://scripts/tactical_battle.gd")
const View = preload("res://scripts/tactical_view.gd")
const PAYLOAD = {"battle_id":"DUCK","ukraine":{"id":"BLUE","personnel":36,"morale":80},"russia":{"id":"RED","personnel":36,"morale":80}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(ok: bool,message: String) -> void:
    if not ok:
        failures.append(message)
        push_error(message)
func same(a: Variant,b: Variant) -> bool: return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))
func fixture(hidden: bool = true) -> RefCounted:
    var sim = Battle.new()
    sim.setup(PAYLOAD)
    for squad in sim.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S2","RU_S1","RU_S2"]:squad["alive"] = 0
    sim.squad_by_id("UKR_S2")["position"] = [212,290] if hidden else [180,245]
    sim.state["postures"]["UKR_S2"] = "prone" if hidden else "stand"
    sim.squad_by_id("RU_S1")["position"] = [298,210] if hidden else [240,245]
    sim.squad_by_id("RU_S2")["position"] = [470,470]
    return sim
func stationary(sim: RefCounted) -> void:
    sim.execute()
    sim.state["orders"].clear()
    sim.state["movement_modes"].clear()
    for id in sim.state["command_remaining"]:sim.state["command_remaining"][id] = 0
func finish(sim: RefCounted) -> void:
    for tick in range(400):
        if sim.state["phase"] == "finished":return
        if sim.state["phase"] == "planning":sim.execute()
        sim.step()
func capture_frame(name: String) -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture=") and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            check(root.get_texture().get_image().save_png(arg.trim_prefix("--capture=").get_base_dir().path_join(name+".png")) == OK,"Actual duck render saves.")
func _run() -> void:
    root.size = Vector2i(1280,720)
    var sim = fixture()
    sim.squad_by_id("UKR_S2")["ammo"] = 360
    check(sim.state["version"] == 22 and sim.order_area_fire("UKR_S2",Vector2(298,210)),"Concealed source has a real eligible ground-fire order.")
    stationary(sim)
    var crouched := false
    var prone := false
    var shots := 0
    for tick in range(18):
        sim.step()
        shots += sim.last_events.size()
        crouched = crouched or sim.posture("RU_S1") == "crouch"
        prone = prone or sim.posture("RU_S1") == "prone"
        check(not sim.can_spot(sim.squad_by_id("RU_S1"),sim.squad_by_id("UKR_S2")) and sim.state["observer_contacts"]["RU_S1"].is_empty(),"Received pressure must not grant hidden attacker identity/position.")
    check(shots == 9 and crouched and prone and sim.squad_by_id("UKR_S2")["ammo"] == 198 and sim.squad_by_id("RU_S1")["alive"] == 9 and sim.posture("UKR_S2") == "prone","Actual support fire triggers red crouch/prone while preserving casualties and blue manual posture.")
    var saved: Dictionary = sim.state.duplicate(true)
    check(Battle.validate(saved,PAYLOAD),"Real v22 prone/hysteresis checkpoint validates with unchanged save shape.")
    var twin = Battle.new()
    twin.restore(saved)
    for tick in range(60):
        for running in [sim,twin]:
            if running.state["phase"] == "planning":stationary(running)
            running.step()
        check(same(sim.state,twin.state) and same(sim.last_events,twin.last_events),"Partial duck/pressure continuation restores exactly every tick/event.")
    check(sim.posture("RU_S1") == "stand" and sim.posture("UKR_S2") == "prone","No new incoming fire lets red rise; blue manual posture stays untouched.")
    # Exact thresholds use pressure after fixed tick recovery; no query writes.
    var edges = fixture(false)
    stationary(edges)
    var red: Dictionary = edges.squad_by_id("RU_S1")
    red["suppression"] = 0.335
    edges.step()
    check(edges.posture("RU_S1") == "crouch","Recovered pressure30% makes a standing red squad crouch.")
    red["suppression"] = 0.585
    edges.step()
    check(edges.posture("RU_S1") == "prone","Recovered pressure55% makes red prone.")
    red["suppression"] = 0.235
    edges.step()
    check(edges.posture("RU_S1") == "prone","Prone persists at20% pressure rather than toggling every threshold crossing.")
    red["suppression"] = 0.18
    edges.step()
    check(edges.posture("RU_S1") == "stand","Below15% recovered pressure rises to stand.")
    edges.state["phase"] = "planning"
    edges.state["remaining"] = 0
    edges.state["postures"]["RU_S1"] = "prone"
    red["suppression"] = 0.6
    var before: Dictionary = edges.state.duplicate(true)
    edges.step()
    edges.can_spot(red,edges.squad_by_id("UKR_S2"))
    check(same(before,edges.state),"Planning/query time cannot update automatic posture.")
    var broken = fixture(false)
    broken.squad_by_id("RU_S1")["morale"] = 20
    broken.squad_by_id("RU_S1")["suppression"] = 0.8
    stationary(broken)
    broken.step()
    check(broken.morale_state("RU_S1") == "broken" and broken.posture("RU_S1") == "stand" and broken.state["orders"].has("RU_S1") and Battle.validate(broken.state,PAYLOAD),"Automatic standing withdrawal takes priority over ducking and keeps its route.")
    var dead = fixture(false)
    dead.squad_by_id("RU_S1")["alive"] = 0
    dead.squad_by_id("RU_S1")["suppression"] = 0.6
    dead.state["postures"]["RU_S1"] = "crouch"
    stationary(dead)
    dead.step()
    check(dead.posture("RU_S1") == "crouch","Eliminated squad keeps last posture; no automatic dead-rig pose updates.")
    var legacy = fixture(false)
    legacy.state["version"] = 21
    legacy.squad_by_id("RU_S1")["suppression"] = 0.6
    stationary(legacy)
    legacy.step()
    check(legacy.posture("RU_S1") == "stand" and Battle.validate(legacy.state,PAYLOAD),"V21 preserves player/nonplayer posture behavior, with no silent rule upgrade.")
    var current = fixture(false)
    var old = fixture(false)
    old.state["version"] = 21
    finish(current)
    finish(old)
    var normalized: Dictionary = current.state.duplicate(true)
    normalized["version"] = 21
    check(same(normalized,old.state) and same(current.result(),old.result()),"With no pressure the complete v22 campaign battle matches v21 fields/results.")
    # Actual campaign save/load with real received fire and autonomous pose.
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://duck_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    var battle = game.tactical_simulation
    battle.squad_by_id("UKR_S2")["position"] = [180,245]
    battle.squad_by_id("RU_S1")["position"] = [240,245]
    battle.squad_by_id("RU_S1")["ammo"] = 0
    battle.order_area_fire("UKR_S2",Vector2(240,245))
    battle.execute()
    for tick in range(12):battle.step()
    check(battle.posture("RU_S1") != "stand" and game._save_campaign()["ok"],"Actual campaign saves ducking after real fire.")
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(game._snapshot(),resumed._snapshot()),"Disk restart restores autonomous postures exactly.")
    for tick in range(400):
        if battle.state["phase"] == "finished":break
        for running in [battle,resumed.tactical_simulation]:
            if running.state["phase"] == "planning":running.execute()
            running.step()
        check(same(battle.state,resumed.tactical_simulation.state) and same(battle.last_events,resumed.tactical_simulation.last_events),"Every resumed actual campaign tick and shot event matches.")
    check(same(battle.result(),resumed.tactical_simulation.result()),"Complete ducking campaign results match after disk restart.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    # Render only actually acquired enemy pose, after actual support shots.
    var visible = fixture(false)
    visible.squad_by_id("UKR_S2")["ammo"] = 360
    visible.order_area_fire("UKR_S2",Vector2(240,245))
    var view = View.new()
    view.simulation = visible
    view.selected = "UKR_S2"
    root.add_child(view)
    await process_frame
    view.set_process(false)
    view.camera_focus = Vector2(240,245)
    view.camera_distance = 24
    view.camera_pitch = deg_to_rad(32)
    view._update_camera()
    stationary(visible)
    var unrendered = Battle.new()
    unrendered.restore(visible.state)
    for tick in range(18):
        var status_before: Dictionary = view._status_snapshot()
        visible.step()
        unrendered.step()
        view._refresh()
        view._show_shot_events(visible.consume_events())
        view._show_combat_changes(status_before)
        view._animate_soldiers(0.05)
        check(same(visible.state,unrendered.state),"Duck/shot/animation rendering preserves every authoritative twin field.")
        if tick in [7,11]:
            var expected := "crouch" if tick == 7 else "prone"
            check(visible.posture("RU_S1") == expected and view.actors["RU_S1"].visible and view.bodies["RU_S1"][0].current_pose == expected and not view.shot_cues.is_empty(),"Actual acquired enemy duck geometry accompanies real shots.")
            await capture_frame("opponent-duck-"+expected+"-preview")
    view.queue_free()
    await process_frame
    if failures.is_empty():print("PASS: real-fire duck/recovery, hysteresis, hidden-source isolation, manual blue/withdrawal/dead priority, v21 parity, full disk continuation and rendered twin purity.")
    quit(0 if failures.is_empty() else 1)
