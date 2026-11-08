extends CharacterBody3D
## Allarion: modeled armored swordsman (Blender glTF, res://assets/allarion.glb).
## Idle/Walk clips on the model's AnimationPlayer, crossfaded by movement state.
## Tap-to-move with standard object avoidance: straight-line steering +
## move_and_slide; when progress stalls against a collider, a detour
## waypoint is probed with physics rays and walked around the obstacle.

signal arrived

const SPEED := 4.5
const GRAVITY := 22.0
const MODEL_SCENE := preload("res://assets/allarion.glb")

const ARRIVE_DIST := 0.15
const WAYPOINT_DIST := 0.38
const STALL_WINDOW := 0.3
const MAX_DETOURS := 8
const GOAL_TIMEOUT := 30.0
const GIVEUP_DIST := 0.95

var has_target := false
var _target := Vector3.ZERO
var _was_moving := false

var _waypoint := Vector3.ZERO
var _has_waypoint := false
var _detours := 0
var _goal_time := 0.0
# Stall detection runs over a 0.3 s window (position at window start +
# whether any slide contact in the window had a wall-like normal). A
# window is immune to per-frame position-sync quirks, and the floor —
# whose contact normal points straight up — never counts as a blocker.
var _win_timer := 0.0
var _win_start := Vector3.ZERO
var _win_blocked := false

var _model: Node3D
var _anim: AnimationPlayer
var _current_anim := ""


func _ready() -> void:
	floor_snap_length = 0.4
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	var inst := MODEL_SCENE.instantiate()
	_model.add_child(inst)
	_apply_gem_materials(inst)
	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim:
		_play("Idle")
	_win_start = global_position


func command_move(t: Vector3) -> void:
	_target = Vector3(t.x, 0.0, t.z)
	has_target = true
	_has_waypoint = false
	_detours = 0
	_goal_time = 0.0
	_win_timer = 0.0
	_win_start = global_position
	_win_blocked = false


func is_moving_now() -> bool:
	return _was_moving


func _play(anim_name: String) -> void:
	if not _anim or _current_anim == anim_name:
		return
	_current_anim = anim_name
	if _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.28)


func _apply_gem_materials(root: Node) -> void:
	# Guarantee the signature glow regardless of glTF emission import quirks.
	var gem := StandardMaterial3D.new()
	gem.albedo_color = Color(0.13, 0.03, 0.26)
	gem.emission_enabled = true
	gem.emission = Color(0.45, 0.16, 0.90)
	gem.emission_energy_multiplier = 1.3
	gem.roughness = 0.3
	var rune := StandardMaterial3D.new()
	rune.albedo_color = Color(0.08, 0.02, 0.19)
	rune.emission_enabled = true
	rune.emission = Color(0.48, 0.20, 0.90)
	rune.emission_energy_multiplier = 1.2
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			var nm := n.name
			if nm.begins_with("Gem"):
				for i in n.mesh.get_surface_count():
					n.set_surface_override_material(i, gem)
			elif nm.begins_with("Rune"):
				for i in n.mesh.get_surface_count():
					n.set_surface_override_material(i, rune)
		for c in n.get_children():
			stack.append(c)


# Probe escape directions around a blocking obstacle and pick a detour
# waypoint: the ray-clear direction that loses the least goal progress.
func _make_detour(blocked_dir: Vector3) -> bool:
	_detours += 1
	if _detours > MAX_DETOURS:
		return false
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3(0.0, 0.9, 0.0)
	var to_goal := _target - global_position
	to_goal.y = 0.0
	var goal_dir := to_goal.normalized() if to_goal.length() > 0.01 else blocked_dir
	var best := Vector3.ZERO
	var best_score := -1.0e9
	for ang_deg in [35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0]:
		var d := blocked_dir.rotated(Vector3.UP, deg_to_rad(ang_deg))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + d * 2.6)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			continue
		var score := -absf(ang_deg) + 60.0 * d.dot(goal_dir)
		if score > best_score:
			best_score = score
			best = global_position + d * 2.3
	if best_score <= -1.0e8:
		return false
	_waypoint = Vector3(best.x, 0.0, best.z)
	_has_waypoint = true
	return true


func _physics_process(delta: float) -> void:
	var moving := false
	if has_target:
		_goal_time += delta
		# Reached the real goal (even mid-detour) -> done.
		var goal_flat := Vector3(_target.x - global_position.x, 0.0, _target.z - global_position.z)
		if goal_flat.length() <= ARRIVE_DIST:
			has_target = false
			_has_waypoint = false
		else:
			var steer := _waypoint if _has_waypoint else _target
			var flat := Vector3(steer.x - global_position.x, 0.0, steer.z - global_position.z)
			var arrive_r := WAYPOINT_DIST if _has_waypoint else ARRIVE_DIST
			if flat.length() <= arrive_r:
				# Waypoint reached; resume toward the goal next frame.
				_has_waypoint = false
				_win_timer = 0.0
				_win_start = global_position
				_win_blocked = false
			else:
				var dir := flat.normalized()
				velocity.x = dir.x * SPEED
				velocity.z = dir.z * SPEED
				moving = true
				# The Blender GLB's front is +Z (eyes/chest at +Z in the
				# imported mesh), so face +Z along travel, not -Z.
				var target_yaw := atan2(dir.x, dir.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))
				# Stall detection over a 0.3 s window: slide contacts from
				# the last move with a wall-like (mostly horizontal) normal
				# mark the window blocked — the floor's up-normal does not.
				for i in get_slide_collision_count():
					if absf(get_slide_collision(i).get_normal().y) < 0.55:
						_win_blocked = true
				_win_timer += delta
				var stalled := false
				if _win_timer >= STALL_WINDOW:
					var disp_win := Vector3(global_position.x - _win_start.x, 0.0, global_position.z - _win_start.z).length()
					stalled = _win_blocked and disp_win < SPEED * STALL_WINDOW * 0.4
					_win_timer = 0.0
					_win_start = global_position
					_win_blocked = false
				if stalled or _goal_time > GOAL_TIMEOUT:
					if not _make_detour(dir):
						# Boxed in or out of detours: stop cleanly rather
						# than pressing against the obstacle forever.
						has_target = false
						_has_waypoint = false
						moving = false
						velocity.x = 0.0
						velocity.z = 0.0
	if not moving:
		velocity.x = 0.0
		velocity.z = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if _was_moving and not moving and not has_target:
		arrived.emit()
	_was_moving = moving or has_target
	_play("Walk" if moving else "Idle")
