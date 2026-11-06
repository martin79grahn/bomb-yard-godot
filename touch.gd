extends Node2D
## On-screen controls for phones: a d-pad on the left, BOMB and BOOM on the right and a START
## button at the top, working like an MD pad (the d-pad and buttons also drive the menus).
## In a 2-player game on one phone, player 2 gets a second set in the top half.
## The menus and messages can also be tapped directly.
## Shown on phones and tablets; T toggles them on a computer.

const C_PAD := Color(1, 1, 1, 0.12)
const C_EDGE := Color(1, 1, 1, 0.4)
const C_ON := Color(1, 0.8, 0.25, 0.6)
const C_BOMB := Color(0.9, 0.15, 0.1, 0.55)
const C_BOOM := Color(0.15, 0.75, 0.3, 0.65)
const C_OFF := Color(0.4, 0.42, 0.55, 0.4)

var main
var enabled := false
var held := [0, 0]           # bits held by fingers on the controls
var pulse := [0, 0]          # bits pressed for one frame by a tap on a menu
var fingers := {}            # touch index -> {"p", "kind": "dpad" | "btn", "bit"}


func _ready() -> void:
	enabled = OS.has_feature("mobile")


## The bits this frame for player p (read once per frame by main).
func take_bits(p: int) -> int:
	var b: int = held[p] | pulse[p]
	pulse[p] = 0
	return b


func two_sets() -> bool:
	return main.nplayers == 2 and main.state in ["play", "paused", "message"]


## Where each control sits for player p: dpad centre and radius, then the two buttons. The
## controls sit in the side margins of a wide phone screen, or over the panels on a narrower one.
func layout(p: int) -> Dictionary:
	var vw: float = get_viewport_rect().size.x
	var side: float = maxf(120.0, main.ox * 0.5)
	var two := two_sets()
	var r: float = 80.0 if two else 100.0
	var y_pad: float = (190.0 if p == 1 else 560.0) if two else 560.0
	var bx: float = vw - side + 10.0
	var by: float = (160.0 if p == 1 else 600.0) if two else 590.0
	var dy: float = 120.0 if p == 1 and two else -120.0
	return {"dpad": Vector2(side, y_pad), "r": r,
		"bomb": Vector2(bx, by), "rb": 56.0 if two else 66.0,
		"boom": Vector2(bx - 70.0, by + dy), "rx": 40.0 if two else 46.0}


func start_rect() -> Rect2:
	var vw: float = get_viewport_rect().size.x
	return Rect2(vw - 150, 80, 130, 48) if main.ox < 150 else Rect2(vw - 150, 14, 130, 52)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		enabled = not enabled
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			fingers.erase(event.index)
			_recompute()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		var f: Dictionary = fingers[event.index]
		if f.kind == "dpad":
			f.bit = _dpad_bits(f.p, event.position)
			_recompute()


func _touch_down(index: int, pos: Vector2) -> void:
	if enabled:
		if start_rect().grow(10).has_point(pos):
			fingers[index] = {"p": 0, "kind": "btn", "bit": main.K_START}
			_recompute()
			return
		if main.state in ["play", "paused", "message"]:
			for p in (2 if two_sets() else 1):
				var l := layout(p)
				if pos.distance_to(l.dpad) < l.r * 1.6:
					fingers[index] = {"p": p, "kind": "dpad", "bit": _dpad_bits(p, pos)}
					_recompute()
					return
				if pos.distance_to(l.bomb) < l.rb * 1.35:
					fingers[index] = {"p": p, "kind": "btn", "bit": main.K_A}
					_recompute()
					return
				if pos.distance_to(l.boom) < l.rx * 1.45:
					fingers[index] = {"p": p, "kind": "btn", "bit": main.K_B}
					_recompute()
					return
	_menu_tap(pos)


func _recompute() -> void:
	held = [0, 0]
	for f in fingers.values():
		held[f.p] |= f.bit


## 8-way: the finger's angle around the pad's centre, with a small dead zone.
func _dpad_bits(p: int, pos: Vector2) -> int:
	var v: Vector2 = pos - layout(p).dpad
	if v.length() < 18.0:
		return 0
	var a := fposmod(v.angle(), TAU)
	var sector := int(round(a / (TAU / 8.0))) % 8   # 0 right, 2 down, 4 left, 6 up
	var bits := [main.K_RIGHT, main.K_RIGHT | main.K_DOWN, main.K_DOWN, main.K_DOWN | main.K_LEFT,
		main.K_LEFT, main.K_LEFT | main.K_UP, main.K_UP, main.K_UP | main.K_RIGHT]
	return bits[sector]


## Taps on the menus and messages.
func _menu_tap(pos: Vector2) -> void:
	match main.state:
		"title":
			for t in 3:
				if main.title_item_rect(t).has_point(pos):
					main._set_title_choice(t)
					pulse[0] |= main.K_START
					return
		"options":
			for r in main.options_rows():
				if main.option_row_rect(r).has_point(pos):
					main.opt_row = r
					main.change_option(r, 1)
					main.audio.play("menu")
					return
			if main.opt_start_rect().has_point(pos):
				pulse[0] |= main.K_START
			elif main.opt_back_rect().has_point(pos):
				pulse[0] |= main.K_B
		"message":
			if main.msg_frames == 0:
				pulse[0] |= main.K_START
		"paused":
			pulse[0] |= main.K_START


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var playing: bool = main.state in ["play", "paused", "message"]
	if playing:
		var sr := start_rect()
		draw_rect(sr, C_ON if held[0] & main.K_START else Color(0.04, 0.06, 0.11, 0.6))
		draw_rect(sr, C_EDGE, false, 2.0)
		_label("PAUSE" if main.state == "play" else "START", sr.get_center(), 22)
	if not playing:
		return
	for p in (2 if two_sets() else 1):
		var l := layout(p)
		var c: Vector2 = l.dpad
		var r: float = l.r
		draw_circle(c, r, C_PAD)
		draw_arc(c, r, 0, TAU, 48, C_EDGE, 3.0, true)
		var dirs := {main.K_UP: Vector2.UP, main.K_DOWN: Vector2.DOWN, main.K_LEFT: Vector2.LEFT, main.K_RIGHT: Vector2.RIGHT}
		for bit in dirs:
			var d: Vector2 = dirs[bit]
			var tip: Vector2 = c + d * r * 0.82
			var base: Vector2 = c + d * r * 0.42
			var n := d.orthogonal() * r * 0.22
			draw_colored_polygon(PackedVector2Array([tip, base + n, base - n]), C_ON if held[p] & bit else C_EDGE)
		draw_circle(l.bomb, l.rb, C_ON if held[p] & main.K_A else C_BOMB)
		draw_arc(l.bomb, l.rb, 0, TAU, 48, C_EDGE, 3.0, true)
		_label("BOMB", l.bomb, 26)
		var has_remote: bool = main.state == "play" and main.prem[p]
		draw_circle(l.boom, l.rx, C_ON if held[p] & main.K_B else (C_BOOM if has_remote else C_OFF))
		draw_arc(l.boom, l.rx, 0, TAU, 40, C_EDGE, 3.0, true)
		_label("BOOM", l.boom, 18)


func _label(s: String, at: Vector2, size: int) -> void:
	draw_string(main.font_black, Vector2(at.x - 100, at.y + size * 0.36), s, HORIZONTAL_ALIGNMENT_CENTER, 200, size, Color.WHITE)
