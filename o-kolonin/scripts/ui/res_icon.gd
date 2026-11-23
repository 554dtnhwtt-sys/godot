extends Control
## Liten ritad ikon för en resurs.

var res := "guld"


func _init(r: String = "guld", s: float = 20.0) -> void:
	res = r
	custom_minimum_size = Vector2(s, s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.42
	var col: Color = Data.RESOURCE_COLORS.get(res, Color.WHITE)
	match res:
		"guld":
			draw_circle(c, r, col.darkened(0.25))
			draw_circle(c, r * 0.78, col)
			draw_line(c + Vector2(0, -r * 0.45), c + Vector2(0, r * 0.45), col.darkened(0.35), 2.0)
		"tra":
			draw_rect(Rect2(c + Vector2(-r, -r * 0.45), Vector2(r * 2, r * 0.9)), col)
			draw_circle(c + Vector2(r, 0), r * 0.45, Color(0.85, 0.7, 0.45))
			draw_arc(c + Vector2(r, 0), r * 0.25, 0, TAU, 10, col.darkened(0.3), 1.0)
		"mat":
			draw_circle(c + Vector2(0, r * 0.1), r * 0.85, Color(0.45, 0.3, 0.15))
			draw_circle(c + Vector2(-r * 0.25, -r * 0.1), r * 0.18, Color(0.25, 0.15, 0.08))
			draw_line(c + Vector2(0, -r * 0.7), c + Vector2(r * 0.6, -r * 1.0), Color(0.3, 0.7, 0.3), 3.0)
		"sten":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(r * 0.3, -r * 0.8), c + Vector2(r, r * 0.1), c + Vector2(r * 0.7, r * 0.7)]), col)
		"sand":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(0, -r * 0.6), c + Vector2(r, r * 0.6)]), col)
		"kristaller":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.55, 0), c + Vector2(0, r), c + Vector2(-r * 0.55, 0)]), col)
			draw_line(c + Vector2(0, -r), c + Vector2(0, r), Color(1, 1, 1, 0.6), 1.0)
		"socker":
			for i in 3:
				draw_line(c + Vector2(-r * 0.6 + i * r * 0.6, r), c + Vector2(-r * 0.5 + i * r * 0.6, -r), Color(0.6, 0.85, 0.4), 3.0)
		"rom":
			draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.4), Vector2(r * 0.9, r * 1.4)), col)
			draw_rect(Rect2(c + Vector2(-r * 0.18, -r), Vector2(r * 0.36, r * 0.6)), col.darkened(0.2))
			draw_rect(Rect2(c + Vector2(-r * 0.45, 0), Vector2(r * 0.9, r * 0.4)), Color(0.95, 0.9, 0.75))
		"kryddor":
			draw_circle(c + Vector2(-r * 0.3, r * 0.2), r * 0.45, col)
			draw_circle(c + Vector2(r * 0.35, r * 0.1), r * 0.4, Color(0.6, 0.35, 0.15))
			draw_circle(c + Vector2(0, -r * 0.4), r * 0.38, Color(0.95, 0.75, 0.25))
		"parlor":
			draw_circle(c, r * 0.75, col)
			draw_circle(c + Vector2(-r * 0.25, -r * 0.25), r * 0.22, Color(1, 1, 1))
		"forskning":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.6), Vector2(r * 1.6, r * 1.2)), Color(0.9, 0.85, 0.7))
			draw_line(c + Vector2(0, -r * 0.6), c + Vector2(0, r * 0.6), Color(0.5, 0.4, 0.3), 1.5)
			draw_line(c + Vector2(r * 0.3, -r * 0.9), c + Vector2(r * 0.9, r * 0.2), col, 2.0)
		_:
			draw_circle(c, r, col)
