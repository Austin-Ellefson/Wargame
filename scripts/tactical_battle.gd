extends RefCounted
## Deterministic, JSON-serializable infantry test simulation. Positions are [east, south].

const SIZE := 512.0
const CELL := 8.0
const INTERVAL := 60
const MAX_SECONDS := 360
const DETACHMENT := 36
const SQUAD_SIZE := 9
const ROUNDS_PER_PERSON := 40
const SPOT_RANGE := 280.0
const WOODS_SPOT_RANGE := 120.0
const BUILDINGS := [Rect2(222, 152, 30, 30), Rect2(304, 326, 30, 30), Rect2(166, 346, 24, 24)]
const WOODS := [Vector3(212, 290, 29), Vector3(298, 210, 30), Vector3(108, 130, 32)]

var state: Dictionary = {}
var navigation := AStarGrid2D.new()
var cover_navigation := AStarGrid2D.new()
## Presentation-only events from the most recent simulated second. They are
## deliberately excluded from state/save validation and never affect RNG.
var last_events: Array = []

static func terrain_height(x: float, z: float) -> float:
    return 3.5 * exp(-Vector2(x - 160, z - 140).length_squared() / 9000.0) + 5.0 * exp(-Vector2(x - 360, z - 390).length_squared() / 12000.0)

static func position(squad: Dictionary) -> Vector2:
    return Vector2(float(squad["position"][0]), float(squad["position"][1]))

static func inside_building(point: Vector2, margin: float = 0.0) -> bool:
    for building in BUILDINGS:
        if building.grow(margin).has_point(point):
            return true
    return false

static func cover(point: Vector2) -> float:
    for wood in WOODS:
        if point.distance_to(Vector2(wood.x, wood.y)) < wood.z:
            return 0.55
    return 0.12

static func visible(a: Vector2, b: Vector2, observer_height: float = 1.6, target_height: float = 1.6) -> bool:
    var distance := a.distance_to(b)
    var samples := maxi(1, int(ceil(distance / 4.0)))
    var start_height := terrain_height(a.x, a.y) + observer_height
    var end_height := terrain_height(b.x, b.y) + target_height
    for index in range(1, samples):
        var fraction := float(index) / samples
        var point := a.lerp(b, fraction)
        if inside_building(point) or terrain_height(point.x, point.y) > lerpf(start_height, end_height, fraction):
            return false
    return true

func setup(payload: Dictionary) -> void:
    state = {"version": 15, "battle_id": payload["battle_id"], "phase": "planning", "elapsed": 0,
        "remaining": 0, "objective": {"UKR": 0, "RU": 0}, "squads": [], "orders": {}, "winner": ""}
    state["squads"] = get_script_static_setup(payload)
    state["contacts"] = {"UKR": {}, "RU": {}}
    state["movement_modes"] = {}
    state["fire_modes"] = {}
    state["fire_targets"] = {}
    state["pause_remaining"] = {}
    state["fatigue"] = {}
    state["morale_states"] = {}
    state["rally_remaining"] = {}
    state["postures"] = {}
    state["weapon_roles"] = {}
    for squad in state["squads"]:
        state["fire_modes"][squad["id"]] = "auto"
        state["fire_targets"][squad["id"]] = ""
        state["pause_remaining"][squad["id"]] = 0
        state["fatigue"][squad["id"]] = 0
        state["morale_states"][squad["id"]] = "steady"
        state["rally_remaining"][squad["id"]] = 0
        state["postures"][squad["id"]] = "stand"
        state["weapon_roles"][squad["id"]] = initial_weapon_role(squad["id"])
    last_events = []
    _build_navigation()
    _update_contacts()

func restore(saved: Dictionary) -> void:
    state = saved.duplicate(true)
    last_events = []
    _build_navigation()

func consume_events() -> Array:
    var events := last_events.duplicate(true)
    last_events = []
    return events

func _build_navigation() -> void:
    # Separate fixed terrain graphs keep player/legacy routing unchanged.
    # Woods cost 1, open ground 1.6: prefer cover, without arbitrary long detours.
    # No enemy positions, contacts or random samples enter the route cost.
    for graph in [navigation, cover_navigation]:
        graph.region = Rect2i(0, 0, 64, 64)
        graph.cell_size = Vector2(CELL, CELL)
        graph.offset = Vector2(CELL / 2, CELL / 2)
        graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
        graph.update()
    for y in range(64):
        for x in range(64):
            var point := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
            var cell := Vector2i(x, y)
            var blocked := inside_building(point, 5.0)
            navigation.set_point_solid(cell, blocked)
            cover_navigation.set_point_solid(cell, blocked)
            cover_navigation.set_point_weight_scale(cell, 1.0 if cover(point) > 0.2 else 1.6)

func squad_by_id(id: String) -> Dictionary:
    for squad in state["squads"]:
        if squad["id"] == id:
            return squad
    return {}

static func initial_weapon_role(id: String) -> String:
    # Fictional roster: alternating maneuver and support-fire squads. Equipment
    # is abstract at squad level; this is not an individual weapon inventory.
    return "support" if id.ends_with("S2") or id.ends_with("S4") else "rifle"

func weapon_role(id: String) -> String:
    return str(state["weapon_roles"][id]) if int(state["version"]) >= 15 else "rifle"

func fire_interval(id: String) -> int:
    return 2 if weapon_role(id) == "support" else 3

func rounds_per_volley(squad: Dictionary) -> int:
    var multiplier := 2 if weapon_role(squad["id"]) == "support" else 1
    return mini(int(squad["alive"]) * multiplier, int(squad["ammo"]))

func posture(id: String) -> String:
    return str(state["postures"][id]) if int(state["version"]) >= 14 else "stand"

func posture_height(id: String) -> float:
    return float({"stand": 1.6, "crouch": 1.0, "prone": 0.35}[posture(id)])

func squad_visible(observer: Dictionary, target: Dictionary) -> bool:
    return visible(position(observer), position(target), posture_height(observer["id"]), posture_height(target["id"]))

func spot_limit(observer: Dictionary, target: Dictionary) -> float:
    var terrain_limit := WOODS_SPOT_RANGE if cover(position(target)) > 0.2 else SPOT_RANGE
    # Fixed prototype tradeoffs, no random acquisition or hidden information.
    var observation: float = {"stand": 1.0, "crouch": 0.9, "prone": 0.75}[posture(observer["id"])]
    var concealment: float = {"stand": 1.0, "crouch": 0.85, "prone": 0.65}[posture(target["id"])]
    return terrain_limit * observation * concealment

func posture_speed(id: String) -> float:
    return float({"stand": 1.0, "crouch": 0.7, "prone": 0.3}[posture(id)])

func hit_probability(shooter: Dictionary, target: Dictionary) -> float:
    var distance := position(shooter).distance_to(position(target))
    var exposure: float = {"stand": 1.0, "crouch": 0.75, "prone": 0.5}[posture(target["id"])]
    return 0.14 * (1.0 - distance / 400.0) * (1.0 - cover(position(target))) * (1.0 - 0.75 * float(shooter["suppression"])) * (0.75 if morale_state(shooter["id"]) == "shaken" else 1.0) * exposure

func order_posture(id: String, value: String, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if int(state["version"]) < 14 or state["phase"] != "planning" or value not in ["stand", "crouch", "prone"] or squad.is_empty() or int(squad["alive"]) <= 0 or morale_state(id) == "broken" or (player and squad["faction"] != "UKR"):
        return false
    state["postures"][id] = value
    _update_contacts()
    return true

func morale_state(id: String) -> String:
    return str(state["morale_states"][id]) if int(state["version"]) >= 13 else "steady"

func _retreat_route(squad: Dictionary) -> void:
    var id: String = squad["id"]
    state["orders"].erase(id)
    state["movement_modes"].erase(id)
    state["pause_remaining"][id] = 0
    if int(state["version"]) >= 14: state["postures"][id] = "stand"
    _assign_route(id, Vector2(32 if squad["faction"] == "UKR" else 480, clampf(position(squad).y, 24, 488)), "quick")

func _update_morale(squad: Dictionary) -> void:
    if int(state["version"]) < 13: return
    var id: String = squad["id"]
    if int(squad["alive"]) <= 0:
        state["rally_remaining"][id] = 0
        return
    var suppression := float(squad["suppression"])
    var heavy_losses := int(squad["alive"]) * 2 <= int(squad["initial"])
    if morale_state(id) == "broken":
        var at_rear := position(squad).x <= 40 if squad["faction"] == "UKR" else position(squad).x >= 472
        if not at_rear and not state["orders"].has(id): _retreat_route(squad)
        if at_rear and not state["orders"].has(id) and suppression < 0.25:
            state["rally_remaining"][id] = maxi(0, int(state["rally_remaining"][id]) - 1)
            if state["rally_remaining"][id] == 0: state["morale_states"][id] = "shaken"
        else:
            state["rally_remaining"][id] = 30
        return
    if suppression >= 0.65 and (int(squad["morale"]) <= 35 or (heavy_losses and int(squad["morale"]) <= 70)):
        state["morale_states"][id] = "broken"
        state["rally_remaining"][id] = 30
        _retreat_route(squad)
    else:
        state["morale_states"][id] = "shaken" if heavy_losses or int(squad["morale"]) < 60 or suppression >= 0.5 else "steady"

func is_pinned(squad: Dictionary) -> bool:
    # V1 engagements retain their original rules when resumed. V2 pinning is
    # derived from saved morale/suppression; no hidden state or random samples.
    return int(state["version"]) >= 2 and int(squad["alive"]) > 0 and float(squad["suppression"]) >= pin_threshold(squad)

static func pin_threshold(squad: Dictionary) -> float:
    return 0.5 + clampf(float(squad["morale"]), 0.0, 100.0) * 0.0035

func combat_status(squad: Dictionary) -> String:
    if int(squad["alive"]) <= 0:
        return "ELIMINATED"
    if morale_state(squad["id"]) == "broken": return "BROKEN"
    return "PINNED" if is_pinned(squad) else ("SHAKEN" if morale_state(squad["id"]) == "shaken" else "READY")

func limited_visibility() -> bool:
    return int(state["version"]) >= 3

func can_spot(observer: Dictionary, target: Dictionary) -> bool:
    if observer.is_empty() or target.is_empty() or int(observer["alive"]) <= 0 or int(target["alive"]) <= 0 or observer["faction"] == target["faction"]:
        return false
    return position(observer).distance_to(position(target)) <= spot_limit(observer, target) and squad_visible(observer, target)

func is_observed(faction: String, target: Dictionary) -> bool:
    if target.is_empty():
        return false
    if target["faction"] == faction or not limited_visibility():
        return true
    for observer in state["squads"]:
        if observer["faction"] == faction and can_spot(observer, target):
            return true
    return false

func observed_contacts(faction: String) -> int:
    var count := 0
    for target in state["squads"]:
        if target["faction"] != faction and int(target["alive"]) > 0 and is_observed(faction, target):
            count += 1
    return count

func _update_contacts() -> void:
    if int(state["version"]) < 4:
        return
    for faction in ["UKR", "RU"]:
        for target in state["squads"]:
            if target["faction"] == faction:
                continue
            if is_observed(faction, target):
                state["contacts"][faction][target["id"]] = {"position": target["position"].duplicate(), "seen_at": int(state["elapsed"])}
            elif int(target["alive"]) == 0:
                # Death can be confirmed only by a living observer with sight
                # of the position. A hidden death must leave memory untouched.
                for observer in state["squads"]:
                    if observer["faction"] == faction and int(observer["alive"]) > 0:
                        var limit := spot_limit(observer, target)
                        if position(observer).distance_to(position(target)) <= limit and squad_visible(observer, target):
                            state["contacts"][faction].erase(target["id"])
                            break

func last_known_contacts(faction: String) -> Array:
    var contacts: Array = []
    if int(state["version"]) < 4 or state["phase"] == "finished":
        return contacts
    for id in state["contacts"][faction]:
        if not is_observed(faction, squad_by_id(id)):
            var record: Dictionary = state["contacts"][faction][id]
            contacts.append({"id": id, "position": record["position"].duplicate(), "seen_at": record["seen_at"]})
    return contacts

func can_engage(shooter: Dictionary, target: Dictionary) -> bool:
    return not shooter.is_empty() and not target.is_empty() and int(shooter["alive"]) > 0 and int(target["alive"]) > 0 and shooter["faction"] != target["faction"] and position(shooter).distance_to(position(target)) < 230.0 and squad_visible(shooter, target) and (not limited_visibility() or can_spot(shooter, target))

func order_target(id: String, target_id: String, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if int(state["version"]) < 7 or state["phase"] != "planning" or squad.is_empty() or int(squad["alive"]) <= 0 or morale_state(id) == "broken" or (player and squad["faction"] != "UKR"):
        return false
    if not target_id.is_empty() and not can_engage(squad, squad_by_id(target_id)):
        return false
    state["fire_targets"][id] = target_id
    return true

func target_status(id: String) -> String:
    if int(state["version"]) < 7 or str(state["fire_targets"][id]).is_empty():
        return "Focus: none"
    return "Focus: ready" if can_engage(squad_by_id(id), squad_by_id(state["fire_targets"][id])) else "Focus: waiting for sight"

func fire_mode(id: String) -> String:
    return str(state["fire_modes"][id]) if int(state["version"]) >= 6 else "auto"

func order_fire(id: String, mode: String, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if int(state["version"]) < 6 or state["phase"] != "planning" or mode not in ["auto", "hold"] or squad.is_empty() or int(squad["alive"]) <= 0 or morale_state(id) == "broken" or (player and squad["faction"] != "UKR"):
        return false
    state["fire_modes"][id] = mode
    return true

func order_pause(id: String, seconds: Variant, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if int(state["version"]) < 8 or state["phase"] != "planning" or not _integer(seconds, 0, 60) or squad.is_empty() or int(squad["alive"]) <= 0 or not state["orders"].has(id) or morale_state(id) == "broken" or (player and squad["faction"] != "UKR"):
        return false
    state["pause_remaining"][id] = int(seconds)
    return true

func movement_mode(id: String) -> String:
    if not state["orders"].has(id):
        return "hold"
    return str(state["movement_modes"].get(id, "move")) if int(state["version"]) >= 5 else "move"

func fatigue(id: String) -> float:
    return float(state["fatigue"][id]) / 1000.0 if int(state["version"]) >= 12 else 0.0

func hunt_paused(squad: Dictionary) -> bool:
    if movement_mode(squad["id"]) != "hunt" or int(squad["alive"]) <= 0:
        return false
    if float(squad["suppression"]) >= 0.25:
        return true
    for enemy in state["squads"]:
        if can_spot(squad, enemy):
            return true
    return false

func movement_status(squad: Dictionary) -> String:
    if int(squad["alive"]) <= 0: return "NONE"
    if morale_state(squad["id"]) == "broken":
        return "WITHDRAWING" if state["orders"].has(squad["id"]) else "RALLY %ds" % int(state["rally_remaining"][squad["id"]])
    var mode := movement_mode(squad["id"])
    if int(state["version"]) >= 8 and int(state["pause_remaining"][squad["id"]]) > 0:
        return "WAIT %ds (%s)" % [state["pause_remaining"][squad["id"]], mode.to_upper()]
    return "HUNT PAUSED" if hunt_paused(squad) else mode.to_upper()

func order_move(id: String, target: Vector2, player: bool = true, mode: String = "move", append: bool = false) -> bool:
    if mode not in ["move", "quick", "hunt"] or (int(state["version"]) < 5 and mode != "move"):
        return false
    var squad := squad_by_id(id)
    if state["phase"] != "planning" or squad.is_empty() or int(squad["alive"]) <= 0 or morale_state(id) == "broken":
        return false
    if player and squad["faction"] != "UKR":
        return false
    return _assign_route(id, target, mode, append)

func _assign_route(id: String, target: Vector2, mode: String = "move", append: bool = false) -> bool:
    var squad := squad_by_id(id)
    if not is_finite(target.x) or not is_finite(target.y) or target.x < 4 or target.y < 4 or target.x > SIZE - 4 or target.y > SIZE - 4 or inside_building(target, 5.0):
        return false
    var previous: Array = state["orders"].get(id, []).duplicate(true) if append else []
    if append and not previous.is_empty() and movement_mode(id) != mode:
        return false
    var origin := Vector2(previous.back()[0], previous.back()[1]) if not previous.is_empty() else position(squad)
    var start := Vector2i(int(origin.x / CELL), int(origin.y / CELL))
    var finish := Vector2i(int(target.x / CELL), int(target.y / CELL))
    if navigation.is_point_solid(finish):
        return false
    var graph := cover_navigation if int(state["version"]) >= 10 and squad["faction"] == "RU" else navigation
    var points := graph.get_point_path(start, finish)
    if points.is_empty():
        return false
    var path: Array = previous
    # Preserve the actual start and finish; intermediate cells route around buildings.
    for index in range(1, points.size()):
        path.append([points[index].x, points[index].y])
    path.append([target.x, target.y])
    if path.size() > 128:
        return false
    state["orders"][id] = path
    if int(state["version"]) >= 5:
        state["movement_modes"][id] = mode
    if int(state["version"]) >= 8 and not append:
        state["pause_remaining"][id] = 0
    return true

func order_hold(id: String) -> bool:
    var squad := squad_by_id(id)
    if state["phase"] != "planning" or squad.is_empty() or squad["faction"] != "UKR" or int(squad["alive"]) <= 0 or morale_state(id) == "broken":
        return false
    state["orders"].erase(id)
    if int(state["version"]) >= 5:
        state["movement_modes"].erase(id)
    if int(state["version"]) >= 8:
        state["pause_remaining"][id] = 0
    return true

func execute() -> bool:
    if state["phase"] != "planning":
        return false
    var reserved: Array[Vector2] = []
    for squad in state["squads"]:
        if squad["faction"] == "RU" and int(squad["alive"]) > 0:
            if morale_state(squad["id"]) == "broken":
                _retreat_route(squad)
                continue
            var destination := opponent_destination(squad, reserved)
            if order_move(squad["id"], destination, false):
                reserved.append(destination)
    state["phase"] = "execution"
    state["remaining"] = INTERVAL
    return true

func opponent_destination(squad: Dictionary, reserved: Array[Vector2]) -> Vector2:
    var lane := int(str(squad["id"]).right(1)) - 1
    var fallback := Vector2(272, 218 + lane * 24)
    if int(state["version"]) < 11:
        return fallback
    # Fixed terrain and own route reachability only. Reserve separated positions
    # for living squads in stable roster order, without consulting enemy state.
    var best := fallback
    var best_score := INF
    var start := Vector2i(position(squad) / CELL)
    for y in range(25, 39):
        for x in range(25, 39):
            var cell := Vector2i(x, y)
            var point := cover_navigation.get_point_position(cell)
            if point.distance_to(Vector2(256, 256)) >= 52.0 or cover(point) <= 0.2 or cover_navigation.is_point_solid(cell):
                continue
            var separated := true
            for taken in reserved:
                if point.distance_to(taken) < 12.0:
                    separated = false
                    break
            var score := point.distance_squared_to(fallback)
            if not separated or score >= best_score or cover_navigation.get_point_path(start, cell).is_empty():
                continue
            best = point
            best_score = score
    return best

func opponent_engaging(squad: Dictionary) -> bool:
    # React only to this squad's currently engageable contact, never shared
    # memory or hidden positions. The objective route remains queued.
    if int(state["version"]) < 9 or squad["faction"] != "RU" or int(squad["alive"]) <= 0 or int(squad["ammo"]) <= 0 or fire_mode(squad["id"]) != "auto" or morale_state(squad["id"]) == "broken":
        return false
    for enemy in state["squads"]:
        if can_engage(squad, enemy):
            return true
    return false

func step() -> void:
    last_events = []
    if state["phase"] != "execution":
        return
    state["elapsed"] = int(state["elapsed"]) + 1
    state["remaining"] = int(state["remaining"]) - 1
    for squad in state["squads"]:
        squad["suppression"] = maxf(0, float(squad["suppression"]) - 0.035)
        _update_morale(squad)
        var waiting := int(state["version"]) >= 8 and int(state["pause_remaining"][squad["id"]]) > 0
        if waiting:
            state["pause_remaining"][squad["id"]] = int(state["pause_remaining"][squad["id"]]) - 1
        if int(squad["alive"]) <= 0:
            state["orders"].erase(squad["id"])
            if int(state["version"]) >= 5:
                state["movement_modes"].erase(squad["id"])
            if int(state["version"]) >= 8:
                state["pause_remaining"][squad["id"]] = 0
            continue
        var path: Array = state["orders"].get(squad["id"], [])
        var base_speed: float = {"move": 2.4, "quick": 4.0, "hunt": 1.2}[movement_mode(squad["id"])] if not path.is_empty() else 0.0
        var mode := movement_mode(squad["id"])
        var speed: float = float(base_speed) * (1.0 - 0.8 * float(squad["suppression"])) * (1.0 - 0.5 * fatigue(squad["id"])) * (0.75 if morale_state(squad["id"]) == "shaken" else 1.0)
        speed *= posture_speed(squad["id"])
        if waiting or is_pinned(squad) or hunt_paused(squad) or opponent_engaging(squad):
            speed = 0.0
        var travelled := 0.0
        while speed > 0 and not path.is_empty():
            var current := position(squad)
            var target := Vector2(float(path[0][0]), float(path[0][1]))
            var distance := current.distance_to(target)
            travelled += minf(distance, speed)
            if distance <= speed:
                squad["position"] = [target.x, target.y]
                path.pop_front()
                speed -= distance
            else:
                var next := current.move_toward(target, speed)
                squad["position"] = [next.x, next.y]
                speed = 0
        if int(state["version"]) >= 12:
            # Per-metre costs charge actual motion, not an order that was halted.
            # Rest uses simulated seconds, including PAUSE/HUNT/pinning holds.
            var cost: float = {"move": 0.001, "quick": 0.002, "hunt": 0.0005}.get(mode, 0.0)
            var change := travelled * cost if travelled > 0.0 else -0.003
            state["fatigue"][squad["id"]] = clampi(int(state["fatigue"][squad["id"]]) + roundi(change * 1000.0), 0, 1000)
        if path.is_empty():
            state["orders"].erase(squad["id"])
            if int(state["version"]) >= 5:
                state["movement_modes"].erase(squad["id"])
            if int(state["version"]) >= 8:
                state["pause_remaining"][squad["id"]] = 0
    _update_contacts()
    # Collect attacks before applying damage: both sides fire from the same tick state.
    var attacks: Array = []
    for shooter in state["squads"]:
        if int(state["elapsed"]) % fire_interval(shooter["id"]) != 0:
            continue
        if int(shooter["alive"]) <= 0 or int(shooter["ammo"]) <= 0 or fire_mode(shooter["id"]) == "hold" or morale_state(shooter["id"]) == "broken":
            continue
        var target := _nearest_target(shooter)
        if target.is_empty():
            continue
        var rounds := rounds_per_volley(shooter)
        shooter["ammo"] = int(shooter["ammo"]) - rounds
        var chance := hit_probability(shooter, target) * (0.65 if weapon_role(shooter["id"]) == "support" else 1.0)
        var random := RandomNumberGenerator.new()
        random.seed = (str(state["battle_id"]) + ":" + str(state["elapsed"]) + ":" + str(shooter["id"])).sha256_text().left(8).hex_to_int()
        var losses := 0
        for round_index in range(rounds):
            if random.randf() < chance:
                losses += 1
        var event := {"type": "shot", "tick": state["elapsed"], "shooter": shooter["id"],
            "target": target["id"], "from": shooter["position"].duplicate(),
            "to": target["position"].duplicate(), "rounds": rounds, "losses": losses}
        # Snapshot visibility at firing time, before simultaneous losses.
        # Hidden enemy endpoints must not be revealed by presentation cues.
        if int(state["version"]) >= 15: event["weapon_role"] = weapon_role(shooter["id"])
        event["player_visible"] = is_observed("UKR", shooter) and is_observed("UKR", target)
        last_events.append(event)
        attacks.append({"target": target["id"], "losses": losses, "pressure": 0.07 + rounds * 0.012})
    for attack in attacks:
        var target := squad_by_id(attack["target"])
        var losses := mini(int(target["alive"]), int(attack["losses"]))
        target["alive"] = int(target["alive"]) - losses
        target["suppression"] = minf(1, float(target["suppression"]) + float(attack["pressure"]))
        target["morale"] = maxi(0, int(target["morale"]) - losses * 3)
    _update_contacts()
    var on_objective := {"UKR": false, "RU": false}
    for squad in state["squads"]:
        if int(squad["alive"]) > 0 and position(squad).distance_to(Vector2(256, 256)) <= 52:
            on_objective[squad["faction"]] = true
    for faction in ["UKR", "RU"]:
        if on_objective[faction] and not on_objective["RU" if faction == "UKR" else "UKR"]:
            state["objective"][faction] = int(state["objective"][faction]) + 1
    if alive("UKR") == 0 or alive("RU") == 0 or int(state["elapsed"]) >= MAX_SECONDS:
        state["phase"] = "finished"
        state["remaining"] = 0
        if alive("UKR") == 0 and alive("RU") > 0:
            state["winner"] = "RU"
        elif alive("RU") == 0 and alive("UKR") > 0:
            state["winner"] = "UKR"
        elif int(state["objective"]["UKR"]) != int(state["objective"]["RU"]):
            state["winner"] = "UKR" if int(state["objective"]["UKR"]) > int(state["objective"]["RU"]) else "RU"
        else:
            state["winner"] = "draw"
    elif int(state["remaining"]) == 0:
        state["phase"] = "planning"

func _nearest_target(shooter: Dictionary) -> Dictionary:
    if int(state["version"]) >= 7:
        var preferred := squad_by_id(state["fire_targets"][shooter["id"]])
        if can_engage(shooter, preferred):
            return preferred
    var best: Dictionary = {}
    var distance := 230.0
    for candidate in state["squads"]:
        if candidate["faction"] == shooter["faction"] or int(candidate["alive"]) <= 0:
            continue
        var separation := position(shooter).distance_to(position(candidate))
        if separation < distance and squad_visible(shooter, candidate) and (not limited_visibility() or can_spot(shooter, candidate)):
            distance = separation
            best = candidate
    return best

func alive(faction: String) -> int:
    var total := 0
    for squad in state["squads"]:
        if squad["faction"] == faction:
            total += int(squad["alive"])
    return total

func result() -> Dictionary:
    if state["phase"] != "finished":
        return {}
    var forces := {}
    for faction in ["UKR", "RU"]:
        var deployed := 0
        var remaining_ammo := 0
        var morale := 0
        var formation := ""
        for squad in state["squads"]:
            if squad["faction"] == faction:
                deployed += int(squad["initial"])
                remaining_ammo += int(squad["ammo"])
                morale += int(squad["morale"])
                formation = squad["formation_id"]
        var count := maxi(1, int(ceil(float(deployed) / SQUAD_SIZE)))
        forces[faction] = {"id": formation, "deployed": deployed, "losses": deployed - alive(faction),
            "ammunition_used": deployed * ROUNDS_PER_PERSON - remaining_ammo, "morale": int(morale / count)}
    return {"version": 1, "battle_id": state["battle_id"], "winner": state["winner"],
        "elapsed": state["elapsed"], "objective": state["objective"].duplicate(true), "forces": forces}

static func validate(saved: Variant, payload: Dictionary) -> bool:
    if not saved is Dictionary or not _integer(saved.get("version"), 1, 15):
        return false
    var version := int(saved["version"])
    var field_count := 9 + int(version >= 4) + int(version >= 5) + int(version >= 6) + int(version >= 7) + int(version >= 8) + int(version >= 12) + 2 * int(version >= 13) + int(version >= 14) + int(version >= 15)
    if saved.size() != field_count:
        return false
    for key in ["version", "battle_id", "phase", "elapsed", "remaining", "objective", "squads", "orders", "winner"]:
        if not saved.has(key):
            return false
    return _validate_fields(saved, payload)

static func _integer(value: Variant, low: int, high: int) -> bool:
    return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func _point(value: Variant) -> bool:
    return value is Array and value.size() == 2 and (typeof(value[0]) == TYPE_INT or typeof(value[0]) == TYPE_FLOAT) and (typeof(value[1]) == TYPE_INT or typeof(value[1]) == TYPE_FLOAT) and is_finite(float(value[0])) and is_finite(float(value[1])) and value[0] >= 4 and value[0] <= SIZE - 4 and value[1] >= 4 and value[1] <= SIZE - 4

static func _validate_fields(saved: Dictionary, payload: Dictionary) -> bool:
    if saved["battle_id"] != payload.get("battle_id") or saved["phase"] not in ["planning", "execution", "finished"]:
        return false
    if not _integer(saved["elapsed"], 0, MAX_SECONDS) or not _integer(saved["remaining"], 0, INTERVAL):
        return false
    if saved["phase"] == "execution" and (saved["remaining"] <= 0 or (int(saved["elapsed"]) + int(saved["remaining"])) % INTERVAL != 0):
        return false
    if saved["phase"] != "execution" and saved["remaining"] != 0:
        return false
    if saved["phase"] == "planning" and (int(saved["elapsed"]) % INTERVAL != 0 or saved["elapsed"] >= MAX_SECONDS):
        return false
    if not saved["objective"] is Dictionary or saved["objective"].size() != 2:
        return false
    for faction in ["UKR", "RU"]:
        if not _integer(saved["objective"].get(faction), 0, int(saved["elapsed"])):
            return false
    if int(saved["objective"]["UKR"]) + int(saved["objective"]["RU"]) > int(saved["elapsed"]):
        return false
    if not saved["squads"] is Array or not saved["orders"] is Dictionary:
        return false
    var expected := get_script_static_setup(payload)
    if saved["squads"].size() != expected.size():
        return false
    var known := {}
    for index in range(expected.size()):
        var original: Dictionary = expected[index]
        var squad = saved["squads"][index]
        if not squad is Dictionary or squad.size() != original.size():
            return false
        for key in original:
            if not squad.has(key):
                return false
        for key in ["id", "formation_id", "faction", "initial"]:
            if squad[key] != original[key]:
                return false
        if not _integer(squad["alive"], 0, int(original["initial"])) or not _integer(squad["ammo"], 0, int(original["ammo"])) or not _integer(squad["morale"], 0, int(original["morale"])):
            return false
        if (typeof(squad["suppression"]) != TYPE_INT and typeof(squad["suppression"]) != TYPE_FLOAT) or not is_finite(float(squad["suppression"])) or squad["suppression"] < 0 or squad["suppression"] > 1 or not _point(squad["position"]):
            return false
        if inside_building(position(squad), 0.5):
            return false
        known[squad["id"]] = true
    for id in saved["orders"]:
        if not known.has(id) or not saved["orders"][id] is Array or saved["orders"][id].size() > 128:
            return false
        for point in saved["orders"][id]:
            if not _point(point) or inside_building(Vector2(point[0], point[1]), 0.5):
                return false
    if int(saved["version"]) >= 4:
        if not saved.get("contacts") is Dictionary or saved["contacts"].size() != 2:
            return false
        for faction in ["UKR", "RU"]:
            var contacts = saved["contacts"].get(faction)
            if not contacts is Dictionary:
                return false
            for id in contacts:
                var enemy := false
                for squad in expected:
                    if squad["id"] == id and squad["faction"] != faction:
                        enemy = true
                var record = contacts[id]
                if not enemy or not record is Dictionary or record.size() != 2 or not _point(record.get("position")) or not _integer(record.get("seen_at"), 0, int(saved["elapsed"])):
                    return false
                if inside_building(Vector2(record["position"][0], record["position"][1]), 0.5):
                    return false
    if int(saved["version"]) >= 5:
        var modes = saved.get("movement_modes")
        if not modes is Dictionary or modes.size() != saved["orders"].size():
            return false
        for id in modes:
            if not saved["orders"].has(id) or modes[id] not in ["move", "quick", "hunt"] or saved["orders"][id].is_empty():
                return false
    if int(saved["version"]) >= 6:
        var modes = saved.get("fire_modes")
        if not modes is Dictionary or modes.size() != known.size():
            return false
        for id in known:
            if modes.get(id) not in ["auto", "hold"]:
                return false
    if int(saved["version"]) >= 7:
        var targets = saved.get("fire_targets")
        if not targets is Dictionary or targets.size() != known.size():
            return false
        for squad in saved["squads"]:
            var target_id = targets.get(squad["id"])
            if not target_id is String:
                return false
            if not target_id.is_empty():
                var opposing := false
                for target in saved["squads"]:
                    if target["id"] == target_id and target["faction"] != squad["faction"]:
                        opposing = true
                if not opposing:
                    return false
    if int(saved["version"]) >= 8:
        var pauses = saved.get("pause_remaining")
        if not pauses is Dictionary or pauses.size() != known.size():
            return false
        for id in known:
            if not _integer(pauses.get(id), 0, 60) or (pauses[id] > 0 and (not saved["orders"].has(id) or saved["orders"][id].is_empty())):
                return false
    if int(saved["version"]) >= 12:
        var fatigue_map = saved.get("fatigue")
        if not fatigue_map is Dictionary or fatigue_map.size() != known.size():
            return false
        for id in known:
            var value = fatigue_map.get(id)
            if not _integer(value, 0, 1000):
                return false
    if int(saved["version"]) >= 13:
        var states = saved.get("morale_states")
        var rally = saved.get("rally_remaining")
        if not states is Dictionary or not rally is Dictionary or states.size() != known.size() or rally.size() != known.size(): return false
        for squad in saved["squads"]:
            var id: String = squad["id"]
            if states.get(id) not in ["steady", "shaken", "broken"] or not _integer(rally.get(id), 0, 30): return false
            if states[id] != "broken" and rally[id] != 0: return false
            if states[id] == "broken" and int(squad["alive"]) > 0 and rally[id] == 0: return false
    if int(saved["version"]) >= 14:
        var postures = saved.get("postures")
        if not postures is Dictionary or postures.size() != known.size(): return false
        for id in known:
            if postures.get(id) not in ["stand", "crouch", "prone"]: return false
            if saved["morale_states"][id] == "broken" and postures[id] != "stand": return false
    if int(saved["version"]) >= 15:
        var roles = saved.get("weapon_roles")
        if not roles is Dictionary or roles.size() != known.size(): return false
        for id in known:
            if not roles.get(id) is String or roles[id] != initial_weapon_role(id): return false
    var survivors := {"UKR": 0, "RU": 0}
    for squad in saved["squads"]:
        survivors[squad["faction"]] += int(squad["alive"])
    if saved["phase"] == "finished":
        if int(saved["elapsed"]) <= 0:
            return false
        if survivors["UKR"] > 0 and survivors["RU"] > 0 and int(saved["elapsed"]) < MAX_SECONDS:
            return false
        var winner := "draw"
        if survivors["UKR"] == 0 and survivors["RU"] > 0:
            winner = "RU"
        elif survivors["RU"] == 0 and survivors["UKR"] > 0:
            winner = "UKR"
        elif saved["objective"]["UKR"] != saved["objective"]["RU"]:
            winner = "UKR" if saved["objective"]["UKR"] > saved["objective"]["RU"] else "RU"
        return saved["winner"] == winner
    return saved["winner"] == "" and int(saved["elapsed"]) < MAX_SECONDS and survivors["UKR"] > 0 and survivors["RU"] > 0

static func get_script_static_setup(payload: Dictionary) -> Array:
    var squads: Array = []
    for faction in ["UKR", "RU"]:
        var force: Dictionary = payload.get("ukraine" if faction == "UKR" else "russia", {})
        var available := mini(DETACHMENT, int(force.get("personnel", 0)))
        var index := 0
        while available > 0:
            var count := mini(SQUAD_SIZE, available)
            squads.append({"id": "%s_S%d" % [faction, index + 1], "formation_id": force.get("id", ""),
                "faction": faction, "initial": count, "alive": count, "ammo": count * ROUNDS_PER_PERSON,
                "morale": int(force.get("morale", 0)), "suppression": 0.0,
                "position": [80.0 if faction == "UKR" else 432.0, 208.0 + index * 32.0]})
            available -= count
            index += 1
    return squads
