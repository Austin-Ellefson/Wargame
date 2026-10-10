extends SceneTree

const Battle = preload("res://scripts/tactical_battle.gd")
var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func same(a: Variant, b: Variant) -> bool:
    return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))


func finish(simulation: RefCounted) -> Dictionary:
    var guard := 0
    while simulation.state["phase"] != "finished" and guard < 500:
        if simulation.state["phase"] == "planning":
            for squad in simulation.state["squads"]:
                if squad["faction"] == "UKR" and int(squad["alive"]) > 0:
                    var lane := int(str(squad["id"]).right(1)) - 1
                    simulation.order_move(squad["id"], Vector2(242, 218 + lane * 24))
            simulation.execute()
        simulation.step()
        guard += 1
    check(simulation.state["phase"] == "finished", "Battle must finish within the six-interval limit.")
    return simulation.result()


func screen_center(sector: Dictionary) -> Vector2:
    return Vector2(70 + (int(sector["x"]) + 0.5) * 170, 90 + (int(sector["y"]) + 0.5) * 125)


func _run() -> void:
    var directory := "user://repeatable_loop_test_%d" % Time.get_ticks_usec()
    var first = load("res://scenes/main.tscn").instantiate()
    first.auto_launch_battles = false
    root.add_child(first)
    await process_frame
    first.save_path = directory.path_join("campaign.json")
    first.battle_export_directory = directory

    # Battle 1 must originate in the real operational movement/contact loop.
    first._handle_click(Vector2(220, 662))
    check(first.battle_payload.get("battle_id") == "T003_B2", "First campaign contact must create T003_B2.")
    var first_id := str(first.battle_payload.get("battle_id", ""))
    var first_result := finish(first.tactical_simulation)
    check(not first_result.is_empty() and first._apply_tactical_result(first_result)["ok"], "First completed battle must apply.")
    var after_first: Dictionary = first._snapshot()
    check(first.battle_payload.is_empty() and first._detect_first_contact().is_empty(), "First result must retreat the loser and unlock campaign turns.")
    check(first.resolved_battle_ids == [first_id], "First battle identity must enter durable history once.")

    # Restart between engagements from the committed save.
    var resumed = load("res://scenes/main.tscn").instantiate()
    resumed.auto_launch_battles = false
    root.add_child(resumed)
    await process_frame
    resumed.save_path = first.save_path
    resumed.battle_export_directory = directory
    check(resumed._load_campaign()["ok"], "Campaign must load between engagements.")
    check(same(resumed._snapshot(), after_first), "Restart must retain first-battle losses, retreat, result and history.")
    check(not resumed._apply_tactical_result(first_result)["ok"], "The first result must remain duplicate-rejected after restart.")

    # The retreat leaves the two survivors adjacent. Select the loser through the
    # actual campaign click path and move it into the winner's occupied sector.
    var retreating_faction := "UKR" if first_result["winner"] in ["RU", "draw"] else "RU"
    var advancing_id := str(first_result["forces"][retreating_faction]["id"])
    var advancing: Dictionary = resumed._get_unit(advancing_id)
    var opponent_id := str(first_result["forces"]["RU" if retreating_faction == "UKR" else "UKR"]["id"])
    var opponent: Dictionary = resumed._get_unit(opponent_id)
    check(resumed._is_adjacent(advancing["sector"], Vector2i(int(opponent["sector"]["x"]), int(opponent["sector"]["y"]))), "Retreat must leave formations adjacent for the next contact.")
    resumed._handle_click(screen_center(advancing["sector"]))
    resumed._handle_click(screen_center(opponent["sector"]))
    check(same(resumed.pending_orders.get(advancing_id), opponent["sector"]), "Actual click input must order the retreated formation back into contact.")
    resumed._handle_click(Vector2(900, 219)) # RESOLVE TURN control.
    var second_id := str(resumed.battle_payload.get("battle_id", ""))
    check(second_id == "T004_B2" and second_id != first_id, "Second contact must receive a fresh turn-based battle ID.")
    check(resumed.campaign["turn"] == 4 and not resumed.battle_payload.is_empty(), "Second campaign contact must advance the turn and restore the battle lock.")
    var second_contact: Dictionary = resumed._snapshot()
    check(not resumed._apply_tactical_result(first_result)["ok"] and same(resumed._snapshot(), second_contact), "A stale first-battle result must not alter the second pending battle.")

    # Restart with battle 2 pending, then complete and commit it.
    var second_resume = load("res://scenes/main.tscn").instantiate()
    second_resume.auto_launch_battles = false
    root.add_child(second_resume)
    await process_frame
    second_resume.save_path = resumed.save_path
    second_resume.battle_export_directory = directory
    check(second_resume._load_campaign()["ok"], "Second pending battle must load after restart.")
    check(same(second_resume._snapshot(), second_contact), "Second contact lock and tactical state must restore exactly.")
    var second_result := finish(second_resume.tactical_simulation)
    check(second_result.get("battle_id") == second_id, "Second simulation result must match its fresh battle ID.")
    check(second_resume._apply_tactical_result(second_result)["ok"], "Second completed battle must apply.")
    check(second_resume.resolved_battle_ids == [first_id, second_id], "Both distinct battle identities must remain in order.")
    check(second_resume.battle_payload.is_empty() and second_resume._detect_first_contact().is_empty(), "Second result must retreat the loser and unlock the campaign again.")
    for unit in second_resume.units:
        var original := 0
        for initial in second_resume.initial_campaign["units"]:
            if initial["id"] == unit["id"]:
                original = int(initial["personnel"])
        var first_losses := int(first_result["forces"][unit["faction"]]["losses"])
        var second_losses := int(second_result["forces"][unit["faction"]]["losses"])
        check(int(unit["personnel"]) == original - first_losses - second_losses, "Formation losses must accumulate across both battles exactly once.")
    var final_snapshot: Dictionary = second_resume._snapshot()
    check(not second_resume._apply_tactical_result(first_result)["ok"] and not second_resume._apply_tactical_result(second_result)["ok"], "Both old results must be duplicate-rejected after battle 2.")
    check(same(second_resume._snapshot(), final_snapshot), "Duplicate results must not change the completed two-battle campaign.")

    first.queue_free()
    resumed.queue_free()
    second_resume.queue_free()
    await process_frame
    for filename in DirAccess.get_files_at(directory):
        DirAccess.remove_absolute(directory.path_join(filename))
    DirAccess.remove_absolute(directory)
    if failures.is_empty():
        print("PASS: two campaign contacts, fresh IDs, restart, retained losses/history, retreat, unlock and stale/duplicate rejection.")
    quit(0 if failures.is_empty() else 1)
