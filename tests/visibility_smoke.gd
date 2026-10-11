extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)

func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

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
    var payload := {"battle_id": "SIGHT_FIXTURE", "ukraine": {"id": "BLUE", "personnel": 36, "morale": 80},
        "russia": {"id": "RED", "personnel": 36, "morale": 80}}
    var battle = Battle.new()
    battle.setup(payload)
    var blue: Dictionary = battle.squad_by_id("UKR_S1")
    var red: Dictionary = battle.squad_by_id("RU_S1")
    check(battle.state["version"] == 4 and battle.observed_contacts("UKR") == 0, "Fresh contacts must not start with omniscient enemy positions.")
    var snapshot: Dictionary = battle.state.duplicate(true)
    for repeat in range(10):
        battle.observed_contacts("UKR")
        battle.is_observed("RU", blue)
    check(same(snapshot, battle.state), "Spotting queries must be pure: no hidden state or RNG changes.")
    blue["position"] = [80, 250]
    red["position"] = [200, 250]
    check(battle.can_spot(blue, red) and battle.can_spot(red, blue), "Open ground spotting must be symmetric.")
    red["position"] = [470, 470]
    check(not battle.can_spot(blue, red), "Distant open-ground enemies must remain hidden.")
    blue["position"] = [200, 166]
    red["position"] = [270, 166]
    check(not battle.can_spot(blue, red) and not battle.can_spot(red, blue), "Buildings must block spotting for both sides.")
    # Woods conceal the target. A concealed shooter can see an exposed target
    # without automatically revealing itself through a full shot line.
    blue["position"] = [42, 290]
    red["position"] = [212, 290]
    check(Battle.visible(Battle.position(blue), Battle.position(red)), "Woods test requires unobstructed terrain LOS.")
    check(not battle.can_spot(blue, red) and battle.can_spot(red, blue), "Woods must reduce target spotting range without blocking all outward observation.")
    for squad in battle.state["squads"]:
        if squad["id"] not in ["UKR_S1", "RU_S1"]:
            squad["alive"] = 0
    var initial_ammo := int(blue["ammo"])
    battle.execute()
    battle.state["orders"].clear()
    for tick in range(3):
        battle.step()
    var shots := battle.consume_events()
    check(shots.size() == 1 and shots[0]["shooter"] == "RU_S1" and not shots[0]["player_visible"], "Unobserved incoming fire must not produce a player-visible enemy endpoint.")
    check(int(blue["ammo"]) == initial_ammo and float(blue["suppression"]) > 0, "Unspotted enemies must not be auto-targeted, while their actual incoming fire still causes pressure.")
    blue["position"] = [110, 290]
    check(battle.can_spot(blue, red) and battle.is_observed("UKR", red), "Closing range must acquire a concealed contact.")
    for tick in range(3):
        battle.step()
    shots = battle.consume_events()
    var returned_fire := false
    for shot in shots:
        if shot["shooter"] == "UKR_S1" and shot["player_visible"]:
            returned_fire = true
    check(returned_fire, "An acquired target must permit actual observed return fire.")
    var acquired_position: Array = blue["position"].duplicate()
    blue["position"] = [42, 290]
    check(not battle.is_observed("UKR", red), "Losing sight must remove the current contact rather than track its hidden position.")
    blue["position"] = acquired_position
    var observer_alive := int(blue["alive"])
    blue["alive"] = 0
    check(not battle.is_observed("UKR", red), "Dead observers cannot acquire or retain contacts.")
    blue["alive"] = observer_alive
    check(Battle.validate(battle.state, payload), "V3 mid-execution sight state must validate.")
    var resumed = Battle.new()
    resumed.restore(JSON.parse_string(JSON.stringify(battle.state)))
    check(resumed.is_observed("UKR", resumed.squad_by_id("RU_S1")), "Reload must derive the same current sight picture.")
    finish(battle)
    finish(resumed)
    check(same(battle.state, resumed.state) and same(battle.result(), resumed.result()), "V3 spotting and combat must reach identical outcomes after JSON restart.")
    # Old rules retain their full visibility and original targeting in woods.
    for version in [1, 2]:
        var legacy = Battle.new()
        legacy.setup(payload)
        legacy.state["version"] = version
        legacy.state.erase("contacts")
        for squad in legacy.state["squads"]:
            if squad["id"] not in ["UKR_S1", "RU_S1"]:
                squad["alive"] = 0
        legacy.squad_by_id("UKR_S1")["position"] = [42, 290]
        legacy.squad_by_id("RU_S1")["position"] = [212, 290]
        check(Battle.validate(legacy.state, payload) and legacy.is_observed("UKR", legacy.squad_by_id("RU_S1")), "V1/V2 saves must retain their original full-visibility rules.")
        var old_restart = Battle.new()
        old_restart.restore(JSON.parse_string(JSON.stringify(legacy.state)))
        legacy.execute()
        old_restart.execute()
        legacy.state["orders"].clear()
        old_restart.state["orders"].clear()
        for tick in range(3):
            legacy.step()
            old_restart.step()
        check(int(legacy.squad_by_id("UKR_S1")["ammo"]) < initial_ammo and same(legacy.state, old_restart.state), "Old rules must still fire at LOS-valid wooded targets and restart identically.")
    if failures.is_empty():
        print("PASS: symmetric LOS/range spotting, woods concealment, hidden fire, acquisition, pure queries and V1/V2/V3 deterministic restart.")
    quit(0 if failures.is_empty() else 1)
