extends Node2D
## Sandfall Rescue: match-3 board under a shaft of falling debris.
## Match gems next to debris cells to destroy them; the debris above slides down.
## Clear the debris before moves run out, or the door gives way.

const DrawLayer := preload("res://scripts/draw_layer.gd")
const Ui := preload("res://scripts/ui.gd")
const Rig := preload("res://scripts/rig.gd")
const RigData := preload("res://scripts/rig_data.gd")
const Puppet := preload("res://scripts/puppet.gd")
const HERO_H := 15.0      # hero height in world cells
const HERO_PX := 1126.0   # hero height in rig pixels
const ROOM_H := 24
const SPIKE_W := 6.0
const CHASER_H := {"golem": 20.0, "mummy": 19.0, "cobra": 17.0}

const COLS := 8
const ROWS := 9
const CELL := 7        # debris grid cells per board cell
const BX := 2          # board left edge, in debris cells
const BY := 44         # board top edge, in debris cells
const SW := 60         # world width, in debris cells
const SH := 110        # world height, in debris cells
const NCOL := 4

const LEVELS := [
	{"name": "The Sand Pit", "theme": "sand", "moves": 22, "shaft": [3, 5], "room": "left", "fill_top": 17,
		"rubble": [[3, 5, 0, 3], [4, 4, 4, 6]], "hazard": "spikes", "tip": "The spike wall moves with every move. Drain the sand fast!"},
	{"name": "Iron Vault", "theme": "iron", "moves": 26, "shaft": [3, 4], "room": "right", "fill_top": 12,
		"rubble": [[3, 4, 0, 4], [2, 3, 5, 7]], "hazard": "water", "tip": "The vault is flooding! Rockets and bombs blast through debris."},
	{"name": "Crystal Cave", "theme": "crystal", "moves": 29, "shaft": [5, 6], "room": "left", "fill_top": 15,
		"rubble": [[5, 6, 0, 2], [4, 5, 3, 4], [3, 4, 5, 6], [2, 3, 7, 8]], "hazard": "golem", "tip": "A rock golem is coming! Follow the crystals down."},
	{"name": "Lava Forge", "theme": "emerald", "moves": 28, "shaft": [1, 2], "room": "right", "fill_top": 11,
		"rubble": [[1, 2, 0, 2], [0, 3, 3, 4], [3, 3, 5, 8]], "hazard": "lava", "tip": "Lava is pouring in! Tap a power-up to fire it."},
	{"name": "Mummy's Tomb", "theme": "tomb", "moves": 28, "shaft": [2, 3], "room": "right", "fill_top": 13,
		"rubble": [[2, 3, 0, 3], [3, 5, 4, 5], [5, 6, 6, 8]], "hazard": "mummy", "tip": "The mummy woke up! Drain the tomb before it reaches Zaki."},
	{"name": "Cobra Temple", "theme": "temple", "moves": 30, "shaft": [4, 5], "room": "left", "fill_top": 14,
		"rubble": [[4, 5, 0, 2], [3, 6, 3, 3], [2, 3, 4, 6], [6, 7, 4, 6], [4, 5, 7, 8]], "hazard": "cobra", "tip": "A giant cobra guards the temple. Split the debris both ways!"},
]

const THEMES := {
	"sand": {"room": "sand", "room_tint": Color(1, 1, 1), "floor": 861.0, "grains": "sand", "gtint": Color(1, 1, 1), "glow": 0.0,
		"glow_col": Color(1, 1, 1), "recess": [Color("24150d"), Color("0f0806")], "ui": Color("e1a64a")},
	"iron": {"room": "water", "room_tint": Color(1, 1, 1), "floor": 873.0, "grains": "iron", "gtint": Color(1.05, 1.05, 1.1), "glow": 0.0,
		"glow_col": Color(1, 1, 1), "recess": [Color("151a22"), Color("07090d")], "ui": Color("8b919c")},
	"crystal": {"room": "crystal", "room_tint": Color(1, 1, 1), "floor": 823.0, "grains": "crystal", "gtint": Color(1, 1, 1), "glow": 0.18,
		"glow_col": Color("c48bff"), "recess": [Color("170b25"), Color("07030c")], "ui": Color("a463f2")},
	"emerald": {"room": "lava", "room_tint": Color(1, 1, 1), "floor": 838.0, "grains": "emerald", "gtint": Color(1, 1, 1), "glow": 0.15,
		"glow_col": Color("5df2a8"), "recess": [Color("1d0c08"), Color("080302")], "ui": Color("3fd08a")},
	"tomb": {"room": "sand", "room_tint": Color(0.58, 0.62, 0.86), "floor": 861.0, "grains": "sand", "gtint": Color(0.82, 0.8, 0.78), "glow": 0.0,
		"glow_col": Color(1, 1, 1), "recess": [Color("141220"), Color("06050c")], "ui": Color("5fd6d0")},
	"temple": {"room": "water", "room_tint": Color(0.72, 1.0, 0.78), "floor": 873.0, "grains": "emerald", "gtint": Color(1, 1, 1), "glow": 0.12,
		"glow_col": Color("5df2a8"), "recess": [Color("0a1d18"), Color("030a08")], "ui": Color("2fbf7a")},
}

const GEM_COLORS := [Color("ff5a6e"), Color("3a8dff"), Color("ffc21a"), Color("36d27d")]

class Gem:
	var kind = "gem"     # gem, rocket, bomb, light
	var color := 0
	var dir := "h"
	var x := 0.0
	var y := 0.0
	var ty := 0.0
	var vy := 0.0
	var scale := 1.0
	var sq := 0.0
	var falling := false
	var dying := false

# ---------- textures ----------
var tex := {}
var glow_tex: Texture2D

# ---------- layout ----------
var g := 6.0
var ox := 0.0
var oy := 0.0

# ---------- level state ----------
var level_idx := 0
var L: Dictionary = {}
var theme: Dictionary = {}
var grid: Array = []
var rubble := {}
var sand := PackedByteArray()
var mask := PackedByteArray()
var grains := 0
var grains0 := 1
var moves := 0
var state = "menu"     # menu, idle, busy, paused, won, lost
var shaft := {}
var room := {}
var door_col := 0
var facing := 1
var door_open := false
var extra_used := false
var selected := Vector2i(-1, -1)
var last_swap: Array = []
var last_input := 0.0
var hint: Array = []
var sand_moved := 0
var sand_acc := 0.0
var sand_sleep := false
var sand_dirty := true
var flip := 0
var ax0 := 0
var ax1 = SW
var ay0 := 0
var ay1 = SH - 1
var hero_t := 0.0
var hero_strain := 0.0
var hero_pose := "push"
var shake := 0.0
var sand_sfx_t := 0.0
var time := 0.0

var tweens: Array = []
var parts: Array = []
var fx: Array = []

var progress = {"best": [0, 0, 0, 0, 0, 0]}
const SAVE_PATH := "user://progress.cfg"

# ---------- nodes ----------
var bg_layer: Node2D
var back_layer: Node2D
var hero: Rig
var chasers := {}
var hz_layer: Node2D
var hz_p := 0.0
var hz_target := 0.0
var hero_x := 0.0        # hip x in world cells
var hero_lift := 0.0     # world cells above the floor (jumps, escape)
var hero_alpha := 1.0
var look_t := 0.0
var look_cd := 3.0
var blink_t := 2.0
var chaser_phase := 0.0
var golem_attack := 0.0
var roar_t := 3.0
var ember_t := 0.0
var sand_sprite: Sprite2D
var sand_img: Image
var sand_tex: ImageTexture
var frame_layer: Node2D
var gem_layer: Node2D
var fx_layer: Node2D
var add_layer: Node2D
var ui: Ui

# ---------- audio ----------
var sfx := {}
var players: Array = []

# ---------- autotest (CI screenshots) ----------
var autotest := false
var shots_dir := ""

func _ready() -> void:
	randomize()
	_load_textures()
	_load_audio()
	_load_progress()
	autotest = OS.get_cmdline_user_args().has("--autotest")
	shots_dir = OS.get_environment("SHOTS_DIR")

	bg_layer = _layer(_draw_bg)
	back_layer = _layer(_draw_back)
	for kname in RigData.CHASERS:
		var pp := Puppet.new()
		pp.setup(RigData.CHASERS[kname])
		pp.visible = false
		pp.z_index = 3
		add_child(pp)
		chasers[kname] = pp
	hero = Rig.new()
	hero.setup(RigData.HERO)
	add_child(hero)
	hz_layer = _layer(_draw_hazard)
	sand_sprite = Sprite2D.new()
	sand_sprite.centered = false
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sand.gdshader")
	sand_sprite.material = sm
	sand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sand_sprite)
	frame_layer = _layer(_draw_frame)
	gem_layer = _layer(_draw_gems)
	fx_layer = _layer(_draw_fx)
	add_layer = _layer(_draw_add)
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_layer.material = am
	# explicit draw order (rig parts add their own small z offsets)
	bg_layer.z_index = 0
	back_layer.z_index = 1
	hero.z_index = 10
	hz_layer.z_index = 16
	sand_sprite.z_index = 20
	frame_layer.z_index = 21
	gem_layer.z_index = 22
	fx_layer.z_index = 23
	add_layer.z_index = 24

	ui = Ui.new()
	ui.game = self
	add_child(ui)
	ui.build()

	get_viewport().size_changed.connect(_layout)
	start_level(0)
	state = "paused"
	_layout()
	ui.show_menu()
	if autotest:
		_run_autotest()

func _layer(fn: Callable) -> Node2D:
	var n := DrawLayer.new()
	n.painter = fn
	add_child(n)
	return n

func _load_textures() -> void:
	tex.goldbar = load("res://assets/gfx/goldbar.png")
	for n in ["gem_red", "gem_blue", "gem_gold", "gem_green", "rocket", "bomb", "light", "tile"]:
		tex[n] = load("res://assets/gfx/board/%s.png" % n)
	for n in ["sand", "iron", "crystal", "emerald"]:
		tex["grains_" + n] = load("res://assets/gfx/board/grains_%s.png" % n)
	for n in ["sand", "water", "crystal", "lava"]:
		tex["room_" + n] = load("res://assets/gfx/rooms/room_%s.jpg" % n)
	for n in ["door", "spikewall", "spout_lion", "spout_ram"]:
		tex[n] = load("res://assets/gfx/props/%s.png" % n)
	tex.gems = [tex.gem_red, tex.gem_blue, tex.gem_gold, tex.gem_green]
	var gt := GradientTexture2D.new()
	gt.width = 128
	gt.height = 128
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.35, Color(1, 1, 1, 0.45))
	gt.gradient = gr
	glow_tex = gt

func _load_audio() -> void:
	for n in ["pop0", "pop1", "pop2", "pop3", "pop4", "swap", "bad", "rocket", "boom", "zap",
			"sand", "shine", "click", "win", "lose", "crack"]:
		sfx[n] = load("res://assets/sfx/%s.wav" % n)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not sfx.has(name):
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[name]
			p.pitch_scale = pitch
			p.volume_db = db
			p.play()
			return

func buzz(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

func _load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		var b = cf.get_value("progress", "best", [])
		if b is Array:
			for i in mini(b.size(), progress.best.size()):
				progress.best[i] = int(b[i])

func save_progress() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "best", progress.best)
	cf.save(SAVE_PATH)

# ---------- layout ----------
func _layout() -> void:
	var vs = get_viewport_rect().size
	var safe = _safe_insets()
	var top: float = safe.x + Ui.HUD_H
	var bottom = safe.y + 12.0
	var avail_h: float = vs.y - top - bottom
	var avail_w = vs.x - 20.0
	g = maxf(2.0, minf(avail_w / SW, avail_h / SH))
	ox = (vs.x - SW * g) / 2.0
	oy = top + maxf(0.0, (avail_h - SH * g) / 2.0)
	sand_sprite.position = Vector2(ox, oy)
	sand_sprite.scale = Vector2(g, g)
	ui.layout(vs, safe)
	_place_hero()
	bg_layer.queue_redraw()
	frame_layer.queue_redraw()

func _safe_insets() -> Vector2:
	var vs = get_viewport_rect().size
	var ws = DisplayServer.window_get_size()
	if ws.y <= 0:
		return Vector2.ZERO
	var k = vs.y / float(ws.y)
	var sa = DisplayServer.get_display_safe_area()
	var top = maxf(0.0, sa.position.y * k)
	var bottom = maxf(0.0, (ws.y - sa.end.y) * k)
	if top > vs.y * 0.2 or bottom > vs.y * 0.2:
		return Vector2.ZERO
	return Vector2(top, bottom)

func cell_cx(c: float) -> float:
	return ox + (BX + c * CELL + CELL / 2.0) * g

func cell_cy(r: float) -> float:
	return oy + (BY + r * CELL + CELL / 2.0) * g

func wx(x: float) -> float:
	return ox + x * g

func wy(y: float) -> float:
	return oy + y * g

# ---------- level setup ----------
func start_level(i: int) -> void:
	level_idx = i
	L = LEVELS[i]
	theme = THEMES[L.theme]
	rubble.clear()
	for rect in L.rubble:
		for r in range(rect[2], rect[3] + 1):
			for c in range(rect[0], rect[1] + 1):
				rubble[r * COLS + c] = true
	var c0: int = L.shaft[0]
	var c1: int = L.shaft[1]
	shaft = {"x0": BX + c0 * CELL, "x1": BX + (c1 + 1) * CELL, "y0": 3}
	if L.room == "left":
		door_col = shaft.x0 - 1
		room = {"x0": BX, "x1": door_col, "y0": BY - ROOM_H, "y1": BY}
		facing = 1
	else:
		door_col = shaft.x1
		room = {"x0": door_col + 1, "x1": BX + COLS * CELL, "y0": BY - ROOM_H, "y1": BY}
		facing = -1
	sand = PackedByteArray()
	sand.resize(SW * SH)
	mask = PackedByteArray()
	mask.resize(SW * SH)
	grains = 0
	for y in range(shaft.y0, BY):
		for x in range(shaft.x0, shaft.x1):
			mask[y * SW + x] = 1
			if y >= L.fill_top:
				sand[y * SW + x] = 1 + randi() % 3
				grains += 1
	for id in rubble:
		var c: int = id % COLS
		var r: int = id / COLS
		for y in range(BY + r * CELL, BY + (r + 1) * CELL):
			for x in range(BX + c * CELL, BX + (c + 1) * CELL):
				mask[y * SW + x] = 1
				sand[y * SW + x] = 1 + randi() % 3
				grains += 1
	grains0 = grains
	_compute_active_region()
	moves = L.moves
	door_open = false
	extra_used = false
	selected = Vector2i(-1, -1)
	hint = []
	last_swap = []
	parts.clear()
	fx.clear()
	tweens.clear()
	hero_pose = "push"
	hz_p = 0.0
	hz_target = 0.0
	hero_x = door_col + 0.5 - facing * 4.4
	hero_lift = 0.0
	hero_alpha = 1.0
	golem_attack = 0.0
	look_t = 0.0
	for kname in chasers:
		chasers[kname].visible = kname == L.hazard
	chaser_phase = 0.0
	sand_sleep = false
	sand_dirty = true
	_fill_board()
	var sm: ShaderMaterial = sand_sprite.material
	sm.set_shader_parameter("grain_tex", tex["grains_" + theme.grains])
	sm.set_shader_parameter("tint", theme.gtint)
	sm.set_shader_parameter("glow", theme.glow)
	sm.set_shader_parameter("glow_col", theme.glow_col)
	sm.set_shader_parameter("gsize", 1.65)
	sm.set_shader_parameter("brightness", 1.0)
	_upload_sand()
	_place_hero()
	bg_layer.queue_redraw()
	frame_layer.queue_redraw()
	ui.set_level(i + 1, L.name, theme.ui)
	ui.update_hud(moves, 100)
	ui.hide_overlay()
	state = "idle"
	last_input = time
	ui.toast(L.tip)

func _compute_active_region() -> void:
	var minx = SW
	var maxx := 0
	var miny = SH
	var maxy := 0
	for y in SH:
		for x in SW:
			if mask[y * SW + x] == 1:
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
				miny = mini(miny, y)
				maxy = maxi(maxy, y)
	ax0 = minx
	ax1 = maxx + 1
	ay0 = miny
	ay1 = mini(maxy + 1, SH - 1)

func _fill_board() -> void:
	for _tries in 200:
		grid = []
		for r in ROWS:
			var row = []
			row.resize(COLS)
			grid.append(row)
		for r in ROWS:
			for c in COLS:
				if is_rub(c, r):
					continue
				var k = randi() % NCOL
				var guard := 0
				while guard < 20 and ((color_at(c - 1, r) == k and color_at(c - 2, r) == k) or (color_at(c, r - 1) == k and color_at(c, r - 2) == k)):
					k = randi() % NCOL
					guard += 1
				grid[r][c] = _new_gem(c, r, k)
		if not find_move().is_empty():
			return

func _new_gem(c: int, r: int, color: int) -> Gem:
	var m := Gem.new()
	m.color = color
	m.x = c
	m.y = r
	m.ty = r
	return m

# ---------- board queries ----------
func in_b(c: int, r: int) -> bool:
	return c >= 0 and c < COLS and r >= 0 and r < ROWS

func is_rub(c: int, r: int) -> bool:
	return rubble.has(r * COLS + c)

func color_at(c: int, r: int) -> int:
	if not in_b(c, r) or is_rub(c, r):
		return -1
	var m = grid[r][c]
	if m != null and m.kind == "gem" and not m.dying:
		return m.color
	return -1

func find_clusters() -> Array:
	var runs = []
	for r in ROWS:
		var c := 0
		while c < COLS:
			var k = color_at(c, r)
			if k < 0:
				c += 1
				continue
			var e = c
			while color_at(e + 1, r) == k:
				e += 1
			if e - c >= 2:
				var cells = []
				for x in range(c, e + 1):
					cells.append(r * COLS + x)
				runs.append({"h": true, "cells": cells})
			c = e + 1
	for c in COLS:
		var r := 0
		while r < ROWS:
			var k = color_at(c, r)
			if k < 0:
				r += 1
				continue
			var e = r
			while color_at(c, e + 1) == k:
				e += 1
			if e - r >= 2:
				var cells = []
				for y in range(r, e + 1):
					cells.append(y * COLS + c)
				runs.append({"h": false, "cells": cells})
			r = e + 1
	if runs.is_empty():
		return []
	# union runs sharing cells into clusters
	var owner_of := {}
	var clusters = []
	for run in runs:
		var hit := -1
		for id in run.cells:
			if owner_of.has(id):
				hit = owner_of[id]
				break
		if hit < 0:
			hit = clusters.size()
			clusters.append({"cells": {}, "runs": []})
		var cl: Dictionary = clusters[hit]
		cl.runs.append(run)
		for id in run.cells:
			if owner_of.has(id) and owner_of[id] != hit:
				# merge the other cluster into this one
				var other: Dictionary = clusters[owner_of[id]]
				var oi: int = owner_of[id]
				for oid in other.cells:
					cl.cells[oid] = true
					owner_of[oid] = hit
				cl.runs.append_array(other.runs)
				clusters[oi] = {"cells": {}, "runs": []}
			cl.cells[id] = true
			owner_of[id] = hit
	var out = []
	for cl in clusters:
		if not cl.cells.is_empty():
			out.append(cl)
	return out

# colour at (x, y) as if the gems at sw[0..1] and sw[2..3] were swapped (sw[4], sw[5] = their colours)
func _color_sw(x: int, y: int, sw: Array) -> int:
	if x == sw[0] and y == sw[1]:
		return sw[5]
	if x == sw[2] and y == sw[3]:
		return sw[4]
	return color_at(x, y)

func _line_len(sw: Array, c: int, r: int, dx: int, dy: int) -> int:
	var k = _color_sw(c, r, sw)
	var n := 1
	var s := 1
	while _color_sw(c + dx * s, r + dy * s, sw) == k:
		n += 1
		s += 1
	s = 1
	while _color_sw(c - dx * s, r - dy * s, sw) == k:
		n += 1
		s += 1
	return n

func all_moves() -> Array:
	var out = []
	for r in ROWS:
		for c in COLS:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var c2: int = c + d.x
				var r2: int = r + d.y
				if not in_b(c2, r2):
					continue
				var a = color_at(c, r)
				var b = color_at(c2, r2)
				if a < 0 or b < 0 or a == b:
					continue
				var sw = [c, r, c2, r2, a, b]
				if _line_len(sw, c, r, 1, 0) >= 3 or _line_len(sw, c, r, 0, 1) >= 3 or _line_len(sw, c2, r2, 1, 0) >= 3 or _line_len(sw, c2, r2, 0, 1) >= 3:
					out.append([Vector2i(c, r), Vector2i(c2, r2)])
	return out

func find_move() -> Array:
	var ms = all_moves()
	return ms[0] if not ms.is_empty() else []

func has_special() -> Vector2i:
	for r in ROWS:
		for c in COLS:
			var m = grid[r][c]
			if m != null and m.kind != "gem":
				return Vector2i(c, r)
	return Vector2i(-1, -1)

func most_common_color() -> int:
	var n = [0, 0, 0, 0]
	for r in ROWS:
		for c in COLS:
			var k = color_at(c, r)
			if k >= 0:
				n[k] += 1
	return n.find(n.max())

# ---------- tiny tween system ----------
func tween(o: Object, props: Dictionary, dur: float, easing := "out", delay := 0.0) -> float:
	var from := {}
	for k in props:
		from[k] = o.get(k)
	tweens.append({"o": o, "from": from, "to": props, "t": -delay, "dur": maxf(0.001, dur), "ease": easing})
	return delay + dur

func _ease(e: String, t: float) -> float:
	match e:
		"back":
			var s := 1.7
			var u = t - 1.0
			return u * u * ((s + 1.0) * u + s) + 1.0
		"in":
			return t * t
		"lin":
			return t
	return 1.0 - (1.0 - t) * (1.0 - t)

func wait(t: float) -> void:
	await get_tree().create_timer(maxf(0.0, t)).timeout

func later(t: float, fn: Callable) -> void:
	get_tree().create_timer(maxf(0.0, t)).timeout.connect(fn)

# ---------- effects ----------
func burst(x: float, y: float, col: Color, n := 10, spd := 1.0) -> void:
	for i in n:
		var a = randf() * TAU
		var v = (40.0 + randf() * 160.0) * spd * g / 6.0
		parts.append({"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v - 60.0 * g / 6.0, "life": 0.0,
			"max": 0.5 + randf() * 0.4, "col": col, "size": g * (0.5 + randf() * 0.7), "grav": 500.0 * g / 6.0, "kind": "dot"})

func sparkle(x: float, y: float, n := 4) -> void:
	for i in n:
		var a = randf() * TAU
		var v = (30.0 + randf() * 90.0) * g / 6.0
		parts.append({"x": x, "y": y, "vx": cos(a) * v, "vy": sin(a) * v, "life": 0.0, "max": 0.6,
			"col": Color("fff6c9"), "size": g * 1.1, "grav": 0.0, "kind": "star"})

func _pop_gem(m: Gem, delay := 0.0) -> float:
	m.dying = true
	tween(m, {"scale": 1.25}, 0.07, "out", delay)
	later(delay + 0.07, func():
		var col: Color = GEM_COLORS[m.color] if m.kind == "gem" else Color("ffe27a")
		burst(cell_cx(m.x), cell_cy(m.y), col, 9)
		sparkle(cell_cx(m.x), cell_cy(m.y), 2)
		play("pop%d" % (randi() % 5), 0.9 + randf() * 0.3, -6.0)
		tween(m, {"scale": 0.0}, 0.11)
	)
	later(delay + 0.19, func():
		var r = int(round(m.y))
		var c = int(round(m.x))
		if in_b(c, r) and grid[r][c] == m:
			grid[r][c] = null
	)
	return delay + 0.2

func damage_rubble(id: int) -> void:
	var c: int = id % COLS
	var r: int = id / COLS
	var hit := 0
	for y in range(BY + r * CELL, BY + (r + 1) * CELL):
		for x in range(BX + c * CELL, BX + (c + 1) * CELL):
			var i: int = y * SW + x
			var v = sand[i]
			if v == 0:
				continue
			sand[i] = 0
			grains -= 1
			hit += 1
			if randf() < 0.4:
				var a = -PI / 2.0 + (randf() - 0.5) * 2.2
				var sp = (120.0 + randf() * 260.0) * g / 6.0
				parts.append({"x": wx(x + 0.5), "y": wy(y + 0.5), "vx": cos(a) * sp, "vy": sin(a) * sp, "life": 0.0,
					"max": 0.7 + randf() * 0.4, "col": theme.gtint, "v": v, "size": g * 1.4, "grav": 900.0 * g / 6.0, "kind": "grain"})
	if hit > 0:
		sand_sleep = false
		sand_dirty = true
		sparkle(cell_cx(c), cell_cy(r), 3)
		fx.append({"kind": "ring", "x": cell_cx(c), "y": cell_cy(r), "r0": g, "r1": CELL * g * 0.8, "life": 0.0, "max": 0.35,
			"col": Color("fff2c0")})
	_update_hud()

func _update_hud() -> void:
	if not L.is_empty() and state != "lost" and state != "won":
		hz_target = clampf(1.0 - float(moves) / float(L.moves), 0.0, 1.0)
	var p := 0
	if grains0 > 0:
		p = maxi(0, ceili(grains * 100.0 / grains0))
	ui.update_hud(moves, p)

# ---------- gravity / refill ----------
func collapse() -> void:
	for c in COLS:
		var r = ROWS - 1
		while r >= 0:
			if is_rub(c, r):
				r -= 1
				continue
			var bottom = r
			while r >= 0 and not is_rub(c, r):
				r -= 1
			var top = r + 1
			var w = bottom
			for y in range(bottom, top - 1, -1):
				var m = grid[y][c]
				if m != null:
					if y != w:
						grid[w][c] = m
						grid[y][c] = null
						m.ty = w
						m.falling = true
					w -= 1
			var missing = w - top + 1
			for y in range(w, top - 1, -1):
				var m = _new_gem(c, y, randi() % NCOL)
				grid[y][c] = m
				if top == 0:
					m.y = y - missing - 0.4
					m.ty = y
					m.falling = true
				else:
					m.scale = 0.0
					tween(m, {"scale": 1.0}, 0.22, "back")
	await _wait_settled()

func _any_falling() -> bool:
	for r in ROWS:
		for c in COLS:
			var m = grid[r][c]
			if m != null and m.falling:
				return true
	return false

func _wait_settled() -> void:
	await get_tree().process_frame
	while _any_falling():
		await get_tree().process_frame
	await wait(0.06)

# ---------- turn flow ----------
func _pick_spawn(cl: Dictionary) -> int:
	for id in last_swap:
		if cl.cells.has(id):
			return id
	if cl.runs.size() > 1:
		var cnt := {}
		for rn in cl.runs:
			for id in rn.cells:
				cnt[id] = cnt.get(id, 0) + 1
		for id in cnt:
			if cnt[id] > 1:
				return id
	var longest: Dictionary = cl.runs[0]
	for rn in cl.runs:
		if rn.cells.size() > longest.cells.size():
			longest = rn
	return longest.cells[longest.cells.size() / 2]

func _resolve_clusters(cls: Array) -> void:
	var rub := {}
	var t_end := 0.0
	var made_special := false
	for cl in cls:
		var max_len := 0
		var has_h := false
		var has_v := false
		for rn in cl.runs:
			max_len = maxi(max_len, rn.cells.size())
			if rn.h:
				has_h = true
			else:
				has_v = true
		var kind := ""
		var dir := "h"
		if max_len >= 5:
			kind = "light"
		elif has_h and has_v:
			kind = "bomb"
		elif max_len == 4:
			kind = "rocket"
			for rn in cl.runs:
				if rn.cells.size() == 4:
					dir = "v" if rn.h else "h"
		var spawn = _pick_spawn(cl) if kind != "" else -1
		for id in cl.cells:
			var c: int = id % COLS
			var r: int = id / COLS
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if in_b(nc, nr) and is_rub(nc, nr):
					rub[nr * COLS + nc] = true
			if id == spawn:
				continue
			t_end = maxf(t_end, _pop_gem(grid[r][c]))
		if kind != "":
			made_special = true
			var m: Gem = grid[spawn / COLS][spawn % COLS]
			m.dying = true
			tween(m, {"scale": 0.0}, 0.12)
			var k = kind
			var dd = dir
			later(0.12, func():
				m.kind = k
				m.dir = dd
				m.color = -1
				m.dying = false
				sparkle(cell_cx(m.x), cell_cy(m.y), 6)
				tween(m, {"scale": 1.0}, 0.26, "back")
			)
			t_end = maxf(t_end, 0.4)
	if made_special:
		later(0.12, func(): play("shine", 1.0, -4.0))
	later(0.09, func():
		for id in rub:
			damage_rubble(id)
		if not rub.is_empty():
			buzz(15)
	)
	await wait(t_end)

func cascade() -> void:
	for _guard in 30:
		var cls = find_clusters()
		if cls.is_empty():
			break
		await _resolve_clusters(cls)
		last_swap = []
		await collapse()

func _area_for(s: Dictionary) -> Array:
	var out = []
	var c: int = s.c
	var r: int = s.r
	var row = func(y: int, from: int) -> void:
		if y < 0 or y >= ROWS:
			return
		for x in COLS:
			out.append([x, y, absf(x - from) * 0.032])
	var col = func(x: int, from: int) -> void:
		if x < 0 or x >= COLS:
			return
		for y in ROWS:
			out.append([x, y, absf(y - from) * 0.032])
	match s.kind:
		"rocket":
			if s.dir == "h":
				row.call(r, c)
			else:
				col.call(c, r)
		"cross":
			row.call(r, c)
			col.call(c, r)
		"big":
			for k in range(-1, 2):
				row.call(r + k, c)
				col.call(c + k, r)
		"bomb":
			var rad: int = s.get("rad", 2)
			for y in range(r - rad, r + rad + 1):
				for x in range(c - rad, c + rad + 1):
					if in_b(x, y):
						out.append([x, y, maxi(absi(x - c), absi(y - r)) * 0.045])
		"light":
			for y in ROWS:
				for x in COLS:
					if color_at(x, y) == s.color:
						out.append([x, y, 0.08 + randf() * 0.26])
		"all":
			for y in ROWS:
				for x in COLS:
					out.append([x, y, (absi(x - c) + absi(y - r)) * 0.028])
	return out

func _spawn_fx(s: Dictionary) -> void:
	var x = cell_cx(s.c)
	var y = cell_cy(s.r)
	var s2 = CELL * g
	var k: String = s.kind
	if k == "rocket" or k == "cross" or k == "big":
		var dirs = []
		if k != "rocket" or s.dir == "h":
			dirs.append_array([Vector2(1, 0), Vector2(-1, 0)])
		if k != "rocket" or s.dir == "v":
			dirs.append_array([Vector2(0, 1), Vector2(0, -1)])
		for d in dirs:
			fx.append({"kind": "rkt", "x": x, "y": y, "vx": d.x * s2 * 32.0, "vy": d.y * s2 * 32.0, "life": 0.0, "max": 0.45})
		fx.append({"kind": "flash", "x": x, "y": y, "life": 0.0, "max": 0.25, "r": s2 * 1.6})
		play("rocket", 0.95 + randf() * 0.1, -3.0)
		shake = maxf(shake, 0.15)
		buzz(25)
	elif k == "bomb" or k == "all":
		var rad: int = s.get("rad", 2)
		fx.append({"kind": "ring", "x": x, "y": y, "r0": g * 2.0, "r1": s2 * (rad + 1.2), "life": 0.0, "max": 0.45, "col": Color("ffd36b")})
		fx.append({"kind": "flash", "x": x, "y": y, "life": 0.0, "max": 0.35, "r": s2 * (rad + 1)})
		burst(x, y, Color("ffb020"), 22, 1.6)
		play("boom", 0.95 + randf() * 0.1, 0.0)
		shake = maxf(shake, 0.3)
		buzz(45)
	elif k == "light":
		fx.append({"kind": "flash", "x": x, "y": y, "life": 0.0, "max": 0.35, "r": s2 * 2.0})
		play("zap", 1.0, -3.0)
		buzz(30)

func detonate(seeds: Array) -> void:
	var hit := {}
	var rub := {}
	var triggered := {}
	var q = seeds.duplicate()
	for s in seeds:
		if s.has("src"):
			triggered[s.src] = true
	while not q.is_empty():
		var s: Dictionary = q.pop_front()
		var sd: Dictionary = s
		later(s.delay, func(): _spawn_fx(sd))
		if s.has("src"):
			var sid: int = s.r * COLS + s.c
			if not hit.has(sid):
				hit[sid] = s.delay
		for a in _area_for(s):
			var c: int = a[0]
			var r: int = a[1]
			var id = r * COLS + c
			var delay: float = s.delay + a[2]
			if is_rub(c, r):
				if not rub.has(id) or rub[id] > delay:
					rub[id] = delay
				continue
			var m = grid[r][c]
			if m == null:
				continue
			if s.kind == "light":
				var x0 = cell_cx(s.c)
				var y0 = cell_cy(s.r)
				var x1 = cell_cx(c)
				var y1 = cell_cy(r)
				later(delay - 0.06, func(): fx.append({"kind": "bolt", "x0": x0, "y0": y0, "x1": x1, "y1": y1, "life": 0.0, "max": 0.3}))
			if not hit.has(id) or hit[id] > delay:
				hit[id] = delay
			if m.kind != "gem" and not triggered.has(m):
				triggered[m] = true
				var ns = {"c": c, "r": r, "kind": m.kind, "dir": m.dir, "delay": delay + 0.04, "src": m}
				if m.kind == "light":
					ns.color = most_common_color()
				q.append(ns)
	var max_d := 0.0
	for id in hit:
		var m = grid[id / COLS][id % COLS]
		if m != null:
			max_d = maxf(max_d, _pop_gem(m, hit[id]))
	for id in rub:
		var rid: int = id
		later(rub[id], func(): damage_rubble(rid))
		max_d = maxf(max_d, rub[id])
	await wait(max_d + 0.08)

func try_swap(a: Vector2i, b: Vector2i) -> void:
	var A = grid[a.y][a.x]
	var B = grid[b.y][b.x]
	if A == null or B == null or A.dying or B.dying:
		return
	state = "busy"
	hint = []
	selected = Vector2i(-1, -1)
	grid[a.y][a.x] = B
	grid[b.y][b.x] = A
	tween(A, {"x": float(b.x), "y": float(b.y)}, 0.15)
	tween(B, {"x": float(a.x), "y": float(a.y)}, 0.15)
	play("swap", 1.0, -8.0)
	await wait(0.16)
	A.ty = A.y
	B.ty = B.y
	var sa: bool = A.kind != "gem"
	var sb: bool = B.kind != "gem"
	if sa or sb:
		moves -= 1
		_update_hud()
		var seeds = []
		if sa and sb:
			var kinds = [A.kind, B.kind]
			kinds.sort()
			var key = "%s+%s" % kinds
			if key == "light+light":
				seeds = [{"c": b.x, "r": b.y, "kind": "all", "delay": 0.0, "src": A}, {"c": a.x, "r": a.y, "kind": "single", "delay": 0.0, "src": B}]
			elif A.kind == "light" or B.kind == "light":
				var other: Gem = B if A.kind == "light" else A
				var lt: Gem = A if A.kind == "light" else B
				var k = most_common_color()
				var conv = []
				for y in ROWS:
					for x in COLS:
						if color_at(x, y) == k:
							var m: Gem = grid[y][x]
							m.kind = other.kind
							m.dir = "h" if randf() < 0.5 else "v"
							m.color = -1
							conv.append(m)
							fx.append({"kind": "bolt", "x0": cell_cx(lt.x), "y0": cell_cy(lt.y), "x1": cell_cx(x), "y1": cell_cy(y), "life": 0.0, "max": 0.4})
							tween(m, {"scale": 1.2}, 0.15)
							tween(m, {"scale": 1.0}, 0.15, "out", 0.15)
				play("zap", 1.0, -2.0)
				await wait(0.45)
				seeds = [{"c": b.x, "r": b.y, "kind": "single", "delay": 0.0, "src": A}, {"c": a.x, "r": a.y, "kind": "single", "delay": 0.0, "src": B}]
				for i in conv.size():
					var m: Gem = conv[i]
					seeds.append({"c": int(m.x), "r": int(m.y), "kind": m.kind, "dir": m.dir, "delay": i * 0.07, "src": m})
			elif key == "rocket+rocket":
				seeds = [{"c": b.x, "r": b.y, "kind": "cross", "delay": 0.0, "src": A}, {"c": a.x, "r": a.y, "kind": "single", "delay": 0.0, "src": B}]
			elif key == "bomb+bomb":
				seeds = [{"c": b.x, "r": b.y, "kind": "bomb", "rad": 3, "delay": 0.0, "src": A}, {"c": a.x, "r": a.y, "kind": "single", "delay": 0.0, "src": B}]
			else:
				seeds = [{"c": b.x, "r": b.y, "kind": "big", "delay": 0.0, "src": A}, {"c": a.x, "r": a.y, "kind": "single", "delay": 0.0, "src": B}]
		else:
			var sp: Gem = A if sa else B
			var pos: Vector2i = b if sa else a
			var other: Gem = B if sa else A
			var sd0 = {"c": pos.x, "r": pos.y, "kind": sp.kind, "dir": sp.dir, "delay": 0.0, "src": sp}
			if sp.kind == "light":
				sd0.color = other.color
			seeds = [sd0]
		await detonate(seeds)
		await collapse()
		await cascade()
		await end_turn()
		return
	last_swap = [a.y * COLS + a.x, b.y * COLS + b.x]
	if find_clusters().is_empty():
		grid[a.y][a.x] = A
		grid[b.y][b.x] = B
		tween(A, {"x": float(a.x), "y": float(a.y)}, 0.15)
		tween(B, {"x": float(b.x), "y": float(b.y)}, 0.15)
		play("bad", 1.0, -8.0)
		await wait(0.16)
		A.ty = A.y
		B.ty = B.y
		state = "idle"
		return
	moves -= 1
	_update_hud()
	await cascade()
	await end_turn()

func activate(c: int, r: int) -> void:
	var m = grid[r][c]
	if m == null or m.kind == "gem":
		return
	state = "busy"
	hint = []
	selected = Vector2i(-1, -1)
	moves -= 1
	_update_hud()
	var sd0 = {"c": c, "r": r, "kind": m.kind, "dir": m.dir, "delay": 0.0, "src": m}
	if m.kind == "light":
		sd0.color = most_common_color()
	await detonate([sd0])
	await collapse()
	await cascade()
	await end_turn()

func win_threshold() -> int:
	return maxi(12, roundi(grains0 * 0.03))

func end_turn() -> void:
	if grains <= win_threshold():
		_win()
		return
	if moves <= 0:
		state = "busy"
		var t0 = time
		while time - t0 < 1.6 and sand_moved > 0:
			await wait(0.1)
		if grains <= win_threshold():
			_win()
			return
		_lose()
		return
	if find_move().is_empty() and has_special().x < 0:
		await _shuffle()
	state = "idle"
	last_input = time

func _shuffle() -> void:
	ui.toast("No moves left. Shuffling!")
	var gems = []
	for r in ROWS:
		for c in COLS:
			var m = grid[r][c]
			if m != null and m.kind == "gem":
				gems.append(m)
				tween(m, {"scale": 0.0}, 0.18)
	await wait(0.2)
	for _t in 100:
		for m in gems:
			m.color = randi() % NCOL
		if find_clusters().is_empty() and not find_move().is_empty():
			break
	for m in gems:
		tween(m, {"scale": 1.0}, 0.26, "back")
	await wait(0.28)

# ---------- win / lose ----------
func _win() -> void:
	state = "won"
	hero_pose = "cheer"
	var rest = []
	for i in sand.size():
		if sand[i] != 0:
			rest.append(i)
	for k in rest.size():
		var i: int = rest[k]
		later(k * 0.008, func():
			if sand[i] == 0:
				return
			var v = sand[i]
			sand[i] = 0
			grains -= 1
			sand_dirty = true
			var x = i % SW
			var y = i / SW
			parts.append({"x": wx(x + 0.5), "y": wy(y + 0.5), "vx": (randf() - 0.5) * 200.0 * g / 6.0, "vy": (-200.0 - randf() * 200.0) * g / 6.0,
				"life": 0.0, "max": 0.8, "col": theme.gtint, "v": v, "size": g * 1.4, "grav": 900.0 * g / 6.0, "kind": "grain"})
		)
	await wait(minf(0.8, rest.size() * 0.008) + 0.2)
	grains = 0
	_update_hud()
	rubble.clear()
	bg_layer.queue_redraw()
	play("win")
	buzz(60)
	await collapse()
	await _escape()
	var ratio = float(moves) / float(L.moves)
	var stars = 3 if ratio >= 0.3 else (2 if ratio >= 0.12 else 1)
	if stars > int(progress.best[level_idx]):
		progress.best[level_idx] = stars
		save_progress()
	for k in 30:
		later(k * 0.04, func(): sparkle(ox + randf() * SW * g, oy + randf() * BY * g, 3))
	await wait(0.9)
	ui.show_win(stars, moves, L.name, level_idx < LEVELS.size() - 1)

func _escape() -> void:
	# the door gives way outward and Zaki runs for the shaft
	await wait(0.5)
	door_open = true
	play("crack", 1.2, -4.0)
	burst(wx(door_col + 0.5), wy(BY - 8), Color("8a5a2b"), 14, 1.2)
	hero_pose = "run"
	var target: float = (shaft.x0 + shaft.x1) / 2.0
	tween(self, {"hero_x": target}, 0.9, "lin")
	await wait(0.9)
	hero_pose = "jump"
	play("shine", 1.3, -4.0)
	tween(self, {"hero_lift": float(BY - shaft.y0) + 6.0}, 0.9, "in")
	tween(self, {"hero_alpha": 0.0}, 0.3, "lin", 0.6)
	for k in 12:
		later(k * 0.06, func(): sparkle(wx(hero_x), wy(BY - hero_lift - 6.0), 2))
	await wait(1.0)

func _set_room_mask(v: int) -> void:
	for y in range(room.y0, room.y1):
		for x in range(room.x0, room.x1):
			mask[y * SW + x] = v
		mask[y * SW + door_col] = v
	_compute_active_region()
	sand_sleep = false

func _lose() -> void:
	state = "lost"
	hz_target = 1.12
	hero_pose = "scared"
	play("boom", 0.6, -6.0)
	await wait(1.1)
	door_open = true
	_set_room_mask(1)
	burst(wx(door_col + 0.5), wy(BY - 9), Color("8a5a2b"), 16, 1.4)
	play("crack")
	shake = 0.4
	buzz(80)
	await wait(1.0)
	play("lose")
	await wait(0.8)
	var left = ceili(grains * 100.0 / grains0) if grains > 0 else 0
	ui.show_lose(left, not extra_used)

func plus_five() -> void:
	extra_used = true
	moves += 5
	ui.hide_overlay()
	for y in range(room.y0, room.y1):
		for x in range(room.x0 - 1, room.x1 + 1):
			if x < 0 or x >= SW:
				continue
			var in_room = (x >= room.x0 and x < room.x1) or x == door_col
			if not in_room:
				continue
			var i: int = y * SW + x
			if sand[i] != 0:
				var v = sand[i]
				sand[i] = 0
				grains -= 1
				if randf() < 0.3:
					parts.append({"x": wx(x + 0.5), "y": wy(y + 0.5), "vx": (randf() - 0.5) * 160.0 * g / 6.0, "vy": (-150.0 - randf() * 150.0) * g / 6.0,
						"life": 0.0, "max": 0.6, "col": theme.gtint, "v": v, "size": g * 1.3, "grav": 900.0 * g / 6.0, "kind": "grain"})
	_set_room_mask(0)
	sand_dirty = true
	door_open = false
	hero_pose = "push"
	golem_attack = 0.0
	state = "idle"
	_update_hud()
	last_input = time

func open_menu() -> void:
	if state == "busy":
		return
	if state == "idle":
		state = "paused"
	ui.show_menu()

func resume() -> void:
	ui.hide_overlay()
	state = "idle"
	last_input = time

func level_unlocked(i: int) -> bool:
	return i == 0 or int(progress.best[i - 1]) > 0

# ---------- input ----------
var down_cell := Vector2i(-1, -1)
var down_pos := Vector2.ZERO
var down_moved := false

func _cell_at(p: Vector2) -> Vector2i:
	var c = int(floor((p.x - ox - BX * g) / (CELL * g)))
	var r = int(floor((p.y - oy - BY * g) / (CELL * g)))
	if in_b(c, r) and not is_rub(c, r) and grid[r][c] != null:
		return Vector2i(c, r)
	return Vector2i(-1, -1)

## Board input arrives through a full-screen Control in the UI layer (ui.gd), as mouse events.
## Touches become mouse events on every platform, so one path covers phones, web and desktop.
func board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(event.pressed, event.position)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_drag(event.position)

func _pointer(pressed: bool, pos: Vector2) -> void:
	if pressed:
		last_input = time
		hint = []
		if state != "idle":
			return
		var cell = _cell_at(pos)
		if cell.x < 0:
			selected = Vector2i(-1, -1)
			return
		down_cell = cell
		down_pos = pos
		down_moved = false
	else:
		if down_cell.x < 0:
			return
		var d = down_cell
		down_cell = Vector2i(-1, -1)
		if down_moved or state != "idle":
			return
		var m = grid[d.y][d.x]
		if selected.x >= 0 and absi(selected.x - d.x) + absi(selected.y - d.y) == 1:
			try_swap(selected, d)
			return
		if m != null and m.kind != "gem":
			activate(d.x, d.y)
			return
		selected = Vector2i(-1, -1) if selected == d else d
		play("click", 1.0, -10.0)

func _drag(pos: Vector2) -> void:
	if down_cell.x < 0 or down_moved or state != "idle":
		return
	var dv: Vector2 = pos - down_pos
	var th = CELL * g * 0.3
	if absf(dv.x) < th and absf(dv.y) < th:
		return
	down_moved = true
	var c = down_cell
	var t = Vector2i(c.x + int(signf(dv.x)), c.y) if absf(dv.x) > absf(dv.y) else Vector2i(c.x, c.y + int(signf(dv.y)))
	if in_b(t.x, t.y) and not is_rub(t.x, t.y) and grid[t.y][t.x] != null:
		selected = Vector2i(-1, -1)
		try_swap(c, t)

# ---------- simulation ----------
func _sand_step() -> int:
	var moved := 0
	flip ^= 1
	var w = ax1 - ax0
	for y in range(ay1 - 1, ay0 - 1, -1):
		var base: int = y * SW
		var ltr = ((y + flip) & 1) == 1
		for k in w:
			var x: int = (ax0 + k) if ltr else (ax1 - 1 - k)
			var i: int = base + x
			var v = sand[i]
			if v == 0:
				continue
			var b: int = i + SW
			if mask[b] == 1 and sand[b] == 0:
				sand[b] = v
				sand[i] = 0
				moved += 1
				continue
			var d = 1 if (randi() & 1) == 1 else -1
			for _t in 2:
				var nx = x + d
				if nx >= ax0 and nx < ax1:
					var j: int = b + d
					if mask[j] == 1 and sand[j] == 0 and mask[i + d] == 1 and sand[i + d] == 0:
						sand[j] = v
						sand[i] = 0
						moved += 1
						break
				d = -d
	return moved

func _upload_sand() -> void:
	sand_img = Image.create_from_data(SW, SH, false, Image.FORMAT_R8, sand)
	if sand_tex == null or sand_tex.get_width() != SW:
		sand_tex = ImageTexture.create_from_image(sand_img)
		sand_sprite.texture = sand_tex
	else:
		sand_tex.update(sand_img)
	sand_dirty = false

func _process(dt: float) -> void:
	dt = minf(dt, 0.033)
	time += dt
	# tweens
	var i = tweens.size() - 1
	while i >= 0:
		var tw: Dictionary = tweens[i]
		tw.t += dt
		if tw.t >= 0.0:
			var p = minf(1.0, tw.t / tw.dur)
			var e = _ease(tw.ease, p)
			var o: Object = tw.o
			for k in tw.to:
				o.set(k, lerpf(tw.from[k], tw.to[k], e))
			if p >= 1.0:
				tweens.remove_at(i)
		elif tw.t + dt >= 0.0:
			# capture start values right when the delay ends
			for k in tw.to:
				tw.from[k] = tw.o.get(k)
		i -= 1
	# falling gems
	if not grid.is_empty():
		for r in ROWS:
			for c in COLS:
				var m = grid[r][c]
				if m == null:
					continue
				if m.falling:
					m.vy = minf(22.0, m.vy + 70.0 * dt)
					m.y += m.vy * dt
					if m.y >= m.ty:
						m.y = m.ty
						m.vy = 0.0
						m.falling = false
						m.sq = 1.0
				if m.sq > 0.0:
					m.sq = maxf(0.0, m.sq - dt * 5.0)
	# sand
	if not sand.is_empty():
		sand_acc += dt * 55.0
		var mv := 0
		var steps := 0
		while sand_acc >= 1.0 and steps < 3:
			if not sand_sleep:
				var n = _sand_step()
				mv += n
				if n == 0:
					sand_sleep = true
			sand_acc -= 1.0
			steps += 1
		if sand_acc > 3.0:
			sand_acc = 0.0
		sand_moved = mv
		if mv > 0:
			sand_dirty = true
		if sand_dirty:
			_upload_sand()
		sand_sfx_t -= dt
		if mv > 25 and sand_sfx_t <= 0.0:
			play("sand", 0.9 + randf() * 0.2, -14.0)
			sand_sfx_t = 0.3
	# particles
	i = parts.size() - 1
	while i >= 0:
		var p: Dictionary = parts[i]
		p.life += dt
		p.vy += p.grav * dt
		p.x += p.vx * dt
		p.y += p.vy * dt
		if p.life > p.max:
			parts.remove_at(i)
		i -= 1
	i = fx.size() - 1
	while i >= 0:
		var f: Dictionary = fx[i]
		f.life += dt
		if f.kind == "rkt":
			f.x += f.vx * dt
			f.y += f.vy * dt
			if randf() < 0.8:
				parts.append({"x": f.x, "y": f.y, "vx": (randf() - 0.5) * 40.0, "vy": (randf() - 0.5) * 40.0, "life": 0.0, "max": 0.35,
					"col": Color("ffb020") if randf() < 0.5 else Color("ff5a3a"), "size": g * 1.2, "grav": 0.0, "kind": "dot"})
		if f.life > f.max:
			fx.remove_at(i)
		i -= 1
	# hero strain: how much debris is pressing on the door
	hero_t += dt
	if not shaft.is_empty():
		var n := 0
		var xs: int = shaft.x0 if facing > 0 else shaft.x1 - 1
		var xs2: int = xs + (1 if facing > 0 else -1)
		for y in range(room.y0, room.y1):
			if sand[y * SW + xs] != 0:
				n += 1
			if sand[y * SW + xs2] != 0:
				n += 1
		var target = float(n) / float((room.y1 - room.y0) * 2)
		hero_strain += (target - hero_strain) * minf(1.0, dt * 4.0)
	if state == "idle" and time - last_input > 5.5 and hint.is_empty():
		var mv = find_move()
		if not mv.is_empty():
			hint = mv
		else:
			var sp = has_special()
			if sp.x >= 0:
				hint = [sp]
	shake = maxf(0.0, shake - dt)
	var sh := Vector2.ZERO
	if shake > 0.0:
		sh = Vector2(randf() - 0.5, randf() - 0.5) * g * 2.0 * shake
	position = sh
	_anim(dt)
	hz_layer.queue_redraw()
	back_layer.queue_redraw()
	gem_layer.queue_redraw()
	fx_layer.queue_redraw()
	add_layer.queue_redraw()

func _place_hero() -> void:
	_anim(0.0)

# ---------- characters: bone-rig animation ----------
const PUSH_POSE := {"torso": 0.28, "head": -0.22, "arm_up_f": -1.75, "arm_lo_f": 0.25, "arm_up_b": -1.6, "arm_lo_b": 0.2,
	"leg_up_f": -0.5, "leg_lo_f": 0.25, "leg_up_b": 0.2, "leg_lo_b": 0.08}

func _hero_target(t: float) -> Dictionary:
	var st := hero_strain
	match hero_pose:
		"push":
			var d := PUSH_POSE.duplicate()
			var q := sin(t * (18.0 + st * 14.0)) * (0.015 + st * 0.035)
			d.torso += q + st * 0.06
			d.arm_up_f -= q * 1.5
			d.arm_up_b -= q * 1.2
			d.leg_up_b += st * 0.12
			if look_t > 0.0:
				d.head = 0.25
				d.torso -= 0.12
			return d
		"scared":
			var w := sin(t * 38.0) * 0.05
			return {"torso": -0.15 + w, "head": 0.25, "arm_up_f": -2.0, "arm_lo_f": -0.9 + w, "arm_up_b": -2.2, "arm_lo_b": -0.8 - w,
				"leg_up_f": 0.25, "leg_lo_f": 0.15, "leg_up_b": -0.1, "leg_lo_b": 0.2}
		"cheer":
			var wv := sin(t * 9.0) * 0.25
			return {"torso": -0.05, "head": -0.1, "arm_up_f": 2.55 + wv, "arm_lo_f": -0.35, "arm_up_b": -2.6 - wv, "arm_lo_b": 0.3,
				"leg_up_f": -0.15, "leg_lo_f": 0.1, "leg_up_b": 0.12, "leg_lo_b": 0.05}
		"run":
			var ph := t * 13.0
			var sw := sin(ph)
			var lean := 0.22
			return {"torso": lean, "head": -0.18, "arm_up_f": -sw * 1.0 - lean, "arm_lo_f": -1.1, "arm_up_b": sw * 1.0 - lean, "arm_lo_b": -1.1,
				"leg_up_f": sw * 0.8 - lean, "leg_lo_f": maxf(0.0, -cos(ph)) * 1.1, "leg_up_b": -sw * 0.8 - lean, "leg_lo_b": maxf(0.0, cos(ph)) * 1.1}
		"jump":
			return {"torso": -0.1, "head": -0.3, "arm_up_f": 2.7, "arm_lo_f": -0.2, "arm_up_b": -2.8, "arm_lo_b": 0.2,
				"leg_up_f": -0.5, "leg_lo_f": 0.9, "leg_up_b": 0.3, "leg_lo_b": 0.7}
	return {}

func _hero_face() -> String:
	match hero_pose:
		"scared":
			return "scared"
		"cheer", "run", "jump":
			return "happy"
	if look_t > 0.0:
		return "look" if hz_p < 0.75 else "scared"
	if blink_t < 0.12:
		return "blink"
	return "strain" if hero_strain > 0.25 or hz_p > 0.5 else "neutral"

func _chaser_target(kind: String, t: float, speed: float) -> Dictionary:
	var ph := chaser_phase
	var sw := sin(ph)
	var br := sin(t * 2.2)
	var a := golem_attack
	var up := clampf(a * 2.0, 0.0, 1.0)
	var down := clampf((a - 0.5) * 3.0, 0.0, 1.0)
	match kind:
		"golem":
			var d := {"pelvis": sw * 0.03 * speed, "chest": 0.04 + br * 0.02, "head": -br * 0.04 + (0.15 if roar_t < 0.9 else 0.0),
				"arm_f": -sw * 0.18 * speed, "arm_b": sw * 0.18 * speed, "leg_f": sw * 0.1 * speed, "leg_b": -sw * 0.1 * speed}
			if a > 0.0:
				d.arm_f = lerpf(0.0, -1.0, up) + down * 0.9
				d.arm_b = lerpf(0.0, -0.85, up) + down * 0.8
				d.chest = 0.22 * down - 0.08 * up
			return d
		"mummy":
			var d := {"pelvis": sw * 0.04 * speed, "chest": 0.08 + sin(ph * 2.0) * 0.04, "head": sin(t * 3.0) * 0.08,
				"arm_b": -0.05 + sin(t * 4.0) * 0.08, "arm_f": 0.05 + sin(t * 4.0 + 1.0) * 0.08,
				"leg_f": -sw * 0.28 * speed, "leg_b": sw * 0.28 * speed}
			if a > 0.0:
				d.chest = 0.25 * up
				d.arm_b = -0.35 * up
				d.arm_f = -0.3 * up
			return d
		"cobra":
			var d := {"coil": 0.0, "neck1": sin(t * 2.0) * 0.1, "neck2": sin(t * 2.0 - 0.8) * 0.14, "head": sin(t * 2.0 - 1.6) * 0.12}
			if a > 0.0:
				d.neck1 += 0.3 * up - 0.1 * down
				d.neck2 += 0.4 * up
				d.head += 0.25 * up
			return d
	return {}

func _hazard_width() -> float:
	var hz: String = L.get("hazard", "")
	if hz == "spikes":
		return SPIKE_W
	if chasers.has(hz):
		var pp: Puppet = chasers[hz]
		return pp.size.x * CHASER_H[hz] / pp.size.y
	return 0.0

func _hazard_front() -> float:
	# x (world cells) of the hazard's leading edge
	var far = room.x0 if facing > 0 else room.x1
	var back := hero_x - facing * 3.2
	var base := _hazard_width() + 0.4
	var dist := absf(back - far)
	return far + facing * (base + hz_p * maxf(0.0, dist - base))

func _anim(dt: float) -> void:
	if room.is_empty() or hero == null:
		return
	# hazard creeps toward its target
	var prev := hz_p
	hz_p = move_toward(hz_p, hz_target, dt * 0.35)
	var hz_speed := absf(hz_p - prev) / maxf(dt, 0.0001)
	# hero timers: blink, glance back at the danger
	blink_t -= dt
	if blink_t < 0.0:
		blink_t = 2.0 + randf() * 2.5
	look_t = maxf(0.0, look_t - dt)
	if hero_pose == "push" and state != "won":
		look_cd -= dt
		if look_cd <= 0.0 and hz_p > 0.2:
			look_t = 0.9
			look_cd = lerpf(5.0, 1.6, hz_p) + randf()
	var k: float = 1.0 if dt == 0.0 else minf(1.0, dt * 14.0)
	hero.pose(_hero_target(hero_t), k)
	hero.set_face(_hero_face())
	var s := HERO_H * g / HERO_PX
	hero.scale = Vector2(s * facing, s)
	var bob := 0.0
	match hero_pose:
		"push":
			bob = sin(hero_t * 26.0) * 0.12 * (0.3 + hero_strain)
		"cheer":
			bob = -absf(sin(hero_t * 7.0)) * 2.2
		"run":
			bob = -absf(sin(hero_t * 13.0)) * 0.7
		"scared":
			bob = sin(hero_t * 40.0) * 0.15
	hero.position = Vector2(wx(hero_x), wy(BY - 1.25 - hero_lift - bob) - hero.foot_drop() * s)
	hero.modulate.a = hero_alpha
	# chaser (golem, mummy, cobra)
	var hz: String = L.get("hazard", "")
	if chasers.has(hz):
		var pp: Puppet = chasers[hz]
		chaser_phase += hz_speed * 9.0 * dt + dt * 0.6
		roar_t += dt
		if roar_t > 4.5 + randf() * 3.0 and hz_p > 0.15:
			roar_t = 0.0
			play("boom", 0.45 if hz == "golem" else 0.8, -12.0)
		if state == "lost":
			golem_attack = minf(1.0, golem_attack + dt * 1.2)
		var gk: float = 1.0 if dt == 0.0 else minf(1.0, dt * 10.0)
		pp.pose(_chaser_target(hz, hero_t, clampf(hz_speed * 6.0, 0.25, 1.0)), gk)
		var cs: float = CHASER_H[hz] * g / pp.size.y
		var lead := wx(_hazard_front())
		var hop: float = absf(sin(chaser_phase)) * 0.3 if hz == "golem" else 0.0
		pp.place(Vector2(lead - facing * pp.front_offset(cs), wy(BY - 1.1 - hop)), cs, facing)
	# lava embers
	if L.get("hazard", "") == "lava" and dt > 0.0:
		ember_t -= dt
		if ember_t <= 0.0 and hz_p > 0.02:
			ember_t = 0.08
			var far = room.x0 if facing > 0 else room.x1
			var ex := lerpf(far, _hazard_front(), randf())
			parts.append({"x": wx(ex), "y": wy(BY - 2.0), "vx": (randf() - 0.5) * 30.0, "vy": -60.0 - randf() * 80.0, "life": 0.0,
				"max": 0.9 + randf() * 0.6, "col": Color(1.0, 0.6 + randf() * 0.3, 0.15), "size": g * 0.45, "grav": -10.0, "kind": "dot"})

# ---------- hazards ----------
func _draw_hazard(ci: CanvasItem) -> void:
	if room.is_empty():
		return
	match L.get("hazard", ""):
		"spikes":
			_draw_spike_wall(ci)
		"water":
			_draw_water(ci)
		"lava":
			_draw_lava(ci)

func _draw_spike_wall(ci: CanvasItem) -> void:
	var front := _hazard_front()
	var y0: float = room.y0 + 1.2
	var y1: float = BY - 0.6
	var w := SPIKE_W * g
	var h := (y1 - y0) * g
	if facing > 0:
		ci.draw_texture_rect(tex.spikewall, Rect2(Vector2(wx(front) - w, wy(y0)), Vector2(w, h)), false)
	else:
		ci.draw_set_transform(Vector2(wx(front) + w, wy(y0)), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(tex.spikewall, Rect2(Vector2.ZERO, Vector2(w, h)), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _spout_pos() -> Vector2:
	var far = room.x0 if facing > 0 else room.x1
	return Vector2(wx(far + facing * 3.4), wy(room.y0 + 5.5))

func _draw_water(ci: CanvasItem) -> void:
	var x0 := wx(room.x0)
	var x1 := wx(room.x1)
	var room_h := float(room.y1 - room.y0)
	var level: float = BY - (0.6 + hz_p * room_h * 0.72)
	# inflow from a pipe high on the far wall
	var sp := _spout_pos()
	var px := sp.x
	var py := sp.y + g * 1.2
	if hz_p < 0.999 or state == "lost":
		var wob := sin(time * 9.0) * g * 0.2
		ci.draw_rect(Rect2(Vector2(px - g * 0.7 + wob, py), Vector2(g * 1.4, wy(level) - py)), Color(0.45, 0.75, 1.0, 0.55))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 24
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var wv := sin(time * 3.0 + i * 0.8) * g * 0.35 + sin(time * 5.3 + i * 1.7) * g * 0.15
		pts.append(Vector2(x, wy(level) + wv))
		cols.append(Color(0.45, 0.78, 1.0, 0.6))
	pts.append(Vector2(x1, wy(BY)))
	cols.append(Color(0.08, 0.28, 0.6, 0.85))
	pts.append(Vector2(x0, wy(BY)))
	cols.append(Color(0.08, 0.28, 0.6, 0.85))
	ci.draw_polygon(pts, cols)
	var top := PackedVector2Array()
	for i in n + 1:
		top.append(pts[i])
	ci.draw_polyline(top, Color(0.85, 0.95, 1.0, 0.8), maxf(1.5, g * 0.35), true)
	for k in 8:
		var bx := lerpf(x0, x1, fmod(k * 0.137 + 0.05, 1.0))
		var by := wy(BY) - fmod(time * 30.0 + k * 41.0, maxf(1.0, (BY - level) * g))
		ci.draw_arc(Vector2(bx + sin(time * 4.0 + k) * g * 0.3, by), g * 0.25, 0, TAU, 10, Color(0.9, 0.97, 1.0, 0.6), 1.5)

func _draw_lava(ci: CanvasItem) -> void:
	var far = room.x0 if facing > 0 else room.x1
	var front := _hazard_front()
	var h := 2.2 + hz_p * 2.6
	# lava pouring from the far wall
	var sp := _spout_pos()
	var px := sp.x
	var py := sp.y + g * 1.2
	if hz_p > 0.0:
		var wob := sin(time * 7.0) * g * 0.2
		_vgrad(ci, Rect2(Vector2(px - g * 0.75 + wob, py), Vector2(g * 1.5, wy(BY - h) - py + g)), Color(1.0, 0.85, 0.3), Color(1.0, 0.45, 0.08))
	if hz_p <= 0.001:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 20
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(far, front, t)
		var bump := sin(time * 2.0 + i * 1.3) * 0.35 + sin(time * 3.1 + i * 0.7) * 0.2
		var hh := h * (1.0 - pow(t, 6.0)) + bump
		pts.append(Vector2(wx(x), wy(BY - maxf(0.3, hh))))
		cols.append(Color(1.0, 0.82, 0.3))
	pts.append(Vector2(wx(front), wy(BY)))
	cols.append(Color(0.85, 0.22, 0.04))
	pts.append(Vector2(wx(far), wy(BY)))
	cols.append(Color(0.85, 0.22, 0.04))
	ci.draw_polygon(pts, cols)
	# cooling crust
	for k in 7:
		var t := fmod(k * 0.17 + time * 0.03, 0.9)
		var x := lerpf(far, front, t)
		ci.draw_circle(Vector2(wx(x), wy(BY - h * 0.45 + sin(time + k) * 0.3)), g * (0.6 + 0.3 * sin(time * 1.3 + k)), Color(0.45, 0.1, 0.04, 0.55))

# ---------- drawing ----------
func _draw_tex_centered(ci: CanvasItem, t: Texture2D, center: Vector2, size: Vector2, rot := 0.0, mod := Color.WHITE) -> void:
	if rot == 0.0:
		ci.draw_texture_rect(t, Rect2(center - size / 2.0, size), false, mod)
	else:
		ci.draw_set_transform(center, rot, Vector2.ONE)
		ci.draw_texture_rect(t, Rect2(-size / 2.0, size), false, mod)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	var pts = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))

func _draw_bg(ci: CanvasItem) -> void:
	if L.is_empty():
		return
	var W = SW * g
	var H = SH * g
	var world := Rect2(ox, oy, W, H)
	ci.draw_rect(world, Color("0c0816"))
	var rt: Texture2D = tex["room_" + theme.room]
	var k: float = rt.get_width() / float(SW)
	var src_top: float = theme.floor - (BY - 2.5) * k
	var rows: float = minf(float(SH), (rt.get_height() - src_top) / k)
	ci.draw_texture_rect_region(rt, Rect2(ox, oy, W, rows * g), Rect2(0, src_top, rt.get_width(), rows * k), theme.room_tint)
	# soften the top and darken outside the room so Zaki's alcove reads first
	_vgrad(ci, Rect2(ox, oy, W, BY * g * 0.45), Color(0, 0, 0, 0.5), Color(0, 0, 0, 0))
	var rr = Rect2(wx(room.x0), wy(room.y0), (room.x1 - room.x0) * g, (room.y1 - room.y0) * g)
	_vgrad(ci, Rect2(rr.position, Vector2(rr.size.x, g * 3.0)), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0))
	# shaft recess
	var sr = Rect2(wx(shaft.x0), wy(shaft.y0), (shaft.x1 - shaft.x0) * g, (BY - shaft.y0) * g)
	_vgrad(ci, sr, theme.recess[1], theme.recess[0])
	# board backing
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("101736")
	sb.set_corner_radius_all(int(g * 1.6))
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = int(g * 1.5)
	sb.border_color = Color("2a356b")
	sb.set_border_width_all(int(maxf(1.0, g * 0.3)))
	ci.draw_style_box(sb, Rect2(wx(BX - 0.8), wy(BY - 0.8), (COLS * CELL + 1.6) * g, (ROWS * CELL + 1.6) * g))
	var s = CELL * g
	for r in ROWS:
		for c in COLS:
			var p = Vector2(wx(BX + c * CELL), wy(BY + r * CELL))
			if is_rub(c, r):
				ci.draw_rect(Rect2(p, Vector2(s, s)), theme.recess[0])
				continue
			var shade = Color(1, 1, 1) if (r + c) % 2 == 0 else Color(0.9, 0.88, 0.85)
			ci.draw_texture_rect(tex.tile, Rect2(p + Vector2(s, s) * 0.02, Vector2(s, s) * 0.96), false, shade)

func _draw_back(ci: CanvasItem) -> void:
	if L.is_empty():
		return
	# water / lava spout on the far wall of the room
	var hz: String = L.get("hazard", "")
	if hz == "water" or hz == "lava":
		var t: Texture2D = tex.spout_lion if hz == "water" else tex.spout_ram
		var sz := Vector2(g * 6.0, g * 6.0 * t.get_height() / t.get_width())
		var sp := _spout_pos()
		ci.draw_texture_rect(t, Rect2(sp - Vector2(sz.x / 2.0, sz.y * 0.55), sz), false)

func _draw_frame(ci: CanvasItem) -> void:
	if L.is_empty():
		return
	var gb: Texture2D = tex.goldbar
	var t = g * 1.4
	var sx0 = wx(shaft.x0)
	var sx1 = wx(shaft.x1)
	var sy = wy(shaft.y0)
	var by = wy(BY)
	# shaft sides (vertical bars drawn rotated)
	for x in [sx0 - t * 0.5, sx1 + t * 0.5]:
		ci.draw_set_transform(Vector2(x, (sy + by) / 2.0), PI / 2.0, Vector2.ONE)
		ci.draw_texture_rect(gb, Rect2(Vector2(-(by - sy) / 2.0 - t / 2, -t / 2), Vector2(by - sy + t, t)), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_texture_rect(gb, Rect2(Vector2(sx0 - t, sy - t * 0.9), Vector2(sx1 - sx0 + t * 2, t)), false)
	# room: top bar and far wall
	var rx0 = wx(room.x0)
	var rx1 = wx(room.x1)
	var ry = wy(room.y0)
	ci.draw_texture_rect(gb, Rect2(Vector2(rx0 - t * 0.3, ry - t * 0.5), Vector2(rx1 - rx0 + t * 0.6, t * 0.8)), false)
	var far = rx0 if facing > 0 else rx1
	ci.draw_set_transform(Vector2(far, (ry + by) / 2.0), PI / 2.0, Vector2.ONE)
	ci.draw_texture_rect(gb, Rect2(Vector2(-(by - ry) / 2.0, -t * 0.4), Vector2(by - ry, t * 0.8)), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# floor ledge over the board
	ci.draw_texture_rect(gb, Rect2(Vector2(wx(BX - 0.8), wy(BY - 1.4)), Vector2((COLS * CELL + 1.6) * g, g * 1.3)), false)
	# door
	_draw_door(ci)

func _draw_door(ci: CanvasItem) -> void:
	var x = wx(door_col + 0.5)
	var top = wy(room.y0) + g * 0.8
	var bot = wy(BY) - g * 0.2
	var h = bot - top
	if door_open:
		var side = facing if state == "won" else -facing
		ci.draw_set_transform(Vector2(x + side * g * 5.0, bot - g * 0.8), PI / 2.0 + side * 0.12, Vector2.ONE)
		ci.draw_texture_rect(tex.door, Rect2(Vector2(-g * 1.5, -h / 2.0), Vector2(g * 3.0, h)), false, Color(0.85, 0.85, 0.85))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var bulge = -facing * hero_strain * g * 0.6 + sin(hero_t * 30.0) * hero_strain * g * 0.12
	ci.draw_set_transform(Vector2(x + bulge, (top + bot) / 2.0), -facing * hero_strain * 0.03, Vector2.ONE)
	ci.draw_texture_rect(tex.door, Rect2(Vector2(-g * 1.5, -h / 2.0), Vector2(g * 3.0, h)), false)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _gem_tex(m: Gem) -> Texture2D:
	match m.kind:
		"gem":
			return tex.gems[m.color]
		"rocket":
			return tex.rocket
		"bomb":
			return tex.bomb
		"light":
			return tex.light
	return tex.gem_red

func _draw_gems(ci: CanvasItem) -> void:
	if grid.is_empty():
		return
	var S = CELL * g * 0.92
	var board_top = wy(BY) - CELL * g * 0.35
	if selected.x >= 0:
		var c = Vector2(cell_cx(selected.x), cell_cy(selected.y))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 0.96, 0.75, 0.25)
		sb.border_color = Color("fff6c9")
		sb.set_border_width_all(int(maxf(2.0, g * 0.5)))
		sb.set_corner_radius_all(int(g * 1.4))
		ci.draw_style_box(sb, Rect2(c - Vector2(CELL * g, CELL * g) / 2.0 + Vector2(g, g) * 0.3, Vector2(CELL * g, CELL * g) - Vector2(g, g) * 0.6))
	for r in ROWS:
		for c in COLS:
			var m = grid[r][c]
			if m == null or m.scale <= 0.0:
				continue
			var x = cell_cx(m.x)
			var y = cell_cy(m.y)
			if not hint.is_empty():
				for k in hint.size():
					var hc: Vector2i = hint[k]
					if hc.x == c and hc.y == r:
						var wv = sin(time * 14.0) * g * 0.6
						if hint.size() == 2:
							var a: Vector2i = hint[0]
							var b: Vector2i = hint[1]
							var sgn = 1.0 if k == 0 else -1.0
							x += (b.x - a.x) * wv * sgn
							y += (b.y - a.y) * wv * sgn
						else:
							y += wv
			if m.falling and y < board_top:
				continue
			var sx: float = 1.0 + m.sq * 0.12
			var sy: float = 1.0 - m.sq * 0.14
			var s: float = S * m.scale
			var rot := 0.0
			if m.kind != "gem" and not m.dying:
				s *= 1.0 + sin(time * 5.0 + c + r) * 0.04
			if m.kind == "rocket" and m.dir == "v":
				rot = -PI / 2.0
			if m.kind == "light":
				rot = time * 0.8
			var size := Vector2(s * sx, s * sy)
			var center = Vector2(x, y + (s - size.y) / 2.0)
			# soft contact shadow
			ci.draw_circle(center + Vector2(0, s * 0.36), s * 0.32, Color(0, 0, 0, 0.18 * m.scale))
			_draw_tex_centered(ci, _gem_tex(m), center, size, rot)

func _draw_fx(ci: CanvasItem) -> void:
	var S = CELL * g * 0.8
	for f in fx:
		var p: float = f.life / f.max
		match f.kind:
			"ring":
				var col: Color = f.col
				col.a = 1.0 - p
				ci.draw_arc(Vector2(f.x, f.y), lerpf(f.r0, f.r1, 1.0 - (1.0 - p) * (1.0 - p)), 0, TAU, 40, col, maxf(1.0, g * (1.2 - p)), true)
			"rkt":
				var ang = atan2(f.vy, f.vx)
				_draw_tex_centered(ci, tex.rocket, Vector2(f.x, f.y), Vector2(S, S), ang + 0.35)
			"bolt":
				var pts := PackedVector2Array()
				pts.append(Vector2(f.x0, f.y0))
				for k in range(1, 6):
					var t: float = k / 6.0
					pts.append(Vector2(lerpf(f.x0, f.x1, t) + (randf() - 0.5) * g * 2.5, lerpf(f.y0, f.y1, t) + (randf() - 0.5) * g * 2.5))
				pts.append(Vector2(f.x1, f.y1))
				ci.draw_polyline(pts, Color(0.9, 0.82, 1.0, 1.0 - p), maxf(1.5, g * 0.5), true)
	for pt in parts:
		var a: float = maxf(0.0, 1.0 - pt.life / pt.max)
		match pt.kind:
			"grain":
				var gt: Texture2D = tex["grains_" + theme.grains]
				var c: Color = pt.col
				c.a = a
				var cw: float = gt.get_height()
				var sz: float = pt.size * 1.2
				ci.draw_texture_rect_region(gt, Rect2(Vector2(pt.x, pt.y) - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Rect2((pt.get("v", 1) - 1) * cw, 0, cw, cw), c)
			"star":
				var s: float = pt.size * a
				var col: Color = pt.col
				col.a = a
				ci.draw_set_transform(Vector2(pt.x, pt.y), pt.life * 6.0, Vector2.ONE)
				ci.draw_rect(Rect2(-s / 2, -s / 8, s, s / 4), col)
				ci.draw_rect(Rect2(-s / 8, -s / 2, s / 4, s), col)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				var col: Color = pt.col
				col.a = a
				ci.draw_circle(Vector2(pt.x, pt.y), pt.size * (0.4 + a * 0.6), col)

func _draw_add(ci: CanvasItem) -> void:
	if L.is_empty():
		return
	if L.get("hazard", "") == "lava" and hz_p > 0.0:
		var far = room.x0 if facing > 0 else room.x1
		var mid := wx((far + _hazard_front()) / 2.0)
		var wdt := absf(_hazard_front() - far) * g
		_draw_tex_centered(ci, glow_tex, Vector2(mid, wy(BY - 2.0)), Vector2(wdt * 1.6 + g * 8.0, g * 14.0), 0.0, Color(1.0, 0.45, 0.1, 0.55))
	for f in fx:
		if f.kind == "flash":
			var p: float = f.life / f.max
			var r: float = f.r
			_draw_tex_centered(ci, glow_tex, Vector2(f.x, f.y), Vector2(r, r) * 2.0, 0.0, Color(1.0, 0.95, 0.8, 0.9 * (1.0 - p)))
		elif f.kind == "rkt":
			_draw_tex_centered(ci, glow_tex, Vector2(f.x, f.y), Vector2(g, g) * 8.0, 0.0, Color(1.0, 0.6, 0.2, 0.6))
	if theme.glow > 0.0:
		# crystal shimmer over the shaft
		var sr = Rect2(wx(shaft.x0), wy(L.fill_top), (shaft.x1 - shaft.x0) * g, (BY - L.fill_top) * g)
		var pulse = 0.10 + 0.05 * sin(time * 2.0)
		var col: Color = theme.glow_col
		col.a = pulse * clampf(float(grains) / float(grains0) * 1.5, 0.0, 1.0)
		_draw_tex_centered(ci, glow_tex, sr.get_center(), sr.size * 1.4, 0.0, col)
	for p in parts:
		if p.kind == "star":
			var a: float = maxf(0.0, 1.0 - p.life / p.max)
			_draw_tex_centered(ci, glow_tex, Vector2(p.x, p.y), Vector2(g, g) * 4.0 * a, 0.0, Color(1, 0.95, 0.7, 0.5 * a))

# ---------- autotest: plays a few levels and saves screenshots for review ----------
func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png(shots_dir.path_join(name + ".png"))
	print("AUTOTEST shot ", name)

func _near_rub(c: int, r: int) -> float:
	var n := 0.0
	for y in range(r - 2, r + 3):
		for x in range(c - 2, c + 3):
			if in_b(x, y) and is_rub(x, y):
				n += 1.0 / (1.0 + absi(x - c) + absi(y - r))
	return n

func _bot_move() -> void:
	var sp = has_special()
	if sp.x >= 0 and randf() < 0.6:
		await activate(sp.x, sp.y)
		return
	var ms = all_moves()
	if ms.is_empty():
		return
	ms.sort_custom(func(a, b): return _near_rub(a[0].x, a[0].y) + _near_rub(a[1].x, a[1].y) > _near_rub(b[0].x, b[0].y) + _near_rub(b[1].x, b[1].y))
	await try_swap(ms[0][0], ms[0][1])

func _run_autotest() -> void:
	await wait(1.0)
	await _shot("01_menu")
	for lv in LEVELS.size():
		start_level(lv)
		await wait(1.5)
		await _shot("L%d_a_start" % (lv + 1))
		var n := 0
		while state != "won" and state != "lost" and n < 60:
			if state == "idle":
				await _bot_move()
				n += 1
				if n == 10:
					await wait(1.2)
					await _shot("L%d_b_chase" % (lv + 1))
			else:
				await wait(0.1)
		if state == "won":
			await wait(1.9)
			await _shot("L%d_c_escape" % (lv + 1))
		else:
			await wait(1.0)
			await _shot("L%d_c_caught" % (lv + 1))
		await wait(2.5)
		print("AUTOTEST RESULT level=%d state=%s moves_left=%d debris=%d" % [lv + 1, state, moves, grains])
		await _shot("L%d_d_end" % (lv + 1))
	get_tree().quit()
