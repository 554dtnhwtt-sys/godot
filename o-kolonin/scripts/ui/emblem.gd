extends Control
## Nationens vapensköld: krona, dödskalle, vulkan eller sol på en sköld.

var nation := "valdoria"


func _init(n: String = "valdoria", s: float = 96.0) -> void:
	nation = n
	custom_minimum_size = Vector2(s, s * 1.15)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var w := size.x
	var h := size.y
	var col := Data.nation_color(nation)
	var acc := Data.nation_accent(nation)
	var shield := PackedVector2Array()
	shield.append(Vector2(w * 0.08, h * 0.06))
	shield.append(Vector2(w * 0.92, h * 0.06))
	shield.append(Vector2(w * 0.92, h * 0.5))
	for i in 9:
		var t := i / 8.0
		shield.append(Vector2(w * (0.92 - 0.42 * t), h * 0.5 + sin(t * PI * 0.5) * h * 0.44))
	for i in range(1, 9):
		var t := i / 8.0
		shield.append(Vector2(w * (0.5 - 0.42 * t), h * 0.94 - (1.0 - cos(t * PI * 0.5)) * h * 0.44))
	draw_colored_polygon(shield, col)
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, acc, max(2.0, w * 0.035), true)
	var c := Vector2(w * 0.5, h * 0.45)
	var r := w * 0.3
	var emblem: String = Data.NATIONS[nation]["emblem"] if Data.NATIONS.has(nation) else ""
	match emblem:
		"krona":
			var pts := PackedVector2Array([c + Vector2(-r, r * 0.5), c + Vector2(-r, -r * 0.3), c + Vector2(-r * 0.5, r * 0.05), c + Vector2(0, -r * 0.6), c + Vector2(r * 0.5, r * 0.05), c + Vector2(r, -r * 0.3), c + Vector2(r, r * 0.5)])
			draw_colored_polygon(pts, acc)
			for p in [c + Vector2(-r, -r * 0.3), c + Vector2(0, -r * 0.6), c + Vector2(r, -r * 0.3)]:
				draw_circle(p, r * 0.13, acc.lightened(0.3))
			draw_rect(Rect2(c + Vector2(-r, r * 0.5), Vector2(r * 2, r * 0.22)), acc.darkened(0.15))
		"dodskalle":
			draw_circle(c + Vector2(0, -r * 0.1), r * 0.62, Color(0.95, 0.93, 0.88))
			draw_rect(Rect2(c + Vector2(-r * 0.35, r * 0.3), Vector2(r * 0.7, r * 0.35)), Color(0.95, 0.93, 0.88))
			draw_circle(c + Vector2(-r * 0.25, -r * 0.12), r * 0.17, col)
			draw_circle(c + Vector2(r * 0.25, -r * 0.12), r * 0.17, col)
			draw_line(c + Vector2(-r, r * 0.6), c + Vector2(r, r * 1.05), acc, r * 0.14)
			draw_line(c + Vector2(r, r * 0.6), c + Vector2(-r, r * 1.05), acc, r * 0.14)
		"vulkan":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.8), c + Vector2(-r * 0.25, -r * 0.4), c + Vector2(r * 0.25, -r * 0.4), c + Vector2(r, r * 0.8)]), Color(0.35, 0.25, 0.2))
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.4), c + Vector2(0, -r * 0.95), c + Vector2(r * 0.25, -r * 0.4)]), acc)
			draw_circle(c + Vector2(r * 0.4, -r * 0.9), r * 0.18, acc.lightened(0.2))
		"sol":
			for i in 12:
				var a := TAU * i / 12.0
				draw_line(c + Vector2.from_angle(a) * r * 0.55, c + Vector2.from_angle(a) * r * 0.95, acc, r * 0.12)
			draw_circle(c, r * 0.5, acc)
			draw_circle(c, r * 0.32, col.lightened(0.2))
