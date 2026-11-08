extends Node3D
## SAU 3D feel slice: one dark void arena, Allarion, one foe, tap-to-move.
## Everything is primitive-built at runtime. Palette law (bando, 2026-11-07
## rebalance): purple + black = sovereignty = the FIELD (area, depth);
## 24k liquid-chrome GOLD = the SA's make and the MOST VIBRANT thing in
## frame (intensity, not coverage).

const PlayerScript := preload("res://scripts/player.gd")
const FoeScript := preload("res://scripts/foe.gd")

var player: CharacterBody3D
var foe: CharacterBody3D
var cam: Camera3D

var _cam_anchor := Vector3.ZERO
var _drift_angle := 0.0
var _sun_dir_to_sun := Vector3(0.0, 1.0, 0.0)  # set from the sun in _build_environment
var _sky_mat: ShaderMaterial
var _idle_time := 0.0
var _orbit_weight := 0.0
var _test_freeze_cam := false
var _hint_label: Label
var _hint_faded := false
var _shot_dir := ""

# Codex sample (bando, 2026-11-07): material-treatment menus over the
# live world — carved black-stone panels, glitter-gold trim values from
# the world's gold language, big arm's-length text, every plate tappable
# to full-size. NOT 3D geometry.
var _hud_layer: CanvasLayer
var _codex_button: Button
var _codex_layer: CanvasLayer
var _codex_root: Control
var _codex_list_box: VBoxContainer
var _codex_entry_box: VBoxContainer
var _codex_entry_title: Label
var _codex_entry_subtitle: Label
var _codex_entry_body: Label
var _codex_plate_frame: Control
var _codex_plate_rect: TextureRect
var _codex_close_button: Button
var _entry_buttons: Dictionary = {}
var _plate_full_root: Control
var _plate_full_rect: TextureRect
var _codex_open := false
var _current_entry := ""
# Full codex (bando, 2026-11-07): the sample's 4 hand-written entries are
# replaced by the crawler's ENTIRE codex, extracted programmatically into
# scripts/codex_data.gd. The list lives in a ScrollContainer (313 entries,
# grouped by category); the entry body lives in its own ScrollContainer.
var _codex_scroll: ScrollContainer
var _codex_body_scroll: ScrollContainer
var _codex_back_button: Button
var _plate_full_caption: Label
var _codex_entries: Dictionary = {}
var _cat_headers: Dictionary = {}
var _saved_list_scroll := 0

# UI gold: the world's glitter-gold albedo (1.0, 0.82, 0.25) with its
# emission tone (1.0, 0.72, 0.18) for headings — same language as the
# arena's gold, carried flat into the panels.
const UI_GOLD := Color(1.0, 0.82, 0.25)
const UI_GOLD_HOT := Color(1.0, 0.78, 0.22)
const UI_STONE := Color(0.055, 0.050, 0.068, 0.98)
const UI_STONE_LIGHT := Color(0.115, 0.105, 0.135, 1.0)
const UI_TEXT := Color(0.93, 0.90, 0.82)
const UI_PURPLE_ACCENT := Color(0.62, 0.48, 0.95)

const CodexData := preload("res://scripts/codex_data.gd")

# Idle camera orbit (bando fix, 2026-11-07): the old drift ran at
# 0.06 rad/s and died permanently on the first tap, so the camera never
# visibly orbited in a real session. Now the orbit eases in whenever
# Allarion has stood still for ORBIT_DELAY seconds — at spawn, after
# arriving, any idle moment — and eases out while he moves.
const ORBIT_DELAY := 2.5
const ORBIT_RATE := 0.15


func _ready() -> void:
	Engine.max_fps = 90
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	_build_environment()
	_build_ground()
	_build_props()
	_build_actors()
	_build_dust()
	_build_camera()
	_build_hud()
	_build_codex()
	if "--slice-test" in OS.get_cmdline_user_args():
		_shot_dir = OS.get_environment("SLICE_SHOT_DIR")
		if _shot_dir.is_empty():
			_shot_dir = ProjectSettings.globalize_path("res://verification")
		DirAccess.make_dir_recursive_absolute(_shot_dir)
		_run_test()


# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Near-black sky with only a faint purple depth at the horizon. Custom
	# sky shader (glitter pass): the visible gradient is the same deep
	# field as the palette pass, but high around the sun there is a warm
	# bright streak that exists ONLY so metallic gold has something hot
	# to mirror. The camera looks down into the arena, so the streak is
	# effectively never in frame; up-facing gold facets reflect it. The
	# scene's ambient stays the desaturated color source below, so the
	# too-purple fix cannot regress through the sky.
	var sky := Sky.new()
	var sky_sh := Shader.new()
	sky_sh.code = """shader_type sky;
uniform vec3 zenith : source_color = vec3(0.006, 0.005, 0.016);
uniform vec3 horizon : source_color = vec3(0.048, 0.035, 0.088);
uniform vec3 ground_col : source_color = vec3(0.016, 0.013, 0.035);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 streak_color : source_color = vec4(1.0, 0.80, 0.42, 1.0);
void sky() {
	float up = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 col;
	if (up >= 0.0) {
		col = mix(horizon, zenith, pow(up, 0.55));
	} else {
		col = mix(horizon, ground_col, pow(-up, 0.6));
	}
	float s = clamp(dot(normalize(EYEDIR), normalize(sun_dir)), 0.0, 1.0);
	col += streak_color.rgb * (pow(s, 10.0) * 0.55 + pow(s, 90.0) * 1.6 + pow(s, 700.0) * 5.0);
	COLOR = col;
}
"""
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sky_sh
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.background_energy_multiplier = 0.5
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.20, 0.27)
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = Color(0.016, 0.013, 0.026)
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 0.007
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_strength = 0.9
	env.glow_bloom = 0.05
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)
	# Direction TO the sun in world space (light travels along -basis.z,
	# so +basis.z points back at the sun). Feeds the sky's reflection
	# streak and the gold shader's sun glints.
	_sun_dir_to_sun = sun.global_transform.basis.z.normalized()
	if _sky_mat:
		_sky_mat.set_shader_parameter("sun_dir", _sun_dir_to_sun)

	# Faint neutral fill from the opposite side (no shadows) so shadow
	# sides read as dark shapes instead of purple silhouettes.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38.0, 140.0, 0.0)
	fill.light_color = Color(0.40, 0.42, 0.48)
	fill.light_energy = 0.25
	fill.shadow_enabled = false
	add_child(fill)


# ------------------------------------------------------------------- helpers

func _mat(albedo: Color, metallic: float = 0.0, roughness: float = 0.9, emission := Color(0, 0, 0, 0), energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _glitter_gold_material() -> ShaderMaterial:
	# Glittering liquid-chrome 24k (bando, 2026-11-07: "make the gold more
	# gold, like glittering gold"). The palette pass's flat 0.75 emission
	# read as glowing yellow paint; this shader drops the flat glow to
	# 0.30 and carries the vibrance with view-dependent glints instead:
	# world-space micro-facet cells (~1.7 cm) each get a pseudo-random
	# facet normal, so sunlight and the sky's warm reflection streak break
	# into sharp sparkles that shift as the camera moves — the way real
	# metal leaf reads as GOLD. Per-flake albedo tone + roughness speckle
	# keep the flake pattern visible even where no glint fires.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec4 albedo_color : source_color = vec4(1.0, 0.80, 0.24, 1.0);
uniform vec4 glint_color : source_color = vec4(1.0, 0.88, 0.52, 1.0);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float flake_density = 60.0;
uniform float facet_tilt = 1.1;
uniform float flat_emission = 0.30;
uniform float glint_strength = 5.0;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 cell = floor(world_pos * flake_density);
	vec3 rnd = hash33(cell);
	ALBEDO = albedo_color.rgb * (0.86 + 0.28 * rnd.z);
	METALLIC = 1.0;
	ROUGHNESS = mix(0.07, 0.34, rnd.y);
	vec3 facet_w = normalize(world_normal + (rnd - 0.5) * (2.0 * facet_tilt));
	NORMAL = normalize((VIEW_MATRIX * vec4(facet_w, 0.0)).xyz);
	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view_w = normalize(cam_pos - world_pos);
	float glint = pow(clamp(dot(reflect(-view_w, facet_w), sun_dir), 0.0, 1.0), 40.0);
	EMISSION = albedo_color.rgb * flat_emission + glint_color.rgb * glint * glint_strength;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("sun_dir", _sun_dir_to_sun)
	return m


func _apply_chrome_gold(root: Node) -> void:
	# Replace every imported "Gold"/"PropGold" surface (crossguard, armor
	# trim, pillar inlay, arch trim) with the glittering-chrome material.
	var gold := _glitter_gold_material()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			var mi := n as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var active: Material = mi.get_active_material(i)
				if active is StandardMaterial3D:
					var sm := active as StandardMaterial3D
					var is_gold := sm.resource_name == "Gold" or sm.resource_name == "PropGold"
					if not is_gold and sm.metallic > 0.9:
						var ac := sm.albedo_color
						is_gold = absf(ac.r - 0.83) + absf(ac.g - 0.60) + absf(ac.b - 0.22) < 0.08
					if is_gold:
						mi.set_surface_override_material(i, gold)
		for c in n.get_children():
			stack.append(c)


func _neutralize_prop_stone(root: Node) -> void:
	# Prop stone materials bake a purple tint; duplicate them (keeping the
	# noise/roughness textures) with a dark grey-black albedo, purple hint
	# only.
	var tints := {
		"PropStone": Color(0.130, 0.125, 0.145),
		"PropStone2": Color(0.155, 0.148, 0.170),
	}
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh:
			var mi2 := n as MeshInstance3D
			for i in mi2.mesh.get_surface_count():
				var active2: Material = mi2.get_active_material(i)
				if active2 is StandardMaterial3D and tints.has(active2.resource_name):
					var dup := (active2 as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.albedo_color = tints[active2.resource_name]
					mi2.set_surface_override_material(i, dup)
		for c in n.get_children():
			stack.append(c)


func _add_box(body: StaticBody3D, size: Vector3, offset: Vector3, mat: Material, collide: bool = true) -> void:
	# mat == null -> collision only (visuals come from the props GLB)
	if mat != null:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.position = offset
		body.add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = offset
		body.add_child(col)


func _prop(at: Vector3, rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = rot_y
	add_child(body)
	return body


# --------------------------------------------------------------------- world

func _build_ground() -> void:
	# Procedural stone: 8x8 worn slabs, cracks, a faded gold ritual ring,
	# plus a baked normal map so the relief catches the sun.
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_texture = load("res://assets/stone_albedo.png")
	ground_mat.normal_enabled = true
	ground_mat.normal_texture = load("res://assets/stone_normal.png")
	ground_mat.normal_scale = 0.7
	ground_mat.roughness = 0.96
	ground_mat.metallic = 0.0
	# Darken the (already neutralized) stone so the field reads dark and
	# the gold ring laid into it stays the brightest thing on the ground.
	ground_mat.albedo_color = Color(0.78, 0.78, 0.82)
	ground_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var body := _prop(Vector3.ZERO)
	_add_box(body, Vector3(60, 1, 60), Vector3(0, -0.5, 0), ground_mat)


func _build_props() -> void:
	# Modeled set (Blender glTF). COLLISION REBUILT 2026-11-07 (bando fix):
	# the old boxes sat at the v2 procedural layout, but the glTF Z-axis
	# conversion puts the DRAWN props at Z-mirrored spots (and the blocks
	# at double-transformed spots), so bando walked through the visible
	# models and hit invisible walls elsewhere. Every box below is placed
	# from the props.glb's MEASURED world AABBs (Godot space), so collision
	# matches what is drawn.
	var props := (load("res://assets/props.glb") as PackedScene).instantiate()
	add_child(props)
	_apply_chrome_gold(props)
	_neutralize_prop_stone(props)
	_apply_crystal_shader(props)

	# Standing pillars: drawn 1.30 x 1.30 footprint, 4.57 tall, at
	# measured centres (-14,2), (14,6), (10,-12), (-6,-14).
	var pillar_spots: Array[Vector3] = [Vector3(-14, 0, 2), Vector3(14, 0, 6), Vector3(10, 0, -12), Vector3(-6, 0, -14)]
	for p in pillar_spots:
		var b := _prop(p)
		_add_box(b, Vector3(1.3, 4.6, 1.3), Vector3(0, 2.3, 0), null)

	# Broken blocks: true dims kept, yaw = glTF-space yaw, centres are the
	# measured AABB centres (29.18,-13.91), (-28.92,-20.37), (8.06,27.39).
	var blocks: Array = [
		[Vector3(29.18, 0, -13.91), Vector3(2.2, 1.1, 1.6), 0.4],
		[Vector3(-28.92, 0, -20.37), Vector3(1.8, 0.9, 1.4), -0.3],
		[Vector3(8.06, 0, 27.39), Vector3(2.4, 1.3, 1.7), 0.15],
	]
	for entry in blocks:
		var b := _prop(entry[0], entry[2])
		var sz: Vector3 = entry[1]
		_add_box(b, sz, Vector3(0, sz.y * 0.5, 0), null)

	# Rubble: measured AABB centres/sizes (heights ~0.5-0.6, centred y 0.16)
	var rubble: Array = [
		[Vector3(17.6, 0, -5.6), Vector3(0.58, 0.55, 0.47)],
		[Vector3(-14.7, 0, -6.8), Vector3(0.60, 0.55, 0.49)],
		[Vector3(4.9, 0, 12.8), Vector3(0.49, 0.55, 0.46)],
	]
	for entry in rubble:
		var b := _prop(entry[0])
		var sz: Vector3 = entry[1]
		_add_box(b, sz, Vector3(0, 0.16, 0), null)

	# Standing stones: measured AABB centres + full AABB footprint
	# (tapered 4-sided stones, so the AABB is the drawn silhouette).
	var stones: Array = [
		[Vector3(-3, 0, 16), Vector3(1.38, 3.25, 1.27)],
		[Vector3(18, 0, 12), Vector3(1.11, 2.83, 1.03)],
		[Vector3(-18, 0, 12), Vector3(1.46, 3.42, 1.35)],
	]
	for entry in stones:
		var b := _prop(entry[0])
		var sz2: Vector3 = entry[1]
		_add_box(b, sz2, Vector3(0, sz2.y * 0.5 - 0.03, 0), null)

	# Broken arch: posts + fallen chunk at their measured world spots
	# (the lintel spans at y 3.3+, over Allarion's head: no collision).
	var arch_l := _prop(Vector3(-15.40, 0, -15.23))
	_add_box(arch_l, Vector3(1.22, 3.4, 1.22), Vector3(0, 1.7, 0), null)
	var arch_r := _prop(Vector3(-12.60, 0, -16.77))
	_add_box(arch_r, Vector3(1.22, 3.4, 1.22), Vector3(0, 1.7, 0), null)
	var arch_f := _prop(Vector3(-11.77, 0, -17.56))
	_add_box(arch_f, Vector3(2.11, 0.8, 1.82), Vector3(0, 0.4, 0), null)

	# Crystal clusters: box = union of base + all five leaning shards
	# (measured: 1.24 x 1.03 footprint, 2.42 tall) at the measured cluster
	# centres (8.05,9.01), (-10.95,-2.99), (13.05,-14.99). The old 0.85
	# box covered only the base, so he clipped through the visible mass.
	var crystal_spots: Array = [
		[Vector3(8.05, 0, 9.01), true],
		[Vector3(-10.95, 0, -2.99), false],
		[Vector3(13.05, 0, -14.99), true],
	]
	for entry in crystal_spots:
		var b := _prop(entry[0])
		_add_box(b, Vector3(1.24, 2.42, 1.03), Vector3(0, 1.21, 0), null)
		if entry[1]:
			var omni := OmniLight3D.new()
			omni.light_color = Color(0.6, 0.3, 1.0)
			omni.light_energy = 0.40
			omni.omni_range = 5.0
			omni.position = Vector3(0, 1.3, 0)
			b.add_child(omni)


func _apply_crystal_shader(root: Node) -> void:
	# Lit-from-inside crystals: deep core + fresnel rim, cheap spatial shader.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec4 core_color : source_color = vec4(0.20, 0.06, 0.48, 1.0);
uniform vec4 rim_color : source_color = vec4(0.45, 0.25, 0.85, 1.0);
void fragment() {
	float fres = pow(1.0 - dot(NORMAL, VIEW), 2.0);
	ALBEDO = core_color.rgb * 0.35;
	EMISSION = core_color.rgb * 0.55 + rim_color.rgb * fres * 0.9;
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.mesh and n.name.begins_with("Crystal"):
			for i in n.mesh.get_surface_count():
				n.set_surface_override_material(i, sm)
		for c in n.get_children():
			stack.append(c)


func _build_dust() -> void:
	# Drifting motes that catch the light: gold leads (brighter, denser,
	# larger); violet stays a faint background presence.
	_make_dust_system(300, Color(1.0, 0.83, 0.45, 0.55), 0.065)
	_make_dust_system(100, Color(0.62, 0.45, 1.0, 0.18), 0.060)


func _make_dust_system(count: int, color: Color, size: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.position = Vector3(0, 2.2, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(26, 3.0, 26)
	pm.direction = Vector3(1, 0.12, 0.3)
	pm.spread = 180.0
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.30
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = color
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = qm
	p.draw_pass_1 = quad
	add_child(p)


func _build_actors() -> void:
	player = PlayerScript.new()
	player.position = Vector3(0, 0.1, 9)
	add_child(player)
	_apply_chrome_gold(player)
	player.arrived.connect(_on_player_arrived)
	# Hero light: a faint warm-gold pool that travels with Allarion so he
	# always reads as a figure against the ground, even on a dim phone
	# screen — warm now, never a purple bath.
	var hero_light := OmniLight3D.new()
	hero_light.light_color = Color(1.0, 0.78, 0.38)
	hero_light.light_energy = 0.35
	hero_light.omni_range = 6.0
	hero_light.position = Vector3(0, 2.4, 0)
	player.add_child(hero_light)

	foe = FoeScript.new()
	foe.position = Vector3(-9, 0.1, -7)
	foe.rotation.y = 2.4
	add_child(foe)
	foe.set("target_node", player)


func _build_camera() -> void:
	cam = Camera3D.new()
	cam.fov = 60.0
	add_child(cam)
	_cam_anchor = player.global_position
	_update_camera(0.016)


func _process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	if not player or not cam or _test_freeze_cam:
		return
	_cam_anchor = _cam_anchor.lerp(player.global_position, 1.0 - exp(-4.0 * delta))
	if bool(player.get("has_target")):
		_idle_time = 0.0
	else:
		_idle_time += delta
	var orbit_target := 1.0 if _idle_time > ORBIT_DELAY else 0.0
	_orbit_weight = move_toward(_orbit_weight, orbit_target, delta * 0.8)
	_drift_angle += delta * ORBIT_RATE * _orbit_weight
	var off := Vector3(0, 8.5, 6.5).rotated(Vector3.UP, _drift_angle)
	cam.global_position = _cam_anchor + off
	cam.look_at(_cam_anchor + Vector3(0, 1.2, 0), Vector3.UP)


# ----------------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	_hud_layer = layer
	add_child(layer)

	var title := Label.new()
	title.text = "SAU — 3D FEEL SLICE"
	title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title.offset_left = 16
	title.offset_top = 12
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	layer.add_child(title)

	_hint_label = Label.new()
	_hint_label.text = "Tap to move"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_label.offset_left = -160
	_hint_label.offset_right = 160
	_hint_label.offset_top = -96
	_hint_label.offset_bottom = -56
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	layer.add_child(_hint_label)

	# CODEX button: top-right, large tap target. It is a real Button, so
	# the GUI consumes taps on it — they never reach the ground raycast
	# in _unhandled_input (foresee-the-thumbs audit).
	_codex_button = Button.new()
	_codex_button.text = "CODEX"
	_codex_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_codex_button.offset_left = -236
	_codex_button.offset_right = -16
	_codex_button.offset_top = 12
	_codex_button.offset_bottom = 84
	_codex_button.add_theme_font_size_override("font_size", 34)
	_codex_button.add_theme_color_override("font_color", UI_GOLD)
	_codex_button.add_theme_color_override("font_hover_color", UI_GOLD_HOT)
	_codex_button.add_theme_stylebox_override("normal", _ui_style(UI_STONE_LIGHT, UI_GOLD, 3, 8))
	_codex_button.add_theme_stylebox_override("hover", _ui_style(Color(0.17, 0.155, 0.20, 1.0), UI_GOLD, 3, 8))
	_codex_button.add_theme_stylebox_override("pressed", _ui_style(UI_STONE, UI_GOLD_HOT, 3, 8))
	_codex_button.pressed.connect(_open_codex)
	layer.add_child(_codex_button)


func _ui_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


# --------------------------------------------------------------------- codex

func _build_codex() -> void:
	_codex_layer = CanvasLayer.new()
	_codex_layer.layer = 10
	add_child(_codex_layer)

	_codex_root = Control.new()
	_codex_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_codex_root.visible = false
	_codex_layer.add_child(_codex_root)

	# Dim over the live world: the arena keeps rendering behind it.
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_codex_root.add_child(dim)

	# Carved black-stone panel with a glitter-gold rim.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -590
	panel.offset_right = 590
	panel.offset_top = -345
	panel.offset_bottom = 345
	panel.add_theme_stylebox_override("panel", _ui_style(UI_STONE, UI_GOLD, 3, 10))
	_codex_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header: title + close.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)
	var title := Label.new()
	title.text = "DELVER'S CODEX"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", UI_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_codex_close_button = Button.new()
	_codex_close_button.text = "CLOSE ✕"
	_codex_close_button.custom_minimum_size = Vector2(190, 64)
	_codex_close_button.add_theme_font_size_override("font_size", 28)
	_codex_close_button.add_theme_color_override("font_color", UI_TEXT)
	_codex_close_button.add_theme_stylebox_override("normal", _ui_style(UI_STONE_LIGHT, UI_GOLD, 2, 8))
	_codex_close_button.add_theme_stylebox_override("hover", _ui_style(Color(0.17, 0.155, 0.20, 1.0), UI_GOLD, 2, 8))
	_codex_close_button.add_theme_stylebox_override("pressed", _ui_style(UI_STONE, UI_GOLD_HOT, 2, 8))
	_codex_close_button.pressed.connect(_close_codex)
	header.add_child(_codex_close_button)

	var rule := HSeparator.new()
	var rule_style := StyleBoxFlat.new()
	rule_style.bg_color = UI_GOLD
	rule.add_theme_stylebox_override("separator", rule_style)
	rule.custom_minimum_size = Vector2(0, 3)
	vbox.add_child(rule)

	# --- List view: the whole codex, grouped by category, in a
	# ScrollContainer. Rows keep the sample's readable scale.
	_codex_scroll = ScrollContainer.new()
	_codex_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_codex_scroll)
	_codex_list_box = VBoxContainer.new()
	_codex_list_box.add_theme_constant_override("separation", 12)
	_codex_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_scroll.add_child(_codex_list_box)
	var sub := Label.new()
	sub.text = CodexData.SUBTITLE
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", UI_PURPLE_ACCENT)
	_codex_list_box.add_child(sub)
	for cat in CodexData.CATEGORIES:
		var cat_name: String = cat["name"]
		var cat_entries: Array = cat["entries"]
		var hdr := Label.new()
		hdr.text = "%s — %d" % [cat_name, cat_entries.size()]
		hdr.add_theme_font_size_override("font_size", 30)
		hdr.add_theme_color_override("font_color", UI_GOLD)
		_codex_list_box.add_child(hdr)
		_cat_headers[cat_name] = hdr
		for e in cat_entries:
			var eid: String = e["id"]
			_codex_entries[eid] = {"title": e["title"], "body": e["body"], "plate": e["plate"], "category": cat_name}
			var b := Button.new()
			b.text = "  " + String(e["title"])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.custom_minimum_size = Vector2(0, 80)
			b.add_theme_font_size_override("font_size", 36)
			b.add_theme_color_override("font_color", UI_TEXT)
			b.add_theme_color_override("font_hover_color", UI_GOLD)
			b.add_theme_stylebox_override("normal", _ui_style(UI_STONE_LIGHT, UI_GOLD, 2, 8))
			b.add_theme_stylebox_override("hover", _ui_style(Color(0.17, 0.155, 0.20, 1.0), UI_GOLD, 2, 8))
			b.add_theme_stylebox_override("pressed", _ui_style(UI_STONE, UI_GOLD_HOT, 2, 8))
			b.pressed.connect(_show_codex_entry.bind(eid))
			_codex_list_box.add_child(b)
			_entry_buttons[eid] = b
	var foot := Label.new()
	foot.text = "%d entries — the whole codex, open. In the full game these fill in as you play." % CodexData.TOTAL_ENTRIES
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_theme_font_size_override("font_size", 24)
	foot.add_theme_color_override("font_color", UI_PURPLE_ACCENT)
	_codex_list_box.add_child(foot)

	# --- Entry view.
	_codex_entry_box = VBoxContainer.new()
	_codex_entry_box.add_theme_constant_override("separation", 10)
	_codex_entry_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_entry_box.visible = false
	vbox.add_child(_codex_entry_box)

	_codex_back_button = Button.new()
	_codex_back_button.text = "‹  ALL ENTRIES"
	_codex_back_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_codex_back_button.custom_minimum_size = Vector2(300, 60)
	_codex_back_button.add_theme_font_size_override("font_size", 28)
	_codex_back_button.add_theme_color_override("font_color", UI_GOLD)
	_codex_back_button.add_theme_stylebox_override("normal", _ui_style(UI_STONE_LIGHT, UI_GOLD, 2, 8))
	_codex_back_button.add_theme_stylebox_override("hover", _ui_style(Color(0.17, 0.155, 0.20, 1.0), UI_GOLD, 2, 8))
	_codex_back_button.add_theme_stylebox_override("pressed", _ui_style(UI_STONE, UI_GOLD_HOT, 2, 8))
	_codex_back_button.pressed.connect(_show_codex_list)
	var back_row := HBoxContainer.new()
	back_row.add_child(_codex_back_button)
	_codex_entry_box.add_child(back_row)

	var entry_row := HBoxContainer.new()
	entry_row.add_theme_constant_override("separation", 26)
	entry_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_codex_entry_box.add_child(entry_row)

	# Plate frame: gold rim panel -> stone inner panel -> the plate.
	# The plate rect takes the tap (gui_input) and opens full-size.
	# Texture is set per entry in _show_codex_entry.
	var gold_rim := PanelContainer.new()
	gold_rim.add_theme_stylebox_override("panel", _ui_style(UI_GOLD, UI_GOLD, 0, 6))
	var stone_in := PanelContainer.new()
	var stone_style := _ui_style(Color(0.09, 0.085, 0.11, 1.0), Color(0.09, 0.085, 0.11, 1.0), 0, 4)
	stone_style.content_margin_left = 8
	stone_style.content_margin_right = 8
	stone_style.content_margin_top = 8
	stone_style.content_margin_bottom = 8
	stone_in.add_theme_stylebox_override("panel", stone_style)
	_codex_plate_rect = TextureRect.new()
	_codex_plate_rect.custom_minimum_size = Vector2(260, 340)
	_codex_plate_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_codex_plate_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_codex_plate_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_codex_plate_rect.gui_input.connect(_on_plate_gui_input)
	stone_in.add_child(_codex_plate_rect)
	gold_rim.add_child(stone_in)
	var plate_col := VBoxContainer.new()
	plate_col.add_theme_constant_override("separation", 10)
	plate_col.add_child(gold_rim)
	var cap := Label.new()
	cap.text = "Tap the plate to view it full-size."
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 21)
	cap.add_theme_color_override("font_color", UI_GOLD)
	plate_col.add_child(cap)
	_codex_plate_frame = plate_col
	entry_row.add_child(plate_col)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 6)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry_row.add_child(text_col)
	_codex_entry_title = Label.new()
	_codex_entry_title.add_theme_font_size_override("font_size", 40)
	_codex_entry_title.add_theme_color_override("font_color", UI_GOLD)
	text_col.add_child(_codex_entry_title)
	_codex_entry_subtitle = Label.new()
	_codex_entry_subtitle.add_theme_font_size_override("font_size", 26)
	_codex_entry_subtitle.add_theme_color_override("font_color", UI_PURPLE_ACCENT)
	text_col.add_child(_codex_entry_subtitle)
	# Body in its own ScrollContainer: full text, never clipped, never cut.
	_codex_body_scroll = ScrollContainer.new()
	_codex_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_codex_body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_col.add_child(_codex_body_scroll)
	_codex_entry_body = Label.new()
	_codex_entry_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_codex_entry_body.add_theme_font_size_override("font_size", 24)
	_codex_entry_body.add_theme_constant_override("line_spacing", -5)
	_codex_entry_body.add_theme_color_override("font_color", UI_TEXT)
	_codex_entry_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_entry_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_codex_body_scroll.add_child(_codex_entry_body)

	# --- Full-size plate view (above the panel, still inside the codex).
	_plate_full_root = Control.new()
	_plate_full_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate_full_root.visible = false
	_codex_layer.add_child(_plate_full_root)
	var full_dim := ColorRect.new()
	full_dim.color = Color(0.0, 0.0, 0.0, 0.93)
	full_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	full_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	full_dim.gui_input.connect(_on_full_dim_gui_input)
	_plate_full_root.add_child(full_dim)
	_plate_full_rect = TextureRect.new()
	_plate_full_rect.set_anchors_preset(Control.PRESET_CENTER)
	_plate_full_rect.offset_left = -207
	_plate_full_rect.offset_right = 207
	_plate_full_rect.offset_top = -310
	_plate_full_rect.offset_bottom = 310
	_plate_full_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_plate_full_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_plate_full_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate_full_rect.gui_input.connect(_on_full_dim_gui_input)
	_plate_full_root.add_child(_plate_full_rect)
	var full_close := Button.new()
	full_close.text = "CLOSE ✕"
	full_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	full_close.offset_left = -220
	full_close.offset_right = -16
	full_close.offset_top = 12
	full_close.offset_bottom = 76
	full_close.add_theme_font_size_override("font_size", 28)
	full_close.add_theme_color_override("font_color", UI_TEXT)
	full_close.add_theme_stylebox_override("normal", _ui_style(UI_STONE_LIGHT, UI_GOLD, 2, 8))
	full_close.add_theme_stylebox_override("hover", _ui_style(Color(0.17, 0.155, 0.20, 1.0), UI_GOLD, 2, 8))
	full_close.add_theme_stylebox_override("pressed", _ui_style(UI_STONE, UI_GOLD_HOT, 2, 8))
	full_close.pressed.connect(_hide_plate_full)
	_plate_full_root.add_child(full_close)
	_plate_full_caption = Label.new()
	_plate_full_caption.text = "— tap anywhere to return"
	_plate_full_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_full_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_plate_full_caption.offset_left = -500
	_plate_full_caption.offset_right = 500
	_plate_full_caption.offset_top = -40
	_plate_full_caption.offset_bottom = -8
	_plate_full_caption.add_theme_font_size_override("font_size", 24)
	_plate_full_caption.add_theme_color_override("font_color", UI_GOLD)
	_plate_full_root.add_child(_plate_full_caption)


func _open_codex() -> void:
	_codex_open = true
	_codex_root.visible = true
	_show_codex_list()
	if _codex_button:
		_codex_button.disabled = true


func _close_codex() -> void:
	_codex_open = false
	_hide_plate_full()
	_codex_root.visible = false
	if _codex_button:
		_codex_button.disabled = false


func _show_codex_list() -> void:
	_codex_scroll.visible = true
	_codex_entry_box.visible = false
	_current_entry = ""
	# Return to the list at the scroll position the reader left it.
	_codex_scroll.set_deferred("scroll_vertical", _saved_list_scroll)


func _show_codex_entry(id: String) -> void:
	if not _codex_entries.has(id):
		return
	_saved_list_scroll = _codex_scroll.scroll_vertical
	_current_entry = id
	var d: Dictionary = _codex_entries[id]
	_codex_entry_title.text = d["title"]
	_codex_entry_subtitle.text = d["category"]
	_codex_entry_body.text = d["body"]
	_codex_body_scroll.set_deferred("scroll_vertical", 0)
	var plate_path: String = d["plate"]
	if plate_path != "":
		var tex: Texture2D = load(plate_path)
		_codex_plate_rect.texture = tex
		_plate_full_rect.texture = tex
		_plate_full_caption.text = "%s — tap anywhere to return" % String(d["title"]).to_upper()
		_codex_plate_frame.visible = true
	else:
		_codex_plate_frame.visible = false
	_codex_scroll.visible = false
	_codex_entry_box.visible = true


# With emulate_mouse_from_touch on (the fix that makes Buttons see
# fingers at all), one physical tap arrives TWICE at handlers that
# accept both event types: the raw InputEventScreenTouch and its
# emulated InputEventMouseButton copy, in the same input flush.
# Idempotent actions don't care, but toggle-style ones do — a plate
# tap's second copy lands on the just-opened full-size view and would
# close it again instantly. The twin check below is TIME-only on
# purpose: gui_input event positions are in each control's LOCAL
# space, so the two copies carry different position values and a
# position-based check can never match them (found by trace,
# 2026-11-07). Real successive taps are never <200 ms apart here.
var _press_marks := {}
var _last_gui_press_msec := -10000

func _press_is_duplicate(mark: String, pos: Vector2) -> bool:
	var now := Time.get_ticks_msec()
	if _press_marks.has(mark):
		var m: Array = _press_marks[mark]
		if pos.distance_to(m[1]) < 2.0 and now - int(m[0]) < 150:
			return true
	_press_marks[mark] = [now, pos]
	return false


func _gui_press_is_twin() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_gui_press_msec < 200:
		return true
	_last_gui_press_msec = now
	return false


func _on_plate_gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _gui_press_is_twin():
		_show_plate_full()


func _show_plate_full() -> void:
	_plate_full_root.visible = true


func _hide_plate_full() -> void:
	_plate_full_root.visible = false


func _on_full_dim_gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if pressed and not _gui_press_is_twin():
		_hide_plate_full()


func _on_player_arrived() -> void:
	if _hint_faded:
		return
	_hint_faded = true
	var tw := create_tween()
	tw.tween_property(_hint_label, "modulate:a", 0.0, 1.2)


# --------------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# While the codex is open, ground taps never move Allarion. (The
	# codex's own controls consume their taps before this anyway; the
	# CODEX button likewise consumes its tap and never issues a move.)
	if "--slice-test" in OS.get_cmdline_user_args():
		if event is InputEventMouseButton and event.pressed:
			print("PROBE unhandled MouseButton device=", event.device, " pos=", event.position)
		elif event is InputEventScreenTouch and event.pressed:
			print("PROBE unhandled ScreenTouch device=", event.device, " pos=", event.position)
	if _codex_open:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# One finger tap = one move order: the touch and its emulated
		# mouse copy both land here; the duplicate check drops the twin.
		if not _press_is_duplicate("ground", event.position):
			_tap_to_ground(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		if not _press_is_duplicate("ground", event.position):
			_tap_to_ground(event.position)


func _tap_to_ground(screen_pos: Vector2) -> void:
	if not cam:
		return
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if abs(dir.y) < 0.0001:
		return
	var t := -origin.y / dir.y
	if t < 0.0:
		return
	var hit := origin + dir * t
	_issue_move(Vector3(clamp(hit.x, -28.0, 28.0), 0.0, clamp(hit.z, -28.0, 28.0)))


func _issue_move(target: Vector3) -> void:
	if _codex_open:
		return
	if "--slice-test" in OS.get_cmdline_user_args():
		print("MOVE_ISSUED target=", target, " from=", player.global_position)
	player.command_move(target)
	_spawn_ring(target)


func _spawn_ring(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.5
	torus.rings = 32
	torus.ring_segments = 12
	mi.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.83, 0.28, 0.95)
	mi.material_override = m
	mi.position = pos + Vector3(0, 0.07, 0)
	add_child(mi)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(2.4, 1.0, 2.4), 0.55).from(Vector3(0.4, 1.0, 0.4))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.55)
	tw.set_parallel(false)
	tw.tween_callback(mi.queue_free)


# ----------------------------------------------------------------- test hook

func _synth_click(pos: Vector2) -> void:
	# REAL touch tap (bando fix, 2026-11-07): press + release an
	# InputEventScreenTouch through the real input pipeline — exactly
	# what a finger produces on the phone. The old harness sent mouse
	# events, which pass even when every Button is dead to touch
	# (emulate_mouse_from_touch off) — that blind spot shipped a CODEX
	# button that did nothing on-device. Never verify touch UI with
	# mouse events again.
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = pos
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame
	var rel := InputEventScreenTouch.new()
	rel.index = 0
	rel.pressed = false
	rel.position = pos
	Input.parse_input_event(rel)
	await get_tree().create_timer(0.3).timeout


func _probe_control_stack(point: Vector2) -> void:
	# Diagnostic (test mode only): what does the GUI think sits at this
	# screen point, and what are the emulation settings in force?
	print("PROBE emulate_mouse_from_touch=", ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), " emulate_touch_from_mouse=", ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"))
	print("PROBE stack at ", point, " (tree order, later = on top):")
	_probe_stack_recursive(self, point)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	await get_tree().process_frame
	print("PROBE gui_get_hovered_control=", get_viewport().gui_get_hovered_control())


func _probe_stack_recursive(n: Node, point: Vector2) -> void:
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree() and c.get_global_rect().has_point(point):
			print("PROBE   ", c.get_path(), " class=", c.get_class(), " mouse_filter=", c.mouse_filter, " rect=", c.get_global_rect())
	for ch in n.get_children():
		_probe_stack_recursive(ch, point)


func _scroll_list_to(c: Control) -> Vector2:
	# Scroll the codex list so control c sits inside the viewport, then
	# return its global centre for a synth click.
	_codex_scroll.scroll_vertical = clampi(int(c.get_position().y) - 140, 0, 1 << 30)
	await get_tree().process_frame
	await get_tree().process_frame
	return c.get_global_rect().get_center()


func _run_codex_test() -> void:
	# Full-codex inspection (scripted, not a playtest): captures +
	# input-audit checks through the real GUI input path.
	print("TEST codex_loaded: entries=", _codex_entries.size(), " categories=", CodexData.CATEGORIES.size(), " (want entries=313)")
	await _take_shot("v9_shot1_world_codex.png")
	await _probe_control_stack(_codex_button.get_global_rect().get_center())
	await _synth_click(_codex_button.get_global_rect().get_center())
	print("TEST codex_button_tap: codex_open=", _codex_open, " has_target=", bool(player.get("has_target")), " (want open=true target=false)")
	await _take_shot("v9_shot2_codex_list_top.png")
	await _synth_click(Vector2(25, 360))
	print("TEST ground_tap_while_open: codex_open=", _codex_open, " has_target=", bool(player.get("has_target")), " (want target=false)")
	# Scroll deep into the list: the FACTIONS header sits after ~294 rows.
	var fpos := await _scroll_list_to(_cat_headers["FACTIONS"])
	print("TEST list_scrolled: scroll_vertical=", _codex_scroll.scroll_vertical, " factions_header_screen_y=", fpos.y)
	await _take_shot("v9_shot3_codex_list_scrolled.png")
	# A creation entry WITH a plate (Thalor's vignette).
	var thalor_pos := await _scroll_list_to(_entry_buttons["thalor"])
	await _synth_click(thalor_pos)
	print("TEST entry_open: entry=", _current_entry, " plate_visible=", _codex_plate_frame.visible, " entry_visible=", _codex_entry_box.visible, " (want thalor plate=true)")
	await _take_shot("v9_shot4_entry_plate.png")
	await _synth_click(_codex_plate_rect.get_global_rect().get_center())
	print("TEST plate_tap: full_visible=", _plate_full_root.visible, " (want true)")
	await _take_shot("v9_shot5_plate_full.png")
	await _synth_click(_plate_full_rect.get_global_rect().get_center())
	print("TEST plate_full_tap_returns: full_visible=", _plate_full_root.visible, " entry_visible=", _codex_entry_box.visible, " (want full=false)")
	await _synth_click(_codex_back_button.get_global_rect().get_center())
	print("TEST back_to_list: list_visible=", _codex_scroll.visible, " scroll_restored=", _codex_scroll.scroll_vertical, " saved=", _saved_list_scroll)
	# The longest body in the codex (The Wedge, 503 chars): open it via
	# the click path and read its body-scroll range.
	var wedge_pos := await _scroll_list_to(_entry_buttons["wedges"])
	await _synth_click(wedge_pos)
	await get_tree().process_frame
	await get_tree().process_frame
	var bmax := _codex_body_scroll.get_v_scroll_bar().max_value
	var bpage := _codex_body_scroll.get_v_scroll_bar().page
	print("TEST long_entry_wedges: body_scroll_max=", bmax, " body_page=", bpage)
	# Probe the other long bodies for one whose text overflows the body
	# view (narrower column when a plate is shown), and capture that one
	# scrolled to mid-body.
	var shot_entry := "wedges"
	for cand in ["faction_bereft", "casket", "cleared", "anomalies", "straightrow"]:
		_show_codex_entry(cand)
		await get_tree().process_frame
		await get_tree().process_frame
		var cmax := _codex_body_scroll.get_v_scroll_bar().max_value
		var cpage := _codex_body_scroll.get_v_scroll_bar().page
		print("TEST body_probe: entry=", cand, " max=", cmax, " page=", cpage, " overflow=", cmax > cpage)
		if cmax > cpage:
			shot_entry = cand
			break
	if shot_entry != "wedges":
		_show_codex_entry(shot_entry)
		await get_tree().process_frame
		await get_tree().process_frame
		var smax := _codex_body_scroll.get_v_scroll_bar().max_value
		var spage := _codex_body_scroll.get_v_scroll_bar().page
		_codex_body_scroll.scroll_vertical = int((smax - spage) * 0.5)
		await get_tree().process_frame
		print("TEST long_entry_scrolled: entry=", shot_entry, " body_scroll=", _codex_body_scroll.scroll_vertical, " range=", smax - spage)
	else:
		_show_codex_entry("wedges")
		await get_tree().process_frame
		print("TEST long_entry_scrolled: NONE — no body overflows the entry view")
	await _take_shot("v9_shot6_entry_long.png")
	await _synth_click(_codex_back_button.get_global_rect().get_center())
	await _synth_click(_codex_close_button.get_global_rect().get_center())
	print("TEST codex_close: codex_open=", _codex_open, " root_visible=", _codex_root.visible, " (want open=false)")
	var pos_before: Vector3 = player.global_position
	# Tap the screen position of a known world point 5u east of Allarion
	# (clear ground), so the check is independent of where the idle
	# orbit has swung the camera by now.
	var want := pos_before + Vector3(5.0, 0.0, 0.0)
	var sp := cam.unproject_position(want)
	print("TEST after_close tap_screen=", sp, " for world=", want)
	await _synth_click(sp)
	print("TEST ground_tap_after_close: has_target=", bool(player.get("has_target")), " moved=", player.global_position.distance_to(pos_before), " (want target=true)")
	await _wait_for_arrival(12.0)
	print("TEST after_close_arrival: pos=", player.global_position, " has_target=", bool(player.get("has_target")))


func _run_test() -> void:
	await get_tree().create_timer(1.2).timeout
	await _run_codex_test()
	await _take_shot("v6_shot1_idle_a.png")
	# Idle for ~5 s: the orbit must ease in (after 2.5 s still) and the
	# framing must visibly rotate between the two idle shots.
	await get_tree().create_timer(5.0).timeout
	await _take_shot("v6_shot2_idle_orbit.png")
	print("TEST drift_angle=", _drift_angle)
	_issue_move(Vector3(5.0, 0.0, 0.0))
	await get_tree().create_timer(0.9).timeout
	# Mid-walk: legs striding, sword carried in the right hand.
	await _take_shot("v6_shot3_walk_sword.png")
	await _wait_for_arrival(8.0)
	var to_foe := foe.global_position - player.global_position
	to_foe.y = 0.0
	var target := foe.global_position - to_foe.normalized() * 3.2
	_issue_move(target)
	await _wait_for_arrival(14.0)
	await get_tree().create_timer(1.2).timeout
	await _take_shot("v6_shot4_foe.png")
	# Carry closeup: freeze the follow cam and frame Allarion up close so
	# the sword-in-hand read can be judged, not guessed at arena distance.
	_test_freeze_cam = true
	player.set("has_target", false)
	var p := player.global_position
	player.rotation.y = 2.14
	cam.global_position = p + Vector3(3.37, 1.6, -2.15)
	cam.look_at(p + Vector3(0, 1.05, 0), Vector3.UP)
	await get_tree().create_timer(0.4).timeout
	await _take_shot("v6_shot5_carry_closeup.png")
	print("SLICE_TEST_DONE")
	get_tree().quit()


func _wait_for_arrival(timeout: float) -> void:
	var t := 0.0
	while player.get("has_target") and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _take_shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.is_empty():
		push_warning("Screenshot empty: " + file_name)
		return
	var err := img.save_png(_shot_dir.path_join(file_name))
	print("SHOT ", file_name, " err=", err, " size=", img.get_size())
