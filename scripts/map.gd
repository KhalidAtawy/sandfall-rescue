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
var room_tex := {}
var boss_tex := {}
var hero_tex: Texture2D
var badge_tex := {}

func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for n in ["sand", "water", "crystal", "lava"]:
		room_tex[n] = load("res://assets/gfx/rooms/room_%s.jpg" % n)
	for n in ["golem", "mummy", "cobra"]:
		boss_tex[n] = load("res://assets/gfx/chasers/%s.png" % n)
	hero_tex = load("res://assets/gfx/zaki3/exit_1.png")
	for m in ["drain", "iron", "chain", "crust", "wrap", "race"]:
		var p := "res://assets/gfx/badges/badge_%s.png" % m
		if ResourceLoader.exists(p):
			badge_tex[m] = load(p)

func total_h() -> float:
	return top_pad + bottom_pad + game.LEVELS.size() * SPACING + game.WORLDS.size() * WORLD_GAP

func node_pos(i: int) -> Vector2:
	var w := i / 10
	var y := total_h() - bottom_pad - i * SPACING - w * WORLD_GAP - SPACING * 0.5
	var x := size.x * 0.5 + sin(i * 0.85) * size.x * 0.24
	if i % 10 == 9:
		x = size.x * 0.5
	return Vector2(x, y)

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
	# world backdrops
	for w in game.WORLDS.size():
		var wd: Dictionary = game.WORLDS[w]
		var y_bot := node_pos(w * 10).y + SPACING * 0.5 + WORLD_GAP * 0.5 - scroll
		var y_top := node_pos(w * 10 + 9).y - SPACING * 0.7 - scroll
		if y_bot < -50 or y_top > size.y + 50:
			continue
		var th: Dictionary = game.THEMES[wd.theme]
		var rt: Texture2D = room_tex[th.room]
		var r := Rect2(0, y_top, W, y_bot - y_top)
		var k := W / rt.get_width()
		var src_h := minf(rt.get_height(), r.size.y / k)
		draw_texture_rect_region(rt, r, Rect2(0, (rt.get_height() - src_h) * 0.5, rt.get_width(), src_h), th.room_tint * Color(0.55, 0.55, 0.6))
		# fades between worlds
		_vgrad(Rect2(0, y_top, W, 140), Color(0.08, 0.06, 0.14, 1), Color(0.08, 0.06, 0.14, 0))
		_vgrad(Rect2(0, y_bot - 140, W, 140), Color(0.08, 0.06, 0.14, 0), Color(0.08, 0.06, 0.14, 1))
		# world banner
		var by := y_bot - 70.0
		var bw := minf(W - 80.0, 520.0)
		var br := Rect2((W - bw) / 2.0, by - 38.0, bw, 76.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.17, 0.12, 0.3, 0.92)
		sb.border_color = Color("b9821c")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(38)
		draw_style_box(sb, br)
		var title := "World %d · %s" % [w + 1, wd.name]
		var fs := 32
		var tw := f_display.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f_display, Vector2((W - tw) / 2.0, by + 12.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("f5c542"))
		if wd.mode != "" and badge_tex.has(wd.mode):
			var bt: Texture2D = badge_tex[wd.mode]
			draw_texture_rect(bt, Rect2(br.position.x - 30.0, by - 52.0, 104, 104), false)
	# path
	for i in game.LEVELS.size() - 1:
		var a := node_pos(i) - Vector2(0, scroll)
		var b := node_pos(i + 1) - Vector2(0, scroll)
		if maxf(a.y, b.y) < -80 or minf(a.y, b.y) > size.y + 80:
			continue
		var n := int(a.distance_to(b) / 26.0)
		for k in range(1, n):
			var p := a.lerp(b, float(k) / n)
			var done: bool = i < cur
			draw_circle(p, 6.0, Color("f5c542") if done else Color(1, 1, 1, 0.28))
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
			draw_texture_rect(bt, Rect2(p.x - bw2 / 2.0, p.y - r - bh + 30.0, bw2, bh), false, Color(1, 1, 1) if unlocked else Color(0.45, 0.45, 0.5))
		draw_circle(p + Vector2(0, 7), r, Color(0, 0, 0, 0.35))
		draw_circle(p, r, col.darkened(0.35))
		draw_circle(p, r - 7.0, col)
		draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.22, Color(1, 1, 1, 0.35))
		var label: String = "BOSS" if lv.boss else str(i + 1)
		var fs2: int = 30 if lv.boss else 34
		var lw := f_display.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var tc: Color = Color("3b2203") if unlocked else Color("2a2540")
		draw_string(f_display, Vector2(p.x - lw / 2.0, p.y + fs2 * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
		if lv.boss:
			var nl := str(i + 1)
			var nw := f_body.get_string_size(nl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f_body, Vector2(p.x - nw / 2.0, p.y + r - 12.0), nl, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tc)
		if stars > 0:
			for s in 3:
				_star(p + Vector2((s - 1) * 26.0, r + 14.0 - (4.0 if s == 1 else 0.0)), 12.0, Color("f5c542") if s < stars else Color(0.3, 0.26, 0.45))
		if not unlocked:
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

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)

func _vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))
