extends CanvasLayer
## HUD, toasts, level select and win/lose cards. All built in code.

const HUD_H := 132.0
const BAR_H := 118.0
const MapView := preload("res://scripts/map.gd")
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
var bar: Control
var bar_btns := {}
var tip_panel: PanelContainer
var tip_label: Label
var tip_tw: Tween
var praise_label: Label
var map_layer: Control
var map_view: Control
var top_bar: Control
var coins_icon: Control
var coins_label: Label
var bar_coins: PanelContainer      # coin count shown inside a level
var bar_coins_label: Label
var title_layer: Control           # the start screen with the logo
var title_logo: TextureRect
var title_tap: Label
var title_hero: TextureRect
var title_t := 0.0
var lives_icon: Control
var lives_label: Label
var lives_timer: Label
var gear_btn: Button
var play_btn: Button
var pre_sel := {}
var pre_btns := {}
var nolives_timer: Label
var sec_t := 0.0

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

class CoinIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		draw_circle(c + Vector2(0, 2), r, Color("9a6410"))
		draw_circle(c, r, Color("f5c542"))
		draw_circle(c, r * 0.68, Color("e0a82a"))
		draw_arc(c, r * 0.68, 0, TAU, 24, Color("fff0a8"), 2.0, true)
		draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.6))

class HeartIcon extends Control:
	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		var pts := PackedVector2Array()
		for k in 40:
			var t := TAU * k / 40.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			pts.append(c + Vector2(x, y) * r / 17.0)
		draw_colored_polygon(pts, Color("e0344a"))
		draw_circle(c + Vector2(-r * 0.35, -r * 0.3), r * 0.18, Color(1, 1, 1, 0.5))

class BoosterBtn extends Button:
	var key := ""
	var count := 0
	var price := 0
	var armed := false
	var f: Font
	func _draw() -> void:
		var c := Vector2(size.x / 2.0, size.y / 2.0 - 6.0)
		var r := minf(size.x, size.y) / 2.0 - 10.0
		draw_circle(c + Vector2(0, 4), r, Color(0, 0, 0, 0.3))
		draw_circle(c, r, Color("f5c542") if armed else Color("3a2d66"))
		draw_arc(c, r, 0, TAU, 40, Color("b9821c"), 4.0, true)
		match key:
			"hammer", "pre_rocket_unused":
				draw_set_transform(c, -0.7, Vector2.ONE)
				draw_rect(Rect2(-r * 0.09, -r * 0.2, r * 0.18, r * 0.85), Color("8a5a2b"))
				draw_rect(Rect2(-r * 0.42, -r * 0.55, r * 0.84, r * 0.36), Color("c9ccd4"))
				draw_rect(Rect2(-r * 0.42, -r * 0.55, r * 0.84, r * 0.1), Color("eef0f5"))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"shuffle":
				for k in 2:
					var a0 := -0.3 + k * PI
					draw_arc(c, r * 0.45, a0, a0 + 2.4, 18, Color("2fc4b2"), r * 0.14, true)
					var tip := c + Vector2.from_angle(a0 + 2.4) * r * 0.45
					var dir := Vector2.from_angle(a0 + 2.4 + PI / 2.0)
					var side := dir.orthogonal()
					draw_colored_polygon(PackedVector2Array([tip + dir * r * 0.22, tip + side * r * 0.18, tip - side * r * 0.18]), Color("2fc4b2"))
			"moves5":
				var tx := "+5"
				var fs := int(r * 0.9)
				var tw := f.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2(c.x - tw / 2.0, c.y + fs * 0.35), tx, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff3dc"))
		# count or price tag
		var tag: String = ("x%d" % count) if count > 0 else str(price)
		var tf := 22
		var tw2: float = f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tf).x + (26.0 if count <= 0 else 0.0)
		var tr := Rect2(Vector2(c.x - tw2 / 2.0 - 10.0, size.y - 30.0), Vector2(tw2 + 20.0, 28.0))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2fbf7a") if count > 0 else Color("231a3a")
		sb.border_color = Color("b9821c")
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		draw_style_box(sb, tr)
		var x0 := tr.position.x + 10.0
		if count <= 0:
			draw_circle(Vector2(x0 + 10.0, tr.position.y + 14.0), 9.0, Color("f5c542"))
			x0 += 26.0
		draw_string(f, Vector2(x0, tr.position.y + 22.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tf, Color("fff3dc"))

class PreBtn extends Button:
	var key := ""
	var on := false
	var count := 0
	var price := 0
	var icon_tex: Texture2D
	var f: Font
	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("3d2f6b") if not on else Color("1f6b5f")
		sb.border_color = Color("2fc4b2") if on else Color("54438a")
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(22)
		draw_style_box(sb, r)
		var s := size.y - 46.0
		draw_texture_rect(icon_tex, Rect2(Vector2((size.x - s) / 2.0, 10.0), Vector2(s, s)), false)
		var tag: String = "ON" if on else (("x%d" % count) if count > 0 else "%d coins" % price)
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		draw_string(f, Vector2((size.x - tw) / 2.0, size.y - 14.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("fff3dc"))

class GearBtn extends Button:
	func _draw() -> void:
		var c := size / 2.0
		var col := Color("f5c542")
		for k in 8:
			var a := TAU * k / 8.0
			draw_set_transform(c, a, Vector2.ONE)
			draw_rect(Rect2(-6, -24, 12, 10), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(c, 17.0, col)
		draw_circle(c, 7.0, Color("2b2050"))

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

	# ----- booster bar -----
	bar = Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	for key in ["hammer", "shuffle", "moves5"]:
		var b := BoosterBtn.new()
		b.key = key
		b.f = font_display
		b.custom_minimum_size = Vector2(104, 108)
		var e := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, e)
		var k2: String = key
		b.pressed.connect(func():
			game.play("click")
			game.use_booster(k2))
		bar.add_child(b)
		bar_btns[key] = b
	bar_coins = PanelContainer.new()
	bar_coins.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.14, 0.88), GOLD_DEEP, 30, 3, 10))
	bar_coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bch := HBoxContainer.new()
	bch.add_theme_constant_override("separation", 8)
	var bci := CoinIcon.new()
	bci.custom_minimum_size = Vector2(40, 40)
	bch.add_child(bci)
	bar_coins_label = _label("0", font_display, 34, INK)
	bch.add_child(bar_coins_label)
	bar_coins.add_child(bch)
	bar.add_child(bar_coins)

	# ----- tip and praise -----
	tip_panel = PanelContainer.new()
	tip_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.06, 0.14, 0.94), Color("2fc4b2"), 22, 3, 18))
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_label = _label("", font_black, 26, INK)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_panel.add_child(tip_label)
	tip_panel.visible = false
	root.add_child(tip_panel)
	praise_label = _label("", font_display, 92, GOLD)
	_heading(praise_label)
	praise_label.add_theme_constant_override("outline_size", 14)
	praise_label.modulate.a = 0.0
	root.add_child(praise_label)

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

	# ----- journey map -----
	map_layer = Control.new()
	map_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(map_layer)
	map_view = MapView.new()
	map_view.game = game
	map_view.ui = self
	map_view.f_display = font_display
	map_view.f_body = font_body
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_layer.add_child(map_view)
	map_view.setup()
	top_bar = PanelContainer.new()
	top_bar.add_theme_stylebox_override("panel", _box(Color(0.1, 0.07, 0.18, 0.9), GOLD_DEEP, 0, 0))
	top_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	map_layer.add_child(top_bar)
	lives_icon = HeartIcon.new()
	coins_icon = CoinIcon.new()
	lives_label = _label("5", font_display, 40, INK)
	lives_timer = _label("Full", font_body, 22, INK_SOFT)
	coins_label = _label("300", font_display, 40, INK)
	for n in [lives_icon, lives_label, lives_timer, coins_icon, coins_label]:
		map_layer.add_child(n)
	gear_btn = GearBtn.new()
	_style_button(gear_btn, PANEL_2, GOLD_DEEP, 20)
	gear_btn.pressed.connect(func():
		game.play("click")
		show_settings())
	map_layer.add_child(gear_btn)
	play_btn = _button("Play", "gold")
	play_btn.add_theme_font_size_override("font_size", 50)
	play_btn.pressed.connect(func():
		game.play("click")
		game.select_level(game.meta.current_level()))
	map_layer.add_child(play_btn)
	map_layer.visible = false

	# ----- title screen -----
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(title_layer)
	var tbg := TextureRect.new()
	tbg.name = "TitleBg"
	var tbp := "res://assets/gfx/ui/title_bg.jpg"
	if not ResourceLoader.exists(tbp):
		tbp = "res://assets/gfx/rooms/room_sand.jpg"
	tbg.texture = load(tbp)
	tbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tbg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(tbg)
	var tshade := ColorRect.new()
	tshade.name = "TitleShade"
	tshade.color = Color(0.05, 0.03, 0.1, 0.0 if tbp.ends_with("title_bg.jpg") else 0.35)
	tshade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tshade.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(tshade)
	title_hero = TextureRect.new()
	var hp := "res://assets/gfx/ui/title_hero.png"
	if not ResourceLoader.exists(hp):
		hp = "res://assets/gfx/zaki3/exit_1.png"
	title_hero.texture = load(hp)
	title_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(title_hero)
	title_logo = TextureRect.new()
	title_logo.texture = load("res://assets/gfx/ui/logo.png")
	title_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(title_logo)
	title_tap = _label("Tap to start", font_display, 46, GOLD)
	_heading(title_tap)
	title_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_layer.add_child(title_tap)
	title_layer.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and title_layer.visible:
			hide_title())
	title_layer.visible = false

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
	var bottom := vs.y - safe.y - BAR_H - 6.0
	bar.position = Vector2(0, bottom)
	bar.size = Vector2(vs.x, BAR_H)
	var keys := ["hammer", "shuffle", "moves5"]
	var bgap := minf(150.0, (vs.x - 200.0) / 3.2)
	for k in keys.size():
		var b: Control = bar_btns[keys[k]]
		b.size = Vector2(104, 108)
		b.position = Vector2(vs.x / 2.0 + 70.0 + (k - 1) * bgap - 52.0, 4.0)
	bar_coins.position = Vector2(pad - 6.0, 28.0)
	bar_coins.size = Vector2(0, 0)
	var tpw := minf(vs.x - 40.0, 640.0)
	tip_panel.custom_minimum_size = Vector2(tpw, 0)
	tip_panel.size = Vector2(tpw, 0)
	tip_panel.position = Vector2((vs.x - tpw) / 2.0, bottom - 150.0)
	praise_label.size = Vector2(vs.x, 120)
	praise_label.position = Vector2(0, vs.y * 0.36)
	praise_label.pivot_offset = praise_label.size / 2.0
	# map
	var mt := safe.x
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(vs.x, mt + 104.0)
	lives_icon.position = Vector2(26, mt + 26)
	lives_icon.size = Vector2(56, 52)
	lives_label.position = Vector2(92, mt + 16)
	lives_timer.position = Vector2(94, mt + 62)
	coins_icon.position = Vector2(vs.x * 0.5 - 40.0, mt + 28)
	coins_icon.size = Vector2(48, 48)
	coins_label.position = Vector2(vs.x * 0.5 + 18.0, mt + 20)
	gear_btn.position = Vector2(vs.x - 100.0, mt + 14)
	gear_btn.size = Vector2(78, 78)
	var pw := minf(vs.x - 120.0, 460.0)
	play_btn.position = Vector2((vs.x - pw) / 2.0, vs.y - safe.y - 150.0)
	play_btn.size = Vector2(pw, 112)
	map_view.top_pad = mt + 150.0
	# title
	title_logo.size = Vector2(vs.x * 0.86, vs.x * 0.86 * 0.5)
	title_logo.position = Vector2(vs.x * 0.07, mt + vs.y * 0.08)
	title_hero.size = Vector2(vs.x * 0.62, vs.y * 0.36)
	title_hero.position = Vector2(vs.x * 0.19, vs.y * 0.44)
	title_tap.size = Vector2(vs.x, 70)
	title_tap.position = Vector2(0, vs.y - safe.y - 190.0)
	title_tap.pivot_offset = title_tap.size / 2.0
	map_view.bottom_pad = safe.y + 330.0

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

func refresh_bar() -> void:
	for k in bar_btns:
		var b: BoosterBtn = bar_btns[k]
		b.count = int(game.meta.boosters.get(k, 0))
		b.price = int(game.meta.PRICES[k])
		b.armed = (k == "hammer" and game.hammer_armed)
		b.queue_redraw()
	bar_coins_label.text = str(game.meta.coins)
	bar_coins.reset_size()

func set_tip(text: String, hold := 0.0) -> void:
	if tip_tw:
		tip_tw.kill()
	if text == "":
		tip_panel.visible = false
		return
	tip_label.text = text
	tip_panel.visible = true
	tip_panel.reset_size()
	tip_panel.position.x = (vsize.x - tip_panel.size.x) / 2.0
	tip_panel.modulate.a = 0.0
	tip_tw = create_tween()
	tip_tw.tween_property(tip_panel, "modulate:a", 1.0, 0.25)
	if hold > 0.0:
		tip_tw.tween_interval(hold)
		tip_tw.tween_property(tip_panel, "modulate:a", 0.0, 0.4)
		tip_tw.tween_callback(func(): tip_panel.visible = false)

func praise(text: String) -> void:
	praise_label.text = text
	praise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	praise_label.scale = Vector2(0.4, 0.4)
	praise_label.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(praise_label, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(praise_label, "scale", Vector2.ONE, 0.1)
	t.tween_interval(0.55)
	t.tween_property(praise_label, "modulate:a", 0.0, 0.35)

func _process(dt: float) -> void:
	if title_layer.visible:
		_title_anim(dt)
	sec_t += dt
	if sec_t < 0.5:
		return
	sec_t = 0.0
	if map_layer.visible:
		_refresh_top()
	if nolives_timer and is_instance_valid(nolives_timer):
		game.meta.tick_lives()
		var sl: int = game.meta.seconds_to_next_life()
		nolives_timer.text = "Next life in %d:%02d" % [sl / 60, sl % 60]
		if game.meta.lives > 0:
			nolives_timer = null
			hide_overlay()
			game.show_map()

func _refresh_top() -> void:
	game.meta.tick_lives()
	lives_label.text = str(game.meta.lives)
	var sl: int = game.meta.seconds_to_next_life()
	lives_timer.text = "Full" if game.meta.lives >= game.meta.MAX_LIVES else "%d:%02d" % [sl / 60, sl % 60]
	coins_label.text = str(game.meta.coins)
	play_btn.text = "Level %d" % (game.meta.current_level() + 1)

func show_title() -> void:
	hide_overlay()
	hud.visible = false
	bar.visible = false
	map_layer.visible = false
	title_layer.visible = true
	title_t = 0.0
	title_logo.pivot_offset = title_logo.size / 2.0
	title_logo.scale = Vector2(0.2, 0.2)
	title_logo.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(title_logo, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_logo, "modulate:a", 1.0, 0.4)

func hide_title() -> void:
	if not title_layer.visible:
		return
	game.play("click")
	var tw := create_tween()
	tw.tween_property(title_layer, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		title_layer.visible = false
		title_layer.modulate.a = 1.0)
	game.show_map()

func _title_anim(dt: float) -> void:
	title_t += dt
	title_tap.modulate.a = 0.8 + 0.2 * sin(title_t * 3.5)
	title_tap.scale = Vector2.ONE * (1.0 + 0.04 * sin(title_t * 3.5))
	title_hero.position.y = vsize.y * 0.44 + sin(title_t * 1.6) * 8.0
	if title_logo.modulate.a >= 1.0:
		title_logo.rotation = sin(title_t * 1.2) * 0.02

func show_map() -> void:
	hide_overlay()
	set_tip("")
	hud.visible = false
	bar.visible = false
	map_layer.visible = true
	_refresh_top()
	await get_tree().process_frame
	map_view.scroll_to(game.meta.current_level())

func hide_map() -> void:
	map_layer.visible = false
	hud.visible = true
	bar.visible = true
	refresh_bar()

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

func _toggle_row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for it in items:
		row.add_child(it)
	return row

func _setting_btn(key: String, label: String) -> Button:
	var on: bool = game.meta.settings[key]
	var b = _button("%s: %s" % [label, "On" if on else "Off"], "teal" if on else "dark")
	b.add_theme_font_size_override("font_size", 34)
	b.custom_minimum_size = Vector2(0, 78)
	b.pressed.connect(func():
		game.meta.settings[key] = not game.meta.settings[key]
		game.apply_settings()
		game.play("click")
		var on2: bool = game.meta.settings[key]
		b.text = "%s: %s" % [label, "On" if on2 else "Off"])
	return b

func show_pause() -> void:
	_clear_card()
	var t = _label("Paused", font_display, 66, GOLD)
	_heading(t)
	card_box.add_child(t)
	var r = _button("Resume", "gold")
	r.pressed.connect(func():
		game.play("click")
		game.resume())
	card_box.add_child(r)
	for k in [["music", "Music"], ["sound", "Sound"], ["vibration", "Vibration"]]:
		card_box.add_child(_setting_btn(k[0], k[1]))
	var q = _button("Leave level (lose a life)", "ghost")
	q.pressed.connect(func():
		game.play("click")
		game.quit_level())
	card_box.add_child(q)
	_show_card()

func show_settings() -> void:
	_clear_card()
	var t = _label("Settings", font_display, 66, GOLD)
	_heading(t)
	card_box.add_child(t)
	for k in [["music", "Music"], ["sound", "Sound"], ["vibration", "Vibration"]]:
		card_box.add_child(_setting_btn(k[0], k[1]))
	var st = _button("Play stats", "teal")
	st.pressed.connect(func():
		game.play("click")
		show_stats())
	card_box.add_child(st)
	var c = _button("Close", "ghost")
	c.pressed.connect(func():
		game.play("click")
		hide_overlay())
	card_box.add_child(c)
	_show_card()

func show_stats() -> void:
	_clear_card()
	var t = _label("Play stats", font_display, 60, GOLD)
	_heading(t)
	card_box.add_child(t)
	var sm: Dictionary = game.meta.log_summary()
	var keys := sm.keys()
	keys.sort()
	var lines := []
	for k in keys.slice(maxi(0, keys.size() - 10)):
		lines.append("Level %d:  %d won, %d lost" % [k, sm[k].win, sm[k].lose])
	if lines.is_empty():
		lines.append("No levels played yet.")
	var d = _label("\n".join(lines), font_body, 28, INK)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(d)
	var n = _label("Every level you play is saved on this phone for testing.", font_body, 22, INK_SOFT)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
	card_box.add_child(n)
	var c = _button("Back", "ghost")
	c.pressed.connect(func():
		game.play("click")
		show_settings())
	card_box.add_child(c)
	_show_card()

func show_no_lives() -> void:
	_clear_card()
	var h := HeartIcon.new()
	h.custom_minimum_size = Vector2(0, 110)
	card_box.add_child(h)
	var t = _label("Out of lives", font_display, 64, GOLD)
	_heading(t)
	card_box.add_child(t)
	nolives_timer = _label("", font_body, 32, INK)
	nolives_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(nolives_timer)
	var price: int = game.meta.PRICES.refill
	var rf = _button("Refill lives · %d coins" % price, "gold")
	rf.disabled = game.meta.coins < price
	rf.pressed.connect(func():
		if game.meta.refill_lives():
			game.play("shine")
			nolives_timer = null
			game.show_map())
	card_box.add_child(rf)
	var c = _button("Back to map", "ghost")
	c.pressed.connect(func():
		game.play("click")
		nolives_timer = null
		hide_overlay())
	card_box.add_child(c)
	_show_card()

func show_intro(idx: int, boss: bool, mode_title: String, text: String, badge: Texture2D = null) -> void:
	_clear_card()
	if badge != null:
		var b0 := TextureRect.new()
		b0.texture = badge
		b0.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		b0.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		b0.custom_minimum_size = Vector2(0, 200)
		b0.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_box.add_child(b0)
	var lv = _label(("BOSS · Level %d" if boss else "Level %d") % (idx + 1), font_display, 40, Color("ff8f6b") if boss else INK_SOFT)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(lv)
	var t = _label(mode_title, font_display, 60, GOLD)
	_heading(t)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
	card_box.add_child(t)
	var d = _label(text, font_body, 28, INK)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
	card_box.add_child(d)
	# start-of-level boosters
	var sub = _label("Start with a booster", font_body, 24, INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(sub)
	pre_sel.clear()
	pre_btns.clear()
	var items := []
	for key in ["pre_rocket", "pre_scarab"]:
		var pb := PreBtn.new()
		pb.key = key
		pb.f = font_display
		pb.icon_tex = game.tex.rocket if key == "pre_rocket" else game.tex.scarab
		pb.count = int(game.meta.boosters.get(key, 0))
		pb.price = int(game.meta.PRICES[key])
		pb.custom_minimum_size = Vector2(170, 150)
		var e := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			pb.add_theme_stylebox_override(st, e)
		var k2: String = key
		pb.pressed.connect(func():
			if pre_sel.has(k2):
				pre_sel.erase(k2)
			elif game.meta.can_use(k2):
				pre_sel[k2] = true
			else:
				toast("Not enough coins")
			pb.on = pre_sel.has(k2)
			pb.queue_redraw()
			game.play("click"))
		pre_btns[key] = pb
		items.append(pb)
	card_box.add_child(_toggle_row(items))
	var b = _button("Play", "gold")
	b.pressed.connect(func():
		game.play("click")
		var used := []
		for k in pre_sel:
			if game.meta.use_booster(k):
				used.append(k)
		game.begin_level(idx, used))
	card_box.add_child(b)
	var c = _button("Back", "ghost")
	c.pressed.connect(func():
		game.play("click")
		if game.state == "map":
			hide_overlay()
		else:
			game.show_map())
	card_box.add_child(c)
	_show_card()

func show_win(stars: int, coins: int, boss: bool, has_next: bool) -> void:
	_clear_card()
	var t = _label("Boss beaten!" if boss else "Zaki escaped!", font_display, 66, GOLD)
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
	var ci := CoinIcon.new()
	ci.custom_minimum_size = Vector2(54, 54)
	var cl = _label("+%d" % coins, font_display, 52, GOLD)
	card_box.add_child(_toggle_row([ci, cl]))
	if has_next:
		var nb = _button("Next level", "gold")
		nb.pressed.connect(func():
			game.play("click")
			game.next_level())
		card_box.add_child(nb)
	else:
		var e = _label("You reached the end of the Nile! More worlds are on the way.", font_body, 28, INK_SOFT)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		e.custom_minimum_size = Vector2(card.custom_minimum_size.x - 80, 0)
		card_box.add_child(e)
	var lb = _button("Map", "ghost")
	lb.pressed.connect(func():
		game.play("click")
		game.show_map())
	card_box.add_child(lb)
	_show_card()

func show_lose(left: int, title := "Zaki got caught!") -> void:
	_clear_card()
	var t = _label(title, font_display, 62, GOLD)
	_heading(t)
	card_box.add_child(t)
	var d = _label("%d%% of the sand was still blocking the door." % left, font_body, 30, INK_SOFT)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(d)
	var have := int(game.meta.boosters.get("moves5", 0))
	var price: int = game.meta.PRICES.moves5
	var mb = _button(("+5 moves, +25 s  (x%d)" % have) if have > 0 else "+5 moves, +25 s  · %d coins" % price, "gold")
	mb.add_theme_font_size_override("font_size", 36)
	mb.disabled = not game.meta.can_use("moves5")
	mb.pressed.connect(func():
		game.play("click")
		game.plus_five())
	card_box.add_child(mb)
	var lives_left: int = maxi(0, game.meta.lives - 1)
	var rb = _button("Try again", "teal")
	rb.pressed.connect(func():
		game.play("click")
		game.give_up(false))
	card_box.add_child(rb)
	var n = _label("Giving up costs a life (%d left after)." % lives_left, font_body, 22, INK_SOFT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(n)
	var lb = _button("Map", "ghost")
	lb.pressed.connect(func():
		game.play("click")
		game.give_up(true))
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
	if kind == "dark":
		bg = Color("4b3f6e")
		edge = Color("2a2245")
		fg = Color("c9bba3")
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
