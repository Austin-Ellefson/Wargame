extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var payload := {"battle_id": "PINNING_FIXTURE", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80},
        "russia": {"id": "RED", "personnel": 36, "morale": 80}}
    var battle = Battle.new()
    battle.setup(payload)
    battle.state["version"] = 15
    battle.state.erase("acquisition")
    for squad in battle.state["squads"]:
        squad["ammo"] = 0
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    blue["suppression"] = 1.0
    check(battle.order_move("UKR_S1", Vector2(140, 208)), "A pinned squad must retain a queued movement order.")
    var original_path: Array = battle.state["orders"]["UKR_S1"].duplicate(true)
    var origin := Battle.position(blue)
    battle.execute()
    for tick in range(6):
        battle.step()
        check(Battle.position(blue) == origin, "Heavy suppression must stop movement until recovery.")
    check(same(original_path, battle.state["orders"]["UKR_S1"]), "Pinning must not consume or erase the route.")
    battle.step()
    check(not battle.is_pinned(blue) and Battle.position(blue) != origin, "Movement must resume automatically below the morale-sensitive threshold.")
    var low := blue.duplicate(true)
    low["morale"] = 20
    low["suppression"] = 0.65
    var high := low.duplicate(true)
    high["morale"] = 100
    check(battle.is_pinned(low) and not battle.is_pinned(high), "Lower morale must make a squad easier to pin at the same pressure.")
    low["alive"] = 0
    check(not battle.is_pinned(low) and battle.combat_status(low) == "ELIMINATED", "Eliminated squads must not be labeled pinned.")
    # Old in-flight engagements retain V1 movement rules and version on restore.
    var legacy = Battle.new()
    legacy.setup(payload)
    legacy.state["version"] = 15
    legacy.state.erase("acquisition")
    legacy.state["version"] = 1
    if int(legacy.state["version"]) < 15: legacy.state.erase("weapon_roles")
    if int(legacy.state["version"]) < 14: legacy.state.erase("postures")
    legacy.state.erase("morale_states")
    legacy.state.erase("rally_remaining")
    legacy.state.erase("fatigue")
    legacy.state.erase("contacts")
    legacy.state.erase("movement_modes")
    legacy.state.erase("fire_modes")
    legacy.state.erase("fire_targets")
    legacy.state.erase("pause_remaining")
    legacy.squad_by_id("UKR_S1")["suppression"] = 1.0
    for squad in legacy.state["squads"]:
        squad["ammo"] = 0
    legacy.order_move("UKR_S1", Vector2(140, 208))
    check(Battle.validate(legacy.state, payload), "Existing V1 tactical saves must still validate.")
    var legacy_restart = Battle.new()
    legacy_restart.restore(JSON.parse_string(JSON.stringify(legacy.state)))
    legacy.execute()
    legacy_restart.execute()
    legacy.step()
    legacy_restart.step()
    check(Battle.position(legacy.squad_by_id("UKR_S1")) != Vector2(80, 208), "V1 suppression must keep its original slowed movement behavior.")
    check(same(legacy.state, legacy_restart.state) and legacy_restart.state["version"] == 1, "Loading a V1 engagement must not silently switch its combat rules.")
    var invalid: Dictionary = battle.state.duplicate(true)
    invalid["version"] = 17
    check(not Battle.validate(invalid, payload), "Unknown tactical rule versions must be rejected.")
    # Actual incoming simulated volleys pin a living squad, not just a UI fixture.
    var firefight = Battle.new()
    firefight.setup(payload)
    firefight.state["version"] = 15
    firefight.state.erase("acquisition")
    for squad in firefight.state["squads"]:
        if squad["faction"] == "UKR":
            squad["ammo"] = 0
            if squad["id"] != "UKR_S1":
                squad["alive"] = 0
        else:
            squad["position"] = [250, 208]
    firefight.order_move("UKR_S1", Vector2(140, 208))
    firefight.execute()
    firefight.state["orders"] = {"UKR_S1": firefight.state["orders"]["UKR_S1"]}
    firefight.state["movement_modes"] = {"UKR_S1": "move"}
    var victim: Dictionary = firefight.squad_by_id("UKR_S1")
    for tick in range(18):
        firefight.step()
        if firefight.is_pinned(victim) or int(victim["alive"]) == 0:
            break
    check(firefight.is_pinned(victim), "Real concentrated incoming fire must pin surviving infantry.")
    check(Battle.validate(firefight.state, payload), "Pinned mid-execution state must validate for restart.")
    var resumed = Battle.new()
    resumed.restore(JSON.parse_string(JSON.stringify(firefight.state)))
    check(resumed.is_pinned(resumed.squad_by_id("UKR_S1")), "JSON restart must retain the same pinning status.")
    # Give the pinned squad ammunition: pinning stops movement, not return fire.
    # Isolate pinning return fire from the new low-morale break rule.
    victim["morale"] = payload["ukraine"]["morale"]
    resumed.squad_by_id("UKR_S1")["morale"] = payload["ukraine"]["morale"]
    victim["ammo"] = 100
    resumed.squad_by_id("UKR_S1")["ammo"] = 100
    var returned_fire := false
    for tick in range(3):
        firefight.step()
        resumed.step()
        for event in firefight.consume_events():
            if event["shooter"] == "UKR_S1":
                returned_fire = true
        check(same(firefight.state, resumed.state), "Pinned restart must preserve every authoritative tick and random outcome.")
    check(returned_fire, "Pinned survivors must still be capable of suppressed return fire.")
    if failures.is_empty():
        print("PASS: incoming-fire pinning, morale thresholds, stopped routes, recovery, return fire and versioned deterministic restart.")
    quit(0 if failures.is_empty() else 1)
