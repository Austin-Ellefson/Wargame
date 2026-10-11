extends Node3D
## Procedural display rig only. No individual AI, collision, RNG or saved state.

var parts := {}
var uniform: StandardMaterial3D
var equipment: StandardMaterial3D
var skin: StandardMaterial3D
var casualty: StandardMaterial3D
var insignia: StandardMaterial3D
var support := false
var current_pose := ""
var rest_transforms := {}
var rest_sizes := {}
var anchors := {}
var recoil_remaining := 0.0
var shot_witnesses: Array = []
var muzzle: MeshInstance3D

func material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.9
    return result

func setup(color: Color, support_weapon: bool = false) -> void:
    uniform = material(Color("647354") if color.b > color.r else Color("8b7860"))
    insignia = material(color)
    equipment = material(Color("303d38"))
    skin = material(Color("bfa080"))
    casualty = material(Color("646965"))
    support = support_weapon
    for key in ["torso", "head", "helmet", "pack", "left_arm", "right_arm", "left_thigh", "right_thigh", "left_shin", "right_shin", "left_boot", "right_boot", "rifle", "insignia"]:
        var piece := MeshInstance3D.new()
        piece.name = key
        var mesh := BoxMesh.new()
        piece.mesh = mesh
        piece.material_override = uniform
        if key in ["rifle", "pack", "left_boot", "right_boot"]:
            piece.material_override = equipment
        if key == "insignia":
            piece.material_override = insignia
        if key == "head":
            piece.material_override = skin
        add_child(piece)
        parts[key] = piece
    muzzle = MeshInstance3D.new()
    var flash := SphereMesh.new()
    flash.radius = 0.085
    flash.height = 0.17
    muzzle.mesh = flash
    var glow := material(Color("ffdb79"))
    glow.emission_enabled = true
    glow.emission = Color("ffb43b")
    glow.emission_energy_multiplier = 3.5
    muzzle.material_override = glow
    muzzle.visible = false
    add_child(muzzle)
    pose("stand", false)

func block(key: String, center: Vector3, dimensions: Vector3) -> void:
    var part: MeshInstance3D = parts[key]
    part.position = center
    part.rotation = Vector3.ZERO
    part.scale = Vector3.ONE
    var mesh: BoxMesh = part.mesh
    mesh.size = dimensions

func limb(key: String, a: Vector3, b: Vector3, width: float) -> void:
    block(key, (a + b) / 2, Vector3(width, a.distance_to(b), width))
    var part: MeshInstance3D = parts[key]
    part.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

func pose(value: String, lost: bool) -> void:
    var next_pose := "casualty" if lost else value
    if current_pose == next_pose: return
    current_pose = next_pose
    anchors.clear()
    for part in parts.values():
        var key: String = part.name
        part.material_override = casualty if lost else (insignia if key == "insignia" else (skin if key == "head" else (equipment if key in ["torso", "rifle", "pack", "left_boot", "right_boot"] else uniform)))
    var low := value == "prone" or lost
    var hip := Vector3(0, 0.32 if low else (0.66 if value == "crouch" else 0.94), 0.22 if low else 0)
    var shoulder := Vector3(0, 0.38 if low else (1.08 if value == "crouch" else 1.43), -0.38 if low else -0.08)
    limb("torso", hip, shoulder, 0.42)
    var head := shoulder + Vector3(0, 0.05 if low else 0.23, -0.23 if low else 0)
    block("head", head, Vector3(0.23, 0.25, 0.23))
    block("helmet", head + Vector3(0, 0.13, 0), Vector3(0.31, 0.15, 0.30))
    block("pack", (hip + shoulder) / 2 + Vector3(0, 0.18 if low else 0, 0.22 if not low else 0), Vector3(0.32, 0.35, 0.19))
    for side in [-1, 1]:
        var prefix: String = "left" if side < 0 else "right"
        var h := hip + Vector3(side * 0.13, 0, 0)
        var knee := Vector3(side * 0.18, 0.18 if low else (0.28 if value == "crouch" else 0.50), 0.71 if low else (-0.22 if value == "crouch" else 0))
        var foot := Vector3(side * 0.20, 0.08, 1.17 if low else (0.20 if value == "crouch" else 0.04))
        anchors[prefix] = {"hip": h, "knee": knee, "foot": foot}
        limb(prefix + "_thigh", h, knee, 0.17)
        limb(prefix + "_shin", knee, foot, 0.14)
        block(prefix + "_boot", foot + Vector3(0, 0, -0.09), Vector3(0.18, 0.15, 0.29))
        var arm := shoulder + Vector3(side * 0.27, -0.06, 0)
        var hand := shoulder + Vector3(side * 0.11, -0.16 if low else -0.25, -0.43)
        anchors[prefix]["arm"] = arm
        anchors[prefix]["hand"] = hand
        limb(prefix + "_arm", arm, hand, 0.13)
    block("insignia", shoulder + Vector3(-0.28, -0.08, 0), Vector3(0.15, 0.12, 0.15))
    block("rifle", shoulder + Vector3(0.10, -0.15 if low else -0.25, -0.57), Vector3(0.10 if support else 0.07, 0.10, 1.05 if support else 0.82))
    if lost:
        parts["rifle"].visible = false
    else:
        parts["rifle"].visible = true
    rest_transforms.clear()
    rest_sizes.clear()
    for key in parts:
        rest_transforms[key] = parts[key].transform
        rest_sizes[key] = parts[key].mesh.size
    if lost: clear_shot()

func clear_shot() -> void:
    recoil_remaining = 0.0
    shot_witnesses.clear()
    muzzle.visible = false

func fire(witnesses: Array) -> void:
    if current_pose == "casualty": return
    recoil_remaining = 0.42
    shot_witnesses = witnesses.duplicate()

func animate(delta: float, moving: bool, phase: float) -> void:
    for key in parts:
        parts[key].transform = rest_transforms[key]
        if parts[key].mesh.size != rest_sizes[key]: parts[key].mesh.size = rest_sizes[key]
    recoil_remaining = maxf(0.0, recoil_remaining - delta)
    if current_pose == "casualty":
        clear_shot()
        return
    if moving:
        var crawl := current_pose == "prone"
        for side in [-1, 1]:
            var prefix: String = "left" if side < 0 else "right"
            var points: Dictionary = anchors[prefix]
            var wave := sin(phase + (PI if side < 0 else 0.0))
            var stride := 0.13 if crawl else (0.24 if current_pose == "crouch" else 0.38)
            var foot: Vector3 = points["foot"] + Vector3(0, maxf(0.0, wave) * (0.025 if crawl else 0.16), wave * stride)
            var knee: Vector3 = points["knee"] + Vector3(0, maxf(0.0, wave) * 0.06, wave * stride * 0.55)
            limb(prefix + "_thigh", points["hip"], knee, 0.17)
            limb(prefix + "_shin", knee, foot, 0.14)
            parts[prefix + "_boot"].position = foot + Vector3(0, 0, -0.09)
            limb(prefix + "_arm", points["arm"], points["hand"] + Vector3(0, 0, -wave * (0.10 if crawl else 0.07)), 0.13)
    var kick := maxf(0, recoil_remaining / 0.42) * 0.075
    parts["rifle"].position.z += kick
    parts["right_arm"].position.z += kick * 0.5
    muzzle.position = parts["rifle"].position + Vector3(0, 0, -0.525 if support else -0.41)
    muzzle.visible = recoil_remaining > 0.0
