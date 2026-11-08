extends CharacterBody3D
## Hulking modeled foe (Blender glTF, res://assets/foe.glb). Presence only:
## idle sway + breathing; inside ~10u it turns toward Allarion and advances,
## stopping ~2.2u away. No attacks.

const SPEED := 1.7
const GRAVITY := 22.0
const AGGRO_RANGE := 10.0
const STOP_DIST := 2.2
const MODEL_SCENE := preload("res://assets/foe.glb")

var target_node: Node3D

var _anim_t := 0.0
var _model: Node3D


func _ready() -> void:
	floor_snap_length = 0.4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 2.6
	col.shape = cap
	col.position.y = 1.3
	add_child(col)
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var inst := MODEL_SCENE.instantiate()
	_model.add_child(inst)
	_apply_signature_materials(inst)


func _apply_signature_materials(root: Node) -> void:
	# Eyes must burn red and the shard must glow, whatever the import did.
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color(0.3, 0.0, 0.0)
	eyes.emission_enabled = true
	eyes.emission = Color(1.0, 0.08, 0.08)
	eyes.emission_energy_multiplier = 5.0
	eyes.roughness = 0.4
	var shard := StandardMaterial3D.new()
	shard.albedo_color = Color(0.12, 0.03, 0.26)
	shard.emission_enabled = true
	shard.emission = Color(0.40, 0.12, 0.85)
	shard.emission_energy_multiplier = 1.1
	shard.roughness = 0.3
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			var want: Material = null
			if n.name.begins_with("Eye"):
				want = eyes
			elif n.name.begins_with("ChestShard"):
				want = shard
			if want:
				for i in n.mesh.get_surface_count():
					n.set_surface_override_material(i, want)
		for c in n.get_children():
			stack.append(c)


func _physics_process(delta: float) -> void:
	_anim_t += delta
	velocity.x = 0.0
	velocity.z = 0.0
	if target_node:
		var flat := Vector3(target_node.global_position.x - global_position.x, 0.0, target_node.global_position.z - global_position.z)
		var dist := flat.length()
		if dist > 0.05 and dist < AGGRO_RANGE:
			var dir := flat / dist
			# GLB front is +Z (eyes at +Z in the imported mesh).
			var target_yaw := atan2(dir.x, dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-3.0 * delta))
			if dist > STOP_DIST:
				velocity.x = dir.x * SPEED
				velocity.z = dir.z * SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# Idle life: slow sway, breath bob, and a subtle breathing scale
	_model.rotation.z = sin(_anim_t * 1.3) * 0.02
	_model.position.y = sin(_anim_t * 1.6) * 0.03
	var b := 1.0 + sin(_anim_t * 1.6) * 0.008
	_model.scale = Vector3(b, 1.0 + sin(_anim_t * 1.6) * 0.012, b)
