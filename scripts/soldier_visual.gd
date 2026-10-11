extends Node3D
## Procedural display rig only. No individual AI, collision, RNG or saved state.

var parts := {}
var uniform: StandardMaterial3D
var equipment: StandardMaterial3D
var skin: StandardMaterial3D
var casualty: StandardMaterial3D
var support := false
var current_pose := ""

func material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.roughness = 0.9
    return result

func setup(color: Color, support_weapon: bool = false) -> void:
    uniform = material(color)
    equipment = material(Color("303d38"))
    skin = material(Color("bfa080"))
    casualty = material(Color("646965"))
    support = support_weapon
    for key in ["torso", "head", "helmet", "pack", "left_arm", "right_arm", "left_thigh", "right_thigh", "left_shin", "right_shin", "left_boot", "right_boot", "rifle"]:
        var piece := MeshInstance3D.new()
        piece.name = key
        var mesh := BoxMesh.new()
        piece.mesh = mesh
        piece.material_override = uniform
        if key in ["rifle", "pack", "left_boot", "right_boot"]:
            piece.material_override = equipment
        if key == "head":
            piece.material_override = skin
        add_child(piece)
        parts[key] = piece
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
    for part in parts.values():
        var key: String = part.name
        part.material_override = casualty if lost else (skin if key == "head" else (equipment if key in ["rifle", "pack", "left_boot", "right_boot"] else uniform))
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
        limb(prefix + "_thigh", h, knee, 0.17)
        limb(prefix + "_shin", knee, foot, 0.14)
        block(prefix + "_boot", foot + Vector3(0, 0, -0.09), Vector3(0.18, 0.15, 0.29))
        var arm := shoulder + Vector3(side * 0.27, -0.06, 0)
        var hand := shoulder + Vector3(side * 0.11, -0.16 if low else -0.25, -0.43)
        limb(prefix + "_arm", arm, hand, 0.13)
    block("rifle", shoulder + Vector3(0.10, -0.15 if low else -0.25, -0.57), Vector3(0.10 if support else 0.07, 0.10, 1.05 if support else 0.82))
    if lost:
        parts["rifle"].visible = false
    else:
        parts["rifle"].visible = true
