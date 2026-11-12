extends RefCounted
## Draws a texture centred inside a rect, keeping its shape.

static func draw(ci: CanvasItem, t: Texture2D, rect: Rect2, mod := Color.WHITE) -> void:
	var s := minf(rect.size.x / t.get_width(), rect.size.y / t.get_height())
	var sz := Vector2(t.get_width(), t.get_height()) * s
	ci.draw_texture_rect(t, Rect2(rect.position + (rect.size - sz) / 2.0, sz), false, mod)
