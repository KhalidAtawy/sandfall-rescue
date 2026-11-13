extends Node2D
## Sandfall Rescue: match-3 board under a shaft of falling debris.
## Match gems next to debris cells to destroy them; the debris above slides down.
## Clear the debris before moves run out, or the door gives way.

const DrawLayer := preload("res://scripts/draw_layer.gd")
const Ui := preload("res://scripts/ui.gd")
const Rig := preload("res://scripts/rig.gd")
const RigData := preload("res://scripts/rig_data.gd")
const Puppet := preload("res://scripts/puppet.gd")
const FramesData := preload("res://scripts/frames_data.gd")
const LevelsData := preload("res://scripts/levels_data.gd")
const Meta := preload("res://scripts/meta.gd")
const HERO_H := 15.0      # hero height in world cells
const HERO_PX := 1126.0   # hero height in rig pixels
const ROOM_H := 24
const SPIKE_W := 6.0
const DOOR_EDGE_W := 2.6   # side view of the door, in cells
const SAFE_H := 17.0       # safe exit door height, in cells
const RUBBLE_HIT := 20     # grains removed from a debris block per hit
const MODES := {
	"drain": {"title": "Clear the Door", "text": "Debris keeps pouring in behind the door, and its weight pushes Zaki back toward the spikes. Match gems next to the sand to drain it faster than it comes in. When the door is clear, Zaki escapes.\n\nA 2x2 square makes a Scarab that flies into the debris. A gem touching a line of 3 from the side joins the match."},
	"iron": {"title": "Heavy Iron", "text": "Iron barely moves for small matches. Make rockets, bombs and orbs: power-ups smash a whole iron block at once."},
	"chain": {"title": "Crystal Chain", "text": "Crystals crack in chains. Every hit also cracks the crystal blocks touching it."},
	"crust": {"title": "Cooling Lava", "text": "Lava you leave alone for 6 moves cools into hard crust. A crusted block needs one hit to crack before it breaks."},
	"wrap": {"title": "Bandaged Gems", "text": "The mummy wrapped some gems in bandages, and wrapped gems are stuck in place. Match next to them to tear the bandages off, then clear the door."},
	"race": {"title": "Cobra Race", "text": "No move limit, but the debris never stops pushing. Be quick! Every power-up you make lets Zaki win back a step."},
	"jars": {"title": "Canopic Jars", "text": "Ancient jars sit on the board. Match next to a jar twice to break it open. Each one hides a rocket. Break every jar and clear the door."},
	"glass": {"title": "Obsidian Glass", "text": "Some gems are sealed in black glass. It takes two matches next to them (or a power-up) to shatter it. Free them all and clear the door."},
	"runes": {"title": "Sun Runes", "text": "Sun runes glow under some gems. Clear a gem on top of a rune to light it. Light every rune and clear the door."},
	"curse": {"title": "Creeping Curse", "text": "A golden curse grabs gems, and it spreads to a new gem every move you don't break any cover. Lift the whole curse and clear the door."},
}
const WRAP_COUNT := 7
const RACE_BONUS := 3.0
const CHASER_H := {"golem": 20.0, "mummy": 19.0, "cobra": 17.0}

const COLS := 8
const ROWS := 9
const CELL := 7        # debris grid cells per board cell
const BX := 2          # board left edge, in debris cells
const BY := 44         # board top edge, in debris cells
const SW := 60         # world width, in debris cells
const SH := 110        # world height, in debris cells
const NCOL := 4

const LEVELS = LevelsData.LEVELS
const WORLDS = LevelsData.WORLDS
const MODE_SHORT := {
	"drain": "Clear the sand from the door.",
	"iron": "Iron: power-ups smash whole blocks.",
	"chain": "Crystals crack in chains.",
	"crust": "Untouched lava cools into crust.",
	"wrap": "Free the bandaged gems too.",
	"race": "No move limit. Be quick!",
	"jars": "Break every jar. Each hides a rocket.",
	"glass": "Shatter the obsidian glass (2 hits).",
	"runes": "Light every sun rune.",
	"curse": "Stop the curse before it spreads.",
}
const BOSS_NAMES := {"golem": "The Rock Golem", "mummy": "The Mummy", "cobra": "The Giant Cobra"}
## One boss per world. "base" is the puppet used until the boss has its own art
## (assets/gfx/bosses/<kind>.png); "attacks" take turns every few moves.
const BOSSES := {
	"scorpion": {"name": "The Scorpion King", "base": "cobra", "tint": Color(1.0, 0.82, 0.5), "attacks": ["slam", "sand"]},
	"golem": {"name": "The Rock Golem", "base": "golem", "tint": Color(1, 1, 1), "attacks": ["smash", "slam"]},
	"spider": {"name": "The Crystal Spider", "base": "golem", "tint": Color(0.78, 0.6, 1.0), "attacks": ["web", "slam"]},
	"salamander": {"name": "The Lava Salamander", "base": "cobra", "tint": Color(1.0, 0.55, 0.35), "attacks": ["magma", "slam"]},
	"mummy": {"name": "The Mummy", "base": "mummy", "tint": Color(1, 1, 1), "attacks": ["wrap", "roar"]},
	"cobra": {"name": "The Giant Cobra", "base": "cobra", "tint": Color(1, 1, 1), "attacks": ["venom", "roar"]},
	"anubis": {"name": "Anubis the Guardian", "base": "mummy", "tint": Color(0.55, 0.6, 0.85), "attacks": ["smash", "roar"]},
	"beetle": {"name": "The Obsidian Beetle", "base": "golem", "tint": Color(0.45, 0.6, 0.5), "attacks": ["burrow", "glass"]},
	"sphinx": {"name": "The Sphinx", "base": "golem", "tint": Color(1.0, 0.9, 0.55), "attacks": ["gold", "roar"]},
	"pharaoh": {"name": "The Cursed Pharaoh", "base": "mummy", "tint": Color(1.0, 0.85, 0.4), "attacks": ["curse", "slam", "wrap"]},
}
const ATTACK_TEXT := {
	"slam": "slams the wall! More debris pours in!", "smash": "smashes the floor! Rocks burst up!",
	"sand": "flings sand over your gems!", "web": "spits webs over your gems!", "magma": "spits lava on your gems!",
	"wrap": "wraps your gems in bandages!", "venom": "spits venom! It spreads if you ignore it!",
	"roar": "roars and shoves Zaki back!", "burrow": "burrows up under the board!", "glass": "seals gems in obsidian!",
	"gold": "turns gems to gold!", "curse": "casts a creeping curse!",
}
const BOSS_EVERY := 3
## Gem covers: a covered gem is stuck. Matching next to it (or blasting it) removes one layer.
const COVER_HP := {"bandage": 1, "sand": 1, "web": 1, "magma": 1, "venom": 1, "glass": 2, "gold": 2, "curse": 1, "jar": 2}
const COVER_COL := {"bandage": Color("efe2c4"), "sand": Color("e0b46a"), "web": Color("f2f2ff"), "magma": Color("ff7a2a"),
	"venom": Color("6ee05a"), "glass": Color("6a6f8a"), "gold": Color("ffd34a"), "curse": Color("b05cff"), "jar": Color("c9774a")}
const PRAISE := ["", "", "Good!", "Great!", "Amazing!", "Unstoppable!"]

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
var area := {}             # everything on the far side of the door: open to the sky, full of debris
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

var meta = Meta.new()
var level_t0 := 0.0
var boosters_used := []
var hammer_armed := false
var tut_move := []
var sand_top := 0
var music: AudioStreamPlayer
var music_key := ""

# ---------- nodes ----------
var bg_layer: Node2D
var back_layer: Node2D
var hero: Sprite2D
var hero_b: Sprite2D      # next frame, cross-faded on top for smoother motion
var frame_tex := {}
var anim_t := 0.0
var pose_t := 0.0
var pose_prev := ""
var jit_t := 0.0
var jit_i := 0
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
var time_left := 100.0
# --- pressure: debris pushed in by a source shoves Zaki back toward the spikes ---
var shaft_cap := 1          # cells in the shaft area behind the door
var push_time := 60.0       # seconds to reach the spikes if the shaft stays full and nobody plays
var pour_left := 0.0        # seconds of pouring left in the current burst
var pour_rate := 0.0        # grains per second while pouring
var pour_cd := 0.0          # seconds until the next burst
var pour_acc := 0.0
var pour_x := 0.0           # where the source sits (world cells)
var push_max := 10.0        # how far Zaki can be shoved before he hits the spikes (cells)
var danger_shown := -1
var mound_col := Color(0.8, 0.65, 0.4)
var shaft_sand := 0
var shaft0 := 1
var door_swing := 0.0      # 0 closed (edge on) .. 1 swung open
var safe_x := 0.0
var safe_glow := 0.0
var push_ph := 0.0
var flinch := 0.0
var pound_prev := 0.0
var door_hit := 0.0
var sweat_t := 1.0
var hand_f := Vector2.ZERO
var hand_b := Vector2.ZERO
var hud_sec := -1
var level_gen := 0
var mode := "drain"
var wrapped := {}          # board cell id -> {"t": cover type, "hp": layers, "goal": counts for the goal}
var runes := {}            # board cell id -> true: sun runes waiting to be lit (Temple of Ra)
var raised := {}           # debris blocks a boss pushed up through the board
var cover_broken := false  # a cover came off this turn (stops venom and curse spreading)
var boss_kind := ""
var boss_base := ""
var boss_cd := 0
var boss_att_i := 0
var boss_tex: Texture2D
var boss_sprite: Sprite2D
var crust := {}            # debris block id -> true (cooled lava)
var last_hit := {}         # debris block id -> move number of its last hit
var move_no := 0
var hud_pct := -1
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
	boss_sprite = Sprite2D.new()
	boss_sprite.centered = false
	boss_sprite.z_index = 3
	boss_sprite.visible = false
	add_child(boss_sprite)
	for key in FramesData.FRAMES:
		var arr := []
		for f in FramesData.FRAMES[key]:
			arr.append(load(f.tex))
		frame_tex[key] = arr
	hero = Sprite2D.new()
	hero.centered = false
	add_child(hero)
	hero_b = Sprite2D.new()
	hero_b.centered = false
	add_child(hero_b)
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
	bg_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	frame_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	back_layer.z_index = 1
	hero.z_index = 10
	hero_b.z_index = 10
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

	music = AudioStreamPlayer.new()
	add_child(music)
	get_viewport().size_changed.connect(_layout)
	start_level(meta.current_level())
	_layout()
	if autotest:
		meta.lives = 99
		meta.coins = 9999
		for f in ["tip_boosters", "tip_boss"]:
			meta.flags[f] = true
	show_map()
	ui.show_title()
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
	for n in ["door_edge", "door_full", "spikewall", "spout_lion", "spout_ram"]:
		tex[n] = load("res://assets/gfx/props/%s.png" % n)
	tex.pillar = load("res://assets/gfx/stone/pillar.png")
	tex.hand = load("res://assets/gfx/ui/hand.png")
	# each world can have its own board tile (assets/gfx/board/tile_<world>.png)
	for w in WORLDS.size():
		var tp := "res://assets/gfx/board/tile_%d.png" % (w + 1)
		tex["tile_%d" % w] = load(tp) if ResourceLoader.exists(tp) else tex.tile
	tex.frieze = load("res://assets/gfx/stone/frieze.png")
	tex.stonewall = load("res://assets/gfx/stone/wall.jpg")
	for n in []:
		tex[n] = load("res://assets/gfx/props/%s.png" % n)
	tex.gems = [tex.gem_red, tex.gem_blue, tex.gem_gold, tex.gem_green]
	tex.scarab = load("res://assets/gfx/board/scarab.png")
	for n in ["rock_chips", "dust_puff", "sparks", "crystal_bolt", "lava_chunks", "crust_crack", "crust", "bandage_tear",
			"bandage", "combo_burst", "scarab_trail", "iron_dent", "crystal_cracks"]:
		tex["fx_" + n] = load("res://assets/gfx/fx/%s.png" % n)
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
		for ext in ["ogg", "mp3", "wav"]:
			var sp := "res://assets/sfx/%s.%s" % [n, ext]
			if ResourceLoader.exists(sp):
				sfx[n] = load(sp)
				break
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if not sfx.has(name) or not meta.settings.sound:
		return
	for p in players:
		if not p.playing:
			p.stream = sfx[name]
			p.pitch_scale = pitch
			p.volume_db = db
			p.play()
			return

func buzz(ms: int) -> void:
	if OS.has_feature("mobile") and meta.settings.vibration:
		Input.vibrate_handheld(ms)

func _load_progress() -> void:
	meta.setup(LEVELS.size())

# ---------- layout ----------
func _layout() -> void:
	var vs = get_viewport_rect().size
	var safe = _safe_insets()
	var top: float = safe.x + Ui.HUD_H
	var bottom = safe.y + 12.0 + Ui.BAR_H
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
	_fill_pockets()
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
	# the debris area runs from the door all the way to the far edge of the board
	area = {"x0": shaft.x0, "x1": BX + COLS * CELL, "y0": shaft.y0} if facing > 0 else {"x0": BX, "x1": shaft.x1, "y0": shaft.y0}
	sand = PackedByteArray()
	sand.resize(SW * SH)
	mask = PackedByteArray()
	mask.resize(SW * SH)
	grains = 0
	var extra_cells := 0
	for y in range(area.y0, BY):
		for x in range(area.x0, area.x1):
			mask[y * SW + x] = 1
			if y >= area.y0 + 7:
				sand[y * SW + x] = 1 + randi() % 3
				grains += 1
				if x < shaft.x0 or x >= shaft.x1:
					extra_cells += 1
	for id in rubble:
		var c: int = id % COLS
		var r: int = id / COLS
		for y in range(BY + r * CELL, BY + (r + 1) * CELL):
			for x in range(BX + c * CELL, BX + (c + 1) * CELL):
				mask[y * SW + x] = 1
				sand[y * SW + x] = 1 + randi() % 3
				grains += 1
	grains0 = grains
	shaft_cap = (BY - shaft.y0 - 5) * (shaft.x1 - shaft.x0)
	shaft0 = shaft_cap
	shaft_sand = _count_shaft()
	_compute_active_region()
	# the wider debris area holds more sand; most of it slides into the drain, so give moves for it
	moves = L.moves + roundi(extra_cells * 0.7 / 104.0)
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
	hero_x = _door_face() - facing * 3.9
	door_swing = 0.0
	safe_glow = 0.0
	level_gen += 1
	hero_alpha = 1.0
	time_left = float(L.time)
	push_time = float(L.get("push", L.time / 4.0))
	pour_rate = shaft_cap * 0.07 / 2.5
	pour_left = 3.0          # the source is still pouring when the level starts
	pour_cd = _pour_period()
	pour_acc = 0.0
	pour_x = (area.x0 + area.x1) * 0.5 + facing * 3.0
	danger_shown = -1
	mound_col = _avg_color(tex["grains_" + theme.grains]) * theme.gtint
	flinch = 0.0
	hud_sec = -1
	hud_pct = -1
	var sw_cells: float = SAFE_H * tex.door_full.get_width() / tex.door_full.get_height()
	safe_x = (area.x1 - sw_cells / 2.0 - 0.6) if facing > 0 else (area.x0 + sw_cells / 2.0 + 0.6)
	hero_lift = 0.0
	hero_alpha = 1.0
	push_max = maxf(4.0, absf(_door_face() - _hazard_front()) - 8.5)
	golem_attack = 0.0
	look_t = 0.0
	boss_kind = L.hazard if L.boss else ""
	boss_base = BOSSES[boss_kind].base if boss_kind != "" else ""
	var bp := "res://assets/gfx/bosses/%s.png" % boss_kind
	boss_tex = load(bp) if boss_kind != "" and ResourceLoader.exists(bp) else null
	boss_sprite.visible = boss_tex != null
	if boss_tex:
		boss_sprite.texture = boss_tex
	for kname in chasers:
		chasers[kname].visible = kname == boss_base and boss_tex == null
		chasers[kname].modulate = BOSSES[boss_kind].tint if kname == boss_base else Color.WHITE
	boss_cd = BOSS_EVERY + 1
	boss_att_i = 0
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
	ui.set_level(i + 1, ("BOSS · " + BOSSES[L.hazard].name) if L.boss else L.name, theme.ui)
	mode = L.get("mode", "drain")
	wrapped.clear()
	runes.clear()
	raised.clear()
	cover_broken = false
	crust.clear()
	last_hit.clear()
	move_no = 0
	if mode == "race":
		moves = 9999
	if mode == "wrap":
		var spots := []
		for r in range(2, ROWS):
			for c in COLS:
				if not is_rub(c, r):
					spots.append(r * COLS + c)
		spots.shuffle()
		for id in spots.slice(0, WRAP_COUNT):
			wrapped[id] = {"t": "bandage", "hp": 1, "goal": true}
	_setup_mode_obstacles()
	ui.update_hud(moves, 100)
	_update_extra()
	state = "paused"
	last_input = time
	sand_top = shaft.y0
	hammer_armed = false
	tut_move = []

## Gem areas too small to play in (cut off by debris) are filled with debris instead.
func _fill_pockets() -> void:
	var seen := {}
	for r in ROWS:
		for c in COLS:
			var id := r * COLS + c
			if rubble.has(id) or seen.has(id):
				continue
			var comp := [id]
			seen[id] = true
			var i := 0
			while i < comp.size():
				var cur: int = comp[i]
				i += 1
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nc: int = cur % COLS + d.x
					var nr: int = cur / COLS + d.y
					var nid := nr * COLS + nc
					if in_b(nc, nr) and not rubble.has(nid) and not seen.has(nid):
						seen[nid] = true
						comp.append(nid)
			if comp.size() < 12:
				for cid in comp:
					rubble[cid] = true

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
	var squares := _find_squares()
	if runs.is_empty() and squares.is_empty():
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
	# a 2x2 square of one colour is a match on its own, or joins the line it touches
	for sq in squares:
		var hit := -1
		for id in sq:
			if owner_of.has(id):
				hit = owner_of[id]
				break
		if hit < 0:
			hit = clusters.size()
			clusters.append({"cells": {}, "runs": []})
		clusters[hit]["square"] = true
		for id in sq:
			clusters[hit].cells[id] = true
			owner_of[id] = hit
	# a same-colour gem touching a line from the side joins it (an L or T of 4)
	for ci in clusters.size():
		var cl: Dictionary = clusters[ci]
		if cl.cells.is_empty() or cl.runs.is_empty():
			continue
		var add := []
		for id in cl.cells:
			var k := color_at(id % COLS, id / COLS)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: int = id % COLS + d.x
				var nr: int = id / COLS + d.y
				var nid := nr * COLS + nc
				if in_b(nc, nr) and not owner_of.has(nid) and color_at(nc, nr) == k:
					add.append(nid)
		for nid in add:
			if not owner_of.has(nid):
				cl.cells[nid] = true
				owner_of[nid] = ci
				cl["bent"] = true
	var out = []
	for cl in clusters:
		if not cl.cells.is_empty():
			out.append(cl)
	return out

func _find_squares() -> Array:
	var out := []
	for r in ROWS - 1:
		for c in COLS - 1:
			var k := color_at(c, r)
			if k >= 0 and color_at(c + 1, r) == k and color_at(c, r + 1) == k and color_at(c + 1, r + 1) == k:
				out.append([r * COLS + c, r * COLS + c + 1, (r + 1) * COLS + c, (r + 1) * COLS + c + 1])
	return out

# colour at (x, y) as if the gems at sw[0..1] and sw[2..3] were swapped (sw[4], sw[5] = their colours)
func _color_sw(x: int, y: int, sw: Array) -> int:
	if x == sw[0] and y == sw[1]:
		return sw[5]
	if x == sw[2] and y == sw[3]:
		return sw[4]
	return color_at(x, y)

func _square_sw(sw: Array, c: int, r: int) -> bool:
	var k := _color_sw(c, r, sw)
	for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var x: int = c + o.x
		var y: int = r + o.y
		if _color_sw(x, y, sw) == k and _color_sw(x + 1, y, sw) == k and _color_sw(x, y + 1, sw) == k and _color_sw(x + 1, y + 1, sw) == k:
			return true
	return false

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
				if a < 0 or b < 0 or a == b or wrapped.has(r * COLS + c) or wrapped.has(r2 * COLS + c2):
					continue
				var sw = [c, r, c2, r2, a, b]
				if _line_len(sw, c, r, 1, 0) >= 3 or _line_len(sw, c, r, 0, 1) >= 3 or _line_len(sw, c2, r2, 1, 0) >= 3 or _line_len(sw, c2, r2, 0, 1) >= 3 or _square_sw(sw, c, r) or _square_sw(sw, c2, r2):
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
## A one-shot sprite effect. `cell` picks a frame from a strip of `frames` equal squares.
func spr(t: Texture2D, x: float, y: float, s0: float, s1: float, dur: float, rot := 0.0, cell := -1, frames := 1, spin := 0.0) -> void:
	fx.append({"kind": "spr", "tex": t, "x": x, "y": y, "s0": s0, "s1": s1, "life": 0.0, "max": dur, "rot": rot,
		"cell": cell, "frames": frames, "spin": spin})

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
	_light_rune(int(round(m.x)), int(round(m.y)))
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

func damage_rubble(id: int, power := false, depth := 0) -> void:
	var c: int = id % COLS
	var r: int = id / COLS
	var hit := 0
	last_hit[id] = move_no
	if crust.has(id):
		# cooled lava: this hit only cracks the crust
		crust.erase(id)
		spr(tex.fx_crust_crack, cell_cx(c), cell_cy(r), CELL * g * 1.0, CELL * g * 1.8, 0.45, randf() * TAU)
		for k in 4:
			spr(tex.fx_lava_chunks, cell_cx(c) + (randf() - 0.5) * CELL * g, cell_cy(r) + (randf() - 0.5) * CELL * g,
				CELL * g * 0.5, CELL * g * 0.8, 0.5, randf() * TAU, -1, 1, (randf() - 0.5) * 4.0)
		play("crack", 1.1, -6.0)
		buzz(20)
		return
	var amount := RUBBLE_HIT
	if mode == "iron":
		amount = 49 if power else 13
	elif depth > 0:
		amount = 7
	# each hit breaks only part of the block (lowest grains first), so blocks take several hits
	var cells := []
	for y in range(BY + (r + 1) * CELL - 1, BY + r * CELL - 1, -1):
		for x in range(BX + c * CELL, BX + (c + 1) * CELL):
			if sand[y * SW + x] != 0:
				cells.append(y * SW + x)
	for i in cells.slice(0, amount):
		var x: int = i % SW
		var y: int = i / SW
		var v = sand[i]
		if true:
			sand[i] = 0
			grains -= 1
			hit += 1
			if randf() < 0.4:
				var a = -PI / 2.0 + (randf() - 0.5) * 2.2
				var sp = (120.0 + randf() * 260.0) * g / 6.0
				parts.append({"x": wx(x + 0.5), "y": wy(y + 0.5), "vx": cos(a) * sp, "vy": sin(a) * sp, "life": 0.0,
					"max": 0.7 + randf() * 0.4, "col": theme.gtint, "v": v, "size": g * 1.4, "grav": 900.0 * g / 6.0, "kind": "grain"})
	if hit > 0 and mode == "chain" and depth < 1:
		# crystals crack in chains: the touching crystal blocks crack too
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: int = c + d.x
			var nr: int = r + d.y
			if in_b(nc, nr) and is_rub(nc, nr):
				var nid: int = nr * COLS + nc
				var dd: int = depth + 1
				fx.append({"kind": "cbolt", "x0": cell_cx(c), "y0": cell_cy(r), "x1": cell_cx(nc), "y1": cell_cy(nr), "life": 0.0, "max": 0.35})
				later(0.14, func(): damage_rubble(nid, false, dd))
	if raised.has(id) and not _block_has_sand(id):
		_lower_rubble(id)
	if hit > 0:
		sand_sleep = false
		sand_dirty = true
		sparkle(cell_cx(c), cell_cy(r), 3)
		var left := 1.0 - float(cells.size() - hit) / float(CELL * CELL)
		var stage := clampi(int(left * 3.0), 0, 2)
		var cx := cell_cx(c)
		var cy := cell_cy(r)
		match mode:
			"iron":
				spr(tex.fx_iron_dent, cx, cy, CELL * g, CELL * g * 1.05, 0.5, 0.0, stage, 3)
				spr(tex.fx_sparks, cx, cy, CELL * g * 0.6, CELL * g * 1.6, 0.35, randf() * TAU)
			"chain":
				spr(tex.fx_crystal_cracks, cx, cy, CELL * g, CELL * g * 1.05, 0.5, 0.0, stage, 3)
			"crust":
				spr(tex.fx_lava_chunks, cx, cy, CELL * g * 0.6, CELL * g * 1.3, 0.4, randf() * TAU, -1, 1, 2.0)
			_:
				spr(tex.fx_dust_puff, cx, cy, CELL * g * 0.6, CELL * g * 1.5, 0.45, randf() * TAU)
				spr(tex.fx_rock_chips, cx, cy, CELL * g * 0.5, CELL * g * 1.4, 0.4, randf() * TAU, -1, 1, 1.5)
		fx.append({"kind": "ring", "x": cell_cx(c), "y": cell_cy(r), "r0": g, "r1": CELL * g * 0.8, "life": 0.0, "max": 0.35,
			"col": Color("fff2c0")})
	_update_hud()

func _update_hud() -> void:
	var p := maxi(0, ceili(shaft_sand * 100.0 / shaft0))
	hud_pct = p
	ui.update_hud(moves, p)

## Lava blocks nobody has hit for 3 moves cool into crust.
func _cool_lava() -> void:
	for id in rubble:
		if crust.has(id):
			continue
		if move_no - int(last_hit.get(id, 0)) >= 6 and _block_has_sand(id):
			crust[id] = true

func _block_has_sand(id: int) -> bool:
	var c: int = id % COLS
	var r: int = id / COLS
	for y in range(BY + r * CELL, BY + (r + 1) * CELL):
		for x in range(BX + c * CELL, BX + (c + 1) * CELL):
			if sand[y * SW + x] != 0:
				return true
	return false

func _count_shaft() -> int:
	var n := 0
	for y in range(shaft.y0, BY):
		for x in range(shaft.x0, shaft.x1):
			if sand[y * SW + x] != 0:
				n += 1
	return n

func _door_face() -> float:
	# x (cells) of the door's room-side face
	return door_col + 0.5 - facing * DOOR_EDGE_W / 2.0

func door_ready() -> bool:
	return shaft_sand <= maxi(4, roundi(shaft0 * 0.02))

## The level's goal: the door is free, plus any extra goal the mode adds.
func goal_done() -> bool:
	return door_ready() and _goal_left() == 0

func _goal_left() -> int:
	var n := runes.size()
	for id in wrapped:
		if wrapped[id].goal:
			n += 1
	return n

func _update_extra() -> void:
	var parts_t := []
	var goal := _goal_left()
	match mode:
		"wrap":
			parts_t.append("Bandages %d" % goal)
		"jars":
			parts_t.append("Jars %d" % goal)
		"glass":
			parts_t.append("Glass %d" % goal)
		"runes":
			parts_t.append("Runes %d" % goal)
		"curse":
			parts_t.append("Curse %d" % goal)
		"race":
			parts_t.append("No move limit")
	if boss_kind != "" and state != "won":
		parts_t.append("Attack in %d" % boss_cd)
	ui.set_extra(" · ".join(parts_t))

func _unwrap(id: int) -> void:
	if not wrapped.has(id):
		return
	var d: Dictionary = wrapped[id]
	var c := id % COLS
	var r := id / COLS
	var col: Color = COVER_COL[d.t]
	d.hp -= 1
	cover_broken = true
	if d.hp > 0:
		# first layer cracks
		fx.append({"kind": "ring", "x": cell_cx(c), "y": cell_cy(r), "r0": g, "r1": CELL * g * 0.7, "life": 0.0, "max": 0.3, "col": col})
		burst(cell_cx(c), cell_cy(r), col, 6, 0.7)
		play("crack", 1.5, -8.0)
		return
	wrapped.erase(id)
	match d.t:
		"bandage":
			spr(tex.fx_bandage_tear, cell_cx(c), cell_cy(r), CELL * g * 0.9, CELL * g * 1.8, 0.45, randf() * TAU)
		"jar":
			# the jar breaks and leaves a rocket behind
			var m = grid[r][c]
			if m != null:
				m.kind = "rocket"
				m.dir = "h" if randf() < 0.5 else "v"
				m.scale = 0.2
				tween(m, {"scale": 1.0}, 0.3, "back")
			for k in 5:
				spr(tex.fx_rock_chips, cell_cx(c), cell_cy(r), CELL * g * 0.5, CELL * g * 1.4, 0.45, randf() * TAU, -1, 1, 2.0)
			play("crack", 0.9, -4.0)
		_:
			fx.append({"kind": "ring", "x": cell_cx(c), "y": cell_cy(r), "r0": g, "r1": CELL * g * 0.9, "life": 0.0, "max": 0.35, "col": col})
	burst(cell_cx(c), cell_cy(r), col, 10, 0.9)
	sparkle(cell_cx(c), cell_cy(r), 3)
	play("crack", 1.6, -10.0)
	_update_extra()

func _light_rune(c: int, r: int) -> void:
	var id := r * COLS + c
	if not runes.has(id):
		return
	runes.erase(id)
	fx.append({"kind": "ring", "x": cell_cx(c), "y": cell_cy(r), "r0": g, "r1": CELL * g * 1.1, "life": 0.0, "max": 0.5, "col": Color("ffe27a")})
	for k in 3:
		sparkle(cell_cx(c), cell_cy(r), 3)
	play("shine", 1.4, -8.0)
	_update_extra()

func _solid(c: int, r: int) -> bool:
	return is_rub(c, r) or wrapped.has(r * COLS + c)

func _avg_color(t: Texture2D) -> Color:
	var img := t.get_image()
	if img == null:
		return Color(0.8, 0.65, 0.4)
	if img.is_compressed():
		img.decompress()
	var acc := Color(0, 0, 0, 0)
	var n := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				acc += c
				n += 1
	if n == 0:
		return Color(0.8, 0.65, 0.4)
	acc /= float(n)
	acc.a = 1.0
	return acc

## How full the area behind the door is (0..1).
func _fill() -> float:
	return clampf(float(shaft_sand) / float(shaft_cap), 0.0, 1.0)

## Seconds between debris bursts: shorter in later worlds.
func _pour_period() -> float:
	return lerpf(15.0, 9.0, clampf(float(L.get("world", 0)) / 9.0, 0.0, 1.0)) + randf() * 3.0

## Pressure pushes Zaki back while the shaft is full; he wins ground back once it is mostly drained.
func _push_rate() -> float:
	var f := _fill()
	return (1.6 * f - 0.38) / push_time

## The source drops debris into the top of the shaft.
func _pour(dt: float) -> void:
	if pour_left <= 0.0:
		return
	pour_left -= dt
	pour_acc += pour_rate * dt
	var w: int = area.x1 - area.x0
	var placed := 0
	while pour_acc >= 1.0:
		pour_acc -= 1.0
		var spread := maxf(2.0, w * 0.2)
		var x := clampi(int(pour_x + randf_range(-spread, spread) * 0.5), area.x0, area.x1 - 1)
		for y in range(shaft.y0 + 5, shaft.y0 + 8):
			var i: int = y * SW + x
			if mask[i] == 1 and sand[i] == 0:
				sand[i] = 1 + randi() % 3
				grains += 1
				placed += 1
				break
	if placed > 0:
		sand_sleep = false
		sand_top = mini(sand_top, shaft.y0)
		sand_dirty = true

func pour_burst(sec: float, rate_mul := 1.0) -> void:
	pour_left = maxf(pour_left, sec)
	pour_rate = shaft_cap * 0.07 / 2.5 * rate_mul
	play("sand", 0.7, -6.0)

## Where Zaki's hands are: the door face, minus how far the debris has pushed him back.
func _push_face() -> float:
	return _door_face() - facing * hz_p * push_max

# ---------- gravity / refill ----------
func collapse() -> void:
	for c in COLS:
		var r = ROWS - 1
		while r >= 0:
			if _solid(c, r):
				r -= 1
				continue
			var bottom = r
			while r >= 0 and not _solid(c, r):
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
	if cl.runs.is_empty():
		return cl.cells.keys()[0]
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
		elif cl.get("square", false):
			kind = "scarab"
		elif max_len == 4:
			kind = "rocket"
			for rn in cl.runs:
				if rn.cells.size() == 4:
					dir = "v" if rn.h else "h"
		elif cl.get("bent", false) and cl.cells.size() >= 5:
			kind = "bomb"
		elif cl.get("bent", false):
			kind = "rocket"
			dir = "h" if cl.runs[0].h else "v"
		var spawn = _pick_spawn(cl) if kind != "" else -1
		for id in cl.cells:
			var c: int = id % COLS
			var r: int = id / COLS
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if in_b(nc, nr) and is_rub(nc, nr):
					rub[nr * COLS + nc] = true
				if in_b(nc, nr) and wrapped.has(nr * COLS + nc):
					_unwrap(nr * COLS + nc)
			_unwrap(id)
			if id == spawn:
				continue
			t_end = maxf(t_end, _pop_gem(grid[r][c]))
		if kind != "":
			made_special = true
			_power_tip(kind)
			if mode == "race":
				hz_p = maxf(0.0, hz_p - 0.015)
				ui.toast("+%d seconds!" % int(RACE_BONUS))
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
				spr(tex.fx_combo_burst, cell_cx(m.x), cell_cy(m.y), CELL * g * 0.6, CELL * g * 2.2, 0.5, 0.0, -1, 1, 1.2)
				tween(m, {"scale": 1.0}, 0.26, "back")
			)
			t_end = maxf(t_end, 0.4)
	if made_special:
		later(0.12, func(): play("shine", 1.0, -4.0))
	later(0.09, func():
		for id in rub:
			damage_rubble(id, false)
		if not rub.is_empty():
			buzz(15)
	)
	await wait(t_end)

func cascade() -> void:
	var waves := 0
	for _guard in 30:
		var cls = find_clusters()
		if cls.is_empty():
			break
		waves += 1
		await _resolve_clusters(cls)
		last_swap = []
		await collapse()
	if waves >= 2 and state != "won":
		ui.praise(PRAISE[mini(waves, PRAISE.size() - 1)])
		play("shine", 1.0 + waves * 0.08, -6.0)

func _scarab_target(c0: int, r0: int) -> int:
	var best := -1
	var best_n := 0
	for id in rubble:
		var n := 0
		var bc: int = id % COLS
		var br: int = id / COLS
		for y in range(BY + br * CELL, BY + (br + 1) * CELL):
			for x in range(BX + bc * CELL, BX + (bc + 1) * CELL):
				if sand[y * SW + x] != 0:
					n += 1
		n += (ROWS - br) * 3   # prefer blocks near the top, closer to the door
		if n > best_n:
			best_n = n
			best = id
	if best < 0:
		best = randi() % (COLS * ROWS)
	return best

func _area_for(s: Dictionary) -> Array:
	var out = []
	var c: int = s.c
	var r: int = s.r
	if s.kind == "scarab":
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if in_b(c + d.x, r + d.y):
				out.append([c + d.x, r + d.y, 0.05])
		if not s.has("target"):
			s.target = _scarab_target(c, r)
		var t: int = s.target
		out.append([t % COLS, t / COLS, 0.45])
		if is_rub(t % COLS, t / COLS):
			later(0.45, func(): spr(tex.fx_combo_burst, cell_cx(t % COLS), cell_cy(t / COLS), CELL * g, CELL * g * 2.4, 0.4))
			later(0.6, func(): damage_rubble(t, true))
		return out
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
	if k == "scarab":
		var t: int = s.get("target", -1)
		if t >= 0:
			fx.append({"kind": "scarab", "x0": x, "y0": y, "x1": cell_cx(t % COLS), "y1": cell_cy(t / COLS), "life": 0.0, "max": 0.45})
		play("zap", 1.5, -6.0)
		buzz(20)
		return
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
			if wrapped.has(id):
				var wid: int = id
				later(delay, func(): _unwrap(wid))
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
		later(rub[id], func(): damage_rubble(rid, true))
		max_d = maxf(max_d, rub[id])
	await wait(max_d + 0.08)

func try_swap(a: Vector2i, b: Vector2i) -> void:
	var A = grid[a.y][a.x]
	var B = grid[b.y][b.x]
	if A == null or B == null or A.dying or B.dying:
		return
	if wrapped.has(a.y * COLS + a.x) or wrapped.has(b.y * COLS + b.x):
		play("bad", 1.0, -8.0)
		var wid: int = a.y * COLS + a.x if wrapped.has(a.y * COLS + a.x) else b.y * COLS + b.x
		fx.append({"kind": "ring", "x": cell_cx(wid % COLS), "y": cell_cy(wid / COLS), "r0": g, "r1": CELL * g * 0.6, "life": 0.0, "max": 0.3, "col": Color("efe2c4")})
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
		if mode != "race":
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
	_tutorial_swapped()
	if mode != "race":
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
	if mode != "race":
		moves -= 1
	_update_hud()
	var sd0 = {"c": c, "r": r, "kind": m.kind, "dir": m.dir, "delay": 0.0, "src": m}
	if m.kind == "light":
		sd0.color = most_common_color()
	await detonate([sd0])
	await collapse()
	await cascade()
	await end_turn()

func end_turn() -> void:
	shaft_sand = _count_shaft()
	if goal_done():
		_win()
		return
	move_no += 1
	if mode == "crust":
		_cool_lava()
	for id in raised.keys():
		if not _block_has_sand(id):
			_lower_rubble(id)
	if not cover_broken:
		_spread_covers()
	cover_broken = false
	if boss_kind != "" and moves > 0:
		boss_cd -= 1
		if boss_cd <= 0:
			boss_cd = BOSS_EVERY
			await _boss_attack()
		_update_extra()
	if moves <= 0:
		state = "busy"
		var t0 = time
		while time - t0 < 1.6 and sand_moved > 0:
			await wait(0.1)
		shaft_sand = _count_shaft()
		if goal_done():
			_win()
			return
		_lose(false)
		return
	if find_move().is_empty() and has_special().x < 0:
		await _shuffle()
	state = "idle"
	last_input = time

func _shuffle(msg := "No moves left. Shuffling!") -> void:
	ui.toast(msg)
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
	var gen := level_gen
	hammer_armed = false
	tut_move = []
	ui.set_tip("")
	var ratio: float = (1.0 - hz_p) if mode == "race" else float(moves) / float(L.moves)
	var win_stars: int = 3 if ratio >= 0.3 else (2 if ratio >= 0.12 else 1)
	var moves_left: int = int(time_left) if mode == "race" else moves
	var left_bonus: int = int(time_left / 5.0) if mode == "race" else moves
	var fired := await _bonus_rockets(mini(left_bonus, 12), gen)
	if gen != level_gen:
		return
	await _escape()
	if gen != level_gen:
		return
	var rest = []
	for i in sand.size():
		if sand[i] != 0:
			rest.append(i)
	for k in rest.size():
		var i: int = rest[k]
		later(k * 0.008, func():
			if gen != level_gen or sand[i] == 0:
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
	if gen != level_gen:
		return
	grains = 0
	_update_hud()
	rubble.clear()
	bg_layer.queue_redraw()
	play("win")
	buzz(60)
	await collapse()
	if gen != level_gen:
		return
	var stars := win_stars
	var earned: int = 10 + stars * 5 + fired * 3 + (50 if L.boss else 0)
	meta.earn(earned)
	meta.log_event("level_end", {"level": level_idx + 1, "mode": mode, "result": "won", "moves_left": moves_left,
		"stars": stars, "seconds": int(time - level_t0), "boosters": boosters_used}, self)
	if stars > int(meta.best[level_idx]):
		meta.best[level_idx] = stars
		meta.save()
	for k in 30:
		later(k * 0.04, func(): sparkle(ox + randf() * SW * g, oy + randf() * BY * g, 3))
	await wait(0.9)
	if gen != level_gen:
		return
	_music("map")
	ui.show_win(stars, earned, L.boss, level_idx < LEVELS.size() - 1)

## Royal-Match style finale: every move left turns into a rocket that fires across the board.
func _bonus_rockets(count: int, gen: int) -> int:
	if count <= 0:
		return 0
	ui.praise("Bonus!")
	await wait(0.5)
	var cells := []
	for r in ROWS:
		for c in COLS:
			var m = grid[r][c]
			if m != null and m.kind == "gem" and not m.dying and not wrapped.has(r * COLS + c):
				cells.append(Vector2i(c, r))
	cells.shuffle()
	count = mini(count, cells.size())
	var seeds := []
	for k in count:
		if gen != level_gen:
			return 0
		var cl: Vector2i = cells[k]
		var m: Gem = grid[cl.y][cl.x]
		m.kind = "rocket"
		m.dir = "h" if randf() < 0.5 else "v"
		m.color = -1
		tween(m, {"scale": 1.25}, 0.08)
		tween(m, {"scale": 1.0}, 0.12, "out", 0.08)
		spr(tex.fx_combo_burst, cell_cx(cl.x), cell_cy(cl.y), CELL * g * 0.4, CELL * g * 1.6, 0.35)
		play("shine", 1.0 + k * 0.05, -9.0)
		if mode != "race":
			moves = maxi(0, moves - 1)
		else:
			time_left = maxf(0.0, time_left - 5.0)
		_update_hud()
		await wait(0.1)
	for k in count:
		var cl: Vector2i = cells[k]
		var m = grid[cl.y][cl.x]
		if m != null and m.kind == "rocket":
			seeds.append({"c": cl.x, "r": cl.y, "kind": "rocket", "dir": m.dir, "delay": k * 0.12, "src": m})
	await detonate(seeds)
	await collapse()
	return count

func _escape() -> void:
	# the sand no longer holds the door: Zaki heaves it open and runs for the safe door
	look_t = 0.0
	hero_pose = "push"
	tween(self, {"hz_p": 0.0}, 0.35, "out")
	await wait(0.4)
	# whatever debris is left on the far side collapses into the drain
	for y in range(area.y0, BY):
		for x in range(area.x0, area.x1):
			var i: int = y * SW + x
			if sand[i] != 0:
				if randf() < 0.08:
					parts.append({"x": wx(x + 0.5), "y": wy(y + 0.5), "vx": (randf() - 0.5) * 80.0 * g / 6.0, "vy": 0.0,
						"life": 0.0, "max": 0.7, "col": theme.gtint, "v": sand[i], "size": g * 1.3, "grav": 900.0 * g / 6.0, "kind": "grain"})
				sand[i] = 0
				grains -= 1
	sand_dirty = true
	play("crack", 1.3, -6.0)
	burst(wx(door_col + 0.5), wy(BY - 3), Color("c9a46a"), 12, 0.8)
	tween(self, {"door_swing": 1.0}, 0.8, "in")
	buzz(30)
	await wait(0.35)
	hero_pose = "cheer"
	await wait(0.45)
	hero_pose = "run"
	var dist := absf(safe_x - hero_x)
	var dur := dist / 11.0
	tween(self, {"hero_x": safe_x}, dur, "lin")
	tween(self, {"safe_glow": 1.0}, dur, "lin")
	await wait(dur)
	hero_pose = "wave"
	play("shine", 1.2, -4.0)
	await wait(0.55)
	hero_pose = "walkin"
	tween(self, {"hero_alpha": 0.0}, 0.7, "in")
	for k in 10:
		later(k * 0.05, func(): sparkle(wx(safe_x), wy(BY - SAFE_H * 0.5), 3))
	await wait(0.6)

func _set_room_mask(v: int) -> void:
	for y in range(room.y0, room.y1):
		for x in range(room.x0, room.x1):
			mask[y * SW + x] = v
		mask[y * SW + door_col] = v
	_compute_active_region()
	sand_sleep = false

func _lose(timed_out := false) -> void:
	state = "lost"
	var gen := level_gen
	hero_pose = "scared"
	play("boom", 0.6, -6.0)
	await wait(1.3)
	shake = 0.4
	buzz(80)
	play("lose")
	await wait(1.0)
	if gen != level_gen:
		return
	var left = ceili(shaft_sand * 100.0 / shaft0) if shaft_sand > 0 else 0
	meta.log_event("level_end", {"level": level_idx + 1, "mode": mode, "result": "lost", "moves_left": 0,
		"sand_left": left, "seconds": int(time - level_t0), "boosters": boosters_used, "timed_out": timed_out}, self)
	ui.show_lose(left, "Out of moves!" if not timed_out else ("The boss got Zaki!" if L.boss else "Pushed into the spikes!"))

func plus_five() -> void:
	if not meta.use_booster("moves5"):
		ui.toast("Not enough coins")
		return
	boosters_used.append("moves5")
	moves += 5
	hz_p = minf(hz_p, 0.55)
	pour_left = 0.0
	pour_cd = _pour_period()
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

func show_map() -> void:
	state = "map"
	meta.tick_lives()
	ui.show_map()
	_music("map")

func select_level(i: int) -> void:
	meta.tick_lives()
	if meta.lives <= 0:
		ui.show_no_lives()
		return
	var lv: Dictionary = LEVELS[i]
	var m: String = lv.mode
	var first := not meta.seen("mode_" + m)
	var badge := "res://assets/gfx/badges/badge_%s.png" % m
	var text: String = MODES[m].text if first else MODE_SHORT[m]
	if lv.boss:
		var bd: Dictionary = BOSSES[lv.hazard]
		var acts := []
		for a in bd.attacks:
			acts.append(ATTACK_TEXT[a].split("!")[0])
		text = bd.name + " waits behind Zaki instead of the spikes, and every %d moves it %s. " % [BOSS_EVERY, " or ".join(acts)] + text
	ui.show_intro(i, lv.boss, MODES[m].title, text, load(badge) if ResourceLoader.exists(badge) else null)

func begin_level(i: int, pre: Array) -> void:
	meta.mark("mode_" + LEVELS[i].mode)
	ui.hide_map()
	ui.hide_overlay()
	start_level(i)
	boosters_used = pre.duplicate()
	level_t0 = time
	for key in pre:
		_place_pre_booster(key)
	state = "idle"
	last_input = time
	_music("boss" if L.boss else "level_" + L.theme)
	meta.log_event("level_start", {"level": i + 1, "mode": mode, "boss": L.boss, "lives": meta.lives}, self)
	_tutorial_start()

func next_level() -> void:
	select_level(mini(level_idx + 1, LEVELS.size() - 1))

func retry_level() -> void:
	select_level(level_idx)

func give_up(to_map: bool) -> void:
	meta.lose_life()
	if to_map:
		show_map()
	else:
		retry_level()

func quit_level() -> void:
	meta.log_event("level_end", {"level": level_idx + 1, "mode": mode, "result": "quit", "moves_left": moves,
		"sand_left": hud_pct, "seconds": int(time - level_t0), "boosters": boosters_used}, self)
	meta.lose_life()
	show_map()

func open_menu() -> void:
	if state == "busy" or state == "map":
		return
	if state == "idle":
		state = "paused"
	ui.show_pause()

func _place_pre_booster(key: String) -> void:
	var spots := []
	for r in ROWS:
		for c in COLS:
			var m = grid[r][c]
			if m != null and m.kind == "gem" and not wrapped.has(r * COLS + c):
				spots.append([_near_rub(c, r) + randf() * 0.3, Vector2i(c, r)])
	spots.sort_custom(func(a, b): return a[0] > b[0])
	for sp in spots:
		var cl: Vector2i = sp[1]
		var m: Gem = grid[cl.y][cl.x]
		if m.kind != "gem":
			continue
		m.kind = "rocket" if key == "pre_rocket" else "scarab"
		m.dir = "h" if randf() < 0.5 else "v"
		m.color = -1
		later(0.3, func(): spr(tex.fx_combo_burst, cell_cx(cl.x), cell_cy(cl.y), CELL * g * 0.6, CELL * g * 2.2, 0.5))
		return

# ---------- in-level boosters ----------
func use_booster(key: String) -> void:
	if state != "idle":
		return
	if key == "hammer" and hammer_armed:
		hammer_armed = false
		ui.set_tip("")
		ui.refresh_bar()
		return
	if not meta.use_booster(key):
		ui.toast("Not enough coins")
		play("bad", 1.0, -8.0)
		return
	boosters_used.append(key)
	ui.refresh_bar()
	match key:
		"hammer":
			hammer_armed = true
			ui.set_tip("Tap a gem or a sand block to smash it.")
			ui.refresh_bar()
		"shuffle":
			state = "busy"
			await _shuffle("Shuffling the board!")
			state = "idle"
		"moves5":
			if mode == "race":
				ui.toast("Zaki pushes back!")
			else:
				moves += 5
				ui.toast("+5 moves")
			hz_p = maxf(0.0, hz_p - 0.2)
			_update_hud()
			play("shine", 1.0, -4.0)

func _raw_cell(p: Vector2) -> Vector2i:
	var c = int(floor((p.x - ox - BX * g) / (CELL * g)))
	var r = int(floor((p.y - oy - BY * g) / (CELL * g)))
	return Vector2i(c, r) if in_b(c, r) else Vector2i(-1, -1)

func _hammer_at(cell: Vector2i) -> void:
	hammer_armed = false
	ui.refresh_bar()
	ui.set_tip("")
	state = "busy"
	var id := cell.y * COLS + cell.x
	spr(tex.fx_combo_burst, cell_cx(cell.x), cell_cy(cell.y), CELL * g * 0.6, CELL * g * 2.2, 0.4)
	play("boom", 1.4, -6.0)
	buzz(30)
	shake = 0.15
	if is_rub(cell.x, cell.y):
		damage_rubble(id, true)
		damage_rubble(id, true)
		await wait(0.3)
	else:
		if wrapped.has(id):
			_unwrap(id)
		var m = grid[cell.y][cell.x]
		if m != null:
			var sd := {"c": cell.x, "r": cell.y, "kind": m.kind if m.kind != "gem" else "single", "dir": m.dir, "delay": 0.0, "src": m}
			if m.kind == "light":
				sd.color = most_common_color()
			await detonate([sd])
	await collapse()
	await cascade()
	shaft_sand = _count_shaft()
	if goal_done():
		_win()
		return
	state = "idle"
	last_input = time

# ---------- tutorial and tips ----------
func _tutorial_start() -> void:
	if level_idx == 0 and not meta.seen("tut_swipe"):
		var ms := all_moves()
		ms.sort_custom(func(a, b): return _near_rub(a[0].x, a[0].y) + _near_rub(a[1].x, a[1].y) > _near_rub(b[0].x, b[0].y) + _near_rub(b[1].x, b[1].y))
		if not ms.is_empty():
			tut_move = ms[0]
			ui.set_tip("Swipe a gem to make a line of 3. Matches next to the sand break it and free Zaki's door!")
	elif level_idx >= 4 and not meta.seen("tip_boosters"):
		meta.mark("tip_boosters")
		ui.set_tip("Stuck? Use a booster below: Hammer, Shuffle or +5 Moves.", 6.0)
	elif L.boss and not meta.seen("tip_boss"):
		meta.mark("tip_boss")
		ui.set_tip("Boss level! The monster replaces the gate. Free the door before it reaches Zaki.", 6.0)

func _tutorial_swapped() -> void:
	if not tut_move.is_empty():
		tut_move = []
		meta.mark("tut_swipe")
		ui.set_tip("Great! Keep going. When no sand is left against the door, Zaki escapes.", 5.0)

const POWER_TIPS := {
	"rocket": "Rocket! 4 in a line. Tap it or swap it to blast a whole row.",
	"bomb": "Bomb! An L or T shape. It blasts everything around it.",
	"light": "Rainbow orb! 5 in a line. Swap it with a gem to clear that colour.",
	"scarab": "Scarab! A 2x2 square. It flies into the sand and hits it hard.",
}

func _power_tip(kind: String) -> void:
	if POWER_TIPS.has(kind) and not meta.seen("tip_" + kind):
		meta.mark("tip_" + kind)
		ui.set_tip(POWER_TIPS[kind], 4.5)

# ---------- music ----------
func _music(key: String) -> void:
	if key == music_key:
		return
	music_key = key
	var cands := ["res://assets/music/%s.ogg" % key, "res://assets/music/%s.mp3" % key]
	if key.begins_with("level_"):
		cands += ["res://assets/music/level.ogg", "res://assets/music/level.mp3"]
	var stream: AudioStream = null
	for c in cands:
		if ResourceLoader.exists(c):
			stream = load(c)
			break
	if stream == null:
		music.stop()
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	music.stream = stream
	music.volume_db = -8.0 if meta.settings.music else -80.0
	music.play()

func apply_settings() -> void:
	meta.save()
	if music:
		music.volume_db = -8.0 if meta.settings.music else -80.0

func resume() -> void:
	ui.hide_overlay()
	state = "idle"
	last_input = time

func level_unlocked(i: int) -> bool:
	return meta.unlocked(i)

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
		if hammer_armed:
			var hc := _raw_cell(pos)
			if hc.x >= 0:
				_hammer_at(hc)
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
	var top_found := SH
	for y in range(ay1 - 1, maxi(ay0, sand_top - 1) - 1, -1):
		var base: int = y * SW
		var ltr = ((y + flip) & 1) == 1
		for k in w:
			var x: int = (ax0 + k) if ltr else (ax1 - 1 - k)
			var i: int = base + x
			var v = sand[i]
			if v == 0:
				continue
			if y < top_found:
				top_found = y
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
	sand_top = top_found
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
	if music and music.playing and (state == "idle" or state == "busy"):
		music.pitch_scale = lerpf(music.pitch_scale, 1.0 + hz_p * 0.06, minf(1.0, dt * 2.0))
	elif music:
		music.pitch_scale = lerpf(music.pitch_scale, 1.0, minf(1.0, dt * 2.0))
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
		var max_steps: int = 3 if Engine.get_frames_per_second() >= 45 else 2
		while sand_acc >= 1.0 and steps < max_steps:
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
		if not shaft.is_empty():
			shaft_sand = _count_shaft()
			var pc := maxi(0, ceili(shaft_sand * 100.0 / shaft0))
			if pc != hud_pct:
				_update_hud()
		if state == "idle" or state == "busy":
			time_left = maxf(0.0, time_left - dt)
			_pour(dt)
			pour_cd -= dt
			if pour_cd <= 0.0 and not door_ready():
				pour_cd = _pour_period()
				pour_burst(2.5)
			hz_p = clampf(hz_p + _push_rate() * dt, 0.0, 1.0)
			if state == "idle" and goal_done():
				_win()
			elif state == "idle" and hz_p >= 1.0:
				state = "busy"
				_lose(true)
		var dp := roundi(hz_p * 100.0) * 2 + (1 if pour_left > 0.0 else 0)
		if dp != danger_shown:
			danger_shown = dp
			ui.update_danger(hz_p, pour_left > 0.0)
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
			var dz := hz_p
			var heave := 0.5 + 0.5 * sin(push_ph)
			var panic := clampf((dz - 0.7) / 0.3, 0.0, 1.0)
			var shake_k := sin(t * 42.0) * 0.035 * clampf((dz - 0.4) * 2.5, 0.0, 1.0)
			var d := {"torso": 0.2 + heave * 0.1 * (1.0 - panic) + dz * 0.05 + shake_k * 0.5,
				"head": -0.18 + heave * 0.06,
				"leg_up_f": -0.48, "leg_lo_f": 0.28 + shake_k,
				"leg_up_b": 0.24 + heave * 0.08 * (1.0 - panic), "leg_lo_b": 0.05 - shake_k}
			if look_t > 0.0 or flinch > 0.0:
				d.torso -= 0.14
				d.head = 0.32
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
	if hero_pose == "push" and (flinch > 0.0 or (hz_p > 0.75 and look_t > 0.0)):
		return "scared"
	match hero_pose:
		"scared":
			return "scared"
		"cheer", "run", "jump":
			return "happy"
	if look_t > 0.0:
		return "look" if hz_p < 0.75 else "scared"
	if blink_t < 0.12:
		return "blink"
	var heave := 0.5 + 0.5 * sin(push_ph)
	return "strain" if heave > 0.55 or hz_p > 0.45 else "neutral"

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

## Picks Zaki's animation frame from the AI sprite sheets and stands him on the floor.
## Pushing frames are placed by their palms on the door face, so the hands never pass through it.
func _hero_frames(dt: float) -> void:
	var key := "push"
	var idx := 0
	var nxt := -1
	var blend := 0.0
	var shake_extra := 0.0
	var fps := 7.0 + hz_p * 7.0
	anim_t += dt * fps
	jit_t -= dt
	if jit_t <= 0.0:
		jit_t = 0.09
		jit_i = randi() % 3 - 1
	var by_hand := false
	if hero_pose != pose_prev:
		pose_prev = hero_pose
		pose_t = 0.0
	pose_t += dt
	match hero_pose:
		"push":
			by_hand = true
			if flinch > 0.0:
				key = "fright"
				idx = 3
			elif hz_p < 0.35:
				key = "push"
				var q := fmod(anim_t * 0.75, 8.0)
				idx = int(q)
			elif hz_p < 0.7:
				key = "fright"
				var q := fmod(anim_t * 0.6, 8.0)
				idx = int(q)
			else:
				var esc := clampi(int((hz_p - 0.7) / 0.3 * 5.0 + 0.5), 0, 5)
				if sin(hero_t * 0.9) > 0.35:
					key = "pound"
					idx = int(anim_t * 0.9) % 8
					by_hand = false
				else:
					key = "fright"
					idx = int(anim_t * 0.6) % 8
		"run":
			key = "run"
			var q := fmod(hero_t * 13.0, 8.0)
			idx = int(q)
		"scared":
			key = "caught"
			idx = mini(3, int(pose_t * 6.0))

		"cheer":
			key = "exit"
			idx = mini(2, int(pose_t * 7.0))
		"wave":
			key = "exit"
			idx = 3
		"walkin":
			key = "exit"
			idx = 4 + int(pose_t * 5.0) % 2
	var f: Dictionary = FramesData.FRAMES[key][idx]
	hero.texture = frame_tex[key][idx]
	var s: float = HERO_H * g / FramesData.FIG_H
	hero.scale = Vector2(s, s)
	hero.flip_h = facing < 0
	var w: float = f.w
	var floor_y := wy(BY - 1.25 - hero_lift)
	var ax: float
	var world_x: float
	if by_hand:
		ax = f.hand
		world_x = wx(_push_face()) + facing * 2.0
	elif hero_pose == "push":
		# pounding: keep the body where the pushing frames put it
		var p0: Dictionary = FramesData.FRAMES["push"][0]
		ax = f.foot[0]
		world_x = wx(_push_face()) - facing * (p0.hand - p0.foot[0]) * s
	else:
		ax = f.foot[0]
		world_x = wx(hero_x)
	var axm: float = ax if facing > 0 else w - ax
	var shake_px := 0.0

	shake_px += shake_extra
	hero.position = Vector2(world_x - axm * s + shake_px, floor_y - float(f.foot[1]) * s)
	hero_b.visible = false
	if hero_pose == "push":
		# remember where his feet are, so running starts from the right spot
		var fx: float = f.foot[0] if facing > 0 else w - f.foot[0]
		hero_x = (hero.position.x + fx * s - ox) / g
	# sweat when the danger is close
	if hero_pose == "push" and hz_p > 0.35 and dt > 0.0:
		sweat_t -= dt
		if sweat_t <= 0.0:
			sweat_t = lerpf(1.4, 0.35, hz_p) + randf() * 0.4
			var hx: float = (0.72 if facing > 0 else 0.28) * w * s
			var hp := hero.position + Vector2(hx, float(f.h) * 0.2 * s)
			parts.append({"x": hp.x, "y": hp.y, "vx": -facing * (20.0 + randf() * 40.0), "vy": -40.0, "life": 0.0, "max": 0.7,
				"col": Color(0.7, 0.88, 1.0, 0.9), "size": g * 0.35, "grav": 600.0, "kind": "dot"})

## Position along a there-and-back loop of n frames: x = frame, y = next frame, z = blend 0..1.
func _pingpong(p: float, n: int) -> Vector3:
	var period := 2 * (n - 1)
	var q := fmod(p, float(period))
	var i := int(q)
	var a: int = i if i < n else period - i
	var j := (i + 1) % period
	var b: int = j if j < n else period - j
	return Vector3(a, b, q - float(i))

func _place_blend(key: String, nxt: int, blend: float, by_hand: bool, s: float, floor_y: float, shake_px: float) -> void:
	if nxt < 0 or blend <= 0.02:
		hero_b.visible = false
		return
	var f: Dictionary = FramesData.FRAMES[key][nxt]
	hero_b.visible = true
	hero_b.texture = frame_tex[key][nxt]
	hero_b.scale = Vector2(s, s)
	hero_b.flip_h = facing < 0
	var w: float = f.w
	var ax: float = f.hand if by_hand else f.foot[0]
	var world_x: float = wx(_push_face()) + facing * 2.0 if by_hand else wx(hero_x)
	var axm: float = ax if facing > 0 else w - ax
	hero_b.position = Vector2(world_x - axm * s + shake_px, floor_y - float(f.foot[1]) * s)
	# ease the blend so each pose holds a moment before it melts into the next
	var e := blend * blend * (3.0 - 2.0 * blend)
	hero_b.modulate.a = hero_alpha * e

const BOSS_H := 21.0

func _hazard_width() -> float:
	var hz: String = boss_base if boss_base != "" else L.get("hazard", "")
	if hz == "spikes":
		return SPIKE_W
	if boss_tex != null:
		return BOSS_H * boss_tex.get_width() / boss_tex.get_height() * 0.8
	if chasers.has(hz):
		var pp: Puppet = chasers[hz]
		return pp.size.x * CHASER_H[hz] / pp.size.y
	return 0.0

func _hazard_front() -> float:
	# x (world cells) of the hazard's leading edge
	var far = room.x0 if facing > 0 else room.x1
	return far + facing * (_hazard_width() + 0.4)

func _anim(dt: float) -> void:
	if room.is_empty() or hero == null:
		return
	# hazard creeps toward its target
	var hz_speed := 0.0
	# hero timers: blink, glance back at the danger
	blink_t -= dt
	if blink_t < 0.0:
		blink_t = 2.0 + randf() * 2.5
	look_t = maxf(0.0, look_t - dt)
	flinch = maxf(0.0, flinch - dt)
	door_hit = maxf(0.0, door_hit - dt * 4.0)
	push_ph += dt * (2.4 + hz_p * 5.5)
	var pound_now := sin(hero_t * 0.9) > 0.35 and hz_p >= 0.7 and hero_pose == "push"
	if pound_now:
		var ph := int(anim_t * 0.9) % 8
		var hit := ph == 1 or ph == 3 or ph == 6
		if hit and pound_prev < 0.5:
			door_hit = 1.0
			play("click", 0.55 + randf() * 0.1, -6.0)
			buzz(10)
		pound_prev = 1.0 if hit else 0.0
	if hero_pose == "push" and state != "won":
		look_cd -= dt
		if look_cd <= 0.0 and hz_p > 0.12:
			look_t = lerpf(0.7, 1.3, hz_p)
			look_cd = lerpf(5.5, 1.2, hz_p) + randf() * 1.5
	_hero_frames(dt)
	hero.modulate.a = hero_alpha
	# boss: its own art if it has one, otherwise a tinted puppet
	var hz: String = boss_base
	if boss_tex != null:
		roar_t += dt
		if state == "lost":
			golem_attack = minf(1.0, golem_attack + dt * 1.2)
		var bh := BOSS_H * g
		var bs := bh / boss_tex.get_height()
		var breathe := 1.0 + sin(hero_t * 2.2) * 0.025
		var lunge := golem_attack * 3.0 * g
		var far = room.x0 if facing > 0 else room.x1
		var bw := boss_tex.get_width() * bs
		boss_sprite.flip_h = facing < 0
		boss_sprite.scale = Vector2(bs, bs * breathe)
		var bx: float = wx(far + facing * 0.2) + (0.0 if facing > 0 else -bw) + facing * lunge
		boss_sprite.position = Vector2(bx, wy(BY - 0.8) - bh * breathe)
		boss_sprite.modulate = Color(1, 1, 1).lerp(Color(1.4, 0.8, 0.8), clampf(golem_attack, 0.0, 1.0))
	elif chasers.has(hz):
		var pp: Puppet = chasers[hz]
		chaser_phase += hz_speed * 9.0 * dt + dt * 0.6
		roar_t += dt
		if roar_t > 4.5 + randf() * 3.0 and hz_p > 0.15:
			roar_t = 0.0
			flinch = 0.7
			play("boom", 0.45 if hz == "golem" else 0.8, -12.0)
		if state == "lost":
			golem_attack = minf(1.0, golem_attack + dt * 1.2)
		var gk: float = 1.0 if dt == 0.0 else minf(1.0, dt * 10.0)
		pp.pose(_chaser_target(hz, hero_t, clampf(hz_speed * 6.0, 0.25, 1.0)), gk)
		var cs: float = CHASER_H[hz] * g / pp.size.y
		var lead := wx(_hazard_front())
		var hop: float = absf(sin(chaser_phase)) * 0.3 if hz == "golem" else 0.0
		pp.place(Vector2(lead - facing * pp.front_offset(cs), wy(BY - 1.1 - hop)), cs, facing)
	if dt > 0.0 and (state == "idle" or state == "busy" or state == "paused"):
		_ambient(dt)
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
	_draw_door(ci)
	match L.get("hazard", ""):
		"spikes":
			_draw_spike_wall(ci)
		"water":
			_draw_water(ci)
		"lava":
			_draw_lava(ci)

## When the debris shoves the door into the room, it fills the gap behind the door.
func _draw_push_debris(ci: CanvasItem, off: float) -> void:
	if absf(off) < 0.05 or door_swing > 0.5:
		return
	var slot := door_col + 0.5 + facing * DOOR_EDGE_W / 2.0
	var x0 := minf(wx(slot), wx(slot + off))
	var x1 := maxf(wx(slot), wx(slot + off))
	var top := wy(room.y0) + g * 0.6
	var bot := wy(BY) - g * 0.2
	var base_col: Color = mound_col
	ci.draw_rect(Rect2(x0, top, x1 - x0, bot - top), base_col.darkened(0.2))
	var gt: Texture2D = tex["grains_" + theme.grains]
	var cw: float = gt.get_height()
	var sz := g * 1.15
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var nx := int((x1 - x0) / sz) + 1
	var ny := int((bot - top) / sz) + 1
	for iy in ny:
		for ix in nx:
			var v := rng.randi() % 3
			var px := x1 - (ix + 1) * sz if facing > 0 else x0 + ix * sz
			if px < x0 - sz * 0.5 or px > x1:
				continue
			var jit := Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * sz * 0.3
			ci.draw_texture_rect_region(gt, Rect2(Vector2(px, top + iy * sz) + jit, Vector2(sz, sz) * 1.15), Rect2(v * cw, 0, cw, cw), theme.gtint)
	# grains trickling out under the door while it is being forced back
	if (state == "idle" or state == "busy") and _push_rate() > 0.0 and randf() < 0.5:
		var dx := wx(slot + off) - facing * DOOR_EDGE_W * g
		parts.append({"x": dx, "y": bot - g, "vx": -facing * (30.0 + randf() * 50.0) * g / 6.0,
			"vy": -30.0 * g / 6.0, "life": 0.0, "max": 0.45, "col": theme.gtint, "v": 1 + randi() % 3, "size": g * 0.9,
			"grav": 500.0 * g / 6.0, "kind": "grain"})

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
	var sp := _spout_pos()
	var px := sp.x
	var py := sp.y + g * 1.2
	var ly := wy(level)
	# stream: a wide translucent body with bright streaks
	if hz_p < 0.999 or state == "lost":
		var wob := sin(time * 9.0) * g * 0.15
		_vgrad(ci, Rect2(Vector2(px - g * 0.85 + wob, py), Vector2(g * 1.7, ly - py)), Color(0.55, 0.85, 1.0, 0.75), Color(0.35, 0.7, 1.0, 0.55))
		for k in 3:
			var sx := px + (k - 1) * g * 0.45 + sin(time * 13.0 + k * 2.0) * g * 0.1
			var off := fmod(time * 260.0 + k * 90.0, maxf(1.0, ly - py))
			ci.draw_line(Vector2(sx, py + off), Vector2(sx, minf(ly, py + off + g * 3.0)), Color(1, 1, 1, 0.55), maxf(1.0, g * 0.18))
		# splash and foam where it lands
		if randf() < 0.7:
			var a := -PI / 2.0 + (randf() - 0.5) * 2.4
			var v := (60.0 + randf() * 140.0) * g / 6.0
			parts.append({"x": px + (randf() - 0.5) * g, "y": ly, "vx": cos(a) * v, "vy": sin(a) * v, "life": 0.0, "max": 0.45,
				"col": Color(0.85, 0.95, 1.0, 0.9), "size": g * (0.2 + randf() * 0.25), "grav": 700.0 * g / 6.0, "kind": "dot"})
		for k in 4:
			var fr := g * (1.0 + 0.5 * sin(time * 6.0 + k * 1.7))
			ci.draw_circle(Vector2(px + (k - 1.5) * g * 0.9, ly), fr, Color(0.92, 0.98, 1.0, 0.55))
	# body: deep blue gradient with a lighter surface band
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 28
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		var wv := sin(time * 3.0 + i * 0.8) * g * 0.35 + sin(time * 5.3 + i * 1.7) * g * 0.15
		pts.append(Vector2(x, ly + wv))
		cols.append(Color(0.5, 0.82, 1.0, 0.62))
	pts.append(Vector2(x1, wy(BY)))
	cols.append(Color(0.04, 0.2, 0.5, 0.88))
	pts.append(Vector2(x0, wy(BY)))
	cols.append(Color(0.04, 0.2, 0.5, 0.88))
	ci.draw_polygon(pts, cols)
	# caustic light lines under the surface
	for k in 6:
		var cy := ly + g * (1.5 + k * 1.6)
		if cy > wy(BY) - g:
			break
		var line := PackedVector2Array()
		for i in 13:
			var x := lerpf(x0, x1, float(i) / 12.0)
			line.append(Vector2(x, cy + sin(time * 2.0 + i * 1.3 + k) * g * 0.4))
		ci.draw_polyline(line, Color(0.75, 0.95, 1.0, 0.12), maxf(1.0, g * 0.25), true)
	var top := PackedVector2Array()
	for i in n + 1:
		top.append(pts[i])
	ci.draw_polyline(top, Color(0.92, 0.98, 1.0, 0.9), maxf(1.5, g * 0.35), true)
	for k in 10:
		var bx := lerpf(x0, x1, fmod(k * 0.137 + 0.05, 1.0))
		var by := wy(BY) - fmod(time * 30.0 + k * 41.0, maxf(1.0, (BY - level) * g))
		ci.draw_arc(Vector2(bx + sin(time * 4.0 + k) * g * 0.3, by), g * 0.22, 0, TAU, 10, Color(0.9, 0.97, 1.0, 0.6), 1.5)

func _draw_lava(ci: CanvasItem) -> void:
	var far = room.x0 if facing > 0 else room.x1
	var front := _hazard_front()
	var h := 2.2 + hz_p * 2.8
	var sp := _spout_pos()
	var px := sp.x
	var py := sp.y + g * 1.2
	if hz_p > 0.0:
		var wob := sin(time * 7.0) * g * 0.15
		var ly := wy(BY - h)
		_vgrad(ci, Rect2(Vector2(px - g * 0.85 + wob, py), Vector2(g * 1.7, ly - py + g)), Color(1.0, 0.92, 0.45), Color(1.0, 0.42, 0.05))
		ci.draw_line(Vector2(px + wob, py), Vector2(px + wob, ly), Color(1.0, 1.0, 0.8, 0.8), maxf(1.0, g * 0.3))
		if randf() < 0.35:
			parts.append({"x": px + (randf() - 0.5) * g, "y": ly, "vx": (randf() - 0.5) * 120.0 * g / 6.0, "vy": -(80.0 + randf() * 120.0) * g / 6.0,
				"life": 0.0, "max": 0.6, "col": Color(1.0, 0.7 + randf() * 0.25, 0.2), "size": g * (0.25 + randf() * 0.3), "grav": 600.0 * g / 6.0, "kind": "dot"})
	if hz_p <= 0.001:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var n := 24
	var surf := []
	for i in n + 1:
		var t := float(i) / n
		var x := lerpf(far, front, t)
		var bump := sin(time * 2.0 + i * 1.3) * 0.35 + sin(time * 3.1 + i * 0.7) * 0.2
		var hh := h * (1.0 - pow(t, 6.0)) + bump
		var pt := Vector2(wx(x), wy(BY - maxf(0.3, hh)))
		pts.append(pt)
		surf.append(pt)
		cols.append(Color(1.0, 0.88, 0.35))
	pts.append(Vector2(wx(front), wy(BY)))
	cols.append(Color(0.7, 0.12, 0.02))
	pts.append(Vector2(wx(far), wy(BY)))
	cols.append(Color(0.7, 0.12, 0.02))
	ci.draw_polygon(pts, cols)
	# dark cooling crust plates drifting with the flow, bright cracks between
	for k in 9:
		var t := fmod(k * 0.113 + time * 0.035, 0.92)
		var x := lerpf(far, front, t)
		var cy := wy(BY - h * 0.5 + sin(time + k) * 0.3)
		var rr := g * (0.7 + 0.3 * sin(time * 1.3 + k))
		ci.draw_circle(Vector2(wx(x), cy), rr, Color(0.32, 0.07, 0.03, 0.7))
		ci.draw_arc(Vector2(wx(x), cy), rr, 0, TAU, 14, Color(1.0, 0.75, 0.25, 0.6), maxf(1.0, g * 0.15))
	# bubbles that swell and pop on the surface
	for k in 5:
		var ph := fmod(time * 0.8 + k * 0.37, 1.0)
		var i := (k * 5 + 2) % (n - 2) + 1
		var b: Vector2 = surf[i]
		ci.draw_circle(b, g * 0.7 * ph, Color(1.0, 0.95, 0.6, 0.8 * (1.0 - ph)))
	var top := PackedVector2Array(surf)
	ci.draw_polyline(top, Color(1.0, 0.98, 0.75, 0.9), maxf(1.5, g * 0.3), true)

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
	# shaft recess: the tomb wall texture deep in shadow
	var sr0 = Rect2(wx(area.x0), wy(area.y0), (area.x1 - area.x0) * g, (BY - area.y0) * g)
	var kw: float = (14.0 * g) / float(tex.stonewall.get_width())
	ci.draw_set_transform(sr0.position, 0.0, Vector2(kw, kw))
	ci.draw_texture_rect(tex.stonewall, Rect2(Vector2.ZERO, sr0.size / kw), true, Color(0.62, 0.55, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_vgrad(ci, sr0, Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.35))
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
			ci.draw_texture_rect(tex.get("tile_%d" % int(L.get("world", 0)), tex.tile), Rect2(p + Vector2(s, s) * 0.02, Vector2(s, s) * 0.96), false, shade)

func _draw_back(ci: CanvasItem) -> void:
	if L.is_empty():
		return
	_draw_open_door(ci)
	_draw_safe_door(ci)
	# water / lava spout on the far wall of the room
	var hz: String = L.get("hazard", "")
	if hz == "water" or hz == "lava":
		var t: Texture2D = tex.spout_lion if hz == "water" else tex.spout_ram
		var sz := Vector2(g * 6.0, g * 6.0 * t.get_height() / t.get_width())
		var sp := _spout_pos()
		ci.draw_texture_rect(t, Rect2(sp - Vector2(sz.x / 2.0, sz.y * 0.55), sz), false)

func _tile_v(ci: CanvasItem, t: Texture2D, x: float, y0: float, y1: float, w: float) -> void:
	# a vertical strip of a texture that repeats along its length
	var k := w / float(t.get_width())
	ci.draw_set_transform(Vector2(x - w / 2.0, y0), 0.0, Vector2(k, k))
	ci.draw_texture_rect(t, Rect2(Vector2.ZERO, Vector2(t.get_width(), (y1 - y0) / k)), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _tile_h(ci: CanvasItem, t: Texture2D, x0: float, x1: float, y: float, h: float) -> void:
	var k := h / float(t.get_height())
	ci.draw_set_transform(Vector2(x0, y - h / 2.0), 0.0, Vector2(k, k))
	ci.draw_texture_rect(t, Rect2(Vector2.ZERO, Vector2((x1 - x0) / k, t.get_height())), true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_frame(ci: CanvasItem) -> void:
	if L.is_empty():
		return
	_draw_frame_inner(ci)

func _draw_frame_inner(ci: CanvasItem) -> void:
	var t = g * 1.5
	var sx0 = wx(shaft.x0)
	var sx1 = wx(shaft.x1)
	var sy = wy(shaft.y0)
	var by = wy(BY)
	var rx0 = wx(room.x0)
	var rx1 = wx(room.x1)
	var ry = wy(room.y0)
	var far = rx0 if facing > 0 else rx1
	# pillars: the wall the door sits in (open at the top) and the room's far wall
	var wall_x = (sx0 - t * 0.5) if facing > 0 else (sx1 + t * 0.5)
	_tile_v(ci, tex.pillar, wall_x, sy - t * 0.5, by, t)
	_tile_v(ci, tex.pillar, far, ry, by, t * 0.9)
	# carved beams: over the room and the floor ledge above the board
	_tile_h(ci, tex.frieze, minf(rx0, rx1) - t * 0.4, maxf(rx0, rx1) + t * 0.4, ry - t * 0.2, t)
	_tile_h(ci, tex.frieze, wx(BX - 0.8), wx(BX + COLS * CELL + 0.8), wy(BY - 0.75), g * 1.5)

func _draw_door(ci: CanvasItem) -> void:
	var off := -facing * hz_p * push_max
	_draw_push_debris(ci, off)
	var x = wx(door_col + 0.5 + off)
	var top = wy(room.y0) + g * 0.8
	var bot = wy(BY) - g * 0.2
	var h = bot - top
	var heave: float = 0.5 + 0.5 * sin(push_ph) if hero_pose == "push" else 0.0
	var free := 1.0 - float(shaft_sand) / float(shaft0)
	var jit := facing * (heave * 0.12 + door_hit * 0.25) * g * (0.4 + free)
	var w := DOOR_EDGE_W * g
	# opening: the door slides up into the ceiling, so only its lower part stays visible
	var lift: float = clampf(door_swing, 0.0, 1.0) * 0.97
	var t: Texture2D = tex.door_edge
	var th: float = t.get_height()
	if lift >= 0.97:
		return
	ci.draw_texture_rect_region(t, Rect2(Vector2(x - w / 2.0 + jit, top), Vector2(w, h * (1.0 - lift))),
		Rect2(0, th * lift, t.get_width(), th * (1.0 - lift)))

func _draw_open_door(ci: CanvasItem) -> void:
	return
	if door_swing <= 0.0:
		return
	var top = wy(room.y0) + g * 0.8
	var bot = wy(BY) - g * 0.2
	var h = bot - top
	var hinge := wx(door_col + 0.5) + facing * DOOR_EDGE_W * g / 2.0
	var face_w: float = minf(h * tex.door.get_width() / tex.door.get_height(), (shaft.x1 - shaft.x0) * g * 0.55)
	var w: float = lerpf(DOOR_EDGE_W * g, face_w, sin(door_swing * PI / 2.0))
	var shade := lerpf(0.75, 1.0, door_swing)
	var r := Rect2(Vector2(hinge if facing > 0 else hinge - w, top), Vector2(w, h))
	ci.draw_texture_rect(tex.door, r, false, Color(shade, shade, shade))
	# the dark doorway left behind
	ci.draw_rect(Rect2(Vector2(wx(door_col + 0.5) - DOOR_EDGE_W * g / 2.0, top), Vector2(DOOR_EDGE_W * g, h)), Color(0.05, 0.03, 0.02, 0.0))

func _draw_safe_door(ci: CanvasItem) -> void:
	var t: Texture2D = tex.door_full
	var hh := SAFE_H * g
	var ww: float = hh * t.get_width() / t.get_height()
	var r := Rect2(Vector2(wx(safe_x) - ww / 2.0, wy(BY - 1.0) - hh), Vector2(ww, hh))
	ci.draw_texture_rect(t, r, false)

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
		"scarab":
			return tex.scarab
	return tex.gem_red

func _draw_gems(ci: CanvasItem) -> void:
	if grid.is_empty():
		return
	var S = CELL * g * 0.92
	var board_top = wy(BY) - CELL * g * 0.35
	_draw_runes(ci)
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
			var jar: bool = wrapped.has(r * COLS + c) and wrapped[r * COLS + c].t == "jar"
			if not jar:
				_draw_tex_centered(ci, _gem_tex(m), center, size, rot)
			if wrapped.has(r * COLS + c):
				_draw_cover(ci, center, s, wrapped[r * COLS + c], c, r)

func _draw_bandage(ci: CanvasItem, c: Vector2, s: float) -> void:
	_draw_tex_centered(ci, tex.fx_bandage, c, Vector2(s, s) * 1.08)

func _draw_crust(ci: CanvasItem) -> void:
	var sz := CELL * g
	for id in crust:
		var c: int = id % COLS
		var r: int = id / COLS
		var glow := 0.88 + 0.12 * sin(time * 2.0 + id)
		_draw_tex_centered(ci, tex.fx_crust, Vector2(cell_cx(c), cell_cy(r)), Vector2(sz, sz) * 1.02, 0.0, Color(glow, glow, glow))

func _draw_fx(ci: CanvasItem) -> void:
	if not shaft.is_empty() and not L.is_empty():
		_draw_source(ci)
	if mode == "crust":
		_draw_crust(ci)
	if not tut_move.is_empty() and state == "idle":
		var a: Vector2i = tut_move[0]
		var b: Vector2i = tut_move[1]
		var pa := Vector2(cell_cx(a.x), cell_cy(a.y))
		var pb := Vector2(cell_cx(b.x), cell_cy(b.y))
		var ph := fmod(time * 0.8, 1.0)
		var e := clampf((ph - 0.15) / 0.55, 0.0, 1.0)
		e = e * e * (3.0 - 2.0 * e)
		var hp := pa.lerp(pb, e)
		var al := 1.0 - clampf((ph - 0.8) / 0.2, 0.0, 1.0)
		for cpos in [pa, pb]:
			ci.draw_arc(cpos, CELL * g * 0.5, 0, TAU, 32, Color(1, 0.95, 0.6, 0.55 + 0.3 * sin(time * 6.0)), maxf(2.0, g * 0.45), true)
		ci.draw_line(pa, pb, Color(1, 1, 1, 0.35), maxf(2.0, g * 0.5))
		# pointing hand: fingertip on the gem, arm coming up from below
		var ht: Texture2D = tex.hand
		var hw := CELL * g * 2.3
		var hh := hw * ht.get_height() / ht.get_width()
		ci.draw_set_transform(hp + Vector2(g * 0.5, g * 0.8), -PI / 2.0, Vector2.ONE)
		ci.draw_texture_rect(ht, Rect2(-hw, -hh * 0.32, hw, hh), false, Color(0, 0, 0, 0.25 * al))
		ci.draw_set_transform(hp, -PI / 2.0, Vector2.ONE)
		ci.draw_texture_rect(ht, Rect2(-hw, -hh * 0.32, hw, hh), false, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ci.draw_arc(hp, CELL * g * 0.3 + (1.0 - al) * g * 3.0, 0, TAU, 32, Color(1, 0.85, 0.3, al), maxf(2.0, g * 0.4), true)
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
			"scarab":
				var e := p * p * (3.0 - 2.0 * p)
				var pos := Vector2(lerpf(f.x0, f.x1, e), lerpf(f.y0, f.y1, e) - sin(p * PI) * CELL * g * 1.5)
				var ss := CELL * g * 0.9
				var e2: float = maxf(0.0, p - 0.08)
				var e2s := e2 * e2 * (3.0 - 2.0 * e2)
				var prev := Vector2(lerpf(f.x0, f.x1, e2s), lerpf(f.y0, f.y1, e2s) - sin(e2 * PI) * CELL * g * 1.5)
				var tl := ss * 1.6
				var tt: Texture2D = tex.fx_scarab_trail
				ci.draw_set_transform(pos, (pos - prev).angle(), Vector2.ONE)
				ci.draw_texture_rect(tt, Rect2(-tl, -tl * 0.25, tl, tl * 0.5), false, Color(1, 1, 1, 0.9))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				_draw_tex_centered(ci, tex.scarab, pos, Vector2(ss, ss), sin(time * 30.0) * 0.15)
			"spr":
				var t: Texture2D = f.tex
				var sz: float = lerpf(f.s0, f.s1, 1.0 - (1.0 - p) * (1.0 - p))
				var a: float = 1.0 - p * p
				var ang: float = f.rot + f.spin * p
				ci.draw_set_transform(Vector2(f.x, f.y), ang, Vector2.ONE)
				if f.cell >= 0:
					var cw: float = t.get_width() / float(f.frames)
					ci.draw_texture_rect_region(t, Rect2(-sz / 2.0, -sz / 2.0, sz, sz), Rect2(f.cell * cw, 0, cw, t.get_height()), Color(1, 1, 1, a))
				else:
					var asp: float = float(t.get_height()) / t.get_width()
					ci.draw_texture_rect(t, Rect2(-sz / 2.0, -sz * asp / 2.0, sz, sz * asp), false, Color(1, 1, 1, a))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"cbolt":
				# crystal lightning stretched from one block to the next
				var a0 := Vector2(f.x0, f.y0)
				var a1 := Vector2(f.x1, f.y1)
				var t: Texture2D = tex.fx_crystal_bolt
				var ln := a0.distance_to(a1) * 1.3
				var hh: float = ln * t.get_height() / t.get_width()
				ci.draw_set_transform((a0 + a1) / 2.0, (a1 - a0).angle(), Vector2.ONE)
				ci.draw_texture_rect(t, Rect2(-ln / 2.0, -hh / 2.0, ln, hh), false, Color(1, 1, 1, 1.0 - p))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
			"mote":
				pass
			"leaf":
				var col: Color = pt.col
				col.a = minf(1.0, a * 2.0)
				ci.draw_set_transform(Vector2(pt.x + sin(pt.life * 3.0 + pt.size) * g * 1.5, pt.y), pt.life * 2.5 + pt.size, Vector2(1.0, 0.45))
				ci.draw_circle(Vector2.ZERO, pt.size, col)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"bat":
				var col: Color = Color(0.08, 0.06, 0.1, minf(1.0, a * 3.0))
				var fl: float = sin(pt.life * 22.0) * pt.size * 0.6
				var c0 := Vector2(pt.x, pt.y)
				ci.draw_line(c0, c0 + Vector2(-pt.size, -fl), col, maxf(1.5, g * 0.35), true)
				ci.draw_line(c0, c0 + Vector2(pt.size, -fl), col, maxf(1.5, g * 0.35), true)
				ci.draw_circle(c0, g * 0.35, col)
			"streak":
				var col: Color = pt.col
				col.a = minf(1.0, a * 1.5)
				ci.draw_line(Vector2(pt.x, pt.y), Vector2(pt.x, pt.y - pt.size), col, maxf(1.0, g * 0.22), true)
			"puff":
				var col: Color = pt.col
				col.a = 0.35 * a
				ci.draw_circle(Vector2(pt.x, pt.y), pt.size * (1.0 + pt.life * 1.6), col)
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
	if not shaft.is_empty():
		var free := 1.0 - float(shaft_sand) / float(shaft0)
		var leak := clampf((free - 0.55) / 0.45, 0.0, 1.0)
		if leak > 0.0 and door_swing <= 0.0:
			var dx := wx(door_col + 0.5) + facing * DOOR_EDGE_W * g * 0.5
			var flick := 0.85 + 0.15 * sin(time * 7.0)
			_draw_tex_centered(ci, glow_tex, Vector2(dx, wy(BY - 9.0)), Vector2(g * 5.0, g * 26.0), 0.0, Color(1.0, 0.85, 0.5, 0.45 * leak * flick))
		var sg := maxf(safe_glow, clampf((free - 0.6) / 0.4, 0.0, 1.0) * 0.4)
		if sg > 0.0:
			_draw_tex_centered(ci, glow_tex, Vector2(wx(safe_x), wy(BY - SAFE_H * 0.45)), Vector2(g * 16.0, g * 18.0), 0.0, Color(1.0, 0.8, 0.4, 0.5 * sg))
	for f in fx:
		if f.kind == "flash":
			var p: float = f.life / f.max
			var r: float = f.r
			_draw_tex_centered(ci, glow_tex, Vector2(f.x, f.y), Vector2(r, r) * 2.0, 0.0, Color(1.0, 0.95, 0.8, 0.9 * (1.0 - p)))
		elif f.kind == "rkt":
			_draw_tex_centered(ci, glow_tex, Vector2(f.x, f.y), Vector2(g, g) * 8.0, 0.0, Color(1.0, 0.6, 0.2, 0.6))
	if theme.glow > 0.0:
		# crystal shimmer over the shaft
		var sr = Rect2(wx(area.x0), wy(L.fill_top), (area.x1 - area.x0) * g, (BY - L.fill_top) * g)
		var pulse = 0.10 + 0.05 * sin(time * 2.0)
		var col: Color = theme.glow_col
		col.a = pulse * clampf(float(grains) / float(grains0) * 1.5, 0.0, 1.0)
		_draw_tex_centered(ci, glow_tex, sr.get_center(), sr.size * 1.4, 0.0, col)
	_draw_rays(ci)
	for p in parts:
		if p.kind == "mote":
			var a2: float = sin(clampf(p.life / p.max, 0.0, 1.0) * PI)
			var tw2: float = 0.6 + 0.4 * sin(time * 6.0 + p.size * 10.0) if p.get("blink", false) else 1.0
			var mc: Color = p.col
			mc.a = a2 * tw2 * mc.a
			_draw_tex_centered(ci, glow_tex, Vector2(p.x, p.y), Vector2(p.size, p.size) * 3.0, 0.0, mc)
		if p.kind == "star":
			var a: float = maxf(0.0, 1.0 - p.life / p.max)
			_draw_tex_centered(ci, glow_tex, Vector2(p.x, p.y), Vector2(g, g) * 4.0 * a, 0.0, Color(1, 0.95, 0.7, 0.5 * a))

# ---------- world atmosphere: room effects and the debris source ----------
const WORLD_FX := [
	{"src": "crack", "col": Color("6b4a22")},
	{"src": "pipe", "col": Color("7d8794")},
	{"src": "vent", "col": Color("9b6cff")},
	{"src": "pipe", "col": Color("3a2a24"), "glow": Color(1.0, 0.45, 0.1)},
	{"src": "urn", "col": Color("8a6a4a")},
	{"src": "snake", "col": Color("3f8a4a")},
	{"src": "jackal", "col": Color("2c3550")},
	{"src": "chute", "col": Color("6b4a2a")},
	{"src": "sun", "col": Color("e8b030")},
	{"src": "pipe", "col": Color("d9a530"), "glow": Color(0.75, 0.4, 1.0)},
]
var amb_t := {}

func _every(key: String, rate: float, dt: float) -> int:
	# how many things to spawn this frame for an effect running at `rate` per second
	var v: float = amb_t.get(key, randf()) + rate * dt
	var n := int(v)
	amb_t[key] = v - n
	return n

func _room_pt(fx_: float, fy: float) -> Vector2:
	return Vector2(wx(lerpf(room.x0, room.x1, fx_)), wy(lerpf(room.y0, room.y1, fy)))

func _ambient(dt: float) -> void:
	var w := int(L.get("world", 0))
	var k := g / 6.0
	match w:
		0:
			for i in _every("trickle", 1.6, dt):
				var p := _room_pt(randf(), 0.05)
				parts.append({"x": p.x, "y": p.y, "vx": 0.0, "vy": 120.0 * k, "life": 0.0, "max": 1.2, "col": Color("d9b06a"), "size": g * 2.0, "grav": 300.0 * k, "kind": "streak"})
			for i in _every("dust", 3.0, dt):
				var p := _room_pt(randf(), randf())
				parts.append({"x": p.x, "y": p.y, "vx": 8.0 * k, "vy": -4.0 * k, "life": 0.0, "max": 3.0, "col": Color(1, 0.9, 0.7, 0.5), "size": g * 0.25, "grav": 0.0, "kind": "dot"})
		1:
			for i in _every("steam", 1.4, dt):
				var p := _room_pt(0.08 + randf() * 0.84, 0.95)
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 10.0 * k, "vy": -40.0 * k, "life": 0.0, "max": 1.8, "col": Color(0.9, 0.95, 1.0), "size": g * 0.9, "grav": 0.0, "kind": "puff"})
			if _every("sparkburst", 0.25, dt) > 0:
				var p := _room_pt(randf(), 0.3 + randf() * 0.4)
				for i in 8:
					var a := randf() * TAU
					parts.append({"x": p.x, "y": p.y, "vx": cos(a) * 140.0 * k, "vy": sin(a) * 140.0 * k - 40.0 * k, "life": 0.0, "max": 0.5, "col": Color(1.0, 0.75, 0.3), "size": g * 0.25, "grav": 500.0 * k, "kind": "dot"})
		2:
			for i in _every("crystal", 4.0, dt):
				var p := _room_pt(randf(), 0.6 + randf() * 0.4)
				var c := Color(0.75, 0.55, 1.0, 0.8) if randf() < 0.6 else Color(0.5, 0.9, 1.0, 0.8)
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 12.0 * k, "vy": -18.0 * k, "life": 0.0, "max": 3.0, "col": c, "size": g * 0.6, "grav": 0.0, "kind": "mote"})
		3:
			for i in _every("ember", 6.0, dt):
				var p := _room_pt(randf(), 1.0)
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 30.0 * k, "vy": -50.0 * k - randf() * 50.0 * k, "life": 0.0, "max": 2.0, "col": Color(1.0, 0.55, 0.15, 0.9), "size": g * 0.45, "grav": -8.0 * k, "kind": "mote"})
			for i in _every("lavadrip", 0.7, dt):
				var p := _room_pt(randf(), 0.05)
				parts.append({"x": p.x, "y": p.y, "vx": 0.0, "vy": 60.0 * k, "life": 0.0, "max": 1.1, "col": Color(1.0, 0.5, 0.1), "size": g * 1.6, "grav": 500.0 * k, "kind": "streak"})
		4:
			for i in _every("dust", 3.0, dt):
				var p := _room_pt(randf(), randf())
				parts.append({"x": p.x, "y": p.y, "vx": 6.0 * k, "vy": 3.0 * k, "life": 0.0, "max": 3.5, "col": Color(0.9, 0.85, 0.75, 0.45), "size": g * 0.22, "grav": 0.0, "kind": "dot"})
			if _every("bats", 0.18, dt) > 0:
				var dir := 1.0 if randf() < 0.5 else -1.0
				for i in 3:
					var p := _room_pt(0.0 if dir > 0 else 1.0, 0.1 + randf() * 0.25)
					parts.append({"x": p.x - dir * i * g * 3.0, "y": p.y + i * g, "vx": dir * 160.0 * k, "vy": (randf() - 0.5) * 20.0 * k, "life": 0.0, "max": 2.4, "col": Color.BLACK, "size": g * 1.2, "grav": 0.0, "kind": "bat"})
		5:
			for i in _every("leaf", 1.2, dt):
				var p := _room_pt(randf(), 0.0)
				var c := Color("5fae4a") if randf() < 0.6 else Color("c9a03a")
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 20.0 * k, "vy": 30.0 * k, "life": 0.0, "max": 4.0, "col": c, "size": g * 0.7, "grav": 0.0, "kind": "leaf"})
			for i in _every("firefly", 1.8, dt):
				var p := _room_pt(randf(), 0.3 + randf() * 0.6)
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 30.0 * k, "vy": (randf() - 0.5) * 20.0 * k, "life": 0.0, "max": 3.0, "col": Color(0.85, 1.0, 0.4, 0.9), "size": g * 0.45, "grav": 0.0, "kind": "mote", "blink": true})
		6:
			for i in _every("dust", 3.0, dt):
				var p := _room_pt(randf(), randf())
				parts.append({"x": p.x, "y": p.y, "vx": 10.0 * k, "vy": 4.0 * k, "life": 0.0, "max": 3.0, "col": Color(1.0, 0.85, 0.6, 0.55), "size": g * 0.25, "grav": 0.0, "kind": "dot"})
		7:
			for i in _every("drip", 1.5, dt):
				var p := _room_pt(randf(), 0.05)
				parts.append({"x": p.x, "y": p.y, "vx": 0.0, "vy": 80.0 * k, "life": 0.0, "max": 1.0, "col": Color(0.6, 0.85, 1.0), "size": g * 1.2, "grav": 700.0 * k, "kind": "streak"})
			for i in _every("glint", 1.5, dt):
				var p := _room_pt(randf(), randf())
				parts.append({"x": p.x, "y": p.y, "vx": 0.0, "vy": 0.0, "life": 0.0, "max": 1.2, "col": Color(0.4, 1.0, 0.6, 0.9), "size": g * 0.5, "grav": 0.0, "kind": "mote"})
		8:
			for i in _every("gold", 3.0, dt):
				var p := _room_pt(randf(), randf() * 0.6)
				parts.append({"x": p.x, "y": p.y, "vx": 0.0, "vy": 12.0 * k, "life": 0.0, "max": 1.6, "col": Color(1.0, 0.85, 0.35), "size": g * 0.9, "grav": 0.0, "kind": "star"})
		9:
			for i in _every("glitter", 3.0, dt):
				var p := _room_pt(randf(), 0.0)
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 10.0 * k, "vy": 40.0 * k, "life": 0.0, "max": 3.0, "col": Color(1.0, 0.85, 0.3), "size": g * 0.8, "grav": 0.0, "kind": "star"})
			for i in _every("wisp", 1.6, dt):
				var p := _room_pt(randf(), 1.0)
				parts.append({"x": p.x, "y": p.y, "vx": (randf() - 0.5) * 20.0 * k, "vy": -30.0 * k, "life": 0.0, "max": 2.5, "col": Color(0.7, 0.35, 1.0, 0.8), "size": g * 0.8, "grav": 0.0, "kind": "mote"})

## Slow beams of sunlight in the Valley of Kings and the Temple of Ra.
func _draw_rays(ci: CanvasItem) -> void:
	if room.is_empty():
		return
	var w := int(L.get("world", 0))
	if w != 6 and w != 8:
		return
	var col := Color(1.0, 0.85, 0.5) if w == 6 else Color(1.0, 0.92, 0.6)
	for i in 3:
		var fx_ := 0.2 + i * 0.3
		var a := 0.07 + 0.04 * sin(time * 0.7 + i * 2.0)
		var top := _room_pt(fx_, 0.0)
		var bw := g * (4.0 + i)
		var drop := _room_pt(fx_ + 0.18, 1.0)
		var poly := PackedVector2Array([top, top + Vector2(bw, 0), drop + Vector2(bw * 2.0, 0), drop])
		ci.draw_colored_polygon(poly, Color(col, a))

## The hole, pipe or statue that keeps pushing debris into the shaft.
func _draw_source(ci: CanvasItem) -> void:
	if shaft.is_empty():
		return
	var w := int(L.get("world", 0))
	var d: Dictionary = WORLD_FX[clampi(w, 0, 9)]
	var col: Color = d.col
	var x := wx(pour_x)
	var y := wy(shaft.y0 + 4.5)
	var u := g * 1.25
	var pouring := pour_left > 0.0
	var jig := sin(time * 40.0) * u * 0.25 if pouring else 0.0
	# the falling stream (the grains themselves come from the sand simulation)
	if pouring:
		var top_y: int = shaft.y0
		var cx := int(pour_x)
		while top_y < BY and sand[top_y * SW + cx] == 0:
			top_y += 1
		var sc: Color = theme.gtint
		ci.draw_rect(Rect2(x - u * 0.9, y, u * 1.8, wy(top_y) - y), Color(sc, 0.55))
		for k in 3:
			var off := fmod(time * 300.0 * g / 6.0 + k * 60.0, maxf(1.0, wy(top_y) - y))
			ci.draw_line(Vector2(x + (k - 1) * u * 0.5, y + off), Vector2(x + (k - 1) * u * 0.5, minf(wy(top_y), y + off + u * 3.0)), sc.lightened(0.3), maxf(1.0, u * 0.25))
	match d.src:
		"crack":
			var pts := PackedVector2Array()
			for k in 9:
				var t := float(k) / 8.0
				pts.append(Vector2(x + (t - 0.5) * u * 7.0, y - u * 1.4 + (u * 1.4 if k % 2 == 0 else u * 2.2) * (1.0 - absf(t - 0.5) * 1.2)))
			pts.append(Vector2(x + u * 3.5, y - u * 3.0))
			pts.append(Vector2(x - u * 3.5, y - u * 3.0))
			ci.draw_colored_polygon(pts, Color(0.12, 0.07, 0.03))
			for k in 4:
				ci.draw_circle(Vector2(x + (k - 1.5) * u * 1.8, y - u * 1.6), u * 0.9, col)
		"pipe":
			var pw := u * 4.0
			var glow: Color = d.get("glow", Color(0, 0, 0, 0))
			ci.draw_rect(Rect2(x - pw / 2.0 + jig, y - u * 8.0, pw, u * 7.6), col)
			ci.draw_rect(Rect2(x - pw / 2.0 + jig, y - u * 8.0, pw * 0.25, u * 7.6), col.lightened(0.25))
			ci.draw_rect(Rect2(x - pw * 0.65 + jig, y - u * 1.6, pw * 1.3, u * 1.4), col.darkened(0.25))
			for k in 3:
				ci.draw_circle(Vector2(x - pw * 0.45 + k * pw * 0.45 + jig, y - u * 0.9), u * 0.25, col.lightened(0.4))
			if glow.a > 0.0:
				ci.draw_rect(Rect2(x - pw * 0.35 + jig, y - u * 0.3, pw * 0.7, u * 0.5), Color(glow, 0.6 + 0.4 * sin(time * 5.0)))
			if pouring:
				# pump piston thumping above the pipe
				var py := y - u * 8.0 - absf(sin(time * 9.0)) * u * 2.0
				ci.draw_rect(Rect2(x - u * 0.6 + jig, py - u * 3.0, u * 1.2, u * 3.0), col.darkened(0.4))
		"vent":
			ci.draw_circle(Vector2(x, y - u * 0.8), u * 2.6, Color(0.1, 0.05, 0.18))
			for k in 6:
				var a := -PI + k * PI / 5.0
				var base := Vector2(x, y - u * 0.8) + Vector2.from_angle(a) * u * 2.6
				var tip := base + Vector2.from_angle(a) * u * (2.0 + (k % 2) * 1.5)
				var side := Vector2.from_angle(a + PI / 2.0) * u * 0.8
				ci.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), col.lightened(0.15 if k % 2 == 0 else 0.0))
		"urn":
			ci.draw_set_transform(Vector2(x + jig, y - u * 2.0), 0.5, Vector2.ONE)
			ci.draw_circle(Vector2(0, -u * 1.0), u * 2.6, col)
			ci.draw_rect(Rect2(-u * 1.2, u * 0.8, u * 2.4, u * 1.4), col.darkened(0.2))
			ci.draw_rect(Rect2(-u * 2.0, -u * 1.4, u * 4.0, u * 0.6), Color("2f8f8a"))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"snake", "jackal":
			var hc := Vector2(x + jig, y - u * 2.4)
			ci.draw_circle(hc, u * 2.6, col)
			if d.src == "jackal":
				ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-u * 2.2, -u * 1.0), hc + Vector2(-u * 1.6, -u * 4.6), hc + Vector2(-u * 0.4, -u * 1.8)]), col)
				ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(u * 2.2, -u * 1.0), hc + Vector2(u * 1.6, -u * 4.6), hc + Vector2(u * 0.4, -u * 1.8)]), col)
				ci.draw_rect(Rect2(hc + Vector2(-u * 2.8, -u * 0.2), Vector2(u * 5.6, u * 0.5)), Color("d9a530"))
			else:
				ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-u * 3.6, -u * 0.6), hc + Vector2(0, -u * 3.6), hc + Vector2(u * 3.6, -u * 0.6)]), col.darkened(0.15))
			var eye := Color(1.0, 0.85, 0.2) if not pouring else Color(1.0, 0.3, 0.2)
			ci.draw_circle(hc + Vector2(-u * 1.0, -u * 0.6), u * 0.45, eye)
			ci.draw_circle(hc + Vector2(u * 1.0, -u * 0.6), u * 0.45, eye)
			ci.draw_circle(hc + Vector2(0, u * 1.4), u * (0.9 + (0.5 if pouring else 0.0)), Color(0.08, 0.04, 0.02))
		"chute":
			ci.draw_set_transform(Vector2(x, y - u * 1.0), -0.5, Vector2.ONE)
			ci.draw_rect(Rect2(-u * 6.0, -u * 1.2, u * 8.0, u * 2.4), col)
			for k in 4:
				ci.draw_line(Vector2(-u * 6.0 + k * u * 2.2, -u * 1.2), Vector2(-u * 6.0 + k * u * 2.2, u * 1.2), col.darkened(0.35), u * 0.25)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sun":
			var sc2 := Vector2(x, y - u * 2.0)
			for k in 12:
				var a := TAU * k / 12.0 + time * 0.3
				ci.draw_line(sc2 + Vector2.from_angle(a) * u * 2.6, sc2 + Vector2.from_angle(a) * u * 4.0, col, u * 0.45, true)
			ci.draw_circle(sc2, u * 2.6, col)
			ci.draw_circle(sc2, u * 1.1, Color(0.2, 0.1, 0.02))

# ---------- bosses, gem covers and world obstacles ----------
func _free_gem_cells(min_row := 0) -> Array:
	var out := []
	for r in range(min_row, ROWS):
		for c in COLS:
			var id: int = r * COLS + c
			var m = grid[r][c]
			if m != null and m.kind == "gem" and not m.dying and not is_rub(c, r) and not wrapped.has(id):
				out.append(id)
	return out

## Obstacles that come with the later worlds, placed when the level starts.
func _setup_mode_obstacles() -> void:
	var spots := _free_gem_cells(2)
	spots.shuffle()
	match mode:
		"jars":
			for id in spots.slice(0, 5):
				wrapped[id] = {"t": "jar", "hp": COVER_HP.jar, "goal": true}
		"glass":
			for id in spots.slice(0, 6):
				wrapped[id] = {"t": "glass", "hp": COVER_HP.glass, "goal": true}
		"runes":
			for id in _free_gem_cells(1).slice(0, 0):
				pass
			var all := []
			for r in range(1, ROWS):
				for c in COLS:
					if not is_rub(c, r):
						all.append(r * COLS + c)
			all.shuffle()
			for id in all.slice(0, 9):
				runes[id] = true
		"curse":
			for id in spots.slice(0, 2):
				wrapped[id] = {"t": "curse", "hp": 1, "goal": true}

## Cover n random gems with a layer of type t, flung from (from_x, from_y).
func _cover_random(t: String, n: int, from := Vector2.ZERO, goal := false) -> void:
	var spots := _free_gem_cells(0)
	spots.shuffle()
	var k := 0
	for id in spots.slice(0, n):
		var c: int = id % COLS
		var r: int = id / COLS
		var cid: int = id
		var dl := 0.12 * k
		if from != Vector2.ZERO:
			later(dl, func(): fx.append({"kind": "bolt", "x0": from.x, "y0": from.y, "x1": cell_cx(c), "y1": cell_cy(r), "life": 0.0, "max": 0.3}))
		later(dl + 0.25, func():
			if grid[r][c] != null and not wrapped.has(cid) and not is_rub(c, r):
				wrapped[cid] = {"t": t, "hp": COVER_HP[t], "goal": goal}
				burst(cell_cx(c), cell_cy(r), COVER_COL[t], 8, 0.8)
				play("crack", 0.8, -10.0)
				_update_extra())
		k += 1

## Venom and the pharaoh's curse creep onto a neighbouring gem when you leave them alone.
func _spread_covers() -> void:
	var src := []
	for id in wrapped:
		if wrapped[id].t == "venom" or wrapped[id].t == "curse":
			src.append(id)
	if src.is_empty():
		return
	src.shuffle()
	for id in src:
		var c: int = id % COLS
		var r: int = id / COLS
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		dirs.shuffle()
		for d in dirs:
			var nc: int = c + d.x
			var nr: int = r + d.y
			var nid := nr * COLS + nc
			if in_b(nc, nr) and not is_rub(nc, nr) and not wrapped.has(nid) and grid[nr][nc] != null and grid[nr][nc].kind == "gem":
				var t: String = wrapped[id].t
				wrapped[nid] = {"t": t, "hp": 1, "goal": wrapped[id].goal}
				fx.append({"kind": "ring", "x": cell_cx(nc), "y": cell_cy(nr), "r0": g, "r1": CELL * g * 0.7, "life": 0.0, "max": 0.4, "col": COVER_COL[t]})
				play("crack", 0.6, -12.0)
				_update_extra()
				return

## A boss pushes debris blocks up through the board.
func _raise_rubble(n: int) -> void:
	var spots := _free_gem_cells(3)
	spots.shuffle()
	var done := 0
	for id in spots:
		if done >= n:
			break
		var c: int = id % COLS
		var r: int = id / COLS
		# keep at least one free neighbour so the board never gets sealed off
		var free := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if in_b(c + d.x, r + d.y) and not is_rub(c + d.x, r + d.y):
				free += 1
		if free < 3:
			continue
		var m = grid[r][c]
		if m != null:
			_pop_gem(m)
		rubble[id] = true
		raised[id] = true
		for y in range(BY + r * CELL, BY + (r + 1) * CELL):
			for x in range(BX + c * CELL, BX + (c + 1) * CELL):
				mask[y * SW + x] = 1
				if sand[y * SW + x] == 0:
					sand[y * SW + x] = 1 + randi() % 3
					grains += 1
		spr(tex.fx_dust_puff, cell_cx(c), cell_cy(r), CELL * g * 0.6, CELL * g * 1.8, 0.5, randf() * TAU)
		spr(tex.fx_rock_chips, cell_cx(c), cell_cy(r), CELL * g * 0.5, CELL * g * 1.6, 0.45, randf() * TAU, -1, 1, 2.0)
		done += 1
	if done > 0:
		later(0.25, func(): grid_clear_raised())
		_compute_active_region()
		sand_sleep = false
		sand_dirty = true
		_upload_sand()

func grid_clear_raised() -> void:
	for id in raised:
		var c: int = id % COLS
		var r: int = id / COLS
		grid[r][c] = null

func _lower_rubble(id: int) -> void:
	raised.erase(id)
	rubble.erase(id)
	var c: int = id % COLS
	var r: int = id / COLS
	for y in range(BY + r * CELL, BY + (r + 1) * CELL):
		for x in range(BX + c * CELL, BX + (c + 1) * CELL):
			if sand[y * SW + x] != 0:
				grains -= 1
			sand[y * SW + x] = 0
			mask[y * SW + x] = 0
	if grid[r][c] == null:
		var m := _new_gem(c, r, randi() % NCOL)
		m.scale = 0.0
		grid[r][c] = m
		tween(m, {"scale": 1.0}, 0.25, "back")
	sand_dirty = true

func _boss_mouth() -> Vector2:
	var far = room.x0 if facing > 0 else room.x1
	return Vector2(wx(far + facing * _hazard_width() * 0.7), wy(BY - 13.0))

func _boss_attack() -> void:
	var bd: Dictionary = BOSSES[boss_kind]
	var atk: String = bd.attacks[boss_att_i % bd.attacks.size()]
	boss_att_i += 1
	ui.toast(bd.name + " " + ATTACK_TEXT[atk])
	tween(self, {"golem_attack": 1.0}, 0.35, "out")
	tween(self, {"golem_attack": 0.0}, 0.4, "in", 0.55)
	roar_t = 0.0
	flinch = 0.8
	play("boom", 0.5, -4.0)
	await wait(0.45)
	shake = 0.45
	buzz(60)
	var mouth := _boss_mouth()
	match atk:
		"slam":
			pour_burst(3.0, 1.8)
		"smash":
			pour_burst(1.5, 1.3)
			_raise_rubble(2)
		"burrow":
			_raise_rubble(3)
		"roar":
			hz_p = minf(0.97, hz_p + 0.12)
			fx.append({"kind": "ring", "x": mouth.x, "y": mouth.y, "r0": g * 2.0, "r1": CELL * g * 3.0, "life": 0.0, "max": 0.5, "col": Color(1, 1, 1, 0.6)})
		"sand", "web", "magma", "glass", "gold":
			_cover_random(atk, 3, mouth)
		"wrap":
			_cover_random("bandage", 3, mouth)
		"venom":
			_cover_random("venom", 2, mouth)
		"curse":
			_cover_random("curse", 2, mouth)
	await wait(0.7)

## Draw a gem cover (or a jar standing in for the gem).
func _draw_cover(ci: CanvasItem, ctr: Vector2, s: float, d: Dictionary, c: int, r: int) -> void:
	var t: String = d.t
	var col: Color = COVER_COL[t]
	match t:
		"bandage":
			_draw_tex_centered(ci, tex.fx_bandage, ctr, Vector2(s, s) * 1.08)
		"web":
			for k in 8:
				var a := TAU * k / 8.0 + 0.2
				ci.draw_line(ctr, ctr + Vector2.from_angle(a) * s * 0.55, Color(1, 1, 1, 0.85), maxf(1.0, g * 0.18), true)
			for ring in [0.18, 0.32, 0.46]:
				var pts := PackedVector2Array()
				for k in 9:
					var a := TAU * k / 8.0 + 0.2
					pts.append(ctr + Vector2.from_angle(a) * s * ring * (1.0 + 0.08 * sin(k * 3.0)))
				ci.draw_polyline(pts, Color(1, 1, 1, 0.75), maxf(1.0, g * 0.14), true)
		"sand":
			ci.draw_circle(ctr + Vector2(0, s * 0.12), s * 0.42, Color(col, 0.92))
			for k in 7:
				var o := Vector2(sin(k * 2.3 + c), cos(k * 1.7 + r)) * s * 0.3
				ci.draw_circle(ctr + o, s * 0.12, col.darkened(0.2))
		"magma":
			ci.draw_circle(ctr, s * 0.46, Color(0.18, 0.1, 0.08, 0.92))
			var glow := 0.6 + 0.4 * sin(time * 3.0 + c + r)
			for k in 5:
				var a := TAU * k / 5.0 + c
				ci.draw_line(ctr + Vector2.from_angle(a) * s * 0.08, ctr + Vector2.from_angle(a + 0.3) * s * 0.42, Color(1.0, 0.5, 0.1, glow), maxf(1.0, g * 0.3), true)
		"venom":
			ci.draw_circle(ctr, s * 0.47, Color(0.3, 0.85, 0.25, 0.55))
			for k in 3:
				var bb := ctr + Vector2(sin(time * 2.0 + k * 2.1) * s * 0.22, cos(time * 1.6 + k) * s * 0.2)
				ci.draw_circle(bb, s * (0.07 + 0.03 * k), Color(0.75, 1.0, 0.6, 0.8))
		"glass":
			ci.draw_rect(Rect2(ctr - Vector2(s, s) * 0.48, Vector2(s, s) * 0.96), Color(0.06, 0.06, 0.12, 0.72))
			ci.draw_rect(Rect2(ctr - Vector2(s, s) * 0.48, Vector2(s, s) * 0.96), Color(0.7, 0.75, 1.0, 0.8), false, maxf(1.5, g * 0.4))
			ci.draw_line(ctr + Vector2(-s * 0.3, -s * 0.38), ctr + Vector2(-s * 0.05, -s * 0.38), Color(1, 1, 1, 0.5), g * 0.4)
			ci.draw_line(ctr + Vector2(s * 0.3, s * 0.1), ctr + Vector2(s * 0.38, -s * 0.2), Color(1, 1, 1, 0.35), g * 0.3)
			if d.hp < COVER_HP.glass:
				ci.draw_polyline(PackedVector2Array([ctr + Vector2(-s * 0.4, -s * 0.1), ctr + Vector2(-s * 0.05, s * 0.05), ctr + Vector2(s * 0.1, s * 0.4)]), Color(0.9, 0.95, 1, 0.8), maxf(1.0, g * 0.2))
				ci.draw_line(ctr + Vector2(-s * 0.05, s * 0.05), ctr + Vector2(s * 0.4, -s * 0.15), Color(0.9, 0.95, 1, 0.8), maxf(1.0, g * 0.2))
		"gold":
			ci.draw_circle(ctr, s * 0.47, Color(1.0, 0.8, 0.25, 0.7))
			ci.draw_arc(ctr, s * 0.47, 0, TAU, 32, Color("b9821c"), g * 0.5, true)
			if d.hp < COVER_HP.gold:
				ci.draw_line(ctr + Vector2(-s * 0.3, -s * 0.2), ctr + Vector2(s * 0.25, s * 0.3), Color("7a4a00"), g * 0.35)
			var sp := 0.5 + 0.5 * sin(time * 4.0 + c * 1.3 + r)
			ci.draw_circle(ctr + Vector2(-s * 0.18, -s * 0.2), s * 0.06 * sp, Color(1, 1, 1, 0.9))
		"curse":
			var pul := 0.75 + 0.25 * sin(time * 3.0 + c + r)
			ci.draw_circle(ctr, s * 0.48, Color(0.45, 0.15, 0.7, 0.55 * pul))
			for k in 3:
				var a := time * 1.5 + k * TAU / 3.0
				ci.draw_circle(ctr + Vector2.from_angle(a) * s * 0.3, s * 0.07, Color(1.0, 0.85, 0.3, 0.9))
		"jar":
			var jw := s * 0.78
			var jh := s * 0.92
			var base := ctr + Vector2(0, jh * 0.45)
			var body := PackedVector2Array()
			for k in 17:
				var a := PI * k / 16.0
				body.append(base + Vector2(-cos(a) * jw * 0.5, -sin(a) * jh * 0.78))
			ci.draw_colored_polygon(body, Color("b8643a") if d.hp >= COVER_HP.jar else Color("9a5230"))
			ci.draw_rect(Rect2(base + Vector2(-jw * 0.22, -jh * 0.98), Vector2(jw * 0.44, jh * 0.2)), Color("d6a24a"))
			ci.draw_circle(base + Vector2(0, -jh * 1.0), jw * 0.2, Color("e8c060"))
			ci.draw_rect(Rect2(base + Vector2(-jw * 0.45, -jh * 0.5), Vector2(jw * 0.9, jh * 0.1)), Color("2f8f8a"))
			if d.hp < COVER_HP.jar:
				ci.draw_polyline(PackedVector2Array([base + Vector2(-jw * 0.2, -jh * 0.7), base + Vector2(0, -jh * 0.45), base + Vector2(-jw * 0.1, -jh * 0.2)]), Color("3a1a08"), maxf(1.0, g * 0.3))

func _draw_runes(ci: CanvasItem) -> void:
	if runes.is_empty():
		return
	var sz := CELL * g
	for id in runes:
		var c: int = id % COLS
		var r: int = id / COLS
		var ctr := Vector2(cell_cx(c), cell_cy(r))
		var pul := 0.55 + 0.25 * sin(time * 2.5 + id)
		ci.draw_rect(Rect2(ctr - Vector2(sz, sz) * 0.47, Vector2(sz, sz) * 0.94), Color(1.0, 0.75, 0.2, 0.28 * pul))
		ci.draw_arc(ctr, sz * 0.36, 0, TAU, 28, Color(1.0, 0.85, 0.35, 0.8 * pul), g * 0.35, true)
		for k in 8:
			var a := TAU * k / 8.0
			ci.draw_line(ctr + Vector2.from_angle(a) * sz * 0.38, ctr + Vector2.from_angle(a) * sz * 0.47, Color(1.0, 0.85, 0.35, 0.7 * pul), g * 0.3)

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
			if in_b(x, y) and (is_rub(x, y) or wrapped.has(y * COLS + x)):
				n += 1.0 / (1.0 + absi(x - c) + absi(y - r))
	if runes.has(r * COLS + c):
		n += 1.5
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
	await wait(1.2)
	await _shot("00_title")
	ui.hide_title()
	await wait(1.0)
	await _shot("01_map")
	select_level(0)
	await wait(0.8)
	await _shot("02_intro")
	var lvls := [0, 1, 4, 9, 12, 19, 33, 45, 54, 59]
	var env_l := OS.get_environment("AUTOTEST_LEVELS")
	if env_l != "":
		lvls = []
		for t in env_l.split(","):
			lvls.append(int(t) - 1)
	var think := float(OS.get_environment("BOT_THINK")) if OS.get_environment("BOT_THINK") != "" else 0.0
	for lv in lvls:
		var peak := 0.0
		begin_level(lv, ["pre_rocket"] if lv == 12 else [])
		await wait(1.5)
		await _shot("L%d_a_start" % (lv + 1))
		var n := 0
		while state != "won" and state != "lost" and n < 60:
			if state == "idle":
				if think > 0.0:
					await wait(think)
					if state != "idle":
						continue
				await _bot_move()
				n += 1
				peak = maxf(peak, hz_p)
				if n == 6:
					await wait(1.2)
					await _shot("L%d_b_chase" % (lv + 1))
			else:
				await wait(0.1)
		if state == "won":
			await wait(1.4)
			await _shot("L%d_c_bonus" % (lv + 1))
		else:
			await wait(1.0)
			await _shot("L%d_c_caught" % (lv + 1))
		var w := 0
		while not ui.overlay.visible and w < 160:
			await wait(0.1)
			w += 1
		await wait(0.5)
		print("AUTOTEST RESULT level=%d mode=%s boss=%s state=%s moves_left=%d danger_peak=%.2f danger_end=%.2f secs=%d" % [lv + 1, mode, L.boss, state, moves, peak, hz_p, int(time - level_t0)])
		await _shot("L%d_d_end" % (lv + 1))
	show_map()
	await wait(1.0)
	await _shot("99_map")
	for wv in [3, 5]:
		ui.map_view.scroll_to(wv * 10 + 4)
		await wait(0.8)
		await _shot("98_map_w%d" % (wv + 1))
	get_tree().quit()
