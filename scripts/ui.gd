extends CanvasLayer
## HUD, toasts, level select and win/lose cards. All built in code.

const HUD_H := 132.0
const GOLD := Color("f5c542")
const GOLD_DEEP := Color("b9821c")
const INK := Color("fff3dc")
const INK_SOFT := Color("c9bba3")
const PANEL := Color("231a3a")
const PANEL_2 := Color("33265a")

var game: Node
var font_display: Font
var font_body: Font
var font_black: Font

var root: Control
var hud: Control
var menu_btn: Button
var lvl_label: Label
var name_label: Label
var time_label: Label
var extra_label: Label
var extra_icon: TextureRect
var moves_panel: PanelContainer
var moves_label: Label
var ring: Ring
var pct_label: Label
var toast_panel: PanelContainer
var toast_label: Label
var toast_tw: Tween
var overlay: Control
var dim: ColorRect
var center: CenterContainer
var card: PanelContainer
var card_box: VBoxContainer
var vsize := Vector2(720, 1280)

class Ring extends Control:
	var p := 100.0
	var col := Color("e1a64a")
	func _draw() -> void:
		var c = size / 2.0
		var r = minf(size.x, size.y) / 2.0 - 5.0
		draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.14), 9.0, true)
		if p > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * p / 100.0, 48, Color("f5c542"), 9.0, true)
		draw_circle(c, r * 0.42, col.darkened(0.35))
		draw_circle(c + Vector2(-r * 0.1, -r * 0.1), r * 0.3, col)
		draw_circle(c + Vector2(-r * 0.18, -r * 0.18), r * 0.09, Color(1, 1, 1, 0.6))

class Stars extends Control:
	var n := 0
	var star_size := 64.0
	func _star(c: Vector2, r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 10:
			var a = -PI / 2.0 + k * PI / 5.0
			var rr = r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		return pts
	func _draw() -> void:
		var gap: float = star_size * 1.15
		var x0: float = size.x / 2.0 - gap
		for i in 3:
			var c = Vector2(x0 + i * gap, size.y / 2.0 - (star_size * 0.15 if i == 1 else 0.0))
			var r: float = star_size / 2.0 * (1.15 if i == 1 else 1.0)
			if i < n:
				draw_colored_polygon(_star(c + Vector2(0, 4), r), Color("9a6410"))
				draw_colored_polygon(_star(c, r), Color("f5c542"))
				draw_colored_polygon(_star(c + Vector2(-r * 0.12, -r * 0.12), r * 0.35), Color(1, 1, 1, 0.35))
			else:
				draw_colored_polygon(_star(c, r), Color("4b3f6e"))

class LevelTile extends Button:
	var idx := 0
	var title := ""
	var stars := 0
	var swatch = Color.WHITE
	var locked := false
	var f_display: Font
	var f_body: Font
	func _draw() -> void:
		var w = size.x
		var a = 0.45 if locked else 1.0
		var num = str(idx + 1)
		var ns := 64
		var tw = f_display.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
		draw_string(f_display, Vector2((w - tw) / 2.0, 72), num, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, Color(1, 0.95, 0.86, a))
		var ts := 26
		var tt = f_body.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x
		draw_string(f_body, Vector2((w - tt) / 2.0, 112), title, HORIZONTAL_ALIGNMENT_LEFT, -1, ts, Color(0.79, 0.73, 0.64, a))
		var sw := Color(swatch.r, swatch.g, swatch.b, a)
		draw_rect(Rect2(w / 2.0 - 30, 126, 60, 12), sw)
		for i in 3:
			var c = Vector2(w / 2.0 + (i - 1) * 34, 166)
			var pts := PackedVector2Array()
			for k in 10:
				var ang = -PI / 2.0 + k * PI / 5.0
				var rr = 14.0 if k % 2 == 0 else 6.3
				pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
			draw_colored_polygon(pts, Color(0.96, 0.77, 0.26, a) if i < stars else Color(0.36, 0.31, 0.53, a))
		if locked:
			var lc := Vector2(w - 34, 30)
			draw_rect(Rect2(lc - Vector2(11, 2), Vector2(22, 18)), Color(0.79, 0.73, 0.64, 0.8))
			draw_arc(lc + Vector2(0, -2), 8, PI, TAU, 12, Color(0.79, 0.73, 0.64, 0.8), 4.0)

class MenuIcon extends Button:
	func _draw() -> void:
		var c = size / 2.0
		for k in 4:
			var o := Vector2(-15 if k % 2 == 0 else 3, -15 if k < 2 else 3)
			draw_rect(Rect2(c + o, Vector2(12, 12)), Color("f5c542"))

func build() -> void:
	layer = 10
	font_display = load("res://assets/fonts/LilitaOne.woff2")
	font_body = load("res://assets/fonts/Nunito-ExtraBold.woff2")
	font_black = load("res://assets/fonts/Nunito-Black.woff2")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font_black
	th.default_font_size = 30
	root.theme = th
	add_child(root)

	# ----- board input catcher (behind HUD and cards) -----
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(ev): game.board_input(ev))
	root.add_child(catcher)

	# ----- HUD -----
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	menu_btn = MenuIcon.new()
	menu_btn.custom_minimum_size = Vector2(78, 78)
	_style_button(menu_btn, PANEL_2, GOLD_DEEP, 20)
	menu_btn.pressed.connect(func():
		game.play("click")
		game.open_menu())
	hud.add_child(menu_btn)
	lvl_label = _label("Level 1", font_display, 40, GOLD)
	hud.add_child(lvl_label)
	name_label = _label("", font_body, 25, INK_SOFT)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hud.add_child(name_label)
	time_label = _label("1:50", font_display, 30, INK)
	hud.add_child(time_label)
	extra_label = _label("", font_black, 24, Color("efe2c4"))
	hud.add_child(extra_label)
	extra_icon = TextureRect.new()
	extra_icon.texture = load("res://assets/gfx/fx/icon_bandage.png")
	extra_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	extra_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	extra_icon.size = Vector2(40, 40)
	extra_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extra_icon.visible = false
	hud.add_child(extra_icon)
	moves_panel = PanelContainer.new()
	moves_panel.add_theme_stylebox_override("panel", _box(PANEL_2, GOLD_DEEP, 22, 4))
	moves_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", -8)
	moves_label = _label("22", font_display, 52, INK)
	moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ml = _label("MOVES", font_black, 18, INK_SOFT)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(moves_label)
	mv.add_child(ml)
	moves_panel.add_child(mv)
	hud.add_child(moves_panel)
	ring = Ring.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ring)
	pct_label = _label("100%", font_display, 34, INK)
	hud.add_child(pct_label)

	# ----- toast -----
	toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.14, 0.92), GOLD_DEEP, 24, 4, 22))
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = _label("", font_black, 30, INK)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel.add_child(toast_label)
	toast_panel.modulate.a = 0.0
	root.add_child(toast_panel)

	# ----- overlay -----
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	dim = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	card = PanelContainer.new()
	var cs = _box(PANEL_2, GOLD_DEEP, 44, 6, 34)
	cs.bg_color = Color("2b2050")
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size = 30
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 22)
	card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(card_box)
	overlay.visible = false

func layout(vs: Vector2, safe: Vector2) -> void:
	vsize = vs
	var top = safe.x + 18.0
	var pad := 22.0
	hud.position = Vector2(0, 0)
	hud.size = Vector2(vs.x, top + HUD_H)
	menu_btn.position = Vector2(pad, top + 12)
	menu_btn.size = Vector2(78, 78)
	lvl_label.position = Vector2(pad + 96, top + 6)
	name_label.position = Vector2(pad + 98, top + 50)
	time_label.position = Vector2(pad + 98, top + 82)
	extra_label.position = Vector2(pad + 298, top + 87)
	extra_icon.position = Vector2(pad + 252, top + 82)
	var right = vs.x - pad
	pct_label.position = Vector2(right - 88, top + 26)
	ring.position = Vector2(right - 88 - 82, top + 12)
	ring.size = Vector2(76, 76)
	moves_panel.position = Vector2(ring.position.x - 16 - 120, top + 2)
	moves_panel.custom_minimum_size = Vector2(120, 96)
	moves_panel.size = Vector2(120, 96)
	name_label.size = Vector2(maxf(60.0, moves_panel.position.x - name_label.position.x - 12), 34)
	var tw = minf(vs.x - 60.0, 600.0)
	toast_panel.custom_minimum_size = Vector2(tw, 0)
	toast_panel.size = Vector2(tw, 0)
	toast_panel.position = Vector2((vs.x - tw) / 2.0, vs.y * 0.42)
	card.custom_minimum_size = Vector2(minf(vs.x - 48.0, 620.0), 0)

func set_level(n: int, title: String, col: Color) -> void:
	lvl_label.text = "Level %d" % n
	name_label.text = title
	ring.col = col
	ring.queue_redraw()

func update_time(sec: int) -> void:
	time_label.text = "Time %d:%02d" % [sec / 60, sec % 60]
	time_label.add_theme_color_override("font_color", Color("ff8f6b") if sec <= 15 else INK)

func set_extra(text: String) -> void:
	extra_icon.visible = text.begins_with("Bandages")
	extra_label.text = text.replace("Bandages ", "") if extra_icon.visible else text

func update_hud(moves: int, pct: int) -> void:
	moves_label.text = "∞" if moves > 999 else str(maxi(0, moves))
	moves_label.add_theme_color_override("font_color", Color("ff8f6b") if moves <= 5 else INK)
	pct_label.text = "%d%%" % pct
	ring.p = pct
	ring.queue_redraw()

func toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.reset_size()
	toast_panel.position.x = (vsize.x - toast_panel.size.x) / 2.0
	if toast_tw:
		toast_tw.kill()
	toast_tw = create_tween()
	toast_tw.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	toast_tw.tween_interval(2.6)
	toast_tw.tween_property(toast_panel, "modulate:a", 0.0, 0.4)

# ----- cards -----
func _clear_card() -> void:
	for ch in card_box.get_children():
		ch.queue_free()

func _show_card() -> void:
	overlay.visible = true
	overlay.modulate.a = 0.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.86, 0.86)
	var t = create_tween().set_parallel(true)
	t.tween_property(overlay, "modulate:a", 1.0, 0.2)
	t.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().process_frame
	card.pivot_offset = card.size / 2.0

func hide_overlay() -> void:
	overlay.visible = false

func show_menu() -> void:
	_clear_card()
	var logo := TextureRect.new()
	logo.texture = load("res://assets/gfx/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(card.custom_minimum_size.x - 120, (card.custom_minimum_size.x - 120) * 0.56)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_box.add_child(logo)
	var d = _label("Zaki is holding the door shut. Match gems beside the debris to drain it before your moves run out.", font_body, 28, INK_SOFT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
	card_box.add_child(d)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var tile_w = (card.custom_minimum_size.x - 68 - 18) / 2.0
	for i in game.LEVELS.size():
		var lt := LevelTile.new()
		lt.idx = i
		lt.title = game.LEVELS[i].name
		lt.stars = int(game.progress.best[i])
		lt.swatch = game.THEMES[game.LEVELS[i].theme].ui
		lt.locked = not game.level_unlocked(i)
		lt.disabled = lt.locked
		lt.f_display = font_display
		lt.f_body = font_body
		lt.custom_minimum_size = Vector2(tile_w, 184)
		_style_button(lt, Color("3a2d66"), Color("54438a"), 26)
		var li: int = i
		lt.pressed.connect(func():
			game.play("click")
			game.start_level(li))
		grid.add_child(lt)
	card_box.add_child(grid)
	if game.state == "paused":
		var b = _button("Back to game", "ghost")
		b.pressed.connect(func():
			game.play("click")
			game.resume())
		card_box.add_child(b)
	_show_card()

func show_intro(n: int, title: String, mode_title: String, text: String, badge: Texture2D = null) -> void:
	_clear_card()
	if badge != null:
		var b0 := TextureRect.new()
		b0.texture = badge
		b0.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b0.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b0.custom_minimum_size = Vector2(0, 230)
		b0.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(b0)
	var lv = _label("Level %d · %s" % [n, title], font_body, 30, INK_SOFT)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(lv)
	var t = _label(mode_title, font_display, 66, GOLD)
	_heading(t)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
	card_box.add_child(t)
	var d = _label(text, font_body, 30, INK)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
	card_box.add_child(d)
	var b = _button("Play", "gold")
	b.pressed.connect(func():
		game.play("click")
		game.resume())
	card_box.add_child(b)
	_show_card()

func show_win(stars: int, moves: int, title: String, has_next: bool) -> void:
	_clear_card()
	var t = _label("Zaki is safe!", font_display, 66, GOLD)
	_heading(t)
	card_box.add_child(t)
	var st := Stars.new()
	st.n = 0
	st.star_size = 84
	st.custom_minimum_size = Vector2(320, 120)
	card_box.add_child(st)
	for k in stars:
		get_tree().create_timer(0.35 + k * 0.28).timeout.connect(func():
			if not is_instance_valid(st):
				return
			st.n = k + 1
			st.queue_redraw()
			game.play("shine", 1.0 + k * 0.15, -4.0))
	var d = _label("%d move%s to spare in %s." % [moves, "" if moves == 1 else "s", title], font_body, 30, INK_SOFT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(d)
	if has_next:
		var nb = _button("Next level", "gold")
		nb.pressed.connect(func():
			game.play("click")
			game.start_level(game.level_idx + 1))
		card_box.add_child(nb)
	else:
		var e = _label("You cleared every chamber. More levels are on the way.", font_body, 28, INK_SOFT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
		card_box.add_child(e)
	var ab = _button("Play again", "teal")
	ab.pressed.connect(func():
		game.play("click")
		game.start_level(game.level_idx))
	card_box.add_child(ab)
	var lb = _button("All levels", "ghost")
	lb.pressed.connect(func():
		game.play("click")
		game.state = "menu"
		show_menu())
	card_box.add_child(lb)
	_show_card()

func show_lose(left: int, can_extra: bool, title := "Zaki got caught!") -> void:
	_clear_card()
	var t = _label(title, font_display, 62, GOLD)
	_heading(t)
	card_box.add_child(t)
	var d = _label("%d%% of the sand was still blocking the door." % left, font_body, 30, INK_SOFT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(d)
	if can_extra:
		var mb = _button("+5 moves, +25 s", "gold")
		mb.pressed.connect(func():
			game.play("click")
			game.plus_five())
		card_box.add_child(mb)
	var rb = _button("Try again", "teal")
	rb.pressed.connect(func():
		game.play("click")
		game.start_level(game.level_idx))
	card_box.add_child(rb)
	var lb = _button("All levels", "ghost")
	lb.pressed.connect(func():
		game.play("click")
		game.state = "menu"
		show_menu())
	card_box.add_child(lb)
	_show_card()

# ----- helpers -----
func _label(text: String, f: Font, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _heading(l: Label) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color("7a4a14"))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 6)
	l.add_theme_color_override("font_outline_color", Color("5a3208"))
	l.add_theme_constant_override("outline_size", 6)

func _box(bg: Color, border: Color, radius: int, bw: int, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	s.anti_aliasing = true
	return s

func _style_button(b: Button, bg: Color, border: Color, radius: int) -> void:
	var n = _box(bg, border, radius, 4)
	var h = _box(bg.lightened(0.08), border, radius, 4)
	var p = _box(bg.darkened(0.15), border, radius, 4)
	var dsb = _box(bg.darkened(0.25), border.darkened(0.3), radius, 4)
	var fo = _box(Color(0, 0, 0, 0), Color("2fc4b2"), radius, 4)
	fo.draw_center = false
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", dsb)
	b.add_theme_stylebox_override("focus", fo)

func _button(text: String, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_display)
	b.add_theme_font_size_override("font_size", 44 if kind != "ghost" else 34)
	b.custom_minimum_size = Vector2(0, 96 if kind != "ghost" else 64)
	var bg := Color("f8c23a")
	var edge := Color("a86c10")
	var fg := Color("3b2203")
	if kind == "teal":
		bg = Color("2fbfae")
		edge = Color("136b60")
		fg = Color("062925")
	if kind == "ghost":
		var e := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, e)
		b.add_theme_color_override("font_color", INK_SOFT)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
		return b
	for st in ["normal", "hover", "pressed", "focus"]:
		var s = _box(bg if st != "pressed" else bg.darkened(0.1), edge, 28, 0)
		s.border_width_bottom = 8 if st != "pressed" else 3
		s.border_color = edge
		if st == "hover":
			s.bg_color = bg.lightened(0.08)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	return b
