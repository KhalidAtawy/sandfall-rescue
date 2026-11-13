extends Control
## The journey map: level 1 at the bottom, worlds stacked upwards, a boss at the top of each world.
## Draws everything itself and scrolls by dragging (with a little momentum).

const SPACING := 170.0
const NODE_R := 46.0
const BOSS_R := 64.0
const WORLD_GAP := 220.0

var game: Node
var ui: Node
var f_display: Font
var f_body: Font
var scroll := 0.0          # distance from the top of the map, in px
var vel := 0.0
var dragging := false
var drag_from := 0.0
var drag_scroll := 0.0
var drag_dist := 0.0
var t := 0.0
var top_pad := 220.0       # room for the top bar
var bottom_pad := 260.0    # room for the play button
var map_tex := {}         # world index -> its road-map background (assets/gfx/map/map_<n>.jpg)
var river_trace := {}     # world index -> river centre x (fraction of image width), bottom to top
const GROUND := {"sand": [Color("d9a65c"), Color("a8722f")], "iron": [Color("8d929c"), Color("50566a")],
	"crystal": [Color("6d4b94"), Color("33214f")], "emerald": [Color("6a2f1c"), Color("2a120c")],
	"tomb": [Color("8a7660"), Color("4a3d33")], "temple": [Color("5b9a55"), Color("2b5a33")]}
var boss_tex := {}
var hero_tex: Texture2D
var badge_tex := {}
var node_tex := {}        # "node", "node_boss", "node_locked" level buttons
var banner_tex: Texture2D

func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for w in game.WORLDS.size():
		var p := "res://assets/gfx/map/map_%d.jpg" % (w + 1)
		if ResourceLoader.exists(p):
			map_tex[w] = load(p)
		var jp := "res://assets/gfx/map/river_%d.json" % (w + 1)
		if FileAccess.file_exists(jp):
			var d = JSON.parse_string(FileAccess.get_file_as_string(jp))
			if d is Array and d.size() > 2:
				river_trace[w] = d
	for n in game.BOSSES:
		var own := "res://assets/gfx/bosses/%s.png" % n
		boss_tex[n] = load(own) if ResourceLoader.exists(own) else load("res://assets/gfx/chasers/%s.png" % game.BOSSES[n].base)
	hero_tex = load("res://assets/gfx/zaki3/exit_1.png")
	for k in ["node", "node_boss", "node_locked"]:
		var np := "res://assets/gfx/map/%s.png" % k
		if ResourceLoader.exists(np):
			node_tex[k] = load(np)
	if ResourceLoader.exists("res://assets/gfx/ui/banner.png"):
		banner_tex = load("res://assets/gfx/ui/banner.png")
	for m in ["drain", "iron", "chain", "crust", "wrap", "race", "jars", "glass", "runes", "curse"]:
		var p := "res://assets/gfx/badges/badge_%s.png" % m
		if ResourceLoader.exists(p):
			badge_tex[m] = load(p)

func total_h() -> float:
	return top_pad + bottom_pad + game.LEVELS.size() * SPACING + game.WORLDS.size() * WORLD_GAP

func node_pos(i: int) -> Vector2:
	var w := i / 10
	var y := total_h() - bottom_pad - i * SPACING - w * WORLD_GAP - SPACING * 0.5
	return Vector2(river_x(y), y)

## World segment w covers [seg_top(w), seg_bot(w)] in map coordinates (no scroll).
func seg_bot(w: int) -> float:
	return total_h() - bottom_pad - w * (10 * SPACING + WORLD_GAP) + WORLD_GAP * 0.5

func seg_top(w: int) -> float:
	return seg_bot(w) - (10 * SPACING + WORLD_GAP)

func world_at(y: float) -> int:
	return clampi(int((total_h() - bottom_pad + WORLD_GAP * 0.5 - y) / (10 * SPACING + WORLD_GAP)), 0, game.WORLDS.size() - 1)

## The Nile's centre line: traced from the world's map image when there is one, otherwise an S-curve.
## Both meet the middle of the screen at every world's top and bottom edge, so the worlds join up.
func river_x(y: float) -> float:
	var w := world_at(y)
	var f := clampf((seg_bot(w) - y) / (seg_bot(w) - seg_top(w)), 0.0, 1.0)
	if river_trace.has(w) and map_tex.has(w):
		var tr: Array = river_trace[w]
		var fi := f * (tr.size() - 1)
		var k := int(fi)
		var frac: float = lerpf(float(tr[k]), float(tr[mini(k + 1, tr.size() - 1)]), fi - k)
		var tex: Texture2D = map_tex[w]
		var disp_w: float = (seg_bot(w) - seg_top(w)) * tex.get_width() / tex.get_height()
		return size.x * 0.5 + (frac - 0.5) * disp_w
	var sgn := 1.0 if w % 2 == 0 else -1.0
	return size.x * 0.5 + size.x * (0.2 * sin(TAU * f) * sgn + 0.05 * sin(3.0 * PI * f))

func scroll_to(i: int) -> void:
	scroll = clampf(node_pos(i).y - size.y * 0.58, 0.0, maxf(0.0, total_h() - size.y))
	vel = 0.0

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	if not dragging and absf(vel) > 1.0:
		scroll = clampf(scroll + vel * dt, 0.0, maxf(0.0, total_h() - size.y))
		vel *= pow(0.04, dt)
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			dragging = true
			drag_from = ev.position.y
			drag_scroll = scroll
			drag_dist = 0.0
			vel = 0.0
		else:
			dragging = false
			if drag_dist < 14.0:
				_tap(ev.position)
	elif ev is InputEventMouseMotion and dragging:
		var ns := clampf(drag_scroll - (ev.position.y - drag_from), 0.0, maxf(0.0, total_h() - size.y))
		vel = (ns - scroll) / maxf(0.001, get_process_delta_time())
		scroll = ns
		drag_dist = maxf(drag_dist, absf(ev.position.y - drag_from))
	elif ev is InputEventMouseButton and ev.pressed and (ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		scroll = clampf(scroll + (-90.0 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 90.0), 0.0, maxf(0.0, total_h() - size.y))

func _tap(p: Vector2) -> void:
	for i in game.LEVELS.size():
		var np := node_pos(i) - Vector2(0, scroll)
		var r: float = BOSS_R if game.LEVELS[i].boss else NODE_R
		if np.distance_to(p) <= r + 12.0:
			if game.meta.unlocked(i):
				game.play("click")
				game.select_level(i)
			else:
				game.play("bad", 1.0, -8.0)
			return

func _draw() -> void:
	var W := size.x
	draw_rect(Rect2(Vector2.ZERO, size), Color("140f24"))
	var cur: int = game.meta.current_level()
	# world backdrops: the world's own map image, or a drawn landscape with the Nile
	for w in game.WORLDS.size():
		var wd: Dictionary = game.WORLDS[w]
		var y_top := seg_top(w) - scroll
		var y_bot := seg_bot(w) - scroll
		if y_bot < -50 or y_top > size.y + 50:
			continue
		var r := Rect2(0, y_top, W, y_bot - y_top)
		if map_tex.has(w):
			var mt: Texture2D = map_tex[w]
			var dw: float = r.size.y * mt.get_width() / mt.get_height()
			var src_w: float = mt.get_width() * minf(1.0, W / dw)
			draw_texture_rect_region(mt, r, Rect2((mt.get_width() - src_w) * 0.5, 0, src_w, mt.get_height()))
		else:
			_draw_land(w, r)
		# soft blend between worlds
		_vgrad(Rect2(0, y_top - 1, W, 70), Color(0.08, 0.06, 0.14, 0.7), Color(0.08, 0.06, 0.14, 0))
		_vgrad(Rect2(0, y_bot - 70, W, 71), Color(0.08, 0.06, 0.14, 0), Color(0.08, 0.06, 0.14, 0.7))
		# world banner at the start of each world
		var by := y_bot - WORLD_GAP * 0.42
		var title := "World %d · %s" % [w + 1, wd.name]
		var fs := 32
		var tw := f_display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var br: Rect2
		if banner_tex:
			var bw := minf(W - 30.0, maxf(560.0, tw * 1.7))
			var bh := bw * banner_tex.get_height() / banner_tex.get_width()
			br = Rect2((W - bw) / 2.0, by - bh * 0.5, bw, bh)
			draw_texture_rect(banner_tex, br, false)
			draw_string(f_display, Vector2((W - tw) / 2.0, by + 11.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("5a3510"))
			br = Rect2(br.position.x + 10.0, by - 38.0, bw, 76.0)
		else:
			var bw := minf(W - 80.0, 520.0)
			br = Rect2((W - bw) / 2.0, by - 38.0, bw, 76.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.17, 0.12, 0.3, 0.92)
			sb.border_color = Color("b9821c")
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(38)
			draw_style_box(sb, br)
			draw_string(f_display, Vector2((W - tw) / 2.0, by + 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f5c542"))
		if wd.mode != "" and badge_tex.has(wd.mode):
			var bt: Texture2D = badge_tex[wd.mode]
			draw_texture_rect(bt, Rect2(br.position.x - 30.0, by - 52.0, 104, 104), false)
	# path along the river
	var cur0: int = game.meta.current_level()
	for i in game.LEVELS.size() - 1:
		var a := node_pos(i) - Vector2(0, scroll)
		var b := node_pos(i + 1) - Vector2(0, scroll)
		if maxf(a.y, b.y) < -80 or minf(a.y, b.y) > size.y + 80:
			continue
		var n := int(absf(a.y - b.y) / 24.0)
		for k in range(1, n):
			var yy := lerpf(a.y, b.y, float(k) / n)
			var p := Vector2(river_x(yy + scroll), yy)
			draw_circle(p, 6.0, Color("f5c542") if i < cur0 else Color(1, 1, 1, 0.45))
	# nodes
	for i in game.LEVELS.size():
		var p := node_pos(i) - Vector2(0, scroll)
		if p.y < -120 or p.y > size.y + 120:
			continue
		var lv: Dictionary = game.LEVELS[i]
		var r: float = BOSS_R if lv.boss else NODE_R
		var unlocked: bool = game.meta.unlocked(i)
		var stars := int(game.meta.best[i])
		var col: Color = Color("f5c542") if stars > 0 else (Color("2fc4b2") if unlocked else Color("5b5470"))
		if i == cur:
			r *= 1.0 + 0.06 * sin(t * 4.0)
			draw_circle(p, r + 14.0, Color(0.18, 0.77, 0.7, 0.25 + 0.15 * sin(t * 4.0)))
		if lv.boss:
			var bt: Texture2D = boss_tex[lv.hazard]
			var bh := 150.0
			var bw2 := bh * bt.get_width() / bt.get_height()
			var tint: Color = game.BOSSES[lv.hazard].tint if not ResourceLoader.exists("res://assets/gfx/bosses/%s.png" % lv.hazard) else Color.WHITE
			draw_texture_rect(bt, Rect2(p.x - bw2 / 2.0, p.y - r - bh + 30.0, bw2, bh), false, tint if unlocked else Color(0.45, 0.45, 0.5))
		var nk: String = "node_locked" if not unlocked else ("node_boss" if lv.boss else "node")
		var art: bool = node_tex.has(nk)
		var lift := 0.0
		if art:
			var nt: Texture2D = node_tex[nk]
			var nh := r * 2.5
			var nw := nh * nt.get_width() / nt.get_height()
			draw_circle(p + Vector2(0, 8), r * 1.05, Color(0, 0, 0, 0.3))
			draw_texture_rect(nt, Rect2(p.x - nw / 2.0, p.y - nh * 0.53, nw, nh), false)
			if not unlocked:
				lift = -r * 0.25
		else:
			draw_circle(p + Vector2(0, 7), r, Color(0, 0, 0, 0.35))
			draw_circle(p, r, col.darkened(0.35))
			draw_circle(p, r - 7.0, col)
			draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.35))
		var label: String = "BOSS" if lv.boss else str(i + 1)
		var fs2: int = 30 if lv.boss else (28 if not unlocked and art else 36)
		var lw := f_display.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var tc: Color = Color("4a2a06") if unlocked else Color("2a2540")
		if art and unlocked and stars > 0:
			tc = Color("6b3a00")
		draw_string(f_display, Vector2(p.x - lw / 2.0, p.y + lift + fs2 * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
		if lv.boss:
			var nl := str(i + 1)
			var nw := f_body.get_string_size(nl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f_body, Vector2(p.x - nw / 2.0, p.y + r - 12.0), nl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tc)
		if stars > 0:
			for s in 3:
				_star(p + Vector2((s - 1) * 26.0, r + 14.0 - (4.0 if s == 1 else 0.0)), 12.0, Color("f5c542") if s < stars else Color(0.3, 0.26, 0.45))
		if not unlocked and not art:
			var lc := p + Vector2(r * 0.62, -r * 0.62)
			draw_circle(lc, 16.0, Color("2a2540"))
			draw_rect(Rect2(lc - Vector2(8, 2), Vector2(16, 12)), Color("c9bba3"))
			draw_arc(lc + Vector2(0, -2), 6.0, PI, TAU, 10, Color("c9bba3"), 3.0)
	# Zaki marks the current level
	var hp := node_pos(cur) - Vector2(0, scroll)
	var hh := 120.0
	var hw := hh * hero_tex.get_width() / hero_tex.get_height()
	var bob := -absf(sin(t * 3.2)) * 10.0
	var side: float = 1.0 if hp.x < size.x * 0.5 else -1.0
	draw_texture_rect(hero_tex, Rect2(hp.x + side * (NODE_R + 18.0) - hw / 2.0, hp.y - hh * 0.75 + bob, hw, hh), false)

func _draw_land(w: int, r: Rect2) -> void:
	var th: String = game.WORLDS[w].theme
	var gc: Array = GROUND.get(th, GROUND.sand)
	_vgrad(r, gc[1], gc[0])
	var lava := th == "emerald"
	var water := Color("ff7a1a") if lava else Color("2f86c9")
	var water2 := Color("ffd04a") if lava else Color("5fc0ee")
	var bank := Color("ffb347").darkened(0.5) if lava else Color("6fae4a")
	var step := 14.0
	var y := r.position.y
	var left_b := PackedVector2Array()
	var right_b := PackedVector2Array()
	var left_w := PackedVector2Array()
	var right_w := PackedVector2Array()
	while y <= r.end.y + step:
		var yy := minf(y, r.end.y)
		var cx := river_x(yy + scroll)
		var rw := size.x * (0.075 + 0.015 * sin(yy * 0.01 + w))
		left_b.append(Vector2(cx - rw * 1.7, yy))
		right_b.append(Vector2(cx + rw * 1.7, yy))
		left_w.append(Vector2(cx - rw, yy))
		right_w.append(Vector2(cx + rw, yy))
		y += step
	var bank_poly := left_b.duplicate()
	var rb := right_b.duplicate()
	rb.reverse()
	bank_poly.append_array(rb)
	draw_colored_polygon(bank_poly, bank)
	var water_poly := left_w.duplicate()
	var rw2 := right_w.duplicate()
	rw2.reverse()
	water_poly.append_array(rw2)
	draw_colored_polygon(water_poly, water)
	# shimmer lines drifting down the river
	for k in left_w.size():
		if (k + int(t * 6.0)) % 5 == 0:
			var a := left_w[k].lerp(right_w[k], 0.3)
			var b := left_w[k].lerp(right_w[k], 0.6)
			draw_line(a, b, Color(water2, 0.7), 3.0, true)
	# a few palms / rocks along the banks
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 977 + 13
	for k in 18:
		var yy := r.position.y + rng.randf() * r.size.y
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var cx := river_x(yy + scroll) + side * size.x * (0.2 + rng.randf() * 0.2)
		if lava or th == "crystal" or th == "iron":
			draw_circle(Vector2(cx, yy), 10.0 + rng.randf() * 12.0, gc[1].darkened(0.3))
		else:
			draw_line(Vector2(cx, yy), Vector2(cx + 6.0, yy - 46.0), Color("6b4a2a"), 6.0)
			for leaf in 5:
				var ang := -PI / 2.0 + (leaf - 2) * 0.6
				draw_line(Vector2(cx + 6.0, yy - 46.0), Vector2(cx + 6.0, yy - 46.0) + Vector2.from_angle(ang) * 30.0, Color("3f8a3a"), 7.0, true)

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)

func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
