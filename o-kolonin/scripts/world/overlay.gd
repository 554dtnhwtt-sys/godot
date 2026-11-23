extends Node2D
## Ritar markeringsrutan, ordermarkörer och vart valda skepp är på väg.

var world = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var z: float = world.cam.zoom.x if world.cam else 1.0
	var lw := 2.0 / z
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
		draw_line(a + dir * t, a + dir * min(d, t + dash * 0.6), c, w)
		t += dash
