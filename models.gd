extends RefCounted
## 3D models for everything that moves or can be picked up, built from primitive meshes with
## physically based materials. Every model stands on y = 0, faces +Z (towards the camera) and is
## about one cell (1 unit) across; bosses are bigger. Parts that animate are stored as metadata
## on the root ("feet", "hands", "wings", "tail"...), and "tint" lists the materials an angry
## boss recolours.

static var _mats := {}


static func mat(c: Color, rough := 0.5, metal := 0.0, emit := Color.BLACK, energy := 1.0, coat := 0.0) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f/%s/%.2f/%.2f" % [c.to_html(), rough, metal, emit.to_html(), energy, coat]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit != Color.BLACK:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	if coat > 0.0:
		m.clearcoat_enabled = true
		m.clearcoat = coat
		m.clearcoat_roughness = 0.1
	_mats[key] = m
	return m


## A fresh (unshared) material, for parts whose colour changes.
static func own(c: Color, rough := 0.5, metal := 0.0, coat := 0.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(c, rough, metal, Color.BLACK, 1.0, coat).duplicate()
	return m


static func glass(c: Color, alpha := 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.2
	m.rim_enabled = true
	m.rim = 0.8
	m.rim_tint = 0.3
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


static func sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


static func cyl(r_top: float, r_bot: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t


static func prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	return p


static func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


# ================================================================ bombers
## The four playable characters (MD SUITS: suit shade/mid/light, visor, glint, trim dark/light,
## boots dark/light) and the green bomber, [normal, angry].
const SUITS := {
	"bit": ["#8890b0", "#c8cee2", "#ffffff", "#182040", "#5ad8ff", "#1e54d0", "#4a90ff", "#4a2a18", "#8a5a30"],
	"ruby": ["#902030", "#d83a4a", "#ff9090", "#182040", "#5ad8ff", "#b08a10", "#ffd84a", "#4a2a18", "#8a5a30"],
	"sky": ["#1c4aa8", "#3a8ae8", "#9ad2ff", "#101830", "#ffe04a", "#b08a10", "#ffd84a", "#2a2a3a", "#5a5a72"],
	"nova": ["#a86a10", "#e8b028", "#fff08a", "#2a1440", "#ff7ad0", "#5a28a8", "#9a62ff", "#3a2014", "#6a4428"],
	"green": ["#1a5a20", "#2e9a34", "#7ad86a", "#0c1a0c", "#ffe04a", "#a87a10", "#ffd84a", "#2a1a0c", "#5a3a1a"],
	"green_angry": ["#801414", "#cc2c2c", "#ff8a7a", "#0c1a0c", "#ffe04a", "#1a5a20", "#2e9a34", "#2a1a0c", "#5a3a1a"],
}
const CHAR_SUIT := ["bit", "ruby", "sky", "nova"]


static func bomber(suit: String, horns := false) -> Node3D:
	var s: Array = SUITS[suit]
	var root := Node3D.new()
	var suit_m := own(Color(s[1]), 0.45, 0.0, 0.6)
	var head_m := own(Color(s[2]), 0.25, 0.0, 1.0)
	var trim := mat(Color(s[6]), 0.35, 0.3)
	var boots := mat(Color(s[8]), 0.6)
	var body := pivot(root, Vector3.ZERO)
	var feet: Array = []
	for side in [-1.0, 1.0]:
		var foot := pivot(root, Vector3(0.13 * side, 0.0, 0.0))
		part(foot, sphere(0.14), boots, Vector3(0, 0.08, 0.04), Vector3(1.0, 0.65, 1.4))
		feet.append(foot)
	part(body, sphere(0.25), suit_m, Vector3(0, 0.36, 0), Vector3(1.0, 0.95, 0.9))
	part(body, torus(0.2, 0.27), trim, Vector3(0, 0.3, 0), Vector3(1.0, 0.9, 0.95))
	part(body, sphere(0.06), mat(Color(s[5]), 0.3, 0.6), Vector3(0, 0.3, 0.25))   # buckle
	var hands: Array = []
	for side in [-1.0, 1.0]:
		hands.append(part(body, sphere(0.095), trim, Vector3(0.3 * side, 0.38, 0.04)))
	var head := pivot(body, Vector3(0, 0.82, 0))
	part(head, sphere(0.32), head_m, Vector3.ZERO)
	part(head, sphere(0.28), mat(Color(s[3]), 0.05, 0.4, Color.BLACK, 1.0, 1.0), Vector3(0, -0.01, 0.12), Vector3(1.0, 0.62, 0.75))
	for side in [-1.0, 1.0]:
		part(head, sphere(0.045), mat(Color.WHITE, 0.2, 0.0, Color(s[4]), 3.0), Vector3(0.09 * side, 0.0, 0.33), Vector3(0.8, 1.5, 0.5))
	part(head, cyl(0.025, 0.035, 0.12), trim, Vector3(0, 0.36, 0))
	part(head, sphere(0.075), mat(Color("#ff4a3a"), 0.2, 0.0, Color("#ff4a3a"), 0.6), Vector3(0, 0.45, 0))
	if horns:
		for side in [-1.0, 1.0]:
			part(head, cyl(0.0, 0.07, 0.3), mat(Color("#ffd84a"), 0.25, 0.8), Vector3(0.22 * side, 0.24, 0), Vector3.ONE, Vector3(0, 0, -0.6 * side))
	root.set_meta("body", body)
	root.set_meta("feet", feet)
	root.set_meta("hands", hands)
	root.set_meta("suit", [suit_m, head_m])
	return root


## Recolour a bomber's suit (the green bomber turning angry).
static func recolour_bomber(root: Node3D, suit: String) -> void:
	var s: Array = SUITS[suit]
	var ms: Array = root.get_meta("suit")
	ms[0].albedo_color = Color(s[1])
	ms[1].albedo_color = Color(s[2])


# ================================================================ monsters (one per level)
static func eye(parent: Node3D, pos: Vector3, r: float, iris := Color.BLACK, glow := Color.BLACK) -> void:
	part(parent, sphere(r), mat(Color.WHITE, 0.15, 0.0, Color.BLACK, 1.0, 1.0), pos)
	var pupil_m := mat(iris, 0.1) if glow == Color.BLACK else mat(iris, 0.1, 0.0, glow, 4.0)
	part(parent, sphere(r * 0.55), pupil_m, pos + Vector3(0, 0, r * 0.62))


static func krax(scale := 1.0) -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3.ZERO)
	b.scale = Vector3.ONE * scale
	var feather := own(Color("#24242e"), 0.55, 0.0, 0.4)
	part(b, sphere(0.34), feather, Vector3(0, 0.42, 0), Vector3(1.0, 0.95, 1.05))
	part(b, sphere(0.22), mat(Color("#4a4a62"), 0.6), Vector3(0, 0.36, 0.14), Vector3(1.0, 1.0, 0.8))   # breast
	part(b, cyl(0.0, 0.1, 0.24), mat(Color("#ff9a1a"), 0.35, 0.0, Color.BLACK, 1.0, 0.5), Vector3(0, 0.48, 0.38), Vector3.ONE, Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		eye(b, Vector3(0.12 * side, 0.58, 0.25), 0.08)
		part(b, box(Vector3(0.14, 0.03, 0.04)), mat(Color("#101014")), Vector3(0.12 * side, 0.68, 0.29), Vector3.ONE, Vector3(0, 0, 0.4 * side))
		part(b, cyl(0.02, 0.02, 0.18), mat(Color("#ff9a1a"), 0.5), Vector3(0.1 * side, 0.08, 0.02))
	part(b, prism(Vector3(0.12, 0.18, 0.05)), feather, Vector3(0, 0.82, -0.02))   # tuft
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var w := pivot(b, Vector3(0.3 * side, 0.45, -0.02))
		part(w, sphere(0.2), feather, Vector3(0.05 * side, -0.02, 0), Vector3(0.35, 0.8, 1.1))
		wings.append(w)
	part(b, prism(Vector3(0.28, 0.25, 0.06)), feather, Vector3(0, 0.36, -0.36), Vector3.ONE, Vector3(-1.2, 0, 0))   # tail
	root.set_meta("body", b)
	root.set_meta("wings", wings)
	root.set_meta("tint", [feather])
	root.set_meta("hop", true)
	return root


static func asp() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3.ZERO)
	var skin := mat(Color("#2ea02e"), 0.35, 0.0, Color.BLACK, 1.0, 0.6)
	var belly := mat(Color("#f0e0a0"), 0.5)
	part(b, torus(0.12, 0.34), skin, Vector3(0, 0.1, 0), Vector3(1.0, 1.4, 1.0))
	var neck := pivot(b, Vector3(0, 0.12, 0.05))
	for i in 5:
		part(neck, sphere(0.12 - i * 0.008), skin, Vector3(0, 0.12 + i * 0.11, 0.02 * i))
	part(neck, sphere(0.2), skin, Vector3(0, 0.6, 0.0), Vector3(1.3, 1.1, 0.35))    # hood
	part(neck, sphere(0.15), belly, Vector3(0, 0.58, 0.05), Vector3(1.0, 1.0, 0.3))
	part(neck, sphere(0.12), skin, Vector3(0, 0.72, 0.1), Vector3(1.0, 0.8, 1.2))   # head
	for side in [-1.0, 1.0]:
		eye(neck, Vector3(0.06 * side, 0.76, 0.2), 0.035, Color("#ffd23f"))
	part(neck, box(Vector3(0.02, 0.01, 0.12)), mat(Color("#d01020")), Vector3(0, 0.68, 0.26))
	root.set_meta("body", b)
	root.set_meta("sway", neck)
	return root


static func yeti() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3.ZERO)
	var fur := mat(Color("#e8eef8"), 0.95)
	var face := mat(Color("#5a9ae0"), 0.5)
	part(b, sphere(0.36), fur, Vector3(0, 0.42, 0), Vector3(1.0, 1.05, 0.95))
	for i in 10:
		var a := i * TAU / 10.0
		part(b, sphere(0.1), fur, Vector3(cos(a) * 0.32, 0.2 + (i % 3) * 0.15, sin(a) * 0.3))   # tufts
	part(b, sphere(0.17), face, Vector3(0, 0.55, 0.26), Vector3(1.1, 0.9, 0.5))
	for side in [-1.0, 1.0]:
		eye(b, Vector3(0.07 * side, 0.6, 0.33), 0.045)
		part(b, cyl(0.0, 0.04, 0.12), mat(Color("#c8d4e8"), 0.3), Vector3(0.05 * side, 0.43, 0.33), Vector3.ONE, Vector3(PI, 0, 0))   # fangs
	var hands: Array = []
	for side in [-1.0, 1.0]:
		hands.append(part(b, sphere(0.13), fur, Vector3(0.38 * side, 0.32, 0.08), Vector3(0.9, 1.2, 0.9)))
		part(b, sphere(0.12), fur, Vector3(0.15 * side, 0.07, 0.05), Vector3(1.0, 0.6, 1.3))
	root.set_meta("body", b)
	root.set_meta("hands", hands)
	return root


static func imp() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3(0, 0.25, 0))
	var skin := mat(Color("#e86a1a"), 0.4, 0.0, Color("#e86a1a"), 0.15, 0.4)
	part(b, sphere(0.24), skin, Vector3(0, 0.35, 0))
	for side in [-1.0, 1.0]:
		part(b, cyl(0.0, 0.05, 0.18), mat(Color("#2a0c04"), 0.4), Vector3(0.13 * side, 0.6, 0), Vector3.ONE, Vector3(0, 0, -0.4 * side))
		eye(b, Vector3(0.08 * side, 0.4, 0.18), 0.06, Color("#fff6a0"), Color("#ffd040"))
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var w := pivot(b, Vector3(0.2 * side, 0.4, -0.1))
		part(w, prism(Vector3(0.35, 0.3, 0.02)), mat(Color("#ffd040"), 0.4, 0.0, Color("#ff9020"), 0.4), Vector3(0.18 * side, 0.05, 0), Vector3.ONE, Vector3(0, 0, -1.2 * side))
		wings.append(w)
	part(b, cyl(0.01, 0.025, 0.4), skin, Vector3(0, 0.15, -0.25), Vector3.ONE, Vector3(-0.9, 0, 0))
	part(b, prism(Vector3(0.1, 0.1, 0.02)), skin, Vector3(0, 0.0, -0.42), Vector3.ONE, Vector3(PI, 0, 0))
	var glow := OmniLight3D.new()
	glow.light_color = Color("#ff7a20")
	glow.light_energy = 0.6
	glow.omni_range = 1.4
	glow.position = Vector3(0, 0.4, 0)
	b.add_child(glow)
	root.set_meta("body", b)
	root.set_meta("wings", wings)
	root.set_meta("fly", true)
	return root


static func angel() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3(0, 0.12, 0))
	var robe := mat(Color("#f4f6ff"), 0.6)
	part(b, cyl(0.12, 0.3, 0.55), robe, Vector3(0, 0.3, 0))
	part(b, sphere(0.16), mat(Color("#ffe0c8"), 0.5), Vector3(0, 0.7, 0))
	for side in [-1.0, 1.0]:
		eye(b, Vector3(0.055 * side, 0.72, 0.13), 0.03, Color("#2a2050"))
	part(b, torus(0.13, 0.17), mat(Color("#ffc830"), 0.2, 0.8, Color("#ffc830"), 2.5), Vector3(0, 0.95, 0), Vector3(1, 0.4, 1))
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var w := pivot(b, Vector3(0.12 * side, 0.5, -0.12))
		part(w, sphere(0.24), mat(Color("#ffffff"), 0.7), Vector3(0.22 * side, 0.08, -0.05), Vector3(1.0, 0.55, 0.15), Vector3(0, 0, 0.5 * side))
		wings.append(w)
	root.set_meta("body", b)
	root.set_meta("wings", wings)
	root.set_meta("fly", true)
	return root


static func fish(scale := 1.0) -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3(0, 0.15, 0))
	b.scale = Vector3.ONE * scale
	var orange := mat(Color("#ff7a1a"), 0.3, 0.0, Color.BLACK, 1.0, 0.8)
	var white := mat(Color("#ffffff"), 0.3, 0.0, Color.BLACK, 1.0, 0.8)
	var black := mat(Color("#141414"), 0.4)
	part(b, sphere(0.3), orange, Vector3(0, 0.3, 0), Vector3(0.75, 0.8, 1.25))
	for z in [0.16, -0.12]:
		var band := part(b, sphere(0.3), white, Vector3(0, 0.3, z), Vector3(0.78, 0.83, 0.12))
		band.scale = Vector3(0.78, 0.83 - absf(z) * 0.4, 0.12)
	part(b, prism(Vector3(0.04, 0.22, 0.3)), orange, Vector3(0, 0.6, -0.02), Vector3.ONE, Vector3(0, 0, 0))
	var tail := pivot(b, Vector3(0, 0.3, -0.36))
	part(tail, prism(Vector3(0.04, 0.34, 0.24)), orange, Vector3(0, 0, -0.1), Vector3.ONE, Vector3(PI / 2, 0, 0))
	part(tail, box(Vector3(0.05, 0.36, 0.03)), black, Vector3(0, 0, -0.22))
	for side in [-1.0, 1.0]:
		eye(b, Vector3(0.14 * side, 0.36, 0.25), 0.055)
	root.set_meta("body", b)
	root.set_meta("tail", tail)
	root.set_meta("swim", true)
	root.set_meta("tint", [orange])
	return root


static func monster(level: int) -> Node3D:
	match level:
		1: return asp()
		2: return yeti()
		3: return imp()
		4: return angel()
		5: return fish()
	return krax()


# ================================================================ bosses
## Normal and angry main colours of each creature boss (MD BOSS_SUITS).
const BOSS_COLS := [
	[Color("#3e3e58"), Color("#a01c24")],    # Krax King
	[Color("#2a64d0"), Color("#d0582a")],    # scorpion
	[Color("#8a4a20"), Color("#b02a14")],    # mammoth
	[Color("#d02a0a"), Color("#ffb020")],    # dragon
	[Color("#8a92a8"), Color("#50506a")],    # storm cloud
	[Color("#6c8296"), Color("#b04a5e")],    # shark
]


static func boss(i: int) -> Node3D:
	var root: Node3D
	match i:
		0: root = _krax_king()
		1: root = _scorpion()
		2: root = _mammoth()
		3: root = _dragon()
		4: root = _storm()
		5: root = _shark()
		_:
			root = bomber("green", true)
			root.scale = Vector3.ONE * 1.25
			return root
	return root


static func set_boss_angry(root: Node3D, i: int, angry: bool) -> void:
	if i >= 6:
		recolour_bomber(root, "green_angry" if angry else "green")
		return
	for m in root.get_meta("tint", []):
		m.albedo_color = BOSS_COLS[i][1 if angry else 0]


static func _krax_king() -> Node3D:
	var root := krax(1.75)
	var b: Node3D = root.get_meta("body")
	var gold := mat(Color("#ffd84a"), 0.2, 1.0)
	part(b, cyl(0.17, 0.17, 0.12, 20), gold, Vector3(0, 0.86, 0))
	for k in 6:
		var a := k * TAU / 6.0
		part(b, cyl(0.0, 0.045, 0.12), gold, Vector3(cos(a) * 0.15, 0.97, sin(a) * 0.15))
	part(b, sphere(0.04), mat(Color("#e02040"), 0.1, 0.0, Color("#e02040"), 1.0), Vector3(0, 0.88, 0.17))
	return root


static func _scorpion() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3.ZERO)
	var shell := own(Color("#2a64d0"), 0.25, 0.1, 1.0)
	var gold := mat(Color("#ffc23f"), 0.25, 0.8)
	for k in 3:
		part(b, sphere(0.3 - k * 0.04), shell, Vector3(0, 0.3, 0.2 - k * 0.28), Vector3(1.2, 0.6, 1.0))
	var tail := pivot(b, Vector3(0, 0.35, -0.55))
	var p := Vector3.ZERO
	for k in 5:
		p += Vector3(0, 0.17, -0.06 + k * 0.07)
		part(tail, sphere(0.12 - k * 0.01), shell, p)
	part(tail, cyl(0.0, 0.07, 0.22), gold, p + Vector3(0, 0.05, 0.15), Vector3.ONE, Vector3(1.9, 0, 0))
	for side in [-1.0, 1.0]:
		var arm := pivot(b, Vector3(0.3 * side, 0.32, 0.4))
		part(arm, cyl(0.05, 0.05, 0.35), shell, Vector3(0.05 * side, 0, 0.15), Vector3.ONE, Vector3(PI / 2, 0.3 * side, 0))
		part(arm, sphere(0.14), shell, Vector3(0.1 * side, 0, 0.38), Vector3(1.0, 0.7, 1.3))
		part(arm, cyl(0.0, 0.05, 0.22), gold, Vector3(0.05 * side, 0, 0.56), Vector3.ONE, Vector3(PI / 2, 0, 0))
		part(arm, cyl(0.0, 0.04, 0.18), gold, Vector3(0.16 * side, 0, 0.53), Vector3.ONE, Vector3(PI / 2, 0, 0))
		for k in 3:
			part(b, cyl(0.025, 0.025, 0.45), shell, Vector3(0.38 * side, 0.15, 0.1 - k * 0.22), Vector3.ONE, Vector3(0, 0, 1.0 * side))
	for side in [-1.0, 1.0]:
		eye(b, Vector3(0.1 * side, 0.45, 0.42), 0.05, Color("#140c24"))
	root.set_meta("body", b)
	root.set_meta("tail", tail)
	root.set_meta("tint", [shell])
	root.scale = Vector3.ONE * 1.3
	return root


static func _mammoth() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3.ZERO)
	var fur := own(Color("#8a4a20"), 0.95)
	var ivory := mat(Color("#fff8e8"), 0.3, 0.0, Color.BLACK, 1.0, 0.6)
	part(b, sphere(0.55), fur, Vector3(0, 0.7, -0.1), Vector3(1.0, 0.9, 1.15))
	part(b, sphere(0.36), fur, Vector3(0, 0.85, 0.48))
	for side in [-1.0, 1.0]:
		part(b, cyl(0.13, 0.15, 0.45), fur, Vector3(0.3 * side, 0.22, 0.2))
		part(b, cyl(0.13, 0.15, 0.45), fur, Vector3(0.3 * side, 0.22, -0.4))
		part(b, sphere(0.22), fur, Vector3(0.36 * side, 0.9, 0.42), Vector3(0.3, 1.0, 0.9))   # ears
		var tusk := pivot(b, Vector3(0.14 * side, 0.65, 0.72))
		for k in 4:
			part(tusk, cyl(0.035 - k * 0.006, 0.045 - k * 0.006, 0.16), ivory,
				Vector3(0.02 * side * k, 0.04 * k * k * 0.5, 0.12 * k), Vector3.ONE, Vector3(1.2 - k * 0.35, 0, 0))
		eye(b, Vector3(0.18 * side, 0.95, 0.75), 0.05)
	var trunk := pivot(b, Vector3(0, 0.75, 0.78))
	for k in 6:
		part(trunk, sphere(0.1 - k * 0.008), fur, Vector3(0, -0.1 * k, 0.04 * k))
	root.set_meta("body", b)
	root.set_meta("sway", trunk)
	root.set_meta("tint", [fur])
	root.scale = Vector3.ONE * 1.15
	return root


static func _dragon() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3.ZERO)
	var scales := own(Color("#d02a0a"), 0.35, 0.2, 0.6)
	var belly := mat(Color("#ffd040"), 0.5)
	part(b, sphere(0.4), scales, Vector3(0, 0.55, -0.05), Vector3(0.9, 0.85, 1.2))
	part(b, sphere(0.3), belly, Vector3(0, 0.5, 0.18), Vector3(0.8, 0.8, 0.7))
	var neck := pivot(b, Vector3(0, 0.7, 0.3))
	for k in 3:
		part(neck, sphere(0.15), scales, Vector3(0, 0.12 * k, 0.1 * k))
	part(neck, sphere(0.22), scales, Vector3(0, 0.42, 0.38), Vector3(0.9, 0.8, 1.3))
	part(neck, sphere(0.12), scales, Vector3(0, 0.36, 0.6), Vector3(1.0, 0.7, 1.0))   # snout
	for side in [-1.0, 1.0]:
		eye(neck, Vector3(0.1 * side, 0.5, 0.52), 0.05, Color("#ffd040"), Color("#ff9020"))
		part(neck, cyl(0.0, 0.05, 0.25), mat(Color("#fff0c0"), 0.4), Vector3(0.1 * side, 0.62, 0.3), Vector3.ONE, Vector3(-0.6, 0, -0.3 * side))
	var wings: Array = []
	for side in [-1.0, 1.0]:
		var w := pivot(b, Vector3(0.3 * side, 0.85, -0.05))
		part(w, prism(Vector3(0.9, 0.55, 0.03)), mat(Color("#ff8a2a"), 0.5, 0.0, Color("#ff4a10"), 0.3), Vector3(0.4 * side, 0.15, -0.1), Vector3.ONE, Vector3(0.3, 0, -0.5 * side))
		wings.append(w)
	var tail := pivot(b, Vector3(0, 0.45, -0.5))
	for k in 5:
		part(tail, sphere(0.14 - k * 0.022), scales, Vector3(0, -0.06 * k, -0.17 * k))
	part(tail, prism(Vector3(0.18, 0.18, 0.03)), belly, Vector3(0, -0.25, -0.9), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		part(b, cyl(0.08, 0.1, 0.35), scales, Vector3(0.25 * side, 0.18, 0.15))
		part(b, cyl(0.08, 0.1, 0.35), scales, Vector3(0.25 * side, 0.18, -0.3))
	root.set_meta("body", b)
	root.set_meta("wings", wings)
	root.set_meta("tail", tail)
	root.set_meta("tint", [scales])
	root.scale = Vector3.ONE * 1.2
	return root


static func _storm() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3(0, 0.55, 0))
	var cloud := own(Color("#8a92a8"), 1.0)
	for p in [Vector3(0, 0.3, 0), Vector3(-0.35, 0.2, 0), Vector3(0.35, 0.22, 0), Vector3(-0.18, 0.5, -0.05),
			Vector3(0.2, 0.48, 0), Vector3(0, 0.15, 0.2), Vector3(-0.5, 0.05, -0.1), Vector3(0.5, 0.05, -0.1)]:
		part(b, sphere(0.32), cloud, p, Vector3.ONE * (0.9 + fmod(p.x * 7.3, 0.3)))
	for side in [-1.0, 1.0]:
		eye(b, Vector3(0.14 * side, 0.32, 0.36), 0.08, Color("#401010"), Color("#ff2a10"))
		part(b, box(Vector3(0.2, 0.04, 0.05)), mat(Color("#20202a")), Vector3(0.14 * side, 0.45, 0.4), Vector3.ONE, Vector3(0, 0, 0.45 * side))
	var bolt_m := mat(Color("#fff04a"), 0.2, 0.0, Color("#fff04a"), 5.0)
	var bolt := pivot(b, Vector3(0, -0.15, 0.1))
	var p := Vector3.ZERO
	for k in 4:
		var q := p + Vector3(0.12 if k % 2 == 0 else -0.12, -0.16, 0)
		var seg := part(bolt, box(Vector3(0.05, 0.2, 0.05)), bolt_m, (p + q) * 0.5)
		seg.rotation.z = atan2(q.x - p.x, -(q.y - p.y))
		p = q
	var flash := OmniLight3D.new()
	flash.light_color = Color("#fff4a0")
	flash.light_energy = 0.0
	flash.omni_range = 3.0
	flash.position = Vector3(0, -0.3, 0.2)
	b.add_child(flash)
	root.set_meta("body", b)
	root.set_meta("bolt", bolt)
	root.set_meta("flash", flash)
	root.set_meta("fly", true)
	root.set_meta("tint", [cloud])
	root.scale = Vector3.ONE * 1.25
	return root


static func _shark() -> Node3D:
	var root := Node3D.new()
	var b := pivot(root, Vector3(0, 0.2, 0))
	var back := own(Color("#6c8296"), 0.3, 0.0, 0.8)
	var belly := mat(Color("#eef2f6"), 0.35)
	part(b, sphere(0.35), back, Vector3(0, 0.35, 0), Vector3(0.85, 0.75, 1.8))
	part(b, sphere(0.33), belly, Vector3(0, 0.27, 0.05), Vector3(0.8, 0.55, 1.65))
	part(b, prism(Vector3(0.05, 0.45, 0.4)), back, Vector3(0, 0.75, -0.05), Vector3.ONE, Vector3(0, PI / 2, 0))
	for side in [-1.0, 1.0]:
		part(b, prism(Vector3(0.4, 0.04, 0.25)), back, Vector3(0.32 * side, 0.18, 0.15), Vector3.ONE, Vector3(0, 0, -0.4 * side))
		eye(b, Vector3(0.2 * side, 0.42, 0.45), 0.045, Color("#0a0e14"))
	var mouth := part(b, box(Vector3(0.36, 0.06, 0.1)), mat(Color("#8a1a2a"), 0.6), Vector3(0, 0.25, 0.55))
	mouth.rotation.x = 0.2
	for k in 6:
		part(b, cyl(0.0, 0.022, 0.06), mat(Color.WHITE, 0.2), Vector3(-0.14 + k * 0.056, 0.27, 0.6), Vector3.ONE, Vector3(PI, 0, 0))
	var tail := pivot(b, Vector3(0, 0.35, -0.6))
	part(tail, prism(Vector3(0.05, 0.6, 0.35)), back, Vector3(0, 0, -0.12), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	root.set_meta("body", b)
	root.set_meta("tail", tail)
	root.set_meta("swim", true)
	root.set_meta("tint", [back])
	root.scale = Vector3.ONE * 1.25
	return root


# ================================================================ bombs and power-ups
static func bomb(remote: bool) -> Node3D:
	var root := Node3D.new()
	var shell := own(Color("#1a1d2a"), 0.22, 0.6, 1.0)
	var body := pivot(root, Vector3.ZERO)
	part(body, sphere(0.34), shell, Vector3(0, 0.36, 0))
	part(body, cyl(0.1, 0.12, 0.12), mat(Color("#3a4466"), 0.3, 0.8), Vector3(0, 0.71, 0))
	if remote:
		part(body, torus(0.31, 0.37), mat(Color("#2ab04a"), 0.3, 0.2), Vector3(0, 0.36, 0), Vector3(1, 1.6, 1))
		part(body, cyl(0.012, 0.012, 0.32), mat(Color("#c0c4d0"), 0.2, 1.0), Vector3(0, 0.9, 0))
		var lamp := part(body, sphere(0.05), mat(Color("#ff3a2a"), 0.2), Vector3(0, 1.07, 0))
		root.set_meta("lamp", lamp)
	else:
		var fuse := part(body, cyl(0.02, 0.025, 0.2), mat(Color("#a8743c"), 0.9), Vector3(0.05, 0.84, 0), Vector3.ONE, Vector3(0, 0, -0.45))
		var spark := part(body, sphere(0.05), mat(Color("#fff6b8"), 0.1, 0.0, Color("#ffb030"), 6.0), Vector3(0.1, 0.94, 0))
		var light := OmniLight3D.new()
		light.light_color = Color("#ffa040")
		light.light_energy = 0.8
		light.omni_range = 1.3
		light.position = spark.position
		body.add_child(light)
		root.set_meta("spark", spark)
		root.set_meta("light", light)
		fuse.name = "fuse"
	part(body, sphere(0.06), mat(Color.WHITE, 0.05, 0.0, Color.WHITE, 0.4), Vector3(-0.12, 0.5, 0.22), Vector3(1.0, 1.4, 0.6))   # highlight
	root.set_meta("body", body)
	root.set_meta("shell", shell)
	return root


## A power-up: a glassy bubble with the item inside. kind: bomb fire shoe life pen rem
static func item(kind: String) -> Node3D:
	var root := Node3D.new()
	var spin := pivot(root, Vector3(0, 0.45, 0))
	var inner := pivot(spin, Vector3.ZERO)
	match kind:
		"bomb", "pen", "rem":
			part(inner, sphere(0.16), mat(Color("#1a1d2a"), 0.2, 0.6, Color.BLACK, 1.0, 1.0), Vector3(0, -0.02, 0))
			part(inner, cyl(0.05, 0.06, 0.06), mat(Color("#3a4466"), 0.3, 0.8), Vector3(0, 0.15, 0))
			if kind == "pen":
				var red := mat(Color("#e02a1a"), 0.3, 0.3)
				part(inner, cyl(0.025, 0.025, 0.5), red, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI / 2))
				part(inner, cyl(0.0, 0.07, 0.14), mat(Color("#ffd02a"), 0.3, 0.6), Vector3(0.3, 0, 0), Vector3.ONE, Vector3(0, 0, -PI / 2))
			elif kind == "rem":
				part(inner, cyl(0.01, 0.01, 0.2), mat(Color("#c0c4d0"), 0.2, 1.0), Vector3(0, 0.26, 0))
				part(inner, sphere(0.035), mat(Color("#ff3a2a"), 0.2, 0.0, Color("#ff3a2a"), 4.0), Vector3(0, 0.37, 0))
				for k in 2:
					part(inner, torus(0.08 + k * 0.06, 0.095 + k * 0.06), mat(Color("#fff6b8"), 0.2, 0.0, Color("#fff6b8"), 2.0),
						Vector3(0, 0.37, 0), Vector3(1, 1, 0.3), Vector3(PI / 2, 0, 0))
			else:
				part(inner, sphere(0.03), mat(Color("#fff6b8"), 0.1, 0.0, Color("#ffb030"), 6.0), Vector3(0.05, 0.22, 0))
		"fire":
			var f1 := mat(Color("#ff8a1a"), 0.4, 0.0, Color("#ff6a10"), 3.0)
			var f2 := mat(Color("#fff6b8"), 0.4, 0.0, Color("#ffd040"), 4.0)
			part(inner, sphere(0.14), f1, Vector3(0, -0.05, 0))
			part(inner, cyl(0.0, 0.13, 0.28), f1, Vector3(0, 0.15, 0))
			part(inner, sphere(0.08), f2, Vector3(0, -0.05, 0.05))
		"shoe":
			var red := mat(Color("#e02a1a"), 0.35, 0.0, Color.BLACK, 1.0, 0.6)
			part(inner, box(Vector3(0.16, 0.12, 0.34)), red, Vector3(0, 0, 0.02))
			part(inner, box(Vector3(0.15, 0.14, 0.14)), red, Vector3(0, 0.1, -0.08))
			part(inner, box(Vector3(0.18, 0.05, 0.38)), mat(Color.WHITE, 0.6), Vector3(0, -0.08, 0.02))
			part(inner, box(Vector3(0.17, 0.02, 0.02)), mat(Color.WHITE, 0.5), Vector3(0, 0.07, 0.08))
		"life":
			var red := mat(Color("#ff2a4a"), 0.15, 0.0, Color("#ff2a4a"), 0.6, 1.0)
			part(inner, sphere(0.11), red, Vector3(-0.08, 0.06, 0))
			part(inner, sphere(0.11), red, Vector3(0.08, 0.06, 0))
			part(inner, box(Vector3(0.18, 0.18, 0.16)), red, Vector3(0, -0.04, 0), Vector3.ONE, Vector3(0, 0, PI / 4))
	part(spin, sphere(0.27), glass(Color("#8fd0ff"), 0.22), Vector3.ZERO)
	var glow := OmniLight3D.new()
	glow.light_color = Color("#9fd8ff") if kind != "life" else Color("#ff6a8a")
	glow.light_energy = 0.5
	glow.omni_range = 1.1
	spin.add_child(glow)
	root.set_meta("spin", spin)
	return root
