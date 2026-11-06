extends Node2D
## On-screen controls for phones: a d-pad on the left, BOMB and BOOM on the right and a START
## button at the top, working like an MD pad (the d-pad and buttons also drive the menus).
## In a 2-player game on one phone, player 2 gets a second set in the top half.
## The menus and messages can also be tapped directly.
## Shown on phones and tablets; T toggles them on a computer.

const C_DPAD := Color(1, 1, 1, 0.16)
const C_EDGE := Color(1, 1, 1, 0.35)
const C_ON := Color(1, 0.88, 0.3, 0.55)
const C_BOMB := Color(0.88, 0.16, 0.1, 0.5)
const C_BOOM := Color(0.2, 0.7, 0.3, 0.6)
const C_OFF := Color(0.5, 0.5, 0.6, 0.35)

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


## Where each control sits for player p: dpad centre and radius, then the two buttons.
func layout(p: int) -> Dictionary:
	var vw: float = get_viewport_rect().size.x
	var side: float = maxf(34.0, main.ox * 0.5)
	var two := two_sets()
	var y_pad: float = (56.0 if p == 1 else 170.0) if two else 166.0
	var r: float = 25.0 if two else 30.0
	var bx: float = vw - side + 4.0
	var by: float = (44.0 if p == 1 else 184.0) if two else 182.0
	var boom_dy: float = 34.0 if p == 1 and two else -34.0
	return {"dpad": Vector2(side, y_pad), "r": r,
		"bomb": Vector2(bx, by), "rb": 17.0 if two else 19.0,
		"boom": Vector2(bx - 20.0, by + boom_dy), "rx": 12.0 if two else 13.0}


func start_rect() -> Rect2:
	var vw: float = get_viewport_rect().size.x
	return Rect2(vw - 36, 2, 33, 13)


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
		if start_rect().grow(4).has_point(pos):
			fingers[index] = {"p": 0, "kind": "btn", "bit": main.K_START}
			_recompute()
			return
		for p in (2 if two_sets() else 1):
			var l := layout(p)
			if pos.distance_to(l.dpad) < l.r * 1.7:
				fingers[index] = {"p": p, "kind": "dpad", "bit": _dpad_bits(p, pos)}
				_recompute()
				return
			if pos.distance_to(l.bomb) < l.rb * 1.4:
				fingers[index] = {"p": p, "kind": "btn", "bit": main.K_A}
				_recompute()
				return
			if pos.distance_to(l.boom) < l.rx * 1.5:
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
	if v.length() < 6.0:
		return 0
	var a := fposmod(v.angle(), TAU)
	var sector := int(round(a / (TAU / 8.0))) % 8   # 0 right, 2 down, 4 left, 6 up
	var bits := [main.K_RIGHT, main.K_RIGHT | main.K_DOWN, main.K_DOWN, main.K_DOWN | main.K_LEFT,
		main.K_LEFT, main.K_LEFT | main.K_UP, main.K_UP, main.K_UP | main.K_RIGHT]
	return bits[sector]


## Taps on the menus and messages, in the MD screen's 8-pixel tiles.
func _menu_tap(pos: Vector2) -> void:
	var tx := int((pos.x - main.ox) / 8.0)
	var ty := int(pos.y / 8.0)
	match main.state:
		"title":
			for t in 3:
				if absi(ty - (13 + t * 2)) <= 1 and tx >= 8 and tx < 32:
					main._set_title_choice(t)
					pulse[0] |= main.K_START
					return
			if ty >= 20 and ty <= 22:
				pulse[0] |= main.K_START
		"options":
			var top: int = 11 if main.nplayers == 1 else 9
			for r in main.options_rows():
				if absi(ty - (top + r * 2)) <= 0 and tx >= 6 and tx < 34:
					main.opt_row = r
					main.change_option(r, 1)
					main.audio.play("menu")
					return
			if ty >= 22 and ty <= 24 and tx >= 6 and tx < 34:
				pulse[0] |= main.K_START if tx < 22 else main.K_B
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
	var sr := start_rect()
	draw_rect(sr, C_ON if held[0] & main.K_START else C_DPAD)
	draw_rect(sr, C_EDGE, false, 1.0)
	_label("START" if main.state != "play" else "PAUSE", sr.get_center())
	for p in (2 if two_sets() else 1):
		var l := layout(p)
		var c: Vector2 = l.dpad
		var r: float = l.r
		draw_circle(c, r, C_DPAD)
		draw_arc(c, r, 0, TAU, 32, C_EDGE, 1.0)
		var dirs := {main.K_UP: Vector2.UP, main.K_DOWN: Vector2.DOWN, main.K_LEFT: Vector2.LEFT, main.K_RIGHT: Vector2.RIGHT}
		for bit in dirs:
			var d: Vector2 = dirs[bit]
			var tip: Vector2 = c + d * r * 0.8
			var base: Vector2 = c + d * r * 0.45
			var n := d.orthogonal() * r * 0.2
			draw_colored_polygon(PackedVector2Array([tip, base + n, base - n]), C_ON if held[p] & bit else C_EDGE)
		var bomb_on: bool = held[p] & main.K_A
		draw_circle(l.bomb, l.rb, C_ON if bomb_on else C_BOMB)
		draw_arc(l.bomb, l.rb, 0, TAU, 32, C_EDGE, 1.0)
		_label("BOMB", l.bomb)
		var has_remote: bool = main.state == "play" and main.prem[p]
		draw_circle(l.boom, l.rx, C_ON if held[p] & main.K_B else (C_BOOM if has_remote else C_OFF))
		draw_arc(l.boom, l.rx, 0, TAU, 24, C_EDGE, 1.0)
		_label("BOOM", l.boom)


## Text in the game's font, centred on a point.
func _label(s: String, at: Vector2) -> void:
	var x := at.x - s.length() * 4.0
	for i in s.length():
		var g: int = main.font_order.find(s[i])
		if g > 0:
			draw_texture_rect_region(main.tex_font, Rect2(x + i * 8, at.y - 4, 8, 8), Rect2(g * 8, 0, 8, 8))
