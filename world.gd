extends Node3D
## The 3D view of the game. It reads main.gd's state every frame (the rules don't know it
## exists) and keeps a 3D scene in step: textured blocks on a textured ground, bombs, blasts,
## power-ups, the bombers, monsters and bosses, with real lights, shadows, glow and particles.
## Cell (cx, cy) is centred at (cx - 7.5, 0, cy - 6), one unit per cell; +Z is down the screen.

const Models := preload("res://models.gd")
const FireShader := preload("res://fire.gdshader")

## Per level: textures, sky (top, horizon), sun colour and energy, ambient, fog colour and density,
## and the colour of broken-block debris.
const THEMES := [
	{"name": "yard", "sky": ["#3f86d9", "#bfe0ff"], "sun": ["#fff1d8", 2.2], "amb": 0.55, "fog": ["#bfe0ff", 0.0], "debris": "#b07a40"},
	{"name": "sand", "sky": ["#5f9ad0", "#f3dcb0"], "sun": ["#ffe2b0", 2.6], "amb": 0.55, "fog": ["#f0d6a8", 0.0015], "debris": "#c9683e"},
	{"name": "frost", "sky": ["#7aa8d8", "#e8f4ff"], "sun": ["#e8f2ff", 1.8], "amb": 0.7, "fog": ["#dceeff", 0.002], "debris": "#ffffff"},
	{"name": "lava", "sky": ["#3a0c06", "#c0441a"], "sun": ["#ffd2b0", 2.2], "amb": 0.6, "ambc": "#8a8090", "fog": ["#4a1206", 0.003], "debris": "#3a1a10"},
	{"name": "cloud", "sky": ["#5aa8ff", "#ffffff"], "sun": ["#fffaf0", 2.4], "amb": 0.85, "fog": ["#ffffff", 0.0015], "debris": "#ffffff"},
	{"name": "sea", "sky": ["#062a44", "#1f7a8c"], "sun": ["#b8f0ff", 1.4], "amb": 0.5, "fog": ["#14596a", 0.008], "debris": "#7a8c98"},
]

var main
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var ground: MeshInstance3D
var theme_i := -1
var serial := -1
var mats := {}             # "floor_yard" -> material
var blocks := {}           # cell -> MeshInstance3D
var block_type := PackedInt32Array()
var bombs := {}            # bomb slot -> {node, cell}
var flames := {}           # cell -> [lower quad, upper quad]
var items := {}            # cell -> {node, kind}
var players: Array = [null, null]
var player_key := ["", ""]
var monsters: Array = [null, null]
var monster_key := ["", ""]
var prev_alive := [0, 0, 0, 0]       # players 0-1, monsters 0-1
var prev_binv := 0
var shake := 0.0
var lights: Array = []               # explosion flashes {light, t}
var fire_noise: NoiseTexture2D
var fire_mesh: QuadMesh
var cam_angle := 0.0
var closeup := Vector3.INF     # tests: look closely at this point
var t := 0.0


func _ready() -> void:
	block_type.resize(main.CELLS)
	block_type.fill(-1)
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME      # the automatic mode left vertical faces black
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_strength = 0.9
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = RenderingServer.get_current_rendering_method() == "forward_plus"   # the phone renderer has none
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.2
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)

	camera = Camera3D.new()
	camera.fov = 34.0
	add_child(camera)

	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	add_child(ground)

	fire_noise = NoiseTexture2D.new()
	fire_noise.seamless = true
	fire_noise.width = 128
	fire_noise.height = 128
	var fn := FastNoiseLite.new()
	fn.frequency = 0.03
	fn.fractal_octaves = 3
	fire_noise.noise = fn
	fire_mesh = QuadMesh.new()
	fire_mesh.size = Vector2(1.0, 1.0)
	fire_mesh.orientation = PlaneMesh.FACE_Y
	var fm := ShaderMaterial.new()
	fm.shader = FireShader
	fm.set_shader_parameter("noise_tex", fire_noise)
	fire_mesh.material = fm


# ================================================================ materials
func surface(name: String, block: bool) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_albedo.png" % name)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/%s_normal.png" % name)
	m.normal_scale = 1.2
	m.roughness_texture = load("res://assets/tex/%s_rough.png" % name)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	if ResourceLoader.exists("res://assets/tex/%s_emit.png" % name):
		m.emission_enabled = true
		m.emission_texture = load("res://assets/tex/%s_emit.png" % name)
		m.emission_energy_multiplier = 3.0
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	if block:
		m.uv1_offset = Vector3(0.5, 0.5, 0.5)       # each face shows the whole texture
	else:
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)        # one texture tile per two cells
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if name == "wall_frost" or name == "stone_frost":
		m.clearcoat_enabled = true
		m.clearcoat = 0.8
	mats[name] = m
	return m


func _apply_theme(i: int) -> void:
	theme_i = i
	var th: Dictionary = THEMES[i]
	sky_mat.sky_top_color = Color(th.sky[0])
	sky_mat.sky_horizon_color = Color(th.sky[1])
	sky_mat.ground_horizon_color = Color(th.sky[1])
	sky_mat.ground_bottom_color = Color(th.sky[1]).darkened(0.5)
	sun.light_color = Color(th.sun[0])
	sun.light_energy = th.sun[1] * 0.7
	env.ambient_light_color = Color(th.ambc) if th.has("ambc") else Color(th.sky[0]).lerp(Color(th.sky[1]), 0.6)
	env.ambient_light_energy = th.amb * 1.3
	env.fog_enabled = th.fog[1] > 0.0
	env.fog_light_color = Color(th.fog[0])
	env.fog_density = th.fog[1]
	ground.material_override = surface("floor_" + th.name, false)
	for c in blocks:
		blocks[c].queue_free()
	blocks.clear()
	block_type.fill(-1)


# ================================================================ per frame
func _process(delta: float) -> void:
	t += delta
	var m = main
	var want_theme: int = 0 if m.state in ["title", "options"] else m.level
	if want_theme != theme_i:
		_apply_theme(want_theme)
	if m.map_serial != serial:
		serial = m.map_serial
		_clear_dynamic()
	_sync_blocks()
	_sync_bombs()
	_sync_flames()
	_sync_items()
	var show_actors: bool = m.sprites_on and not m.state in ["title", "options"]
	for p in 2:
		_sync_player(p, show_actors)
	for i in 2:
		_sync_monster(i, show_actors)
	_update_lights(delta)
	_update_camera(delta)


func cell_pos(ci: int, y := 0.0) -> Vector3:
	return Vector3((ci & 15) - 7.5, y, (ci >> 4) - 6.0)


func pix_pos(x: float, y: float) -> Vector3:
	return Vector3(x / 16.0 - 7.5, 0.0, y / 16.0 - 6.0)


func _clear_dynamic() -> void:
	for d in [bombs, items]:
		for k in d:
			d[k].node.queue_free()
		d.clear()
	for k in flames:
		for q in flames[k]:
			q.queue_free()
	flames.clear()
	for p in 2:
		prev_alive[p] = main.palive[p]
		prev_alive[2 + p] = main.malive[p]


func _sync_blocks() -> void:
	var m = main
	var th: String = THEMES[theme_i].name
	for ci in m.CELLS:
		var ty: int = m.cell_type(ci)
		if ty == block_type[ci]:
			continue
		var was := block_type[ci]
		block_type[ci] = ty
		if blocks.has(ci):
			blocks[ci].queue_free()
			blocks.erase(ci)
		if was == m.STONE and ty == m.FLOOR and serial == m.map_serial:
			_debris(ci)
		if ty == m.FLOOR:
			continue
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		if ty == m.CEMENT:
			bm.size = Vector3(1.0, 1.0, 1.0)
			mi.material_override = surface("wall_" + th, true)
			mi.position = cell_pos(ci, 0.5)
		else:
			bm.size = Vector3(0.94, 0.86, 0.94)
			mi.material_override = surface("stone_" + th, true)
			mi.position = cell_pos(ci, 0.43)
		mi.mesh = bm
		add_child(mi)
		blocks[ci] = mi


func _sync_bombs() -> void:
	var m = main
	for b in m.MAX_BOMBS:
		var used: bool = m.b_used[b] != 0
		if bombs.has(b) and (not used or bombs[b].cell != m.b_cell[b]):
			_explosion(bombs[b].cell)
			bombs[b].node.queue_free()
			bombs.erase(b)
		if not used:
			continue
		var rem: bool = m.b_rem[b] != 0
		if not bombs.has(b) or bombs[b].rem != rem:
			if bombs.has(b):
				bombs[b].node.queue_free()
			var n := Models.bomb(rem)
			n.position = cell_pos(m.b_cell[b])
			add_child(n)
			bombs[b] = {"node": n, "cell": m.b_cell[b], "rem": rem}
		var node: Node3D = bombs[b].node
		var body: Node3D = node.get_meta("body")
		var fz: int = m.b_fuse[b]
		var pulse := 1.0 + 0.06 * sin(t * (9.0 if fz > 60 else 22.0))
		body.scale = Vector3(pulse, 2.0 - pulse, pulse)
		var shell: StandardMaterial3D = node.get_meta("shell")
		var flash := not rem and fz < 60 and ((fz / 5) & 1) == 1
		shell.emission_enabled = flash
		if flash:
			shell.emission = Color("#ff2a10")
			shell.emission_energy_multiplier = 1.5
		if rem:
			var lamp: MeshInstance3D = node.get_meta("lamp")
			lamp.material_override = Models.mat(Color("#ff3a2a"), 0.2, 0.0, Color("#ff3a2a"), 5.0 if (int(t * 2.0) & 1) else 0.2)
		else:
			var light: OmniLight3D = node.get_meta("light")
			light.light_energy = 0.6 + 0.4 * randf()
			var spark: Node3D = node.get_meta("spark")
			spark.scale = Vector3.ONE * (0.8 + 0.6 * randf())


func _sync_flames() -> void:
	var m = main
	for ci in m.CELLS:
		var f: int = m.flame[ci]
		if f == 0:
			if flames.has(ci):
				for q in flames[ci]:
					q.queue_free()
				flames.erase(ci)
			continue
		if not flames.has(ci):
			var qs := []
			for k in 2:
				var q := MeshInstance3D.new()
				q.mesh = fire_mesh
				q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				q.position = cell_pos(ci, 0.25 + k * 0.32)
				q.set_instance_shader_parameter("seed", randf() * 10.0)
				add_child(q)
				qs.append(q)
			flames[ci] = qs
		var sides: int = (1 if m.flame[ci - 1] else 0) | (2 if m.flame[ci + 1] else 0) \
			| (4 if m.flame[ci - m.GW] else 0) | (8 if m.flame[ci + m.GW] else 0)
		var power: float = 1.0 if f >= m.FLAME_LOW else 0.45 + 0.55 * f / float(m.FLAME_LOW)
		for k in 2:
			flames[ci][k].set_instance_shader_parameter("sides", sides)
			flames[ci][k].set_instance_shader_parameter("power", power * (1.0 if k == 0 else 0.7))


func _sync_items() -> void:
	var m = main
	var seen := {}
	for ci in m.CELLS:
		if m.cell_type(ci) != m.FLOOR or m.flame[ci] or m.has_bomb(ci) or not m.item(ci):
			continue
		var kind: String = "life" if m.is_life(ci) else ("pen" if m.is_pen(ci) else ("rem" if m.is_rem(ci) else
			["", "shoe", "fire", "bomb"][m.item(ci)]))
		seen[ci] = true
		if items.has(ci) and items[ci].kind != kind:
			items[ci].node.queue_free()
			items.erase(ci)
		if not items.has(ci):
			var n := Models.item(kind)
			n.position = cell_pos(ci)
			add_child(n)
			items[ci] = {"node": n, "kind": kind}
		var spin: Node3D = items[ci].node.get_meta("spin")
		spin.rotation.y = t * 1.6 + ci
		spin.position.y = 0.45 + 0.06 * sin(t * 2.5 + ci)
	for ci in items.keys():
		if not seen.has(ci):
			items[ci].node.queue_free()
			items.erase(ci)


# ================================================================ characters
const DIR_YAW := [-PI / 2, PI / 2, PI, 0.0]     # left, right, up, down
const ACTOR_SCALE := 1.3      # characters a bit larger than a cell, so they read well from above


func _sync_player(p: int, show: bool) -> void:
	var m = main
	var is_boss: bool = p == 1 and m.boss
	var active: bool = show and (p < m.nplayers or is_boss)
	var key := ""
	if active:
		key = "boss%d" % m.bi() if is_boss else "char%d" % m.opt_char[p]
	if key != player_key[p]:
		if players[p]:
			players[p].queue_free()
		players[p] = null
		player_key[p] = key
		if key != "":
			players[p] = Models.boss(m.bi()) if is_boss else Models.bomber(Models.CHAR_SUIT[m.opt_char[p]])
			players[p].scale *= ACTOR_SCALE
			add_child(players[p])
			prev_alive[p] = m.palive[p]
	var n: Node3D = players[p]
	if n == null:
		return
	if prev_alive[p] and not m.palive[p]:
		_burst(pix_pos(m.px[p], m.py[p]) + Vector3(0, 0.5, 0), Color("#ffffff") if not is_boss else Color("#ffd040"), 40, 3.0)
	prev_alive[p] = m.palive[p]
	var visible: bool = m.palive[p] or (m.pdeath[p] & 4)
	if is_boss:
		if m.palive[1] and m.binv > prev_binv:
			_burst(pix_pos(m.px[1], m.py[1]) + Vector3(0, 0.8, 0), Color("#ffd040"), 30, 3.5)
			shake = maxf(shake, 0.25)
		prev_binv = m.binv
		if m.palive[1] and (m.binv & 4):
			visible = false
		Models.set_boss_angry(n, m.bi(), m.boss_angry())
	n.visible = visible
	n.position = pix_pos(m.px[p], m.py[p])
	if not m.palive[p]:
		n.position.y = -0.4 * (1.0 - m.pdeath[p] / 60.0)
	_face(n, DIR_YAW[m.pdir[p]])
	_animate(n, m.pmoving[p] != 0, p)


func _sync_monster(i: int, show: bool) -> void:
	var m = main
	var active: bool = show and (m.malive[i] or m.mdeath[i])
	var key := "mon%d" % m.level if active else ""
	if key != monster_key[i]:
		if monsters[i]:
			monsters[i].queue_free()
		monsters[i] = null
		monster_key[i] = key
		if key != "":
			monsters[i] = Models.monster(m.level)
			monsters[i].scale *= ACTOR_SCALE
			add_child(monsters[i])
	var n: Node3D = monsters[i]
	if prev_alive[2 + i] and not m.malive[i]:
		_burst(pix_pos(m.mx[i], m.my[i]) + Vector3(0, 0.4, 0), Color("#d8d8e0"), 30, 2.5)
	prev_alive[2 + i] = m.malive[i]
	if n == null:
		return
	n.visible = m.malive[i] or (m.mdeath[i] & 4)
	n.position = pix_pos(m.mx[i], m.my[i])
	_face(n, DIR_YAW[m.mdir[i]])
	_animate(n, m.mmoving[i] != 0, 10 + i)


func _face(n: Node3D, yaw: float) -> void:
	n.rotation.y = lerp_angle(n.rotation.y, yaw, 0.3)


## Walk cycles: feet and hands swing, wings flap, tails wag, fliers bob, the Krax hops.
func _animate(n: Node3D, moving: bool, seed: int) -> void:
	var ph := t * (11.0 if moving else 2.0) + seed
	var body: Node3D = n.get_meta("body", null)
	if n.has_meta("feet"):
		var feet: Array = n.get_meta("feet")
		var hands: Array = n.get_meta("hands")
		for k in 2:
			var s := sin(ph) * (1.0 if k == 0 else -1.0)
			feet[k].position.z = s * 0.12 if moving else 0.0
			feet[k].position.y = maxf(0.0, s) * 0.06 if moving else 0.0
			hands[k].position.z = 0.04 - s * 0.1 if moving else 0.04
		body.position.y = absf(sin(ph)) * 0.04 if moving else 0.01 * sin(ph)
	if n.has_meta("hop") and body:
		body.position.y = absf(sin(ph * 0.8)) * 0.12 if moving else 0.0
	if n.has_meta("fly") and body:
		body.position.y = (body.position.y * 0.0) + 0.12 * sin(t * 3.0 + seed) + (0.25 if n.has_meta("bolt") else 0.0)
	if n.has_meta("swim") and body:
		body.position.y = 0.06 * sin(t * 2.0 + seed) + 0.1
	if n.has_meta("wings"):
		var wings: Array = n.get_meta("wings")
		var flap := sin(t * (14.0 if moving or n.has_meta("fly") else 3.0) + seed) * 0.5
		for k in wings.size():
			wings[k].rotation.z = flap * (1.0 if k == 0 else -1.0)
	if n.has_meta("tail"):
		var tail: Node3D = n.get_meta("tail")
		tail.rotation.y = sin(t * (8.0 if moving else 3.0) + seed) * 0.35
	if n.has_meta("sway"):
		var sway: Node3D = n.get_meta("sway")
		sway.rotation.z = sin(t * 2.2 + seed) * 0.12
		sway.rotation.x = sin(t * 1.6 + seed) * 0.08
	if n.has_meta("hands") and not n.has_meta("feet"):
		var hs: Array = n.get_meta("hands")
		for k in hs.size():
			hs[k].position.y = 0.32 + 0.05 * sin(ph + k * PI)
	if n.has_meta("bolt"):
		var on := fmod(t + seed, 1.6) < 0.18
		n.get_meta("bolt").visible = on
		n.get_meta("flash").light_energy = 4.0 if on else 0.0


# ================================================================ effects
func _explosion(ci: int) -> void:
	var p := cell_pos(ci, 0.5)
	var l := OmniLight3D.new()
	l.light_color = Color("#ff9a3a")
	l.omni_range = 5.0
	l.light_energy = 6.0
	l.position = p + Vector3(0, 0.5, 0)
	add_child(l)
	lights.append({"light": l, "t": 0.0})
	while lights.size() > 8:
		var old: Dictionary = lights.pop_front()
		old.light.queue_free()
	_burst(p, Color(3.0, 1.6, 0.4), 26, 4.0, 0.55)
	_smoke(p)
	shake = maxf(shake, 0.18)


func _update_lights(delta: float) -> void:
	for i in range(lights.size() - 1, -1, -1):
		var e: Dictionary = lights[i]
		e.t += delta
		e.light.light_energy = 6.0 * maxf(0.0, 1.0 - e.t / 0.5)
		if e.t >= 0.5:
			e.light.queue_free()
			lights.remove_at(i)


func _particles(amount: int, life: float, mesh: Mesh, pm: ParticleProcessMaterial, at: Vector3) -> void:
	var gp := GPUParticles3D.new()
	gp.amount = amount
	gp.lifetime = life
	gp.one_shot = true
	gp.explosiveness = 0.95
	gp.process_material = pm
	gp.draw_pass_1 = mesh
	gp.position = at
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gp)
	gp.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(gp.queue_free)


## Glowing sparks (an explosion, a boss hit, someone caught).
func _burst(at: Vector3, c: Color, amount: int, speed: float, life := 0.7) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, -4, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(c, 1.0))
	ramp.set_color(1, Color(c.r * 0.4, c.g * 0.2, c.b * 0.1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	gt.use_hdr = true
	pm.color_ramp = gt
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.14, 0.14)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.vertex_color_use_as_albedo = true
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.albedo_texture = _soft_dot()
	mesh.material = mm
	_particles(amount, life, mesh, pm, at)


func _smoke(at: Vector3) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 1.6))
	var ct := CurveTexture.new()
	ct.curve = sc
	pm.scale_curve = ct
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.35, 0.33, 0.32, 0.55))
	ramp.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = ramp
	pm.color_ramp = gt
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.6, 0.6)
	var mm := StandardMaterial3D.new()
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.vertex_color_use_as_albedo = true
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.albedo_texture = _soft_dot()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mm
	_particles(6, 1.2, mesh, pm, at + Vector3(0, 0.3, 0))


## Chunks of a broken block flying apart.
func _debris(ci: int) -> void:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 70.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.5
	pm.gravity = Vector3(0, -12, 0)
	pm.angular_velocity_min = -400.0
	pm.angular_velocity_max = 400.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.35, 0.3, 0.35)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.12, 0.14)
	mesh.material = surface("stone_" + THEMES[theme_i].name, true)
	_particles(14, 0.9, mesh, pm, cell_pos(ci, 0.45))


var _dot: Texture2D
func _soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_dot = gt
	return _dot


# ================================================================ camera
## Tilted down at the arena. The arena is framed so it fits between the side panels; on the title
## and options screens the camera slowly circles the arena.
func _update_camera(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / vp.y
	var menu: bool = main.state in ["title", "options"]
	shake = maxf(0.0, shake - delta * 0.8)
	var target := Vector3(0, 0, 0.35)
	if menu:
		cam_angle += delta * 0.08
		var dist := 24.0
		camera.position = Vector3(sin(cam_angle) * dist * 0.6, 15.0, cos(cam_angle) * dist * 0.6)
		camera.look_at(Vector3.ZERO, Vector3.UP)
		return
	cam_angle = 0.0
	if closeup != Vector3.INF:
		camera.position = closeup + Vector3(0, 5.0, 2.6)
		camera.look_at(closeup + Vector3(0, 0.4, 0), Vector3.UP)
		return
	# fit 16 x 13 cells in the middle of a 1280-wide layout (panels take ~250 px per side)
	var usable := minf(1.0, (vp.y / 720.0 * 780.0) / vp.x) if aspect > 1.0 else 1.0
	var dist := 27.0 / maxf(0.75, usable * aspect / (780.0 / 720.0))
	dist = clampf(dist, 26.0, 44.0)
	var tilt := deg_to_rad(62.0)
	camera.position = target + Vector3(0, sin(tilt) * dist, cos(tilt) * dist)
	camera.look_at(target, Vector3.UP)
	if shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.5
