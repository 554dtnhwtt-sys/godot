extends Node2D
## Ritar markeringsrutan, ordermarkörer och vart valda skepp är på väg.

const ResIcon = preload("res://scripts/ui/res_icon.gd")

var world = null
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta / maxf(0.001, Engine.time_scale)
	queue_redraw()


## Ikoner över resursplatserna på egna och obebodda öar. Hovrad plats får en ring och text.
func _draw_sites(z: float) -> void:
	var font := ThemeDB.fallback_font
	var r := 13.0 / sqrt(z)
	for isl in world.islands:
		if isl.owner_id != Game.player and isl.owner_id != "neutral":
			continue
		if not world.fog.is_explored(isl.position):
			continue
		var mine: bool = isl.owner_id == Game.player
		for i in isl.sites.size():
			var st: Dictionary = isl.sites[i]
			var b = st["b"]
			var hovered: bool = isl.hover_site == i
			var c: Vector2 = isl.position + st["pos"] + Vector2(0, -46.0 - sin(_t * 2.0 + i) * 3.0)
			if b == null or hovered:
				draw_circle(c, r + 3.0, Color(0.08, 0.06, 0.04, 0.85))
				draw_arc(c, r + 3.0, 0, TAU, 24, Data.RESOURCE_COLORS.get(st["res"], Color(0.5, 0.8, 1.0)) if st["res"] != "fisk" else Color(0.5, 0.8, 1.0), 2.0, true)
				ResIcon.paint(self, st["res"], c, r * 0.8)
				if mine and b == null:
					var pc := c + Vector2(r * 0.85, -r * 0.85)
					draw_circle(pc, r * 0.45, Color(0.3, 0.75, 0.35))
					draw_line(pc - Vector2(r * 0.25, 0), pc + Vector2(r * 0.25, 0), Color(1, 1, 1), 2.0)
					draw_line(pc - Vector2(0, r * 0.25), pc + Vector2(0, r * 0.25), Color(1, 1, 1), 2.0)
			if hovered:
				var ground: Vector2 = isl.position + st["pos"]
				draw_set_transform(ground, 0.0, Vector2(1, 0.5))
				draw_arc(Vector2.ZERO, 46.0, 0, TAU, 32, Color(1, 0.9, 0.5, 0.8 + 0.2 * sin(_t * 5.0)), 3.0 / z, true)
				draw_set_transform(Vector2.ZERO)
				var txt: String = Data.SITES[st["res"]]["name"]
				if b != null:
					txt = "%s (level %d)" % [b.display_name(), b.level]
				elif mine:
					txt += " – click to build a %s" % Data.BUILDINGS[Data.SITES[st["res"]]["building"]]["name"]
				var fs := int(16.0 / sqrt(z))
				var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var tp := c + Vector2(-w * 0.5, -r - 12.0)
				draw_rect(Rect2(tp + Vector2(-6, -fs), Vector2(w + 12, fs + 8)), Color(0.08, 0.06, 0.04, 0.85))
				draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.8))


func _draw() -> void:
	if world == null:
		return
	var z: float = world.cam.zoom.x if world.cam else 1.0
	var lw := 2.0 / z
	_draw_sites(z)
	for s in world.selected_ships:
		if not is_instance_valid(s) or not s.is_alive():
			continue
		var dest = null
		var col := Color(0.6, 1, 0.6, 0.5)
		match s.order:
			"move":
				dest = s.target_pos
			"attack":
				if s.target_ship != null and is_instance_valid(s.target_ship):
					dest = s.target_ship.position
					col = Color(1, 0.35, 0.3, 0.6)
			"attack_island", "colonize":
				if s.target_island != null:
					dest = s.target_island.position
					col = Color(1, 0.35, 0.3, 0.6) if s.order == "attack_island" else Color(0.5, 1, 0.6, 0.6)
			"trade":
				if s.trade_a != null and s.trade_b != null:
					_dashed(s.trade_a.position, s.trade_b.position, Color(1, 0.85, 0.4, 0.6), lw * 1.5, 30.0 / z)
		if dest != null:
			_dashed(s.position, dest, col, lw, 18.0 / z)
	for m in world.markers:
		var k: float = m["t"] / 0.8
		var r := (10.0 + (1.0 - k) * 26.0) / z
		draw_arc(m["p"], r, 0, TAU, 24, Color(m["c"], k), lw * 1.5)
	if world.dragging and world.drag_from.distance_to(world.drag_to) > 10.0 / z:
		var r := Rect2(world.drag_from, Vector2.ZERO).expand(world.drag_to)
		draw_rect(r, Color(0.6, 1, 0.6, 0.12))
		draw_rect(r, Color(0.6, 1, 0.6, 0.8), false, lw)


func _dashed(a: Vector2, b: Vector2, c: Color, w: float, dash: float) -> void:
	var d := a.distance_to(b)
	if d < 1.0:
		return
	var dir := (b - a) / d
	var t := 0.0
	while t < d:
		draw_line(a + dir * t, a + dir * minf(d, t + dash * 0.6), c, w)
		t += dash
