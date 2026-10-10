extends RefCounted
## Deterministic, JSON-serializable infantry test simulation. Positions are [east, south].

const SIZE := 512.0
const CELL := 8.0
const INTERVAL := 60
const MAX_SECONDS := 360
const DETACHMENT := 36
const SQUAD_SIZE := 9
const ROUNDS_PER_PERSON := 40
const BUILDINGS := [Rect2(222, 152, 30, 30), Rect2(304, 326, 30, 30), Rect2(166, 346, 24, 24)]
const WOODS := [Vector3(212, 290, 29), Vector3(298, 210, 30), Vector3(108, 130, 32)]

var state: Dictionary = {}
var navigation := AStarGrid2D.new()
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

static func visible(a: Vector2, b: Vector2) -> bool:
    var distance := a.distance_to(b)
    var samples := maxi(1, int(ceil(distance / 4.0)))
    var start_height := terrain_height(a.x, a.y) + 1.6
    var end_height := terrain_height(b.x, b.y) + 1.6
    for index in range(1, samples):
        var fraction := float(index) / samples
        var point := a.lerp(b, fraction)
        if inside_building(point) or terrain_height(point.x, point.y) > lerpf(start_height, end_height, fraction):
            return false
    return true

func setup(payload: Dictionary) -> void:
    state = {"version": 1, "battle_id": payload["battle_id"], "phase": "planning", "elapsed": 0,
        "remaining": 0, "objective": {"UKR": 0, "RU": 0}, "squads": [], "orders": {}, "winner": ""}
    state["squads"] = get_script_static_setup(payload)
    last_events = []
    _build_navigation()

func restore(saved: Dictionary) -> void:
    state = saved.duplicate(true)
    last_events = []
    _build_navigation()

func consume_events() -> Array:
    var events := last_events.duplicate(true)
    last_events = []
    return events

func _build_navigation() -> void:
    navigation.region = Rect2i(0, 0, 64, 64)
    navigation.cell_size = Vector2(CELL, CELL)
    navigation.offset = Vector2(CELL / 2, CELL / 2)
    navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    navigation.update()
    for y in range(64):
        for x in range(64):
            var point := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
            navigation.set_point_solid(Vector2i(x, y), inside_building(point, 5.0))

func squad_by_id(id: String) -> Dictionary:
    for squad in state["squads"]:
        if squad["id"] == id:
            return squad
    return {}

func order_move(id: String, target: Vector2, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if state["phase"] != "planning" or squad.is_empty() or int(squad["alive"]) <= 0:
        return false
    if player and squad["faction"] != "UKR":
        return false
    if not is_finite(target.x) or not is_finite(target.y) or target.x < 4 or target.y < 4 or target.x > SIZE - 4 or target.y > SIZE - 4 or inside_building(target, 5.0):
        return false
    var origin := position(squad)
    var start := Vector2i(int(origin.x / CELL), int(origin.y / CELL))
    var finish := Vector2i(int(target.x / CELL), int(target.y / CELL))
    if navigation.is_point_solid(finish):
        return false
    var points := navigation.get_point_path(start, finish)
    if points.is_empty():
        return false
    var path: Array = []
    # Preserve the actual start and finish; intermediate cells route around buildings.
    for index in range(1, points.size()):
        path.append([points[index].x, points[index].y])
    path.append([target.x, target.y])
    state["orders"][id] = path
    return true

func order_hold(id: String) -> bool:
    var squad := squad_by_id(id)
    if state["phase"] != "planning" or squad.is_empty() or squad["faction"] != "UKR" or int(squad["alive"]) <= 0:
        return false
    state["orders"].erase(id)
    return true

func execute() -> bool:
    if state["phase"] != "planning":
        return false
    for squad in state["squads"]:
        if squad["faction"] == "RU" and int(squad["alive"]) > 0:
            var lane := int(str(squad["id"]).right(1)) - 1
            order_move(squad["id"], Vector2(272, 218 + lane * 24), false)
    state["phase"] = "execution"
    state["remaining"] = INTERVAL
    return true

func step() -> void:
    last_events = []
    if state["phase"] != "execution":
        return
    state["elapsed"] = int(state["elapsed"]) + 1
    state["remaining"] = int(state["remaining"]) - 1
    for squad in state["squads"]:
        squad["suppression"] = maxf(0, float(squad["suppression"]) - 0.035)
        if int(squad["alive"]) <= 0:
            state["orders"].erase(squad["id"])
            continue
        var path: Array = state["orders"].get(squad["id"], [])
        var speed := 2.4 * (1.0 - 0.8 * float(squad["suppression"]))
        while speed > 0 and not path.is_empty():
            var current := position(squad)
            var target := Vector2(float(path[0][0]), float(path[0][1]))
            var distance := current.distance_to(target)
            if distance <= speed:
                squad["position"] = [target.x, target.y]
                path.pop_front()
                speed -= distance
            else:
                var next := current.move_toward(target, speed)
                squad["position"] = [next.x, next.y]
                speed = 0
        if path.is_empty():
            state["orders"].erase(squad["id"])
    # Collect attacks before applying damage: both sides fire from the same tick state.
    var attacks: Array = []
    if int(state["elapsed"]) % 3 == 0:
        for shooter in state["squads"]:
            if int(shooter["alive"]) <= 0 or int(shooter["ammo"]) <= 0:
                continue
            var target := _nearest_target(shooter)
            if target.is_empty():
                continue
            var rounds := mini(int(shooter["alive"]), int(shooter["ammo"]))
            shooter["ammo"] = int(shooter["ammo"]) - rounds
            var distance := position(shooter).distance_to(position(target))
            var chance := 0.14 * (1.0 - distance / 400.0) * (1.0 - cover(position(target))) * (1.0 - 0.75 * float(shooter["suppression"]))
            var random := RandomNumberGenerator.new()
            random.seed = (str(state["battle_id"]) + ":" + str(state["elapsed"]) + ":" + str(shooter["id"])).sha256_text().left(8).hex_to_int()
            var losses := 0
            for round_index in range(rounds):
                if random.randf() < chance:
                    losses += 1
            var event := {"type": "shot", "tick": state["elapsed"], "shooter": shooter["id"],
                "target": target["id"], "from": shooter["position"].duplicate(),
                "to": target["position"].duplicate(), "rounds": rounds, "losses": losses}
            last_events.append(event)
            attacks.append({"target": target["id"], "losses": losses, "pressure": 0.07 + rounds * 0.012})
    for attack in attacks:
        var target := squad_by_id(attack["target"])
        var losses := mini(int(target["alive"]), int(attack["losses"]))
        target["alive"] = int(target["alive"]) - losses
        target["suppression"] = minf(1, float(target["suppression"]) + float(attack["pressure"]))
        target["morale"] = maxi(0, int(target["morale"]) - losses * 3)
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
    var best: Dictionary = {}
    var distance := 230.0
    for candidate in state["squads"]:
        if candidate["faction"] == shooter["faction"] or int(candidate["alive"]) <= 0:
            continue
        var separation := position(shooter).distance_to(position(candidate))
        if separation < distance and visible(position(shooter), position(candidate)):
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
    if not saved is Dictionary or saved.size() != 9:
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
    if not _integer(saved["version"], 1, 1) or saved["battle_id"] != payload.get("battle_id") or saved["phase"] not in ["planning", "execution", "finished"]:
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
