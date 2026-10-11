extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
const Saves = preload("res://scripts/campaign_save.gd")
const PAYLOAD = {"battle_id": "MOVEMENT_FIXTURE", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80},
    "russia": {"id": "RED", "personnel": 36, "morale": 80}}
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func fixture(mode: String) -> RefCounted:
    var battle = Battle.new()
    battle.setup(PAYLOAD)
    battle.state["version"] = 15
    battle.state.erase("acquisition")
    battle.state.erase("command_remaining")
    battle.state.erase("shared_contacts")
    battle.state.erase("pending_reports")
    for squad in battle.state["squads"]:
        squad["ammo"] = 0
        if squad["id"] not in ["UKR_S1", "RU_S1"]:
            squad["alive"] = 0
    battle.squad_by_id("UKR_S1")["position"] = [80, 250]
    battle.squad_by_id("RU_S1")["position"] = [470, 470]
    battle.order_move("UKR_S1", Vector2(180, 250), true, mode)
    battle.execute()
    battle.state["orders"].erase("RU_S1")
    battle.state["movement_modes"].erase("RU_S1")
    return battle

func finish(battle: RefCounted) -> void:
    for tick in range(400):
        if battle.state["phase"] == "finished":
            return
        if battle.state["phase"] == "planning":
            battle.execute()
        battle.step()

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for mode in ["move", "quick", "hunt"]:
        var battle = fixture(mode)
        var origin := Battle.position(battle.squad_by_id("UKR_S1"))
        battle.step()
        var expected_speed: float = {"move": 2.4, "quick": 4.0, "hunt": 1.2}[mode]
        check(is_equal_approx(origin.distance_to(Battle.position(battle.squad_by_id("UKR_S1"))), expected_speed), "Each movement mode must use its documented speed.")
        check(Battle.validate(battle.state, PAYLOAD), "Mode and path must form a valid execution save.")
        var restarted = Battle.new()
        restarted.restore(JSON.parse_string(JSON.stringify(battle.state)))
        finish(battle)
        finish(restarted)
        check(same(battle.state, restarted.state) and same(battle.result(), restarted.result()), "Every movement mode must preserve complete outcomes across JSON restart.")
    var hunt = fixture("hunt")
    var blue: Dictionary = hunt.squad_by_id("UKR_S1")
    var red: Dictionary = hunt.squad_by_id("RU_S1")
    red["position"] = [200, 250]
    blue["ammo"] = 100
    var origin := Battle.position(blue)
    var route: Array = hunt.state["orders"]["UKR_S1"].duplicate(true)
    for tick in range(3):
        hunt.step()
    check(Battle.position(blue) == origin and same(route, hunt.state["orders"]["UKR_S1"]) and hunt.movement_status(blue) == "HUNT PAUSED", "Local contact must pause HUNT without consuming the queued route.")
    check(int(blue["ammo"]) < 100, "A paused hunting squad must still fire at its own observed target.")
    red["position"] = [470, 470]
    hunt.step()
    check(Battle.position(blue) != origin and not hunt.hunt_paused(blue), "HUNT must resume when local contact clears.")
    # A side-wide contact seen by another observer must not halt this squad.
    var other: Dictionary = hunt.squad_by_id("UKR_S2")
    other["alive"] = 9
    other["position"] = [360, 470]
    var before := Battle.position(blue)
    check(hunt.is_observed("UKR", red) and not hunt.can_spot(blue, red), "Remote-observer fixture must share a contact beyond the hunter's local sight.")
    hunt.step()
    check(Battle.position(blue) != before, "Shared/remembered contacts must not act as local HUNT triggers.")
    blue["suppression"] = 0.30
    before = Battle.position(blue)
    route = hunt.state["orders"]["UKR_S1"].duplicate(true)
    hunt.step()
    check(Battle.position(blue) == before and same(route, hunt.state["orders"]["UKR_S1"]), "HUNT must pause at 25% suppression after recovery without losing its route.")
    hunt.step()
    check(Battle.position(blue) != before, "HUNT must resume below the suppression threshold.")
    for mode in ["move", "quick", "hunt"]:
        var pinned = fixture(mode)
        pinned.squad_by_id("UKR_S1")["suppression"] = 1.0
        var start := Battle.position(pinned.squad_by_id("UKR_S1"))
        pinned.step()
        check(Battle.position(pinned.squad_by_id("UKR_S1")) == start and pinned.movement_mode("UKR_S1") == mode, "Pinning must halt every mode while retaining it.")
    var queue = Battle.new()
    queue.setup(PAYLOAD)
    queue.state["version"] = 15
    queue.state.erase("acquisition")
    queue.state.erase("command_remaining")
    queue.state.erase("shared_contacts")
    queue.state.erase("pending_reports")
    check(queue.order_move("UKR_S1", Vector2(180, 250), true, "quick"), "Queue fixture must accept its first leg.")
    var prefix: Array = queue.state["orders"]["UKR_S1"].duplicate(true)
    check(queue.order_move("UKR_S1", Vector2(320, 300), true, "quick", true), "Append must route the next leg from the previous endpoint.")
    check(same(queue.state["orders"]["UKR_S1"].slice(0, prefix.size()), prefix) and same(queue.state["orders"]["UKR_S1"].back(), [320, 300]), "Appending must preserve every queued point and final destination.")
    var intact: Dictionary = queue.state.duplicate(true)
    check(not queue.order_move("UKR_S1", Vector2(230, 160), true, "quick", true) and same(intact, queue.state), "Blocked append must reject atomically.")
    check(not queue.order_move("UKR_S1", Vector2(340, 300), true, "hunt", true) and same(intact, queue.state), "Changing a mode during append must reject atomically.")
    queue.state["orders"]["UKR_S1"] = []
    for index in range(128): queue.state["orders"]["UKR_S1"].append([180, 250])
    intact = queue.state.duplicate(true)
    check(not queue.order_move("UKR_S1", Vector2(320, 300), true, "quick", true) and same(intact, queue.state), "Oversized appended paths must retain the old route unchanged.")
    var completed = fixture("quick")
    for tick in range(40):
        completed.step()
    check(completed.movement_mode("UKR_S1") == "hold" and not completed.state["movement_modes"].has("UKR_S1"), "Reaching a destination must clear its mode.")
    var dead = fixture("hunt")
    dead.squad_by_id("UKR_S1")["alive"] = 0
    dead.step()
    check(not dead.state["orders"].has("UKR_S1") and not dead.state["movement_modes"].has("UKR_S1"), "Eliminated squads must clear their mode and route.")
    var frozen = fixture("quick")
    var frozen_state: Dictionary = frozen.state.duplicate(true)
    check(not frozen.order_move("UKR_S1", Vector2(120, 250), true, "hunt") and same(frozen_state, frozen.state), "Modes and routes cannot be changed during execution.")
    var planning = Battle.new()
    planning.setup(PAYLOAD)
    planning.state["version"] = 15
    planning.state.erase("acquisition")
    planning.state.erase("command_remaining")
    planning.state.erase("shared_contacts")
    planning.state.erase("pending_reports")
    var unchanged: Dictionary = planning.state.duplicate(true)
    check(not planning.order_move("UKR_S1", Vector2(120, 250), true, "warp") and same(unchanged, planning.state), "Unknown commands must be rejected without mutation.")
    check(not planning.order_move("RU_S1", Vector2(120, 250), true, "quick"), "Player movement modes must not command the opponent.")
    planning.order_move("UKR_S1", Vector2(120, 250), true, "quick")
    planning.order_move("UKR_S1", Vector2(130, 250), true, "hunt")
    check(planning.movement_mode("UKR_S1") == "hunt", "Replacing a route must also replace its mode.")
    planning.order_hold("UKR_S1")
    check(planning.movement_mode("UKR_S1") == "hold" and planning.state["movement_modes"].is_empty(), "Hold must clear both path and mode.")
    check(planning.order_move("RU_S1", Vector2(450, 300), false, "hunt") and planning.movement_mode("RU_S1") == "hunt", "The symmetric simulation API must support opponent movement modes.")
    for version in [1, 2, 3, 4]:
        var legacy = fixture("move")
        legacy.state["version"] = version
        if int(legacy.state["version"]) < 15: legacy.state.erase("weapon_roles")
        if int(legacy.state["version"]) < 14: legacy.state.erase("postures")
        if version < 13: legacy.state.erase("morale_states")
        if version < 13: legacy.state.erase("rally_remaining")
        if version < 12: legacy.state.erase("fatigue")
        legacy.state.erase("movement_modes")
        legacy.state.erase("fire_modes")
        legacy.state.erase("fire_targets")
        legacy.state.erase("pause_remaining")
        if version < 4:
            legacy.state.erase("contacts")
        check(Battle.validate(legacy.state, PAYLOAD), "Existing v1-v4 fields must remain valid without added modes.")
        var saved: Dictionary = legacy.state.duplicate(true)
        var restored = Battle.new()
        restored.restore(JSON.parse_string(JSON.stringify(saved)))
        legacy.step()
        restored.step()
        check(same(legacy.state, restored.state) and not restored.state.has("movement_modes"), "Legacy restart must retain old movement rules and fields.")
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://movement_test_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._play_demo()
    game.tactical_simulation.state["version"] = 15
    game.tactical_simulation.state.erase("acquisition")
    game.tactical_simulation.state.erase("command_remaining")
    game.tactical_simulation.state.erase("shared_contacts")
    game.tactical_simulation.state.erase("pending_reports")
    game.tactical_simulation.order_move("UKR_S1", Vector2(180, 250), true, "hunt")
    check(game.tactical_simulation.order_move("UKR_S1", Vector2(320, 300), true, "hunt", true), "Actual campaign must append a second leg before disk checkpoint.")
    game.tactical_simulation.order_move("UKR_S2", Vector2(180, 272), true, "quick")
    game.tactical_simulation.execute()
    game.tactical_simulation.step()
    check(game._save_campaign()["ok"], "Actual campaign save must persist distinct orders mid-execution.")
    var snapshot: Dictionary = game._snapshot()
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = game.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"] and same(snapshot, resumed._snapshot()), "Disk load must restore exact paths, modes and execution state.")
    for kind in range(5):
        var bad: Dictionary = snapshot.duplicate(true)
        match kind:
            0: bad["tactical_state"]["movement_modes"]["UKR_S1"] = "warp"
            1: bad["tactical_state"].erase("movement_modes")
            2: bad["tactical_state"]["movement_modes"].erase("UKR_S1")
            3: bad["tactical_state"]["movement_modes"]["UNKNOWN"] = "hunt"
            4: bad["tactical_state"]["orders"]["UKR_S1"] = []
        check(not Saves.validate(bad, game.initial_campaign)["ok"] and same(snapshot, game._snapshot()), "Malformed modes must reject the entire save without live-state changes.")
    finish(game.tactical_simulation)
    finish(resumed.tactical_simulation)
    check(same(game.tactical_simulation.state, resumed.tactical_simulation.state), "Actual disk continuation must preserve the complete battle outcome.")
    game.queue_free()
    resumed.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty():
        print("PASS: distinct speeds, local HUNT contact/fire, suppression pause/recovery, pinning, replacement/hold, legacy rules, validation and disk restart.")
    quit(0 if failures.is_empty() else 1)
