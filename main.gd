extends Node2D
## Bomb Yard: the Mega Drive game (bomb-yard-nes/md/src/main.c) remade in Godot.
##
## The rules are ported function by function from main.c and keep its numbers: 60 ticks a
## second, 16-pixel cells, speeds in 1/16 pixel per frame, fuses and flames in frames. The
## screen is the MD's 320 x 224: a 16 x 13 arena between two HUD panels under a band with the
## level and the clock. On wider screens (phones) the extra width is split left and right and
## holds the touch controls. Graphics come from the MD's own drawing code (tools/export_art.py).

const Touch := preload("res://touch.gd")

# ---------------------------------------------------------------- layout and rules (main.c)
const AX := 4                 # arena's left edge, in 8-pixel tiles
const AY := 2                 # arena's top edge
const GW := 16
const GH := 13
const CELLS := GW * GH

const FLOOR := 0
const CEMENT := 1
const STONE := 2
const TUFT := 0x80            # with a shoe item: the extra life
const HAS_BOMB := 0x10
const RUBBLE := 0x20          # a stone just blasted: still stops blasts while it burns, but can't hurt
const PEN := 0x40             # bomb item + PEN = penetrator, fire item + PEN = remote

const IT_SHOE := 1
const IT_FIRE := 2
const IT_BOMB := 3

const FUSE := 180
const FLAME_TIME := 32
const FLAME_LOW := 12
const MAX_BOMBS := 40
const MAX_SPEEDUPS := 4
const POOL_LIFE := 1
const POOL_PEN := 2
const POOL_REM := 2
const ROUND_SECS := 120
const STRESS_SECS := 20

# pad bits, as the MD reads its controllers
const K_UP := 1
const K_DOWN := 2
const K_LEFT := 4
const K_RIGHT := 8
const K_A := 16
const K_B := 32
const K_C := 64
const K_START := 128
const K_BOMB := K_A | K_B | K_C
const K_REMOTE := K_B

const DX := [-1, 1, 0, 0]
const DY := [0, 0, -1, 1]
const DSTEP := [-1, 1, -GW, GW]
const DBTN := [K_LEFT, K_RIGHT, K_UP, K_DOWN]
const BACK := [1, 0, 3, 2]

const CHAR_NAME := ["BIT ", "RUBY", "SKY ", "NOVA"]
const WIN_CHOICES := [3, 5, 10]

const NBOSS := 7
const FINAL := 6
const BOSS_HP := [3, 4, 4, 5, 6, 7, 8]
const BOSS_ANGRY := [2, 2, 2, 3, 3, 4, 4]
const BOSS_BOMBS := [2, 2, 3, 3, 3, 4, 4]
const BOSS_FIRE_R := [5, 5, 6, 6, 7, 7, 8]
const BOSS_SPEED := [14, 15, 15, 16, 17, 18, 19]
const BOSS_REST := [30, 26, 22, 18, 14, 12, 10]
const BOSS_NAME := ["THE KRAX KING", "THE SCORPION", "THE MAMMOTH", "THE DRAGON", "THE STORM CLOUD", "THE SHARK", "THE GREEN BOMBER"]
const BOSS_TAKES := ["IT TAKES 3 HITS", "IT TAKES 4 HITS", "IT TAKES 4 HITS", "IT TAKES 5 HITS", "IT TAKES 6 HITS", "IT TAKES 7 HITS", "IT TAKES 8 HITS"]

const NMON := 2
const LEVELS := 6
const SEA := 5
const MON_GOT := ["THE KRAX GOT YOU", "AN ASP GOT YOU", "A YETI GOT YOU", "AN IMP GOT YOU", "AN ANGEL GOT YOU", "A FISH GOT YOU"]
const MON_WATCH := ["WATCH OUT FOR THE KRAX", "WATCH OUT FOR THE ASPS", "WATCH OUT FOR THE YETIS",
	"WATCH OUT FOR THE IMPS", "WATCH OUT FOR THE ANGELS", "WATCH OUT FOR THE FISH"]
const LEVEL_NAME := ["THE YARD", "SAND PIT", "FROST CAVE", "LAVA PEAK", "CLOUD NINE", "DEEP SEA"]
const LEVEL_SONG := ["yard", "sand", "frost", "lava", "cloud", "sea"]
const MONSTER_SPEED := [8, 10, 13, 14, 15, 16]
const LEVEL_PAL := [0, 1, 2, 4, 5, 6]    # row in tiles.png; 3 is the boss arena (title only)

const R_NONE := -1
const R_DIED := 0
const R_CLEARED := 1
const R_P1 := 2
const R_P2 := 3
const R_DRAW := 4

const MON_NAMES := ["KRAX", "ASPS", "YETIS", "IMPS", "ANGELS", "FISH"]
const CONFETTI := [Color("#ff3b30"), Color("#ff9500"), Color("#ffcc00"), Color("#34c759"), Color("#0a84ff"), Color("#ff2d92")]

# ---------------------------------------------------------------- look
const W := 1280.0            # the layout is designed for 1280 x 720; wider screens get side margins
const H := 720.0
const C_CARD := Color(0.04, 0.06, 0.11, 0.74)
const C_EDGE := Color(1, 1, 1, 0.14)
const C_GOLD := Color("#ffc83a")
const C_DIM := Color("#a9b4cc")
const SUIT_COL := [Color("#e9edf7"), Color("#e8424f"), Color("#3a8ae8"), Color("#f0b42a")]
var font_black: Font = preload("res://assets/fonts/NotoSans-Black.ttf")
var font_bold: Font = preload("res://assets/fonts/NotoSans-Bold.ttf")
var world

# ---------------------------------------------------------------- arena state
var cell := PackedByteArray()
var flame := PackedByteArray()
var bfire := PackedByteArray()     # burning only with the boss's own fire, which can't hurt it
var fowner := 0
var bpen := false
var flame_phase := 0

var b_cell := PackedInt32Array()
var b_fuse := PackedInt32Array()
var b_range := PackedInt32Array()
var b_used := PackedInt32Array()
var b_owner := PackedInt32Array()
var b_pen := PackedInt32Array()
var b_rem := PackedInt32Array()

# players: 0 is pad 1, 1 is pad 2 (2 players) or the boss
var px := PackedInt32Array([0, 0])
var py := PackedInt32Array([0, 0])
var pcx := PackedInt32Array([0, 0])
var pcy := PackedInt32Array([0, 0])
var pmoving := PackedInt32Array([0, 0])
var pdir := PackedInt32Array([3, 3])
var pleft := PackedInt32Array([0, 0])
var pfrac := PackedInt32Array([0, 0])
var pspeed := PackedInt32Array([16, 16])
var pups := PackedInt32Array([0, 0])
var pfire := PackedInt32Array([1, 1])
var pbombs := PackedInt32Array([1, 1])
var pactive := PackedInt32Array([0, 0])
var ppen := PackedInt32Array([0, 0])
var prem := PackedInt32Array([0, 0])
var pdx := PackedInt32Array([0, 0])
var pdy := PackedInt32Array([0, 0])
var pbuf := PackedInt32Array([0, 0])
var pbuft := PackedInt32Array([0, 0])
var palive := PackedInt32Array([0, 0])
var pdeath := PackedInt32Array([0, 0])
var panim := PackedInt32Array([0, 0])
var pframe := PackedInt32Array([0, 0])
var ppending := PackedInt32Array([0, 0])
var pburned := PackedInt32Array([0, 0])
var pl := 0
var nplayers := 1
var wins := PackedInt32Array([0, 0])

var boss := false
var fin := false
var bhits := 0
var binv := 0
var bwait := 0
var vb_cell := 0
var vb_on := false
var shark_fl := false

var mx := PackedInt32Array([0, 0])
var my := PackedInt32Array([0, 0])
var mcx := PackedInt32Array([0, 0])
var mcy := PackedInt32Array([0, 0])
var mmoving := PackedInt32Array([0, 0])
var mdir := PackedInt32Array([0, 0])
var mleft := PackedInt32Array([0, 0])
var mfrac := PackedInt32Array([0, 0])
var mdx := PackedInt32Array([0, 0])
var mdy := PackedInt32Array([0, 0])
var malive := PackedInt32Array([0, 0])
var mdeath := PackedInt32Array([0, 0])
var mwait := PackedInt32Array([0, 0])
var mbob := PackedInt32Array([0, 0])
var mspeed := 8

var level := 0
var debug := false
var rush := false
var secs := ROUND_SECS
var subsec := 60
var time_up := false
var lives := 3
var win_target := 3
var frame_count := 0
var test_clear := false      # like the MD's TEST_CLEAR build: each monster level clears after 2 s

# options (saved)
var opt_level := 0
var opt_monsters := false
var opt_wins := 0
var opt_lives := 0
var opt_items := 5
var opt_char := [0, 1]
var opt_row := 0

# ---------------------------------------------------------------- screen state
## title | options | play | message | paused
var state := "title"
var sprites_on := true
var msg_lines: Array = []
var msg_frames := 0
var msg_then: Callable
var confetti := false
var cf_x := PackedInt32Array()
var cf_y := PackedInt32Array()
var title_walk := 0
var title_kx := -16
var on_title_backdrop := false

# pads
var pad := [0, 0]
var pad_old := [0, 0]
var pad_new := [0, 0]
var ox := 0                  # left edge of the 1280-wide layout inside a wider viewport
var map_serial := 0          # bumped by build_map, so the 3D view knows to start over

var audio
var touch


# ================================================================ setup
func _ready() -> void:
	cell.resize(CELLS)
	flame.resize(CELLS)
	bfire.resize(CELLS)
	for a in [b_cell, b_fuse, b_range, b_used, b_owner, b_pen, b_rem]:
		a.resize(MAX_BOMBS)
	cf_x.resize(32)
	cf_y.resize(32)
	world = preload("res://world.gd").new()
	world.main = self
	add_child(world)
	audio = preload("res://audio.gd").new()
	add_child(audio)
	touch = Touch.new()
	touch.main = self
	add_child(touch)
	_load_options()
	randomize()
	get_tree().set_auto_accept_quit(false)
	title_screen()


func _load_options() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://options.cfg") != OK:
		return
	opt_level = clampi(cf.get_value("opts", "level", 0), 0, LEVELS - 1)
	opt_monsters = cf.get_value("opts", "monsters", false)
	opt_wins = clampi(cf.get_value("opts", "wins", 0), 0, 2)
	opt_lives = clampi(cf.get_value("opts", "lives", 0), 0, 2)
	opt_items = clampi(cf.get_value("opts", "items", 5), 1, 7)
	opt_char = [clampi(cf.get_value("opts", "p1", 0), 0, 3), clampi(cf.get_value("opts", "p2", 1), 0, 3)]
	audio.muted = cf.get_value("opts", "muted", false)


func _save_options() -> void:
	var cf := ConfigFile.new()
	for k in ["level", "monsters", "wins", "lives", "items"]:
		cf.set_value("opts", k, get("opt_" + k))
	cf.set_value("opts", "p1", opt_char[0])
	cf.set_value("opts", "p2", opt_char[1])
	cf.set_value("opts", "muted", audio.muted)
	cf.save("user://options.cfg")


func rand8() -> int:
	return randi() & 255


# ================================================================ pads
## Keyboard, gamepads and the touch controls, folded into one MD pad per player.
func _read_pads() -> void:
	var versus: bool = nplayers == 2 and state in ["play", "paused", "message"]
	for p in 2:
		var b := 0
		if p == 0 and not versus:
			b |= _keys([KEY_UP, KEY_W], K_UP) | _keys([KEY_DOWN, KEY_S], K_DOWN)
			b |= _keys([KEY_LEFT, KEY_A], K_LEFT) | _keys([KEY_RIGHT, KEY_D], K_RIGHT)
			b |= _keys([KEY_SPACE, KEY_X], K_A) | _keys([KEY_Z, KEY_SHIFT], K_B) | _keys([KEY_C], K_C)
			b |= _keys([KEY_ENTER, KEY_KP_ENTER, KEY_P], K_START)
		elif p == 0:
			b |= _keys([KEY_W], K_UP) | _keys([KEY_S], K_DOWN) | _keys([KEY_A], K_LEFT) | _keys([KEY_D], K_RIGHT)
			b |= _keys([KEY_SPACE, KEY_F], K_A) | _keys([KEY_E, KEY_G], K_B) | _keys([KEY_P], K_START)
		else:
			b |= _keys([KEY_UP], K_UP) | _keys([KEY_DOWN], K_DOWN) | _keys([KEY_LEFT], K_LEFT) | _keys([KEY_RIGHT], K_RIGHT)
			b |= _keys([KEY_ENTER, KEY_KP_ENTER, KEY_SLASH], K_A) | _keys([KEY_SHIFT, KEY_PERIOD], K_B)
		var pads := Input.get_connected_joypads()
		if p < pads.size():
			var d: int = pads[p]
			b |= _joy(d, [JOY_BUTTON_DPAD_UP], K_UP) | _joy(d, [JOY_BUTTON_DPAD_DOWN], K_DOWN)
			b |= _joy(d, [JOY_BUTTON_DPAD_LEFT], K_LEFT) | _joy(d, [JOY_BUTTON_DPAD_RIGHT], K_RIGHT)
			b |= _joy(d, [JOY_BUTTON_A], K_A) | _joy(d, [JOY_BUTTON_B], K_B) | _joy(d, [JOY_BUTTON_X, JOY_BUTTON_Y], K_C)
			b |= _joy(d, [JOY_BUTTON_START], K_START)
			var ax := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
			var ay := Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
			if ax < -0.5: b |= K_LEFT
			if ax > 0.5: b |= K_RIGHT
			if ay < -0.5: b |= K_UP
			if ay > 0.5: b |= K_DOWN
		b |= touch.take_bits(p)
		pad_old[p] = pad[p]
		pad[p] = b
		pad_new[p] = b & ~pad_old[p]


func _keys(keys: Array, bit: int) -> int:
	for k in keys:
		if Input.is_physical_key_pressed(k):
			return bit
	return 0


func _joy(d: int, buttons: Array, bit: int) -> int:
	for b in buttons:
		if Input.is_joy_button_pressed(d, b):
			return bit
	return 0


## Ignore whatever is held right now (the MD sets pad = 0xFFFF before a wait).
func _swallow_pads() -> void:
	_read_pads()
	pad_new = [0, 0]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			audio.toggle_mute()
			_save_options()
		elif event.physical_keycode == KEY_ESCAPE:
			_back()
		elif event.physical_keycode == KEY_U and state == "title":
			check_updates()
		elif event.physical_keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if what == NOTIFICATION_WM_CLOSE_REQUEST:
			get_tree().quit()
		else:
			_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play":
		_pause(true)


## Esc / the phone's back button: pause a game, step back in the menus, quit from the title.
func _back() -> void:
	match state:
		"play": _pause(true)
		"paused": _quit_to_title()
		"options":
			audio.play("menu")
			title_screen()
		"title": get_tree().quit()
		"message": _quit_to_title()


func _pause(on: bool) -> void:
	state = "paused" if on else "play"
	audio.pause_music(on)


func _quit_to_title() -> void:
	audio.pause_music(false)
	confetti = false
	title_screen()


# ================================================================ main loop
func _physics_process(_delta: float) -> void:
	ox = int((get_viewport_rect().size.x - W) / 2)
	frame_count = (frame_count + 1) & 0xFFFF
	_read_pads()
	var start: bool = ((pad_new[0] | pad_new[1]) & K_START) != 0
	match state:
		"title": _title_frame()
		"options": _options_frame()
		"play":
			if start:
				_pause(true)
			else:
				var r := play_frame()
				if r != R_NONE:
					if nplayers == 1:
						_solo_result(r)
					else:
						_versus_result(r)
		"paused":
			if start:
				_pause(false)
		"message":
			if confetti:
				_confetti_frame()
			if msg_frames > 0:
				msg_frames -= 1
				if msg_frames == 0:
					_end_message()
			elif start:
				_end_message()
	queue_redraw()


# ================================================================ arena
func cell_type(ci: int) -> int: return cell[ci] & 3
func item(ci: int) -> int: return (cell[ci] >> 2) & 3
func is_life(ci: int) -> bool: return item(ci) == IT_SHOE and (cell[ci] & TUFT) != 0
func is_pen(ci: int) -> bool: return item(ci) == IT_BOMB and (cell[ci] & PEN) != 0
func is_rem(ci: int) -> bool: return item(ci) == IT_FIRE and (cell[ci] & PEN) != 0
func set_item(ci: int, v: int) -> void: cell[ci] = (cell[ci] & ~(0x0C | PEN)) | (v << 2)
func has_bomb(ci: int) -> bool: return (cell[ci] & HAS_BOMB) != 0
func hot(ci: int) -> bool: return flame[ci] != 0 and (cell[ci] & RUBBLE) == 0
func is_block(ci: int) -> bool: return cell_type(ci) != FLOOR
func walkable(ci: int) -> bool: return cell_type(ci) == FLOOR and not has_bomb(ci)


func is_safe(cx: int, cy: int) -> bool:
	var x := cx if cx < GW / 2 else GW - 1 - cx
	var y := cy if cy < GH / 2 else GH - 1 - cy
	return (x == 1 and y <= 3) or (y == 1 and x <= 3)


func hide_items(it: int, n: int) -> void:
	var tries := 1000
	while n > 0 and tries > 0:
		tries -= 1
		var ci := rand8()
		if ci >= CELLS or cell_type(ci) != STONE or item(ci) != 0:
			continue
		set_item(ci, it & 3)
		if it & 0x20:
			cell[ci] |= TUFT
		cell[ci] |= it & PEN
		n -= 1


func build_map() -> void:
	map_serial += 1
	for k in CELLS:
		var cx := k & 15
		var cy := k >> 4
		flame[k] = 0
		bfire[k] = 0
		if cx == 0 or cy == 0 or cx == GW - 1 or cy == GH - 1 or ((cx & 1) == 0 and (cy & 1) == 0 and cx < GW - 2 and cy < GH - 2):
			cell[k] = CEMENT
		elif not is_safe(cx, cy) and rand8() < (90 if boss else 154):
			cell[k] = STONE
		else:
			cell[k] = FLOOR
	for k in MAX_BOMBS:
		b_used[k] = 0
	if nplayers == 1:
		hide_items(IT_SHOE | 0x20, POOL_LIFE)
	hide_items(IT_BOMB | PEN, POOL_PEN)
	hide_items(IT_FIRE | PEN, POOL_REM)
	hide_items(IT_BOMB, opt_items)
	hide_items(IT_FIRE, opt_items)
	hide_items(IT_SHOE, opt_items)


# ================================================================ bombs and flames
func bomb_at(ci: int) -> int:
	for b in MAX_BOMBS:
		if b_used[b] and b_cell[b] == ci:
			return b
	return 0


func add_flame(ci: int) -> void:
	if boss and fowner == 1:
		if not flame[ci]:
			bfire[ci] = 1
	else:
		bfire[ci] = 0
	if not flame[ci]:
		set_item(ci, 0)
	flame[ci] = FLAME_TIME


func blast_line(start: int, rng: int, d: int) -> void:
	var ci := start
	for n in rng:
		ci += DSTEP[d]
		if cell_type(ci) == CEMENT:
			return
		if cell_type(ci) == STONE:
			var t := cell[ci] & (TUFT | PEN | 0x0C)
			cell[ci] = FLOOR
			add_flame(ci)
			cell[ci] |= t | RUBBLE
			if bpen:
				continue                # a penetrator blasts on through the stone
			return
		if (cell[ci] & RUBBLE) and flame[ci] and not bpen:
			add_flame(ci)               # burning rubble stops it too
			return
		add_flame(ci)
		if has_bomb(ci):
			b_fuse[bomb_at(ci)] = 1


func explode(b: int) -> void:
	var ci := b_cell[b]
	var o := b_owner[b]
	if not b_used[b]:
		return
	b_used[b] = 0
	cell[ci] &= ~HAS_BOMB
	if pactive[o]:
		pactive[o] -= 1
	fowner = o
	bpen = b_pen[b] != 0
	audio.play("boom")
	add_flame(ci)
	for d in 4:
		blast_line(ci, b_range[b], d)


func place_bomb() -> void:
	var ci := pcy[pl] * GW + pcx[pl]
	if not palive[pl] or pactive[pl] >= pbombs[pl] or has_bomb(ci):
		return
	var k := 0
	while k < MAX_BOMBS and b_used[k]:
		k += 1
	if k == MAX_BOMBS:
		return
	b_used[k] = 1; b_cell[k] = ci; b_fuse[k] = FUSE; b_range[k] = pfire[pl]; b_owner[k] = pl
	b_pen[k] = ppen[pl]; b_rem[k] = prem[pl]
	cell[ci] |= HAS_BOMB
	pactive[pl] += 1
	audio.play("place")


## The remote: player p's bombs go off on the next fuse tick.
func set_off(p: int) -> void:
	for k in MAX_BOMBS:
		if b_used[k] and b_owner[k] == p and b_rem[k]:
			b_fuse[k] = 1


func update_bombs() -> void:
	if (frame_count & 3) == 0:
		flame_phase ^= 1
	for k in MAX_BOMBS:
		if b_used[k] and (not b_rem[k] or b_fuse[k] == 1):
			b_fuse[k] -= 1
			if b_fuse[k] == 0:
				explode(k)
	for c in CELLS:
		if flame[c]:
			flame[c] -= 1
			if flame[c] == 0:
				cell[c] &= ~RUBBLE


# ================================================================ players
func can_go(d: int) -> bool:
	var nx: int = pcx[pl] + DX[d]
	var ny: int = pcy[pl] + DY[d]
	return walkable(pcy[pl] * GW + pcx[pl] + DSTEP[d]) \
		or (debug and nplayers == 1 and nx >= 1 and nx <= GW - 2 and ny >= 1 and ny <= GH - 2)


func want_dir() -> int:
	var p: int = pad[pl]
	if pbuft[pl] and can_go(pbuf[pl]):
		return pbuf[pl]
	for d in 4:
		if (p & DBTN[d]) and d != pdir[pl] and can_go(d):
			return d
	for d in 4:
		if p & DBTN[d]:
			return d
	return -1


func try_step(d: int) -> void:
	if d < 0:
		pframe[pl] = 0; panim[pl] = 0
		return
	pdir[pl] = d
	if can_go(d):
		pmoving[pl] = 1; pdx[pl] = DX[d]; pdy[pl] = DY[d]; pleft[pl] = 16
		if d == pbuf[pl]:
			pbuft[pl] = 0


## While moving: turn back at once, or turn late (up to 5 pixels) into a side way just passed.
func steer() -> void:
	var d := pbuf[pl]
	if not pbuft[pl] or d == pdir[pl]:
		return
	if DX[d] == -pdx[pl] and DY[d] == -pdy[pl]:
		pcx[pl] += pdx[pl]; pcy[pl] += pdy[pl]
		pdx[pl] = DX[d]; pdy[pl] = DY[d]; pleft[pl] = 16 - pleft[pl]
		pdir[pl] = d; pbuft[pl] = 0
	elif pleft[pl] >= 11 and can_go(d):
		px[pl] = pcx[pl] << 4; py[pl] = pcy[pl] << 4
		pdx[pl] = DX[d]; pdy[pl] = DY[d]; pleft[pl] = 16
		pdir[pl] = d; pbuft[pl] = 0


func collect() -> void:
	var ci := pcy[pl] * GW + pcx[pl]
	var t := item(ci)
	if not t or (pl and boss):
		return
	if is_life(ci):
		if lives < 99:
			lives += 1
		set_item(ci, 0)
		cell[ci] &= ~TUFT
		audio.play("heart")
		return
	if is_pen(ci): ppen[pl] = 1
	elif is_rem(ci): prem[pl] = 1
	elif t == IT_SHOE and pups[pl] < MAX_SPEEDUPS:
		pups[pl] += 1; pspeed[pl] += 4
	elif t == IT_FIRE and pfire[pl] < 99: pfire[pl] += 1
	elif t == IT_BOMB and pbombs[pl] < 99: pbombs[pl] += 1
	set_item(ci, 0)
	audio.play("pickup")


func update_player() -> void:
	if not palive[pl]:
		if pdeath[pl]:
			pdeath[pl] -= 1
		return
	var n: int = pad_new[pl]
	if prem[pl] and (n & K_REMOTE):
		set_off(pl)
	elif n & K_BOMB:
		ppending[pl] = 1
	if pbuft[pl]:
		pbuft[pl] -= 1
	for k in 4:
		if n & DBTN[k]:
			pbuf[pl] = k; pbuft[pl] = 14
	if pmoving[pl]:
		steer()
	if not pmoving[pl]:
		if ppending[pl]:
			place_bomb(); ppending[pl] = 0
		try_step(want_dir())
	if pmoving[pl]:
		_advance(pl)
		panim[pl] += 1
		if panim[pl] >= 8:
			panim[pl] = 0; pframe[pl] = (pframe[pl] + 1) & 3
		if pleft[pl] == 0:
			pmoving[pl] = 0; pcx[pl] = px[pl] >> 4; pcy[pl] = py[pl] >> 4
			collect()
			if ppending[pl]:
				place_bomb(); ppending[pl] = 0
			try_step(want_dir())


## Move a step of pspeed/16 pixels (the fraction carries over), never past the cell.
func _advance(p: int) -> void:
	pfrac[p] += pspeed[p]
	var s := mini(pfrac[p] >> 4, pleft[p])
	pfrac[p] &= 15
	px[p] += pdx[p] * s; py[p] += pdy[p] * s; pleft[p] -= s


func kill_player(p: int) -> void:
	if debug and nplayers == 1:
		return                          # debug mode: immortal
	palive[p] = 0; pdeath[p] = 60; ppen[p] = 0
	audio.play("die")
	if prem[p]:                         # the remote is lost: its bombs tick again
		prem[p] = 0
		for k in MAX_BOMBS:
			if b_used[k] and b_owner[k] == p and b_rem[k]:
				b_rem[k] = 0


# ================================================================ the boss
func bi() -> int:
	return FINAL if fin else level


func reaches(b: int, r: int, ci: int) -> bool:
	if b == ci:
		return true
	for d in 4:
		var x := b
		for n in r:
			x += DSTEP[d]
			if cell_type(x) != FLOOR:
				break
			if x == ci:
				return true
	return false


func in_danger(ci: int) -> bool:
	if flame[ci]:
		return true
	if vb_on and reaches(vb_cell, pfire[1], ci):
		return true
	for b in MAX_BOMBS:
		if b_used[b] and reaches(b_cell[b], b_range[b], ci):
			return true
	return false


func boss_safe(ci: int) -> bool:
	return walkable(ci) and not in_danger(ci)


func escape_dir() -> int:
	var ci := pcy[1] * GW + pcx[1]
	for d in 4:
		var x := ci
		for n in 5:
			x += DSTEP[d]
			if not walkable(x) or flame[x]:
				break
			if not in_danger(x):
				return d
			for s in 4:
				if (s >> 1) != (d >> 1) and boss_safe(x + DSTEP[s]):
					return d
	return -1


func boss_think() -> int:
	var ci := pcy[1] * GW + pcx[1]
	var best := -1
	var want := 0
	vb_on = false
	if in_danger(ci):
		return escape_dir()
	var dx := pcx[0] - pcx[1]
	var dy := pcy[0] - pcy[1]
	if absi(dx) > absi(dy):
		want = 0 if dx < 0 else 1
	else:
		want = 2 if dy < 0 else 3
	if not bwait and pactive[1] < pbombs[1] and \
			((palive[0] and reaches(ci, pfire[1], pcy[0] * GW + pcx[0])) or cell_type(ci + DSTEP[want]) == STONE or rand8() < 6):
		vb_cell = ci; vb_on = true
		var d := escape_dir()
		if d >= 0:
			place_bomb(); bwait = BOSS_REST[bi()]
			return d
		vb_on = false
	if boss_safe(ci + DSTEP[want]) and rand8() < 200:
		return want
	for d in 4:
		if boss_safe(ci + DSTEP[d]) and (d != BACK[pdir[1]] or best < 0) and (best < 0 or rand8() < 100):
			best = d
	return best


func update_boss() -> void:
	pl = 1
	if not palive[1]:
		if pdeath[1]:
			pdeath[1] -= 1
		return
	if binv: binv -= 1
	if bwait: bwait -= 1
	if not pmoving[1]:
		var d := boss_think()
		if d < 0:
			pframe[1] = 0
			return
		pdir[1] = d; pdx[1] = DX[d]; pdy[1] = DY[d]; pmoving[1] = 1; pleft[1] = 16
	_advance(1)
	panim[1] += 1
	if panim[1] >= 8:
		panim[1] = 0; pframe[1] = (pframe[1] + 1) & 3
	if pleft[1] == 0:
		pmoving[1] = 0; pcx[1] = px[1] >> 4; pcy[1] = py[1] >> 4


func hit_boss() -> void:
	bhits += 1; binv = 90
	audio.play("bosshit")
	if bhits == BOSS_ANGRY[bi()]:
		pspeed[1] = BOSS_SPEED[bi()] + 5; pbombs[1] = BOSS_BOMBS[bi()] + 1
	if bhits >= BOSS_HP[bi()]:
		palive[1] = 0; pdeath[1] = 60


func boss_angry() -> bool:
	return bhits >= BOSS_ANGRY[bi()]


# ================================================================ monsters
func monster_pick(m: int) -> int:
	var open: Array[int] = []
	var fwd := false
	var ci := mcy[m] * GW + mcx[m]
	for d in 4:
		var nc: int = ci + DSTEP[d]
		if walkable(nc) and not flame[nc]:
			open.append(d)
			if d == mdir[m]:
				fwd = true
	if open.is_empty():
		return -1
	if fwd and rand8() < 180:
		return mdir[m]
	for i in 8:
		var k: int = open[rand8() % open.size()]
		if k != BACK[mdir[m]] or open.size() == 1:
			return k
	return open[0]


func update_monster(m: int) -> void:
	if not malive[m]:
		if mdeath[m]:
			mdeath[m] -= 1
		return
	mbob[m] = (mbob[m] + 1) & 255
	if not mmoving[m]:
		if mwait[m]:
			mwait[m] -= 1
			return
		var d := monster_pick(m)
		if d < 0:
			mwait[m] = 20
			return
		mdir[m] = d; mdx[m] = DX[d]; mdy[m] = DY[d]; mmoving[m] = 1; mleft[m] = 16
	mfrac[m] += mspeed
	var s := mini(mfrac[m] >> 4, mleft[m])
	mfrac[m] &= 15
	mx[m] += mdx[m] * s; my[m] += mdy[m] * s; mleft[m] -= s
	if mleft[m] == 0:
		mmoving[m] = 0; mcx[m] = mx[m] >> 4; mcy[m] = my[m] >> 4
		if rand8() < 26:
			mwait[m] = 10 + (rand8() & 31)


# ================================================================ levels
func reset_player(p: int, cx: int, cy: int, keep: bool) -> void:
	pcx[p] = cx; pcy[p] = cy; px[p] = cx * 16; py[p] = cy * 16
	pmoving[p] = 0; pdir[p] = 3; pframe[p] = 0; panim[p] = 0; pfrac[p] = 0; pbuft[p] = 0
	palive[p] = 1; pdeath[p] = 0; pactive[p] = 0; ppending[p] = 0; pburned[p] = 0
	if not keep:
		pspeed[p] = 16; pups[p] = 0; pfire[p] = 1; pbombs[p] = 1; ppen[p] = 0; prem[p] = 0


func start_level(keep: bool) -> void:
	on_title_backdrop = false
	build_map()
	reset_player(0, 1, 1, keep)
	palive[1] = 0; pdeath[1] = 0; py[1] = 0
	if nplayers == 2:
		reset_player(1, GW - 2, GH - 2, false)
	if boss:
		reset_player(1, GW - 2, GH - 2, false)
		pfire[1] = BOSS_FIRE_R[bi()]; pbombs[1] = BOSS_BOMBS[bi()]; pspeed[1] = BOSS_SPEED[bi()]
		bhits = 0; binv = 0; bwait = 90
	mspeed = MONSTER_SPEED[level]
	for m in NMON:
		mcx[m] = 1 if (nplayers == 2 and m == 0) else GW - 2
		mcy[m] = 1 if m else GH - 2
		mx[m] = mcx[m] * 16; my[m] = mcy[m] * 16
		mmoving[m] = 0; mdir[m] = 0; mfrac[m] = 0; mdeath[m] = 0; mwait[m] = 30; mbob[m] = 0
		malive[m] = 1 if ((nplayers == 1 and not boss) or (nplayers == 2 and opt_monsters)) else 0
	secs = ROUND_SECS; subsec = 60; time_up = false
	sprites_on = true
	audio.play_music("boss" if boss else LEVEL_SONG[level])


## One frame of play (play_level's loop body). Returns how the round ended, or R_NONE.
func play_frame() -> int:
	for p in nplayers:
		pl = p
		update_player()
	if boss:
		update_boss()
	for m in NMON:
		update_monster(m)
	update_bombs()

	for p in nplayers:
		if palive[p] and hot(((py[p] + 8) >> 4) * GW + ((px[p] + 8) >> 4)):
			pburned[p] = 1
			kill_player(p)
	var kx := ((py[1] + 8) >> 4) * GW + ((px[1] + 8) >> 4)
	if boss and palive[1] and not binv and hot(kx) and not bfire[kx]:
		hit_boss()                       # its own fire can't hurt it
	for m in NMON:
		if not malive[m]:
			continue
		if hot(((my[m] + 8) >> 4) * GW + ((mx[m] + 8) >> 4)):
			malive[m] = 0; mdeath[m] = 40
			audio.play("pickup")
			continue
		for p in nplayers:
			if palive[p] and absi(px[p] - mx[m]) < 11 and absi(py[p] - my[m]) < 11:
				kill_player(p)
	if test_clear and nplayers == 1 and not boss and secs == ROUND_SECS - 2:
		malive[0] = 0; malive[1] = 0
	if (palive[0] or palive[1]) and secs:
		subsec -= 1
		if subsec == 0:
			subsec = 60
			secs -= 1
			if secs == 0:
				time_up = true
				for p in nplayers:
					if palive[p]:
						kill_player(p)
			if secs == STRESS_SECS:
				audio.hurry(true)       # hurry up
			if secs <= STRESS_SECS and secs:
				audio.play("tick")

	if nplayers == 1:
		if not palive[0] and pdeath[0] == 0:
			return R_DIED
		if palive[0] and not malive[0] and not malive[1] and not mdeath[0] and not mdeath[1] and not palive[1] and not pdeath[1]:
			return R_CLEARED
	elif not pdeath[0] and not pdeath[1] and palive[0] + palive[1] <= 1:
		return R_P1 if palive[0] else (R_P2 if palive[1] else R_DRAW)
	return R_NONE


func death_reason() -> String:
	return "TIME UP" if time_up else ("CAUGHT IN THE BLAST" if pburned[0] else MON_GOT[level])


# ================================================================ messages
## A box over the arena with up to three lines; waits `frames`, or for START when 0.
func message(lines: Array, frames: int, then: Callable) -> void:
	msg_lines = lines
	msg_frames = frames
	msg_then = then
	state = "message"
	if confetti:
		for k in 32:
			cf_x[k] = randi() % int(W)
			cf_y[k] = -(randi() % int(H))
	_swallow_pads()


func _end_message() -> void:
	confetti = false
	msg_lines = []
	msg_then.call()


func _confetti_frame() -> void:
	for k in 32:
		cf_y[k] += 3 + 2 * (k & 1)
		cf_x[k] += 1 if (k & 2) else -1
		if cf_y[k] > H:
			cf_y[k] = -20


func _go_play() -> void:
	state = "play"
	_swallow_pads()


func hide_sprites() -> void:
	sprites_on = false


# ================================================================ 1 player and boss rush
func solo_game() -> void:
	level = 0; boss = rush; fin = false
	lives = WIN_CHOICES[opt_lives]
	start_level(false)
	if rush:
		message(["BOSS RUSH", BOSS_NAME[0], BOSS_TAKES[0]], 100, _go_play)
	else:
		message(["LEVEL 1", LEVEL_NAME[0], "GET READY!"], 100, _go_play)


func _solo_result(r: int) -> void:
	hide_sprites()
	audio.hurry(false)
	if r == R_CLEARED:
		if boss and fin:
			confetti = true
			audio.jingle("victory")
			message(["CONGRATULATIONS!", "YOU BEAT ALL 7 BOSSES", "YOU WIN!  PRESS START"], 0, _quit_to_title)
			return
		audio.jingle("clear")
		var lines: Array
		if not boss:
			lines = ["LEVEL CLEARED", "NEXT UP", BOSS_NAME[level]]
			boss = true
		elif level == LEVELS - 1:          # after the shark: the green bomber, back in the Yard
			lines = ["BOSS DEFEATED", "THE FINAL BOSS", BOSS_NAME[FINAL]]
			fin = true; level = 0
		else:
			lines = ["BOSS DEFEATED", "NEXT BOSS" if rush else "NEXT UP", BOSS_NAME[level + 1] if rush else LEVEL_NAME[level + 1]]
			boss = rush
			level += 1
		message(lines, 150, func():
			start_level(true)
			message([BOSS_NAME[bi()] if boss else "LEVEL %d" % (level + 1),
				BOSS_TAKES[bi()] if boss else LEVEL_NAME[level], "GET READY!"], 90, _go_play))
	else:
		if lives:
			lives -= 1
		if not lives:
			audio.jingle("gameover")
			message([death_reason(), "GAME OVER", "PRESS START"], 0, _quit_to_title)
			return
		audio.stop_music()
		message([death_reason(), "TRY AGAIN", "%d %s LEFT" % [lives, "LIFE" if lives == 1 else "LIVES"]], 120, func():
			start_level(true)
			_go_play())


# ================================================================ 2 players
func versus_game() -> void:
	level = opt_level; boss = false
	wins[0] = 0; wins[1] = 0
	start_level(false)
	message([LEVEL_NAME[level], MON_WATCH[level] if opt_monsters else "BLAST YOUR FRIEND!", "GET READY!"], 100, _go_play)


func _score() -> String:
	return "SCORE %d-%d" % [wins[0], wins[1]]


func _versus_result(r: int) -> void:
	hide_sprites()
	audio.hurry(false)
	if r == R_DRAW:
		audio.stop_music()
		message(["TIME UP" if time_up else "DRAW", "NOBODY SCORES", _score()], 120, func():
			start_level(false)
			_go_play())
		return
	var w := r - R_P1
	wins[w] += 1
	if wins[w] >= win_target:
		confetti = true
		audio.jingle("victory")
		message(["PLAYER %d WINS THE MATCH!" % (w + 1), _score(), "PRESS START"], 0, _quit_to_title)
		return
	audio.jingle("clear")
	message(["PLAYER %d WINS THE ROUND" % (w + 1), _score()], 150, func():
		start_level(false)
		_go_play())


# ================================================================ title and options
func title_screen() -> void:
	state = "title"
	boss = false; level = 0; fin = false
	var n := nplayers
	nplayers = 2                     # a fresh arena behind the menu (no heart)
	build_map()
	nplayers = n
	on_title_backdrop = true
	sprites_on = false
	title_walk = 0
	title_kx = -16
	audio.hurry(false)
	audio.play_music("title")
	_swallow_pads()


func _title_frame() -> void:
	title_walk += 1
	title_kx += 1
	if title_kx > 330:
		title_kx = -48
	var n: int = pad_new[0]
	if n & K_START:
		audio.play("select")
		options_screen()
		return
	if n & (K_UP | K_DOWN):
		var t := 2 if rush else nplayers - 1
		t = ((0 if t == 2 else t + 1) if (n & K_DOWN) else (t - 1 if t else 2))
		_set_title_choice(t)
		audio.play("menu")
	if n & K_C:
		debug = not debug
		audio.play("menu")


## The title screen's "Check for updates" button (U on a keyboard).
func check_updates() -> void:
	if UpdateChecker.busy:
		return
	audio.play("menu")
	UpdateChecker.check(true, true)


func update_rect() -> Rect2:
	return Rect2(ox + W - 330, 628, 300, 46)


func _set_title_choice(t: int) -> void:
	rush = t == 2
	nplayers = 2 if t == 1 else 1


func options_screen() -> void:
	state = "options"
	opt_row = 0
	if nplayers == 2 and opt_char[0] == opt_char[1]:
		next_char(1, 1)
	_swallow_pads()


func options_rows() -> int:
	return 4 if nplayers == 1 else 6


func next_items(step: int) -> void:
	opt_items = (1 if opt_items == 7 else opt_items + 1) if step == 1 else (7 if opt_items == 1 else opt_items - 1)


func next_char(p: int, step: int) -> void:
	opt_char[p] = (opt_char[p] + step) & 3
	while nplayers == 2 and opt_char[p] == opt_char[p ^ 1]:
		opt_char[p] = (opt_char[p] + step) & 3


func _options_frame() -> void:
	var n: int = pad_new[0]
	var rows := options_rows()
	if n & K_START:
		win_target = WIN_CHOICES[opt_wins]
		audio.play("select")
		_save_options()
		if nplayers == 1:
			solo_game()
		else:
			versus_game()
		return
	if n & K_B:
		audio.play("menu")
		title_screen()
		return
	if n & K_UP:
		opt_row = opt_row - 1 if opt_row else rows - 1
	elif n & K_DOWN:
		opt_row = 0 if opt_row == rows - 1 else opt_row + 1
	elif n & (K_LEFT | K_RIGHT | K_A | K_C):
		change_option(opt_row, 2 if (n & K_LEFT) else 1)
	else:
		return
	audio.play("menu")


## step 1 forward, 2 back (as the MD's options screen).
func change_option(row: int, t: int) -> void:
	if nplayers == 1:
		match row:
			0: opt_lives = (opt_lives + t) % 3
			1: next_items(t)
			2: next_char(0, 3 if t == 2 else 1)
			_: debug = not debug
	else:
		match row:
			0: opt_level = (opt_level + (LEVELS - 1 if t == 2 else 1)) % LEVELS
			1: opt_monsters = not opt_monsters
			2: opt_wins = (opt_wins + t) % 3
			3: next_items(t)
			_: next_char(row - 4, 3 if t == 2 else 1)


# ================================================================ drawing (the 2D layer over the 3D view)
func _draw() -> void:
	draw_set_transform(Vector2(ox, 0))
	match state:
		"title": _draw_title()
		"options": _draw_options()
		_:
			_draw_hud()
			if state == "paused":
				_card_text(Rect2(440, 270, 400, 170), "PAUSED", ["Press Start to keep playing", "Esc / Back: quit to the title"])
			if not msg_lines.is_empty():
				var rest: Array = msg_lines.slice(1)
				_card_text(Rect2(300, 240, 680, 230), msg_lines[0], rest)
			if confetti:
				for k in 32:
					var c: Color = CONFETTI[k % 6]
					var a := frame_count * 0.1 + k
					draw_set_transform(Vector2(ox + cf_x[k], cf_y[k]), a)
					draw_rect(Rect2(-6, -3, 12, 6), c)
				draw_set_transform(Vector2(ox, 0))
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- building blocks
var _sb_cache := {}
func card(r: Rect2, bg := C_CARD, edge := C_EDGE, radius := 18, shadow := true) -> void:
	var key := "%s%s%d%s" % [bg, edge, radius, shadow]
	if not _sb_cache.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = edge
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		if shadow:
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_size = 14
			sb.shadow_offset = Vector2(0, 6)
		_sb_cache[key] = sb
	_sb_cache[key].draw(get_canvas_item(), r)


func label(s: String, pos: Vector2, size: int, c := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT, f: Font = null, width := -1.0) -> void:
	f = f if f else font_bold
	var w := width if width > 0 else 1000.0
	var x := pos.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	draw_string_outline(f, Vector2(x, pos.y), s, align, w, size, maxi(2, size / 7), Color(0, 0, 0, 0.55 * c.a))
	draw_string(f, Vector2(x, pos.y), s, align, w, size, c)


func _card_text(r: Rect2, title: String, lines: Array) -> void:
	card(r)
	label(title, Vector2(r.get_center().x, r.position.y + 72), 44, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, font_black, r.size.x)
	for i in lines.size():
		label(str(lines[i]), Vector2(r.get_center().x, r.position.y + 124 + i * 38), 26,
			Color.WHITE if i == 0 else C_DIM, HORIZONTAL_ALIGNMENT_CENTER, font_bold, r.size.x)


## Small vector icons for the panels: bomb, fire, shoe, life, pen, rem, foe, boss.
func icon(kind: String, c: Vector2, s: float) -> void:
	match kind:
		"bomb", "pen", "rem":
			draw_circle(c + Vector2(0, 2), s * 0.42, Color("#0d0f18"))
			draw_circle(c + Vector2(0, 2), s * 0.38, Color("#2a3048"))
			draw_circle(c + Vector2(-s * 0.13, -s * 0.08), s * 0.1, Color(1, 1, 1, 0.55))
			draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.44), Vector2(s * 0.2, s * 0.1)), Color("#5a6488"))
			if kind == "bomb":
				draw_line(c + Vector2(0, -s * 0.44), c + Vector2(s * 0.22, -s * 0.6), Color("#c08a50"), 3.0)
				draw_circle(c + Vector2(s * 0.25, -s * 0.62), s * 0.1, Color("#ffd040"))
			elif kind == "pen":
				draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(s * 0.45, s * 0.05), Color("#ff3a2a"), 4.0)
				draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.6, s * 0.05), c + Vector2(s * 0.38, -s * 0.12), c + Vector2(s * 0.38, s * 0.22)]), Color("#ffd02a"))
			else:
				draw_line(c + Vector2(0, -s * 0.44), c + Vector2(0, -s * 0.7), Color("#c0c4d0"), 2.0)
				draw_circle(c + Vector2(0, -s * 0.72), s * 0.07, Color("#ff3a2a"))
				for k in 2:
					draw_arc(c + Vector2(0, -s * 0.72), s * (0.2 + k * 0.14), -2.4, -0.7, 8, Color("#5ad8ff"), 2.0)
		"fire":
			var pts := PackedVector2Array()
			for k in 20:
				var a := k / 20.0 * TAU
				var r := s * 0.38
				var p := Vector2(sin(a) * r, -cos(a) * r)
				if p.y < 0:
					p.x *= 1.0 + p.y / (s * 0.5)
					p.y *= 1.7
				pts.append(c + p + Vector2(0, s * 0.12))
			draw_colored_polygon(pts, Color("#ff6a1a"))
			draw_circle(c + Vector2(0, s * 0.2), s * 0.18, Color("#ffd040"))
		"shoe":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.3), c + Vector2(-s * 0.1, -s * 0.3), c + Vector2(0, -s * 0.05),
				c + Vector2(s * 0.45, s * 0.05), c + Vector2(s * 0.45, s * 0.22), c + Vector2(-s * 0.4, s * 0.22)]), Color("#e8323a"))
			draw_rect(Rect2(c + Vector2(-s * 0.42, s * 0.22), Vector2(s * 0.9, s * 0.1)), Color.WHITE)
			for k in 3:
				draw_line(c + Vector2(-s * 0.7, -s * 0.15 + k * s * 0.15), c + Vector2(-s * 0.5, -s * 0.15 + k * s * 0.15), Color(1, 1, 1, 0.7), 2.0)
		"life":
			var pts := PackedVector2Array()
			for k in 32:
				var tt := k / 32.0 * TAU
				pts.append(c + Vector2(16 * pow(sin(tt), 3), -(13 * cos(tt) - 5 * cos(2 * tt) - 2 * cos(3 * tt) - cos(4 * tt))) * s * 0.026)
			draw_colored_polygon(pts, Color("#ff2d55"))
			draw_circle(c + Vector2(-s * 0.16, -s * 0.12), s * 0.07, Color(1, 1, 1, 0.6))


func stat_row(y: float, x: float, kind: String, value: String, note := "") -> void:
	icon(kind, Vector2(x + 26, y - 10), 34)
	label(value, Vector2(x + 58, y), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, font_black)
	if note != "":
		label(note, Vector2(x + 110, y - 2), 18, C_GOLD)


# ---------------------------------------------------------------- the game's HUD
func _draw_hud() -> void:
	# top bar: the level on the left, the clock on the right
	var title := ""
	if nplayers == 1:
		title = ("BOSS FIGHT  ·  " + BOSS_NAME[bi()]) if boss else ("LEVEL %d  ·  %s" % [level + 1, LEVEL_NAME[level]])
	else:
		title = "%s  ·  FIRST TO %d" % [LEVEL_NAME[level], win_target]
	card(Rect2(20, 14, 600, 52), C_CARD, C_EDGE, 26, false)
	label(title, Vector2(44, 50), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, font_black)
	if debug and nplayers == 1:
		card(Rect2(636, 14, 120, 52), Color(0.5, 0.1, 0.4, 0.8), C_EDGE, 26, false)
		label("DEBUG", Vector2(696, 50), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, font_black, 120)
	var hurry := secs <= STRESS_SECS
	var blink := secs <= 10 and (frame_count & 16)
	card(Rect2(1110, 14, 150, 52), Color(0.6, 0.08, 0.06, 0.85) if hurry else C_CARD, C_EDGE, 26, false)
	if not blink:
		label("%d:%02d" % [secs / 60, secs % 60], Vector2(1185, 52), 34, C_GOLD if hurry else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, font_black, 150)
	# left: player 1
	_player_card(0, Rect2(20, 86, 210, 370 if nplayers == 1 else 400))
	if nplayers == 2:
		_player_card(1, Rect2(1050, 86, 210, 400))
	elif boss:
		var r := Rect2(1050, 86, 210, 230)
		card(r)
		label("BOSS", Vector2(r.position.x + 22, r.position.y + 42), 22, C_DIM)
		label(BOSS_NAME[bi()].trim_prefix("THE "), Vector2(r.position.x + 22, r.position.y + 82), 26, Color("#ff6a5a") if boss_angry() else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, font_black, 180)
		var hp: int = BOSS_HP[bi()] - bhits
		label("HITS LEFT", Vector2(r.position.x + 22, r.position.y + 128), 18, C_DIM)
		for k in BOSS_HP[bi()]:
			var pr := Rect2(r.position.x + 22 + (k % 4) * 42, r.position.y + 144 + (k / 4) * 36, 34, 26)
			card(pr, Color("#ff3b30") if k < hp else Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.25), 8, false)
	else:
		var r := Rect2(1050, 86, 210, 200)
		card(r)
		label("FOES", Vector2(r.position.x + 22, r.position.y + 42), 22, C_DIM)
		label(MON_NAMES[level], Vector2(r.position.x + 22, r.position.y + 80), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, font_black)
		label(str(malive[0] + malive[1]), Vector2(r.position.x + 22, r.position.y + 158), 64, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, font_black)
		label("LEFT", Vector2(r.position.x + 90, r.position.y + 154), 22, C_DIM)


func _player_card(p: int, r: Rect2) -> void:
	card(r)
	var x := r.position.x + 14
	draw_circle(Vector2(x + 16, r.position.y + 34), 11, SUIT_COL[opt_char[p]])
	draw_arc(Vector2(x + 16, r.position.y + 34), 11, 0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
	label(CHAR_NAME[opt_char[p]].strip_edges(), Vector2(x + 36, r.position.y + 44), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, font_black)
	var y := r.position.y + 104
	stat_row(y, x, "pen" if ppen[p] else "bomb", str(pbombs[p]), "PEN" if ppen[p] else "")
	stat_row(y + 60, x, "fire", str(pfire[p]))
	stat_row(y + 120, x, "shoe", "%d/%d" % [pups[p], MAX_SPEEDUPS])
	if prem[p]:
		stat_row(y + 180, x, "rem", "REMOTE")
	if nplayers == 1:
		stat_row(y + 240, x, "life", str(lives))
	else:
		label("WINS", Vector2(x + 8, r.end.y - 52), 20, C_DIM)
		label("%d / %d" % [wins[p], win_target], Vector2(x + 8, r.end.y - 16), 32, C_GOLD, HORIZONTAL_ALIGNMENT_LEFT, font_black)


# ---------------------------------------------------------------- title and options
func title_item_rect(i: int) -> Rect2:
	return Rect2(ox + 470, 300 + i * 74, 340, 60)


func _draw_title() -> void:
	var c := Vector2(W / 2, 180)
	for k in 3:          # a deep drop shadow, then the logo with an outline
		label("BOMB YARD", c + Vector2(0, 14 - k * 4), 130, Color(0.25, 0.02, 0.0, 0.5), HORIZONTAL_ALIGNMENT_CENTER, font_black, 1100)
	draw_string_outline(font_black, c + Vector2(-550, 0), "BOMB YARD", HORIZONTAL_ALIGNMENT_CENTER, 1100, 130, 18, Color("#5a0a04"))
	draw_string(font_black, c + Vector2(-550, 0), "BOMB YARD", HORIZONTAL_ALIGNMENT_CENTER, 1100, 130, Color("#ffb21a"))
	label("6 levels  ·  7 bosses  ·  2 players", Vector2(W / 2, 236), 22, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, font_bold, 800)
	var names := ["1 PLAYER", "2 PLAYERS", "BOSS RUSH"]
	var sel := 2 if rush else nplayers - 1
	for i in 3:
		var r := title_item_rect(i)
		r.position.x -= ox
		card(r, Color(1.0, 0.72, 0.1, 0.92) if i == sel else C_CARD, Color(1, 1, 1, 0.5) if i == sel else C_EDGE, 30)
		label(names[i], Vector2(W / 2, r.position.y + 42), 28, Color("#1a1206") if i == sel else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, font_black, 340)
	var sub := "Beat all seven bosses in a row" if rush else ("Six levels and seven bosses" if nplayers == 1 else "Blast your friend!")
	label(sub, Vector2(W / 2, 548), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, font_bold, 800)
	if (frame_count >> 5) & 1:
		label("TAP A MODE TO START" if touch.enabled else "PRESS ENTER TO START", Vector2(W / 2, 600), 26, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, font_black, 800)
	if debug:
		label("DEBUG ON", Vector2(W / 2, 640), 22, Color("#ff7ad0"), HORIZONTAL_ALIGNMENT_CENTER, font_black, 400)
	var ur := update_rect()
	ur.position.x -= ox
	card(ur, C_CARD, C_EDGE, 23)
	label(UpdateChecker.button_text().to_upper(), Vector2(ur.get_center().x, ur.position.y + 31), 19,
		C_DIM if UpdateChecker.busy else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, font_black, ur.size.x)
	if not touch.enabled:
		label("C: debug mode   ·   M: sound   ·   F11: full screen   ·   U: updates", Vector2(30, 700), 18, Color(1, 1, 1, 0.75))
	label("MGRAHN 2026", Vector2(W - 30, 700), 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)


func option_row_rect(r: int) -> Rect2:
	return Rect2(ox + 360, 200 + r * 58, 560, 50)


func opt_start_rect() -> Rect2:
	return Rect2(ox + 360, 584 if nplayers == 1 else 584, 330, 60)


func opt_back_rect() -> Rect2:
	return Rect2(ox + 710, 584, 210, 60)


func _draw_options() -> void:
	card(Rect2(330, 90, 620, 580))
	label("BOSS RUSH" if rush else ("1 PLAYER" if nplayers == 1 else "2 PLAYERS"), Vector2(W / 2, 160), 44, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, font_black, 600)
	var labels: Array
	var values: Array
	if nplayers == 1:
		labels = ["Lives", "Power-ups", "Player", "Debug"]
		values = [str(WIN_CHOICES[opt_lives]), str(opt_items), CHAR_NAME[opt_char[0]].strip_edges(), "On" if debug else "Off"]
	else:
		labels = ["Level", "Monsters", "Wins needed", "Power-ups", "Player 1", "Player 2"]
		values = [LEVEL_NAME[opt_level], "On" if opt_monsters else "Off", str(WIN_CHOICES[opt_wins]), str(opt_items),
			CHAR_NAME[opt_char[0]].strip_edges(), CHAR_NAME[opt_char[1]].strip_edges()]
	for r in labels.size():
		var rr := option_row_rect(r)
		rr.position.x -= ox
		var on := r == opt_row
		card(rr, Color(1, 1, 1, 0.14) if on else Color(1, 1, 1, 0.04), Color(1, 0.8, 0.3, 0.8) if on else Color(1, 1, 1, 0.08), 14, false)
		label(labels[r], Vector2(rr.position.x + 22, rr.position.y + 34), 24, Color.WHITE if on else C_DIM)
		var vx := rr.end.x - 24
		label(str(values[r]).to_upper(), Vector2(vx - 40, rr.position.y + 35), 26, C_GOLD if on else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, font_black, 300)
		if on:
			label("‹", Vector2(vx - 250, rr.position.y + 34), 30, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, font_black, 30)
			label("›", Vector2(vx - 6, rr.position.y + 34), 30, C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, font_black, 30)
		var char_row := (nplayers == 1 and r == 2) or (nplayers == 2 and r >= 4)
		if char_row:
			var p := 0 if nplayers == 1 else r - 4
			draw_circle(Vector2(rr.end.x - 220, rr.position.y + 25), 12, SUIT_COL[opt_char[p]])
	var sr := opt_start_rect()
	sr.position.x -= ox
	card(sr, Color(1.0, 0.72, 0.1, 0.95), Color(1, 1, 1, 0.5), 30)
	label("START", Vector2(sr.get_center().x, sr.position.y + 42), 30, Color("#1a1206"), HORIZONTAL_ALIGNMENT_CENTER, font_black, sr.size.x)
	var br := opt_back_rect()
	br.position.x -= ox
	card(br, C_CARD, C_EDGE, 30)
	label("BACK", Vector2(br.get_center().x, br.position.y + 42), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, font_black, br.size.x)
	if not touch.enabled:
		label("↑↓ choose   ←→ change   Enter start   Esc back", Vector2(W / 2, 700), 18, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, font_bold, 900)
