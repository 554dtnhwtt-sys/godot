extends Node2D
## Kanonkulor och effekter (rök, stänk, splitter, explosioner) ritade i en enda nod.

var world = null
var balls: Array = []
var parts: Array = []


func fire_cannonball(from: Vector2, target, dmg: float, owner: String, bld = null, delay: float = 0.0) -> void:
	var tp: Vector2
	var tship = null
	if target is Vector2:
		tp = target
	else:
		tship = target
		tp = target.position
	var dist := from.distance_to(tp)
	var dur: float = clampf(dist / 520.0, 0.25, 1.2)
	if tship != null:
		tp = tship.position + tship.velocity * (dur + delay) * 0.8
	var spread := 5.0 + dist * 0.045
	tp += Vector2(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7)) * spread
	balls.append({"from": from, "to": tp, "t": -delay, "dur": dur, "dmg": dmg, "owner": owner, "bld": bld, "h": dist * 0.12})


func smoke(p: Vector2, n: int = 1) -> void:
	for i in n:
		parts.append({"k": "smoke", "p": p + Vector2(randf_range(-4, 4), randf_range(-4, 4)), "v": Vector2(randf_range(-8, 8), randf_range(-22, -10)), "life": 0.0, "max": randf_range(1.0, 1.6), "s": randf_range(6, 10)})


func splash(p: Vector2, scale_f: float = 1.0) -> void:
	parts.append({"k": "ring", "p": p, "v": Vector2.ZERO, "life": 0.0, "max": 0.7, "s": 10.0 * scale_f})
	for i in int(5 * scale_f):
		parts.append({"k": "drop", "p": p, "v": Vector2(randf_range(-40, 40), randf_range(-110, -60)) * scale_f, "life": 0.0, "max": 0.6, "s": 2.5})


func splinters(p: Vector2) -> void:
	for i in 6:
		parts.append({"k": "splinter", "p": p + Vector2(0, -10), "v": Vector2(randf_range(-70, 70), randf_range(-120, -40)), "life": 0.0, "max": 0.8, "s": 3.0})
	parts.append({"k": "boom", "p": p + Vector2(0, -8), "v": Vector2.ZERO, "life": 0.0, "max": 0.35, "s": 14.0})


func dust(p: Vector2) -> void:
	parts.append({"k": "boom", "p": p, "v": Vector2.ZERO, "life": 0.0, "max": 0.35, "s": 12.0})
	for i in 3:
		parts.append({"k": "smoke", "p": p, "v": Vector2(randf_range(-15, 15), randf_range(-20, -8)), "life": 0.0, "max": 1.2, "s": 8.0})


func text(p: Vector2, s: String, col: Color) -> void:
	parts.append({"k": "text", "p": p, "v": Vector2(0, -30), "life": 0.0, "max": 1.8, "s": 0.0, "t": s, "c": col})


func _process(delta: float) -> void:
	var i := 0
	while i < balls.size():
		var b: Dictionary = balls[i]
		b["t"] += delta
		if b["t"] >= b["dur"]:
			_resolve(b)
			balls.remove_at(i)
		else:
			i += 1
	i = 0
	while i < parts.size():
		var p: Dictionary = parts[i]
		p["life"] += delta
		if p["life"] >= p["max"]:
			parts.remove_at(i)
			continue
		p["p"] += p["v"] * delta
		if p["k"] == "drop" or p["k"] == "splinter":
			p["v"].y += 260.0 * delta
		i += 1
	queue_redraw()


func _resolve(b: Dictionary) -> void:
	var to: Vector2 = b["to"]
	var owner: String = b["owner"]
	var bld = b["bld"]
	if bld != null and is_instance_valid(bld) and bld.global_position.distance_to(to) < 50.0:
		bld.take_damage(b["dmg"])
		dust(to)
		return
	for s in world.ships:
		if not s.is_alive() or not Game.at_war(owner, s.owner_id):
			continue
		if s.position.distance_to(to) < 16.0 * s.size_f + 6.0:
			s.take_damage(b["dmg"], owner)
			return
	for isl in world.islands:
		if isl.contains_world_point(to):
			if Game.at_war(owner, isl.owner_id):
				isl.garrison = maxf(0.0, isl.garrison - b["dmg"] * 0.06)
				isl.last_attacked = Game.time
			dust(to)
			return
	splash(to)


func _draw() -> void:
	for b in balls:
		if b["t"] < 0.0:
			continue
		var k: float = b["t"] / b["dur"]
		var p: Vector2 = b["from"].lerp(b["to"], k)
		var h: float = sin(k * PI) * b["h"]
		draw_circle(p, 2.5, Color(0, 0, 0, 0.25))
		draw_circle(p - Vector2(0, h), 3.2, Color(0.12, 0.12, 0.13))
	for p in parts:
		var k: float = p["life"] / p["max"]
		var pos: Vector2 = p["p"]
		match p["k"]:
			"smoke":
				draw_circle(pos, p["s"] * (1.0 + k * 1.5), Color(0.85, 0.85, 0.85, 0.55 * (1.0 - k)))
			"ring":
				draw_arc(pos, p["s"] * (1.0 + k * 2.0), 0, TAU, 20, Color(1, 1, 1, 0.8 * (1.0 - k)), 2.0)
			"drop":
				draw_circle(pos, p["s"], Color(0.85, 0.97, 1.0, 0.9 * (1.0 - k)))
			"splinter":
				draw_line(pos, pos + p["v"].normalized() * 5.0, Color(0.5, 0.35, 0.2, 1.0 - k), 2.0)
			"boom":
				draw_circle(pos, p["s"] * (0.6 + k), Color(1.0, 0.6 - k * 0.4, 0.15, 0.85 * (1.0 - k)))
			"text":
				var font := ThemeDB.fallback_font
				draw_string(font, pos + Vector2(1, 1), p["t"], HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0, 0, 0, 0.7 * (1.0 - k)))
				draw_string(font, pos, p["t"], HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(p["c"], 1.0 - k))
