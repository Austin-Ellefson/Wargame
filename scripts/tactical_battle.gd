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
const COVER_PRESSURE_TICKS := 6
const COVER_RADIUS := 32.0
const COVER_PATH_LIMIT := 40.0
const COVER_SEPARATION := 12.0
const COVER_RETRY_SECONDS := 12
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
    state = {"version": 27, "battle_id": payload["battle_id"], "phase": "planning", "elapsed": 0,
        "remaining": 0, "objective": {"UKR": 0, "RU": 0}, "squads": [], "orders": {}, "winner": ""}
    state["squads"] = get_script_static_setup(payload)
    state["contacts"] = {"UKR": {}, "RU": {}}
    state["shared_contacts"] = {"UKR": {}, "RU": {}}
    state["pending_reports"] = {"UKR": {}, "RU": {}}
    state["observer_contacts"] = {}
    state["facing_orders"] = {}
    state["area_fire"] = {}
    state["cover_responses"] = {}
    state["movement_modes"] = {}
    state["route_legs"] = {}
    state["route_modes"] = {}
    state["fire_modes"] = {}
    state["fire_targets"] = {}
    state["pause_remaining"] = {}
    state["fatigue"] = {}
    state["morale_states"] = {}
    state["rally_remaining"] = {}
    state["postures"] = {}
    state["weapon_roles"] = {}
    state["acquisition"] = {}
    state["command_remaining"] = {}
    for squad in state["squads"]:
        state["acquisition"][squad["id"]] = {}
        state["observer_contacts"][squad["id"]] = {}
        state["area_fire"][squad["id"]] = []
        _clear_cover_response(squad["id"])
        state["facing_orders"][squad["id"]] = {"heading": 0 if squad["faction"] == "UKR" else 180, "width": 0}
        state["command_remaining"][squad["id"]] = 0
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
    _update_acquisition()
    _update_contacts()
    return true

func morale_state(id: String) -> String:
    return str(state["morale_states"][id]) if int(state["version"]) >= 13 else "steady"

func _retreat_route(squad: Dictionary) -> void:
    var id: String = squad["id"]
    if int(state["version"]) >= 23: _clear_cover_response(id)
    state["orders"].erase(id)
    state["movement_modes"].erase(id)
    if int(state["version"]) >= 26: state["route_legs"].erase(id)
    if int(state["version"]) >= 27: state["route_modes"].erase(id)
    state["pause_remaining"][id] = 0
    if int(state["version"]) >= 14: state["postures"][id] = "stand"
    _assign_route(id, Vector2(32 if squad["faction"] == "UKR" else 480, clampf(position(squad).y, 24, 488)), "quick")
    if int(state["version"]) >= 17: state["command_remaining"][id] = 0

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
        if int(state["version"]) >= 20: state["facing_orders"][id]["width"] = 0
        if int(state["version"]) >= 21: state["area_fire"][id] = []
        state["rally_remaining"][id] = 30
        _retreat_route(squad)
    else:
        state["morale_states"][id] = "shaken" if heavy_losses or int(squad["morale"]) < 60 or suppression >= 0.5 else "steady"

# Red reacts to its own received pressure only; no attacker/contact lookup.
# Existing saved posture supplies hysteresis. Planning and render queries do
# not run this behavior, and automatic morale withdrawal keeps priority.
func _opponent_duck(squad: Dictionary) -> void:
    if int(state["version"]) < 22 or squad["faction"] != "RU" or int(squad["alive"]) <= 0 or morale_state(squad["id"]) == "broken": return
    # Compare fixed precision to avoid JSON/binary drift at decimal thresholds.
    var pressure := roundi(float(squad["suppression"]) * 1000000.0)
    var id: String = squad["id"]
    if pressure >= 550000:
        state["postures"][id] = "prone"
    elif pressure >= 300000 and posture(id) == "stand":
        state["postures"][id] = "crouch"
    elif pressure < 150000:
        state["postures"][id] = "stand"

func seeking_cover(id: String) -> bool:
    return int(state["version"]) >= 23 and not state["cover_responses"][id]["goal"].is_empty()

func _stable_pressure(value: float) -> float:
    # Moving through area falloff produces long decimals. V23 rounds writes,
    # so JSON disk checkpoints cannot perturb subsequent suppression ticks.
    return roundi(value * 1000000.0) / 1000000.0 if int(state["version"]) >= 23 else value

func _clear_cover_response(id: String) -> void:
    state["cover_responses"][id] = {"pressure_ticks": 0, "goal": [], "path": []}
    if int(state["version"]) >= 25: state["cover_responses"][id]["retry_remaining"] = 0

func _terrain_path(origin: Vector2, target: Vector2) -> Array:
    var points := cover_navigation.get_point_path(Vector2i(origin / CELL), Vector2i(target / CELL))
    var path: Array = []
    if points.is_empty(): return path
    for index in range(1, points.size()): path.append([points[index].x, points[index].y])
    if path.is_empty() or Vector2(path.back()[0], path.back()[1]) != target: path.append([target.x, target.y])
    return path

static func _path_length(origin: Vector2, path: Array) -> float:
    var distance := 0.0
    for point in path:
        var next := Vector2(point[0], point[1])
        distance += origin.distance_to(next)
        origin = next
    return distance

func _resume_cover_route(squad: Dictionary) -> void:
    var id: String = squad["id"]
    var queued: Array = state["orders"].get(id, [])
    if seeking_cover(id) and not queued.is_empty():
        # Rejoin the untouched queue through terrain navigation, never by a
        # straight shortcut across a building after the sideways cover move.
        var join := _terrain_path(position(squad), Vector2(queued[0][0], queued[0][1]))
        if join.is_empty() or join.size() + queued.size() - 1 > 128: return
        join.append_array(queued.slice(1))
        state["orders"][id] = join
    _clear_cover_response(id)

func _cover_goal_available(squad: Dictionary, point: Vector2) -> bool:
    if int(state["version"]) < 24: return true
    # Reserve a squad footprint using friendly state only. The validated roster
    # order resolves simultaneous choices; persisted active goals reserve space
    # before arrival. No cache, enemy lookup or random tie-break is needed.
    for friendly in state["squads"]:
        if friendly["id"] == squad["id"] or friendly["faction"] != squad["faction"] or int(friendly["alive"]) <= 0: continue
        if point.distance_squared_to(position(friendly)) < COVER_SEPARATION * COVER_SEPARATION: return false
        if seeking_cover(friendly["id"]):
            var goal: Array = state["cover_responses"][friendly["id"]]["goal"]
            if point.distance_squared_to(Vector2(goal[0], goal[1])) < COVER_SEPARATION * COVER_SEPARATION: return false
    return true

func _opponent_cover(squad: Dictionary) -> void:
    if int(state["version"]) < 23: return
    var id: String = squad["id"]
    if squad["faction"] != "RU" or int(squad["alive"]) <= 0 or morale_state(id) == "broken":
        _clear_cover_response(id)
        return
    var pressure := roundi(float(squad["suppression"]) * 1000000.0)
    if pressure < 150000:
        _resume_cover_route(squad)
        return
    var response: Dictionary = state["cover_responses"][id]
    if seeking_cover(id): return
    if pressure < 300000:
        response["pressure_ticks"] = 0
        if int(state["version"]) >= 25: response["retry_remaining"] = 0
        return
    if int(response["pressure_ticks"]) == COVER_PRESSURE_TICKS:
        if int(state["version"]) < 25 or int(response["retry_remaining"]) == 0: return
        # Only a previously viable but occupied destination arms this timer.
        # Count simulated seconds, not frames; no pathfinding during cooldown.
        response["retry_remaining"] = int(response["retry_remaining"]) - 1
        if int(response["retry_remaining"]) > 0: return
    else:
        response["pressure_ticks"] = int(response["pressure_ticks"]) + 1
    if int(response["pressure_ticks"]) < COVER_PRESSURE_TICKS or cover(position(squad)) > 0.2: return
    # A bounded local terrain search in fixed y/x order. No enemy positions,
    # acquisition, remembered contacts, threat bearings or random samples.
    var origin := position(squad)
    var start := Vector2i(origin / CELL)
    var best_length := INF
    var best_path: Array = []
    var crowded := false
    for y in range(maxi(0, start.y - 4), mini(64, start.y + 5)):
        for x in range(maxi(0, start.x - 4), mini(64, start.x + 5)):
            var cell := Vector2i(x, y)
            var point := cover_navigation.get_point_position(cell)
            if cover_navigation.is_point_solid(cell) or cover(point) <= 0.2 or origin.distance_to(point) > COVER_RADIUS: continue
            var available := _cover_goal_available(squad, point)
            if not available and int(state["version"]) < 25: continue
            var path := _terrain_path(origin, point)
            if path.is_empty(): continue
            var distance := _path_length(origin, path)
            # Reserve enough of the existing 128-point budget for the later
            # terrain-safe rejoin, retaining every original queued waypoint.
            if distance > COVER_PATH_LIMIT or distance >= best_length or path.size() * 2 + state["orders"].get(id, []).size() + 2 > 128: continue
            if not available:
                crowded = true
                continue
            best_length = distance
            best_path = path
    if not best_path.is_empty():
        response["goal"] = best_path.back().duplicate()
        response["path"] = best_path
    elif crowded and int(state["version"]) >= 25:
        response["retry_remaining"] = COVER_RETRY_SECONDS

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

func has_sight(observer: Dictionary, target: Dictionary) -> bool:
    if observer.is_empty() or target.is_empty() or int(observer["alive"]) <= 0 or int(target["alive"]) <= 0 or observer["faction"] == target["faction"]:
        return false
    return position(observer).distance_to(position(target)) <= spot_limit(observer, target) and squad_visible(observer, target)

# Acquisition advances once per simulated second, never from a UI query or
# planning order. Shared contacts do not fill another observer's local timer.
func _update_acquisition(advance: bool = false) -> void:
    if int(state["version"]) < 16: return
    for observer in state["squads"]:
        var records: Dictionary = state["acquisition"][observer["id"]]
        for target in state["squads"]:
            if not has_sight(observer, target):
                if int(observer["alive"]) > 0 and int(target["alive"]) == 0 and observer["faction"] != target["faction"] and int(records.get(target["id"], 0)) >= 3 and position(observer).distance_to(position(target)) <= spot_limit(observer, target) and squad_visible(observer, target):
                    state["contacts"][observer["faction"]].erase(target["id"])
                    _remember_elimination(observer, target)
                records.erase(target["id"])
            elif advance:
                records[target["id"]] = mini(3, int(records.get(target["id"], 0)) + 1)

func can_spot(observer: Dictionary, target: Dictionary) -> bool:
    if not has_sight(observer, target): return false
    return int(state["version"]) < 16 or int(state["acquisition"][observer["id"]].get(target["id"], 0)) >= 3

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
                        if position(observer).distance_to(position(target)) <= limit and squad_visible(observer, target) and (int(state["version"]) < 16 or int(state["acquisition"][observer["id"]].get(target["id"], 0)) >= 3):
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

# Fixed in-flight snapshots: never overwrite a packet with a later hidden/live
# position. Delivery and transmission happen once per executed second.
func _update_shared_reports() -> void:
    if int(state["version"]) < 18: return
    var elapsed := int(state["elapsed"])
    for faction in ["UKR", "RU"]:
        var pending: Dictionary = state["pending_reports"][faction]
        var shared: Dictionary = state["shared_contacts"][faction]
        var local: Dictionary = state["contacts"][faction]
        for id in pending.keys():
            var packet: Dictionary = pending[id]
            if int(packet["deliver_at"]) <= elapsed:
                if packet["kind"] == "contact":
                    shared[id] = {"position": packet["position"].duplicate(), "seen_at": int(packet["seen_at"])}
                else:
                    shared.erase(id)
                pending.erase(id)
        for target in state["squads"]:
            if target["faction"] == faction or pending.has(target["id"]): continue
            var id: String = target["id"]
            if local.has(id) and int(local[id]["seen_at"]) > int(shared.get(id, {}).get("seen_at", -1)):
                var record: Dictionary = local[id]
                pending[id] = {"position": record["position"].duplicate(), "seen_at": int(record["seen_at"]), "sent_at": elapsed, "deliver_at": elapsed + 5, "kind": "contact"}
            elif not local.has(id) and shared.has(id):
                # Absence after an observed death confirms elimination; a hidden
                # death leaves local memory intact and cannot send a removal.
                pending[id] = {"position": shared[id]["position"].duplicate(), "seen_at": elapsed, "sent_at": elapsed, "deliver_at": elapsed + 5, "kind": "lost"}

func shared_reports(faction: String, observer_id: String) -> Array:
    var reports: Array = []
    if int(state["version"]) < 18 or state["phase"] == "finished": return reports
    var observer := squad_by_id(observer_id)
    for id in state["shared_contacts"][faction]:
        if not can_spot(observer, squad_by_id(id)):
            var record: Dictionary = state["shared_contacts"][faction][id]
            reports.append({"id": id, "position": record["position"].duplicate(), "seen_at": int(record["seen_at"])})
    return reports

# Local knowledge is independent of faction reports. A confirmed elimination
# tombstone prevents an older in-flight report from resurrecting this contact.
func _remember_elimination(observer: Dictionary, target: Dictionary) -> void:
    if int(state["version"]) >= 19:
        state["observer_contacts"][observer["id"]][target["id"]] = {"position": target["position"].duplicate(), "seen_at": int(state["elapsed"]), "kind": "lost"}

func _update_observer_contacts() -> void:
    if int(state["version"]) < 19: return
    for observer in state["squads"]:
        if int(observer["alive"]) <= 0: continue
        for target in state["squads"]:
            if can_spot(observer, target):
                state["observer_contacts"][observer["id"]][target["id"]] = {"position": target["position"].duplicate(), "seen_at": int(state["elapsed"]), "kind": "contact"}
            elif observer["faction"] != target["faction"] and int(target["alive"]) == 0 and int(state["acquisition"][observer["id"]].get(target["id"], 0)) >= 3 and position(observer).distance_to(position(target)) <= spot_limit(observer, target) and squad_visible(observer, target):
                _remember_elimination(observer, target)

# Pure query: choose newest known observation; own sight wins equal timestamps.
# Never read hidden coordinates/alive status to update or remove remembered data.
func remembered_contacts(observer_id: String) -> Array:
    var contacts: Array = []
    if int(state["version"]) < 19 or state["phase"] == "finished": return contacts
    var observer := squad_by_id(observer_id)
    if observer.is_empty() or int(observer["alive"]) <= 0: return contacts
    var local: Dictionary = state["observer_contacts"][observer_id]
    var combined: Dictionary = state["shared_contacts"][observer["faction"]].duplicate(true)
    for id in local:
        if not combined.has(id) or int(local[id]["seen_at"]) >= int(combined[id]["seen_at"]):
            combined[id] = local[id].duplicate(true)
    for id in combined:
        var record: Dictionary = combined[id]
        if record.get("kind", "contact") == "lost" or can_spot(observer, squad_by_id(id)): continue
        var own: bool = local.has(id) and int(local[id]["seen_at"]) >= int(record["seen_at"])
        contacts.append({"id": id, "position": record["position"].duplicate(), "seen_at": int(record["seen_at"]), "source": "local" if own else "report"})
    return contacts

# Bearings: north(-south)0, east90, south180, west270. Integer storage
# avoids JSON drift. Arc is fixed in world direction and moves with the squad.
func facing(id: String) -> int:
    return int(state["facing_orders"][id]["heading"]) if int(state["version"]) >= 20 else (0 if id.begins_with("UKR") else 180)

func arc_width(id: String) -> int:
    return int(state["facing_orders"][id]["width"]) if int(state["version"]) >= 20 else 0

func order_facing(id: String, point: Vector2, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if not _can_order_facing(squad, player) or not _point([point.x, point.y]) or position(squad).distance_to(point) < 1.0: return false
    var offset := point - position(squad)
    state["facing_orders"][id]["heading"] = posmod(roundi(rad_to_deg(atan2(offset.x, -offset.y))), 360)
    return true

func order_arc(id: String, width: Variant, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if not _can_order_facing(squad, player) or not _integer(width, 0, 180) or int(width) not in [0, 90, 180]: return false
    state["facing_orders"][id]["width"] = int(width)
    return true

func _can_order_facing(squad: Dictionary, player: bool) -> bool:
    return int(state["version"]) >= 20 and state["phase"] == "planning" and not squad.is_empty() and int(squad["alive"]) > 0 and morale_state(squad["id"]) != "broken" and (not player or squad["faction"] == "UKR")

func within_fire_arc(shooter: Dictionary, target: Dictionary) -> bool:
    if shooter.is_empty() or target.is_empty(): return false
    var width := arc_width(shooter["id"])
    if width == 0: return true
    var offset := position(target) - position(shooter)
    if offset.length_squared() < 0.000001: return true
    var bearing := atan2(offset.x, -offset.y)
    return absf(wrapf(bearing - deg_to_rad(facing(shooter["id"])), -PI, PI)) <= deg_to_rad(width * 0.5) + 0.000001

# Explicit ground coordinates, never an enemy ID or a hidden target lookup.
# Suppression-only prototype: pressure falls to zero at 16m; no casualty RNG.
func area_target(id: String) -> Array:
    return state["area_fire"][id].duplicate() if int(state["version"]) >= 21 else []

func can_area_fire(shooter: Dictionary, point: Vector2) -> bool:
    var distance := position(shooter).distance_to(point)
    return distance >= 1.0 and distance < 230.0 and not inside_building(point,0.5) and visible(position(shooter),point,posture_height(shooter["id"]),0.3) and within_fire_arc(shooter,{"position":[point.x,point.y]})

func order_area_fire(id: String, point: Vector2, player: bool = true) -> bool:
    var shooter := squad_by_id(id)
    if int(state["version"]) < 21 or not _can_order_facing(shooter,player) or not _point([point.x,point.y]) or not can_area_fire(shooter,point): return false
    state["area_fire"][id] = [point.x,point.y]
    state["fire_targets"][id] = ""
    return true

func _area_point_visible(observer: Dictionary, point: Vector2) -> bool:
    var factor: float = {"stand":1.0,"crouch":0.9,"prone":0.75}[posture(observer["id"])]
    var limit := WOODS_SPOT_RANGE if cover(point) > 0.2 else SPOT_RANGE
    return position(observer).distance_to(point) <= limit * factor and visible(position(observer),point,posture_height(observer["id"]),0.3)

func _collect_area_fire(shooter: Dictionary, attacks: Array) -> void:
    var coords := area_target(shooter["id"])
    if coords.is_empty(): return
    var point := Vector2(coords[0],coords[1])
    if not can_area_fire(shooter,point): return
    var rounds := rounds_per_volley(shooter)
    shooter["ammo"] = int(shooter["ammo"]) - rounds
    var witnesses: Array = []
    for observer in state["squads"]:
        if observer["faction"] == "UKR" and int(observer["alive"]) > 0 and (shooter["faction"] == "UKR" or (can_spot(observer,shooter) and _area_point_visible(observer,point))): witnesses.append(observer["id"])
    # Event exposes ordered endpoint and real rounds only, never impacted enemy
    # IDs, suppression or live coordinates. Rendering cannot learn hidden hits.
    last_events.append({"type":"shot","area":true,"tick":state["elapsed"],"shooter":shooter["id"],"target":"","from":shooter["position"].duplicate(),"to":coords.duplicate(),"rounds":rounds,"losses":0,"weapon_role":weapon_role(shooter["id"]),"player_visible":not witnesses.is_empty(),"local_observers":witnesses})
    for target in state["squads"]:
        if target["faction"] == shooter["faction"] or int(target["alive"]) <= 0: continue
        var separation := point.distance_to(position(target))
        if separation < 16.0 and visible(point,position(target),0.3,posture_height(target["id"])):
            var pressure := (0.04 + rounds * 0.008) * (1.0 - separation / 16.0)
            attacks.append({"target":target["id"],"losses":0,"pressure":pressure})

func can_engage(shooter: Dictionary, target: Dictionary) -> bool:
    return not shooter.is_empty() and not target.is_empty() and int(shooter["alive"]) > 0 and int(target["alive"]) > 0 and shooter["faction"] != target["faction"] and position(shooter).distance_to(position(target)) < 230.0 and squad_visible(shooter, target) and (not limited_visibility() or can_spot(shooter, target)) and within_fire_arc(shooter, target)

func order_target(id: String, target_id: String, player: bool = true) -> bool:
    var squad := squad_by_id(id)
    if int(state["version"]) < 7 or state["phase"] != "planning" or squad.is_empty() or int(squad["alive"]) <= 0 or morale_state(id) == "broken" or (player and squad["faction"] != "UKR"):
        return false
    if not target_id.is_empty() and not can_engage(squad, squad_by_id(target_id)):
        return false
    state["fire_targets"][id] = target_id
    if int(state["version"]) >= 21: state["area_fire"][id] = []
    return true

func target_status(id: String) -> String:
    var area := area_target(id)
    if not area.is_empty():
        var shooter := squad_by_id(id)
        if int(shooter["alive"]) <= 0: return "Area: eliminated"
        if fire_mode(id) == "hold": return "Area: HOLD FIRE"
        if int(shooter["ammo"]) <= 0: return "Area: empty"
        return "Area: active" if can_area_fire(shooter,Vector2(area[0],area[1])) else "Area: waiting for LOS/range/arc"
    if int(state["version"]) < 7 or str(state["fire_targets"][id]).is_empty():
        return "Focus: none"
    var observer := squad_by_id(id)
    var target := squad_by_id(state["fire_targets"][id])
    if int(state["version"]) >= 20 and can_spot(observer, target) and not within_fire_arc(observer, target): return "Focus: outside arc"
    return "Focus: ready" if can_engage(observer, target) else "Focus: waiting for sight"

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

func command_delay(id: String) -> int:
    return int(state["command_remaining"][id]) if int(state["version"]) >= 17 else 0

func movement_status(squad: Dictionary) -> String:
    if int(squad["alive"]) <= 0: return "NONE"
    if morale_state(squad["id"]) == "broken":
        return "WITHDRAWING" if state["orders"].has(squad["id"]) else "RALLY %ds" % int(state["rally_remaining"][squad["id"]])
    var mode := movement_mode(squad["id"])
    if int(state["version"]) >= 8 and int(state["pause_remaining"][squad["id"]]) > 0:
        return "WAIT %ds (%s)" % [state["pause_remaining"][squad["id"]], mode.to_upper()]
    if hunt_paused(squad): return "HUNT PAUSED"
    if command_delay(squad["id"]) > 0: return "%s IN %ds" % [mode.to_upper(), command_delay(squad["id"])]
    return mode.to_upper()

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
    var editable_leg_modes: bool = int(state["version"]) >= 27 and squad["faction"] == "UKR" and morale_state(id) != "broken"
    if append and not previous.is_empty() and movement_mode(id) != mode and not editable_leg_modes:
        return false
    var previous_legs: Array = []
    var previous_modes: Array = []
    if int(state["version"]) >= 26 and squad["faction"] == "UKR" and morale_state(id) != "broken" and append and not previous.is_empty():
        if not state["route_legs"].has(id):
            return false
        previous_legs = state["route_legs"][id].duplicate()
        if int(state["version"]) >= 27:
            if not state["route_modes"].has(id):
                return false
            previous_modes = state["route_modes"][id].duplicate()
    var previous_size := previous.size()
    var new_command := not append or previous.is_empty()
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
    if int(state["version"]) >= 26:
        if squad["faction"] == "UKR" and morale_state(id) != "broken":
            var legs: Array = previous_legs if append and previous_size > 0 else []
            legs.append(path.size() - previous_size)
            state["route_legs"][id] = legs
            if int(state["version"]) >= 27:
                var modes: Array = previous_modes if append and previous_size > 0 else []
                modes.append(mode)
                state["route_modes"][id] = modes
        else:
            state["route_legs"].erase(id)
            if int(state["version"]) >= 27: state["route_modes"].erase(id)
    if int(state["version"]) >= 17 and new_command: state["command_remaining"][id] = 5
    if int(state["version"]) >= 5:
        # V27 player routes execute the mode attached to their first remaining
        # authored leg. Appending a later leg must not rewrite the active leg.
        state["movement_modes"][id] = state["route_modes"][id][0] if editable_leg_modes else mode
    if int(state["version"]) >= 8 and not append:
        state["pause_remaining"][id] = 0
    return true

func order_hold(id: String) -> bool:
    var squad := squad_by_id(id)
    if state["phase"] != "planning" or squad.is_empty() or squad["faction"] != "UKR" or int(squad["alive"]) <= 0 or morale_state(id) == "broken":
        return false
    state["orders"].erase(id)
    if int(state["version"]) >= 26: state["route_legs"].erase(id)
    if int(state["version"]) >= 27: state["route_modes"].erase(id)
    if int(state["version"]) >= 5:
        state["movement_modes"].erase(id)
    if int(state["version"]) >= 8:
        state["pause_remaining"][id] = 0
    if int(state["version"]) >= 17: state["command_remaining"][id] = 0
    return true

func order_remove_last_waypoint(id: String) -> bool:
    var squad := squad_by_id(id)
    if state["phase"] != "planning" or squad.is_empty() or squad["faction"] != "UKR" or int(squad["alive"]) <= 0 or morale_state(id) == "broken":
        return false
    var path: Array = state["orders"].get(id, [])
    if path.is_empty():
        return false
    if int(state["version"]) >= 26:
        var legs = state["route_legs"].get(id)
        if not legs is Array or legs.is_empty():
            return false
        var modes: Array = []
        if int(state["version"]) >= 27:
            var saved_modes = state["route_modes"].get(id)
            if not saved_modes is Array or saved_modes.size() != legs.size():
                return false
            modes = saved_modes.duplicate()
        # V26 records the number of still-queued path points contributed by
        # each authored click. Remove the complete final click-leg without
        # pathfinding again or disturbing the earlier command.
        if legs.size() == 1:
            return order_hold(id)
        var remove_count := int(legs.back())
        if remove_count <= 0 or remove_count >= path.size():
            return false
        path = path.duplicate(true)
        path.resize(path.size() - remove_count)
        legs = legs.duplicate()
        legs.pop_back()
        state["orders"][id] = path
        state["route_legs"][id] = legs
        if int(state["version"]) >= 27:
            modes.pop_back()
            state["route_modes"][id] = modes
        return true
    # A one-point route has no earlier destination to retain. Reuse HOLD so its
    # movement-mode, timed-pause and command-response cleanup stays canonical.
    if path.size() == 1:
        return order_hold(id)
    path = path.duplicate(true)
    path.pop_back()
    state["orders"][id] = path
    # Trimming an existing command is not a new order: preserve its movement
    # mode, concurrent pause and any response time already earned.
    return true

func _consume_route_point(id: String) -> bool:
    if int(state["version"]) < 26 or not state["route_legs"].has(id):
        return false
    var legs: Array = state["route_legs"][id].duplicate()
    if legs.is_empty():
        return false
    legs[0] = int(legs[0]) - 1
    var changed_mode := false
    if int(legs[0]) <= 0:
        legs.pop_front()
        if int(state["version"]) >= 27:
            var modes: Array = state["route_modes"][id].duplicate()
            var prior_mode: String = str(modes.pop_front())
            if modes.is_empty():
                state["route_modes"].erase(id)
            else:
                state["route_modes"][id] = modes
                state["movement_modes"][id] = modes[0]
                changed_mode = prior_mode != str(modes[0])
    if legs.is_empty():
        state["route_legs"].erase(id)
    else:
        state["route_legs"][id] = legs
    return changed_mode

func execute() -> bool:
    if state["phase"] != "planning":
        return false
    var reserved: Array[Vector2] = []
    for squad in state["squads"]:
        if squad["faction"] == "RU" and int(squad["alive"]) > 0:
            if morale_state(squad["id"]) == "broken":
                _retreat_route(squad)
                continue
            if seeking_cover(squad["id"]):
                var goal: Array = state["cover_responses"][squad["id"]]["goal"]
                reserved.append(Vector2(goal[0], goal[1]))
                continue
            if int(state["version"]) >= 25 and int(state["cover_responses"][squad["id"]]["retry_remaining"]) > 0:
                # A retry may straddle an interval. Keep its original queue,
                # mode and wait rather than replacing them with an AI advance.
                var queued: Array = state["orders"].get(squad["id"], [])
                reserved.append(Vector2(queued.back()[0],queued.back()[1]) if not queued.is_empty() else position(squad))
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
        squad["suppression"] = _stable_pressure(maxf(0, float(squad["suppression"]) - 0.035))
        _update_morale(squad)
        _opponent_duck(squad)
        _opponent_cover(squad)
        if int(state["version"]) >= 17 and (not state["orders"].has(squad["id"]) or int(squad["alive"]) <= 0): state["command_remaining"][squad["id"]] = 0
        var responding := command_delay(squad["id"]) > 0
        if responding: state["command_remaining"][squad["id"]] = command_delay(squad["id"]) - 1
        var waiting := int(state["version"]) >= 8 and int(state["pause_remaining"][squad["id"]]) > 0
        if waiting:
            state["pause_remaining"][squad["id"]] = int(state["pause_remaining"][squad["id"]]) - 1
        if int(squad["alive"]) <= 0:
            state["orders"].erase(squad["id"])
            if int(state["version"]) >= 26: state["route_legs"].erase(squad["id"])
            if int(state["version"]) >= 27: state["route_modes"].erase(squad["id"])
            if int(state["version"]) >= 5:
                state["movement_modes"].erase(squad["id"])
            if int(state["version"]) >= 8:
                state["pause_remaining"][squad["id"]] = 0
            continue
        var covering := seeking_cover(squad["id"])
        var path: Array = state["cover_responses"][squad["id"]]["path"] if covering else state["orders"].get(squad["id"], [])
        var mode := "move" if covering else movement_mode(squad["id"])
        var base_speed: float = {"move": 2.4, "quick": 4.0, "hunt": 1.2}[mode] if not path.is_empty() else 0.0
        var speed: float = float(base_speed) * (1.0 - 0.8 * float(squad["suppression"])) * (1.0 - 0.5 * fatigue(squad["id"])) * (0.75 if morale_state(squad["id"]) == "shaken" else 1.0)
        speed *= posture_speed(squad["id"])
        if responding or waiting or is_pinned(squad) or hunt_paused(squad) or (not covering and opponent_engaging(squad)):
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
                var changed_leg_mode := false
                if not covering: changed_leg_mode = _consume_route_point(squad["id"])
                speed -= distance
                # A changed authored mode starts on the next whole simulation
                # second. Stop at the authored node so HUNT and pace gates can
                # never be skipped by leftover movement from the prior mode.
                if changed_leg_mode: speed = 0.0
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
        if path.is_empty() and not covering:
            state["orders"].erase(squad["id"])
            if int(state["version"]) >= 26: state["route_legs"].erase(squad["id"])
            if int(state["version"]) >= 27: state["route_modes"].erase(squad["id"])
            if int(state["version"]) >= 5:
                state["movement_modes"].erase(squad["id"])
            if int(state["version"]) >= 8:
                state["pause_remaining"][squad["id"]] = 0
            if int(state["version"]) >= 17: state["command_remaining"][squad["id"]] = 0
    _update_acquisition(true)
    _update_observer_contacts()
    _update_contacts()
    # Collect attacks before applying damage: both sides fire from the same tick state.
    var attacks: Array = []
    for shooter in state["squads"]:
        if int(state["elapsed"]) % fire_interval(shooter["id"]) != 0:
            continue
        if int(shooter["alive"]) <= 0 or int(shooter["ammo"]) <= 0 or fire_mode(shooter["id"]) == "hold" or morale_state(shooter["id"]) == "broken":
            continue
        if not area_target(shooter["id"]).is_empty():
            _collect_area_fire(shooter,attacks)
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
        if int(state["version"]) >= 18:
            event["local_observers"] = []
            for observer in state["squads"]:
                if observer["faction"] == "UKR" and int(observer["alive"]) > 0 and (shooter["faction"] == "UKR" or can_spot(observer, shooter)) and (target["faction"] == "UKR" or can_spot(observer, target)):
                    event["local_observers"].append(observer["id"])
        last_events.append(event)
        attacks.append({"target": target["id"], "losses": losses, "pressure": 0.07 + rounds * 0.012})
    for attack in attacks:
        var target := squad_by_id(attack["target"])
        var losses := mini(int(target["alive"]), int(attack["losses"]))
        target["alive"] = int(target["alive"]) - losses
        target["suppression"] = _stable_pressure(minf(1, float(target["suppression"]) + float(attack["pressure"])))
        target["morale"] = maxi(0, int(target["morale"]) - losses * 3)
    if int(state["version"]) >= 17:
        for squad in state["squads"]:
            if int(squad["alive"]) <= 0: state["command_remaining"][squad["id"]] = 0
    if int(state["version"]) >= 23:
        for squad in state["squads"]:
            if int(squad["alive"]) <= 0: _clear_cover_response(squad["id"])
    _update_observer_contacts()
    _update_contacts()
    _update_shared_reports()
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
        if separation < distance and can_engage(shooter, candidate):
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
    if not saved is Dictionary or not _integer(saved.get("version"), 1, 27):
        return false
    var version := int(saved["version"])
    var field_count := 9 + int(version >= 4) + int(version >= 5) + int(version >= 6) + int(version >= 7) + int(version >= 8) + int(version >= 12) + 2 * int(version >= 13) + int(version >= 14) + int(version >= 15) + int(version >= 16) + int(version >= 17) + 2 * int(version >= 18) + int(version >= 19) + int(version >= 20) + int(version >= 21) + int(version >= 23) + int(version >= 26) + int(version >= 27)
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
        known[squad["id"]] = squad
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
    if int(saved["version"]) >= 26:
        var route_legs = saved.get("route_legs")
        if not route_legs is Dictionary:
            return false
        for id in route_legs:
            if not saved["orders"].has(id) or not known.has(id) or known[id]["faction"] != "UKR" or saved["morale_states"][id] == "broken":
                return false
            var legs = route_legs[id]
            if not legs is Array or legs.is_empty() or legs.size() > 128:
                return false
            var covered := 0
            for length in legs:
                if not _integer(length, 1, 128):
                    return false
                covered += int(length)
            if covered != saved["orders"][id].size():
                return false
        for id in saved["orders"]:
            if known[id]["faction"] == "UKR" and saved["morale_states"][id] != "broken" and not route_legs.has(id):
                return false
        if int(saved["version"]) >= 27:
            var route_modes = saved.get("route_modes")
            if not route_modes is Dictionary or route_modes.size() != route_legs.size():
                return false
            for id in route_legs:
                var modes = route_modes.get(id)
                if not modes is Array or modes.size() != route_legs[id].size() or modes.is_empty():
                    return false
                for mode in modes:
                    if mode not in ["move", "quick", "hunt"]:
                        return false
                if str(modes[0]) != str(saved["movement_modes"][id]):
                    return false
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
    if int(saved["version"]) >= 16:
        var acquisition = saved.get("acquisition")
        if not acquisition is Dictionary or acquisition.size() != known.size(): return false
        for id in known:
            var records = acquisition.get(id)
            if not records is Dictionary: return false
            for target_id in records:
                if not known.has(target_id) or known[target_id]["faction"] == known[id]["faction"] or not _integer(records[target_id], 1, mini(3, int(saved["elapsed"]))): return false
    if int(saved["version"]) >= 17:
        var commands = saved.get("command_remaining")
        if not commands is Dictionary or commands.size() != known.size(): return false
        for id in known:
            if not _integer(commands.get(id), 0, 5): return false
            if int(commands[id]) > 0 and (not saved["orders"].has(id) or int(known[id]["alive"]) <= 0 or saved["morale_states"][id] == "broken"): return false
    if int(saved["version"]) >= 18:
        for key in ["shared_contacts", "pending_reports"]:
            var maps = saved.get(key)
            if not maps is Dictionary or maps.size() != 2: return false
            for faction in ["UKR", "RU"]:
                var records = maps.get(faction)
                if not records is Dictionary: return false
                for id in records:
                    if not known.has(id) or known[id]["faction"] == faction: return false
                    var record = records[id]
                    var pending: bool = key == "pending_reports"
                    if not record is Dictionary or record.size() != (5 if pending else 2) or not _point(record.get("position")) or not _integer(record.get("seen_at"), 1, int(saved["elapsed"]) if pending else int(saved["elapsed"]) - 5): return false
                    if inside_building(Vector2(record["position"][0], record["position"][1]), 0.5): return false
                    if pending and (record.get("kind") not in ["contact", "lost"] or not _integer(record.get("deliver_at"), int(saved["elapsed"]) + 1, int(saved["elapsed"]) + 5) or not _integer(record.get("sent_at"), int(record["seen_at"]), int(saved["elapsed"])) or int(record["deliver_at"]) != int(record["sent_at"]) + 5): return false
    if int(saved["version"]) >= 19:
        var memories = saved.get("observer_contacts")
        if not memories is Dictionary or memories.size() != known.size(): return false
        for id in known:
            var records = memories.get(id)
            if not records is Dictionary: return false
            for target_id in records:
                if not known.has(target_id) or known[target_id]["faction"] == known[id]["faction"]: return false
                var record = records[target_id]
                if not record is Dictionary or record.size() != 3 or record.get("kind") not in ["contact", "lost"] or not _point(record.get("position")) or not _integer(record.get("seen_at"), 3, int(saved["elapsed"])): return false
                if inside_building(Vector2(record["position"][0], record["position"][1]), 0.5) or (record["kind"] == "lost" and int(known[target_id]["alive"]) > 0): return false
    if int(saved["version"]) >= 20:
        var facings = saved.get("facing_orders")
        if not facings is Dictionary or facings.size() != known.size(): return false
        for id in known:
            var record = facings.get(id)
            if not record is Dictionary or record.size() != 2 or not _integer(record.get("heading"), 0, 359) or not _integer(record.get("width"), 0, 180) or int(record["width"]) not in [0, 90, 180]: return false
            if saved["morale_states"][id] == "broken" and int(record["width"]) != 0: return false
    if int(saved["version"]) >= 21:
        var areas = saved.get("area_fire")
        if not areas is Dictionary or areas.size() != known.size(): return false
        for id in known:
            var point = areas.get(id)
            if not point is Array: return false
            if point.is_empty(): continue
            if not _point(point) or inside_building(Vector2(point[0],point[1]),0.5) or not saved["fire_targets"][id].is_empty() or saved["morale_states"][id] == "broken": return false
    if int(saved["version"]) >= 23:
        var responses = saved.get("cover_responses")
        if not responses is Dictionary or responses.size() != known.size(): return false
        var reserved_goals: Array[Vector2] = []
        for id in known:
            var response = responses.get(id)
            if not response is Dictionary or response.size() != 3 + int(saved["version"] >= 25) or not _integer(response.get("pressure_ticks"), 0, COVER_PRESSURE_TICKS) or not response.get("goal") is Array or not response.get("path") is Array: return false
            var goal: Array = response["goal"]
            var path: Array = response["path"]
            if int(saved["version"]) >= 25:
                if not _integer(response.get("retry_remaining"), 0, COVER_RETRY_SECONDS): return false
                if int(response["retry_remaining"]) > 0 and (response["pressure_ticks"] != COVER_PRESSURE_TICKS or not goal.is_empty()): return false
            if known[id]["faction"] != "RU" or int(known[id]["alive"]) <= 0 or saved["morale_states"][id] == "broken":
                if response["pressure_ticks"] != 0 or not goal.is_empty() or not path.is_empty() or response.get("retry_remaining", 0) != 0: return false
            if goal.is_empty():
                if not path.is_empty(): return false
                continue
            if not _point(goal) or cover(Vector2(goal[0],goal[1])) <= 0.2 or inside_building(Vector2(goal[0],goal[1]),5.0) or response["pressure_ticks"] != COVER_PRESSURE_TICKS or path.size() > 12: return false
            if int(saved["version"]) >= 24:
                var point := Vector2(goal[0], goal[1])
                for reserved in reserved_goals:
                    if point.distance_squared_to(reserved) < COVER_SEPARATION * COVER_SEPARATION: return false
                reserved_goals.append(point)
            for point in path:
                if not _point(point) or inside_building(Vector2(point[0],point[1]),5.0): return false
            if path.is_empty():
                if position(known[id]).distance_to(Vector2(goal[0],goal[1])) > 0.01: return false
            elif Vector2(path.back()[0],path.back()[1]) != Vector2(goal[0],goal[1]) or _path_length(position(known[id]),path) > COVER_PATH_LIMIT + 0.01: return false
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
