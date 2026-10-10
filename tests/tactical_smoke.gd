extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
const Saves = preload("res://scripts/campaign_save.gd")
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func finish(battle: RefCounted, give_orders: bool = true) -> void:
    var guard := 0
    while battle.state["phase"] != "finished" and guard < 500:
        if battle.state["phase"] == "planning":
            if give_orders:
                for squad in battle.state["squads"]:
                    if squad["faction"] == "UKR":
                        var lane := int(str(squad["id"]).right(1)) - 1
                        battle.order_move(squad["id"], Vector2(242, 218 + lane * 24))
            battle.execute()
        battle.step()
        guard += 1
    check(battle.state["phase"] == "finished", "Battle must terminate within six intervals.")

func _run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    game.auto_launch_battles = false
    root.add_child(game)
    await process_frame
    var directory := "user://tactical_test_%d" % Time.get_ticks_usec()
    game.save_path = directory.path_join("campaign.json")
    game.battle_export_directory = directory
    game._handle_click(Vector2(220, 662)) # Actual integrated-demo control.
    check(game.battle_payload.get("battle_id") == "T003_B2", "Demo must use the campaign movement/contact loop.")
    check(FileAccess.file_exists(game.save_path), "Contact must autosave the unresolved battle.")
    var contact: Dictionary = game._snapshot()
    game._resolve_turn()
    game._handle_click(Vector2(325, 277))
    check(same(game._snapshot(), contact), "Pending battle must lock turns and campaign orders.")
    var payload: Dictionary = game.battle_payload.duplicate(true)
    var battle = game.tactical_simulation
    check(Battle.validate(battle.state, payload), "Initial tactical state must validate.")
    check(battle.alive("UKR") == 36 and battle.alive("RU") == 36, "Only the detachment must deploy, not the whole battalion.")
    check(not battle.order_move("RU_S1", Vector2(200, 200)), "Player must not issue enemy orders.")
    check(not battle.order_move("UKR_S1", Vector2(-1, 200)), "Out-of-map orders must be rejected.")
    check(not battle.order_move("UKR_S1", Vector2(230, 166)), "Building destinations must be rejected.")
    check(not Battle.visible(Vector2(200, 166), Vector2(270, 166)), "Buildings must obstruct line of sight.")
    check(Battle.cover(Vector2(212, 290)) > Battle.cover(Vector2(80, 208)), "Woods must provide cover.")
    check(battle.order_move("UKR_S1", Vector2(274, 166)), "Navigation must find a route around a building.")
    for point in battle.state["orders"]["UKR_S1"]:
        check(not Battle.inside_building(Vector2(point[0], point[1]), 5), "Path must avoid building footprints.")
    var initial_point: Vector2 = Battle.position(battle.squad_by_id("UKR_S1"))
    check(Battle.position(battle.squad_by_id("UKR_S1")) == initial_point, "Planning must not execute movement.")
    battle.execute()
    check(not battle.order_move("UKR_S1", Vector2(100, 100)), "Orders must freeze during execution.")
    for tick in range(17):
        battle.step()
    check(Battle.position(battle.squad_by_id("UKR_S1")) != initial_point, "Execution must move ordered squads.")
    check(game._save_campaign()["ok"], "Mid-interval tactical state must save.")
    var midway: Dictionary = game._snapshot()
    var restarted = load("res://scenes/main.tscn").instantiate()
    restarted.auto_launch_battles = false
    root.add_child(restarted)
    await process_frame
    restarted.save_path = game.save_path
    restarted.battle_export_directory = directory
    check(restarted._load_campaign()["ok"], "Native battle must load after restart.")
    check(same(restarted._snapshot(), midway), "Restore must preserve exact positions, ammo, paths, phase and clock.")
    finish(battle)
    finish(restarted.tactical_simulation)
    check(same(battle.state, restarted.tactical_simulation.state), "Restored simulation must deterministically reach the same result.")
    check(Battle.validate(battle.state, payload), "Completed tactical state must validate.")
    var result: Dictionary = battle.result()
    print("Fixture battle: ", JSON.stringify(result))
    var total_losses := int(result["forces"]["UKR"]["losses"]) + int(result["forces"]["RU"]["losses"])
    check(total_losses > 0, "Engaging detachments must exchange fire and incur casualties.")
    for faction in ["UKR", "RU"]:
        check(result["forces"][faction]["losses"] <= 36, "Losses must be limited to deployed personnel.")
        check(result["forces"][faction]["ammunition_used"] > 0, "Combat must expend ammunition.")
    # Altered, stale and excessive results cannot touch live state.
    var finished_snapshot: Dictionary = game._snapshot()
    var invalid := result.duplicate(true)
    invalid["battle_id"] = "T999_A1"
    check(not game._apply_tactical_result(invalid)["ok"], "Stale result identity must be rejected.")
    invalid = result.duplicate(true)
    invalid["forces"]["UKR"]["losses"] = 9999
    check(not game._apply_tactical_result(invalid)["ok"], "Fabricated losses must be rejected.")
    check(same(game._snapshot(), finished_snapshot), "Rejected results must leave campaign state untouched.")
    # A failed commit retains both the old save and the completed battle for retry.
    check(game._save_campaign()["ok"], "Completed battle must save before commit.")
    var saved_bytes := FileAccess.get_file_as_string(game.save_path)
    DirAccess.make_dir_absolute(game.save_path + ".tmp")
    check(not game._apply_tactical_result(result)["ok"], "Result commit must report a save write failure.")
    check(same(game._snapshot(), finished_snapshot), "Failed result save must roll back force losses and resolution history.")
    check(FileAccess.get_file_as_string(game.save_path) == saved_bytes, "Failed result commit must retain previous on-disk state.")
    DirAccess.remove_absolute(game.save_path + ".tmp")
    check(game._apply_tactical_result(result)["ok"], "Valid native result must apply and save.")
    var applied: Dictionary = game._snapshot()
    for index in range(2):
        var faction: String = game.units[index]["faction"]
        check(game.units[index]["personnel"] == int(finished_snapshot["units"][index]["personnel"]) - int(result["forces"][faction]["losses"]), "Campaign losses must subtract exactly once.")
        check(game.units[index]["vehicles"] == finished_snapshot["units"][index]["vehicles"], "Reserve vehicles must not receive invented losses.")
    check(game.battle_payload.is_empty() and game._detect_first_contact().is_empty(), "Result must unlock the campaign and retreat the losing formation.")
    check(not game._apply_tactical_result(result)["ok"] and same(game._snapshot(), applied), "Duplicate result must not apply twice.")
    check(restarted._load_campaign()["ok"] and same(restarted._snapshot(), applied), "Applied losses and resolved IDs must persist across restart.")
    check(not restarted._apply_tactical_result(result)["ok"], "Duplicate result must remain rejected after restart.")
    game._resolve_turn()
    check(game.campaign["turn"] == 4, "Campaign must advance after the result is committed.")
    # Legacy saves migrate without discarding formation progress.
    var legacy := contact.duplicate(true)
    for key in ["tactical_state", "battle_origins", "resolved_battle_ids", "last_battle_result"]:
        legacy.erase(key)
    legacy["schema_version"] = 1
    var migrated := Saves.validate(legacy, game.initial_campaign)
    check(migrated["ok"] and migrated["snapshot"]["schema_version"] == 2, "Version 1 saves must migrate.")
    var bad_states: Array = []
    var bad: Dictionary = midway.duplicate(true)
    bad["tactical_state"]["squads"][0]["alive"] = 100
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["tactical_state"]["squads"][0]["position"] = [999, 10]
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["tactical_state"]["squads"][0]["ammo"] = -1
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["tactical_state"]["remaining"] = 60
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["tactical_state"] = {}
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["tactical_state"]["phase"] = "finished"
    bad["tactical_state"]["remaining"] = 0
    bad["tactical_state"]["winner"] = "UKR"
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["tactical_state"]["orders"]["unknown"] = [[100, 100]]
    bad_states.append(bad)
    bad = midway.duplicate(true)
    bad["pending_orders"] = {"UKR_1": {"x": 0, "y": 1}}
    bad_states.append(bad)
    bad = applied.duplicate(true)
    bad["resolved_battle_ids"].append(result["battle_id"])
    bad_states.append(bad)
    for corrupted in bad_states:
        check(not Saves.validate(corrupted, game.initial_campaign)["ok"], "Malformed tactical/lock/history data must be rejected.")
    # Low-strength formations deploy only the personnel that actually remain.
    var depleted := payload.duplicate(true)
    depleted["ukraine"]["personnel"] = 5
    var small = Battle.new()
    small.setup(depleted)
    check(small.alive("UKR") == 5 and small.state["squads"].size() == 5, "Depleted formation must not fabricate a full platoon.")
    var timed = Battle.new()
    timed.setup(payload)
    for squad in timed.state["squads"]:
        squad["ammo"] = 0
    finish(timed, false)
    check(timed.state["elapsed"] == Battle.MAX_SECONDS and timed.result()["forces"]["UKR"]["losses"] == 0, "Ammunition exhaustion must prevent fire and the battle clock must still terminate.")
    check(timed.state["winner"] == "RU", "Uncontested objective control must determine the timed result.")
    # Transient shot events must describe actual attacks without entering saved state.
    var event_battle = Battle.new()
    event_battle.setup(payload)
    for squad in event_battle.state["squads"]:
        squad["alive"] = 0
    var blue: Dictionary = event_battle.squad_by_id("UKR_S1")
    var red: Dictionary = event_battle.squad_by_id("RU_S1")
    blue["alive"] = 9
    red["alive"] = 9
    blue["position"] = [120, 220]
    red["position"] = [180, 220]
    event_battle.execute()
    for tick in range(3):
        event_battle.step()
    var events := event_battle.consume_events()
    check(events.size() == 2, "Both eligible squads must emit an event when they actually fire.")
    for event in events:
        check(event["type"] == "shot" and event["rounds"] > 0 and event.has("shooter") and event.has("target"), "Shot events must identify shooter, target and expended rounds.")
    check(not event_battle.state.has("events") and event_battle.consume_events().is_empty(), "Presentation events must be transient and excluded from authoritative state.")
    var no_fire = Battle.new()
    no_fire.setup(payload)
    for squad in no_fire.state["squads"]:
        squad["ammo"] = 0
    no_fire.execute()
    for tick in range(3):
        no_fire.step()
    check(no_fire.consume_events().is_empty(), "Empty-ammunition squads must not emit firing events.")
    var blocked = Battle.new()
    blocked.setup(payload)
    for squad in blocked.state["squads"]:
        squad["alive"] = 0
    blocked.squad_by_id("UKR_S1")["alive"] = 9
    blocked.squad_by_id("RU_S1")["alive"] = 9
    blocked.squad_by_id("UKR_S1")["position"] = [200, 166]
    blocked.squad_by_id("RU_S1")["position"] = [270, 166]
    blocked.execute()
    for tick in range(3):
        blocked.step()
    check(blocked.consume_events().is_empty(), "Building-blocked fire must not emit a cue.")
    var distant = Battle.new()
    distant.setup(payload)
    for squad in distant.state["squads"]:
        squad["alive"] = 0
    distant.squad_by_id("UKR_S1")["alive"] = 9
    distant.squad_by_id("RU_S1")["alive"] = 9
    distant.squad_by_id("UKR_S1")["position"] = [40, 40]
    distant.squad_by_id("RU_S1")["position"] = [470, 470]
    distant.execute()
    for tick in range(3):
        distant.step()
    check(distant.consume_events().is_empty(), "Out-of-range fire must not emit a cue.")
    game.units[0]["personnel"] = 0
    game.units[0]["sector"] = game.units[1]["sector"].duplicate(true)
    var occupied: Dictionary = game.units[1]["sector"]
    check(game._top_unit_in_sector(Vector2i(occupied["x"], occupied["y"]))["id"] == "RU_1", "Eliminated formations must not block selecting a surviving formation in the same sector.")
    restarted.queue_free()
    game.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty():
        print("PASS: native WEGO, navigation/LOS, deterministic restart, battle locks, validated results, once-only losses, rollback and migration.")
    quit(0 if failures.is_empty() else 1)
