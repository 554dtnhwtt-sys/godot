extends Node2D
## Kanonkulor och effekter: målad krutrök, mynningsflammor, vattenkaskader, explosioner,
## splitter och svart rök från bränder. Effekter på vattenytan (skumringar och vrakdelar
## som flyter och driver) ritas i ett eget lager under skeppen.

var world = null
var balls: Array = []
var parts: Array = []
var low: Array = []          # skum och vrakdelar på vattnet
var _low_node: Node2D
var _debris_n := 0


func _ready() -> void:
	_low_node = Node2D.new()
	_low_node.z_index = -14  # = -9: över öarna, under skeppen
	_low_node.draw.connect(_draw_low)
	add_child(_low_node)
	for i in 20:
		if FileAccess.file_exists("res://assets/fx/debris/%02d.png" % (i + 1)) or ResourceLoader.exists("res://assets/fx/debris/%02d.png" % (i + 1)):
			_debris_n = i + 1


static func _tex(name: String) -> Texture2D:
	return Art.tex("res://assets/fx/%s.png" % name)


func _wind() -> Vector2:
	return Vector2.from_angle(Game.wind_angle) * (8.0 + Game.wind_strength * 10.0 + Game.storm * 30.0)


func fire_cannonball(from: Vector2, target, dmg: float, owner: String, bld = null, delay: float = 0.0, spread_f: float = 1.0, src = null) -> void:
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
	var spread := (5.0 + dist * 0.045) * spread_f
	tp += Vector2(randf_range(-1.0, 1.0), randf_range(-0.7, 0.7)) * spread
	balls.append({"from": from, "to": tp, "t": -delay, "dur": dur, "dmg": dmg, "owner": owner, "bld": bld, "h": dist * 0.12, "src": src})


func _puff(p: Vector2, v: Vector2, size: float, life: float, col: Color, delay: float = 0.0) -> void:
	parts.append({"k": "psmoke", "p": p, "v": v, "life": -delay, "max": life, "s": size, "rot": randf() * TAU, "spin": randf_range(-0.5, 0.5), "c": col})


## Ljus rök (skorstenar, fort, damm).
func smoke(p: Vector2, n: int = 1) -> void:
	for i in n:
		_puff(p + Vector2(randf_range(-4, 4), randf_range(-4, 4)), Vector2(randf_range(-6, 6), randf_range(-22, -12)), randf_range(14, 20), randf_range(1.4, 2.0), Color(0.92, 0.92, 0.92, 0.75))


## Krutrök och mynningsflamma när en kanon avfyras.
func cannon_smoke(p: Vector2, dir: Vector2, delay: float, scale_f: float) -> void:
	parts.append({"k": "pflash", "p": p, "v": dir * 10.0, "life": -delay, "max": 0.16, "s": 30.0 * scale_f, "rot": dir.angle(), "spin": 0.0})
	_puff(p + dir * 4.0, dir * randf_range(34, 50) + Vector2(0, -6), 18.0 * scale_f, randf_range(2.0, 2.8), Color(0.93, 0.93, 0.9, 0.85), delay)
	_puff(p + dir * 10.0, dir * randf_range(18, 28) + Vector2(0, -10), 24.0 * scale_f, randf_range(2.4, 3.2), Color(0.88, 0.88, 0.86, 0.7), delay + 0.05)


## Mynningsflamma (används av fort).
func flash(p: Vector2, delay: float = 0.0) -> void:
	parts.append({"k": "pflash", "p": p, "v": Vector2.ZERO, "life": -delay, "max": 0.16, "s": 26.0, "rot": randf() * TAU, "spin": 0.0})


## Svart rök från en brand ombord.
func fire_smoke(p: Vector2, scale_f: float) -> void:
	_puff(p + Vector2(randf_range(-3, 3), 0), Vector2(randf_range(-4, 4), -26.0), 16.0 * scale_f, randf_range(2.2, 3.0), Color(0.22, 0.2, 0.2, 0.75))


func splash(p: Vector2, scale_f: float = 1.0) -> void:
	parts.append({"k": "psplash", "p": p, "v": Vector2.ZERO, "life": 0.0, "max": 0.85, "s": 34.0 * scale_f, "rot": randf_range(-0.25, 0.25), "flip": randf() < 0.5})
	low.append({"k": "foam", "p": p, "v": Vector2.ZERO, "life": 0.0, "max": 1.4, "s": 22.0 * scale_f, "rot": randf() * TAU})
	for i in int(4 * scale_f):
		parts.append({"k": "drop", "p": p, "v": Vector2(randf_range(-40, 40), randf_range(-110, -60)) * scale_f, "life": 0.0, "max": 0.6, "s": 2.2})


func splinters(p: Vector2) -> void:
	parts.append({"k": "explo", "p": p + Vector2(0, -10), "v": Vector2.ZERO, "life": 0.0, "max": 0.32, "s": 26.0, "rot": randf() * TAU})
	for i in 7:
		parts.append({"k": "splinter", "p": p + Vector2(0, -10), "v": Vector2(randf_range(-80, 80), randf_range(-130, -40)), "life": 0.0, "max": 0.8, "s": 3.0})
	_puff(p + Vector2(0, -12), Vector2(randf_range(-6, 6), -14), 14.0, 1.4, Color(0.6, 0.58, 0.56, 0.7))


func dust(p: Vector2) -> void:
	parts.append({"k": "explo", "p": p, "v": Vector2.ZERO, "life": 0.0, "max": 0.25, "s": 16.0, "rot": randf() * TAU})
	for i in 2:
		_puff(p, Vector2(randf_range(-15, 15), randf_range(-16, -6)), 14.0, 1.3, Color(0.86, 0.78, 0.64, 0.7))


## Ett skepp går under: vrakdelar sprids och flyter, skum och rök.
func wreck(p: Vector2, L: float) -> void:
	low.append({"k": "foam", "p": p, "v": Vector2.ZERO, "life": 0.0, "max": 3.5, "s": L * 0.6, "rot": randf() * TAU})
	parts.append({"k": "explo", "p": p + Vector2(0, -L * 0.15), "v": Vector2.ZERO, "life": 0.0, "max": 0.45, "s": L * 0.4, "rot": randf() * TAU})
	for i in 3:
		_puff(p + Vector2(randf_range(-L, L) * 0.25, -L * 0.1), Vector2(randf_range(-8, 8), -20), L * 0.25, 3.0, Color(0.3, 0.28, 0.28, 0.75), i * 0.3)
	if _debris_n <= 0:
		return
	var n := 6 + int(L / 30.0)
	for i in n:
		var a := randf() * TAU
		var r := randf_range(0.1, 0.45) * L
		var off := Vector2(cos(a) * r, sin(a) * r * 0.72)
		low.append({"k": "debris", "p": p + off, "v": off.normalized() * randf_range(4, 12), "life": -randf_range(0.0, 1.5), "max": randf_range(22.0, 34.0), "s": randf_range(0.12, 0.24) * L, "rot": randf() * TAU, "spin": randf_range(-0.3, 0.3), "tex": 1 + randi() % _debris_n})


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
	var wind := _wind()
	i = 0
	while i < parts.size():
		var p: Dictionary = parts[i]
		p["life"] += delta
		if p["life"] < 0.0:
			i += 1
			continue
		if p["life"] >= p["max"]:
			parts.remove_at(i)
			continue
		p["p"] += p["v"] * delta
		match p["k"]:
			"drop", "splinter":
				p["v"].y += 260.0 * delta
			"psmoke":
				# Röken bromsas, stiger och driver med vinden
				p["v"] = p["v"].lerp(wind + Vector2(0, -12), clampf(delta * 0.8, 0.0, 1.0))
				p["rot"] += p["spin"] * delta
		i += 1
	i = 0
	while i < low.size():
		var q: Dictionary = low[i]
		q["life"] += delta
		if q["life"] >= q["max"]:
			low.remove_at(i)
			continue
		if q["life"] >= 0.0 and q["k"] == "debris":
			q["v"] = q["v"].lerp(wind * 0.25, clampf(delta * 0.2, 0.0, 1.0))
			q["p"] += q["v"] * delta
			q["rot"] += q["spin"] * delta
		i += 1
	queue_redraw()
	_low_node.queue_redraw()


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
			var src = b["src"] if b["src"] != null and is_instance_valid(b["src"]) else null
			s.take_damage(b["dmg"], owner, src)
			return
	for isl in world.islands:
		if isl.contains_world_point(to):
			if Game.at_war(owner, isl.owner_id):
				isl.garrison = maxf(0.0, isl.garrison - b["dmg"] * 0.06)
				isl.last_attacked = Game.time
			dust(to)
			return
	splash(to)


func _sprite(tex: Texture2D, pos: Vector2, size: float, rot: float, col: Color, anchor := Vector2(0.5, 0.5), squash := 1.0) -> void:
	if tex == null:
		return
	var sc := size / maxf(tex.get_width(), tex.get_height())
	draw_set_transform(pos, rot, Vector2(sc, sc * squash))
	draw_texture(tex, -Vector2(tex.get_width(), tex.get_height()) * anchor, col)
	draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	for b in balls:
		if b["t"] < 0.0:
			continue
		var k: float = b["t"] / b["dur"]
		var p: Vector2 = b["from"].lerp(b["to"], k)
		var h: float = sin(k * PI) * b["h"]
		var tail: Vector2 = b["from"].lerp(b["to"], maxf(0.0, k - 0.06)) - Vector2(0, sin(maxf(0.0, k - 0.06) * PI) * b["h"])
		draw_circle(p, 2.5, Color(0, 0, 0, 0.22))
		draw_line(tail, p - Vector2(0, h), Color(0.85, 0.85, 0.85, 0.35), 2.0)
		draw_circle(p - Vector2(0, h), 3.0, Color(0.1, 0.1, 0.11))
	for p in parts:
		if p["life"] < 0.0:
			continue
		var k: float = p["life"] / p["max"]
		var pos: Vector2 = p["p"]
		match p["k"]:
			"psmoke":
				var frame := mini(3, int(k * 4.0))
				var c: Color = p["c"]
				var a: float = c.a * pow(1.0 - k, 1.3) * smoothstep(0.0, 0.06, k)
				_sprite(_tex("smoke%d" % (frame + 1)), pos, p["s"] * (0.7 + k * 1.6), p["rot"], Color(c.r, c.g, c.b, a))
			"pflash":
				_sprite(_tex("flash"), pos, p["s"] * (1.0 + k * 0.4), p["rot"], Color(1, 1, 1, 1.0 - k * k))
			"psplash":
				var hgt: float = p["s"] * (0.5 + 0.9 * sin(minf(k * 1.6, 1.0) * PI * 0.5))
				var tx := _tex("splash")
				if tx != null:
					var sc := hgt / tx.get_height()
					draw_set_transform(pos, p["rot"], Vector2(sc * (-1.0 if p["flip"] else 1.0), sc * (1.0 - k * 0.3)))
					draw_texture(tx, -Vector2(tx.get_width() * 0.5, tx.get_height() * 0.92), Color(1, 1, 1, 0.95 * (1.0 - k * k)))
					draw_set_transform(Vector2.ZERO)
			"explo":
				_sprite(_tex("explosion"), pos, p["s"] * (0.7 + k * 0.7), p["rot"], Color(1, 1, 1, 1.0 - k))
			"drop":
				draw_circle(pos, p["s"], Color(0.85, 0.97, 1.0, 0.9 * (1.0 - k)))
			"splinter":
				draw_line(pos, pos + p["v"].normalized() * 5.0, Color(0.5, 0.35, 0.2, 1.0 - k), 2.0)
			"text":
				var font := ThemeDB.fallback_font
				draw_string(font, pos + Vector2(1, 1), p["t"], HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(0, 0, 0, 0.7 * (1.0 - k)))
				draw_string(font, pos, p["t"], HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color(p["c"], 1.0 - k))


## Vattenlagret: skumringar och flytande vrakdelar.
func _draw_low() -> void:
	var n := _low_node
	for q in low:
		if q["life"] < 0.0:
			continue
		var k: float = q["life"] / q["max"]
		var pos: Vector2 = q["p"]
		match q["k"]:
			"foam":
				var tx := _tex("foamring")
				if tx != null:
					var sc: float = q["s"] * (0.6 + k * 1.2) / tx.get_width()
					n.draw_set_transform(pos, 0.0, Vector2(sc, sc * 0.72))
					n.draw_texture(tx, -tx.get_size() * 0.5, Color(1, 1, 1, 0.75 * (1.0 - k)))
					n.draw_set_transform(Vector2.ZERO)
			"debris":
				var tx := Art.tex("res://assets/fx/debris/%02d.png" % q["tex"])
				if tx == null:
					continue
				var bob := sin(q["life"] * 1.7 + q["rot"] * 3.0) * 1.2
				var fade := clampf((1.0 - k) * 4.0, 0.0, 1.0) * clampf(q["life"] * 2.0, 0.0, 1.0)
				var sc: float = q["s"] / maxf(tx.get_width(), tx.get_height())
				n.draw_set_transform(pos + Vector2(0, bob), q["rot"], Vector2(sc, sc * 0.8))
				n.draw_texture(tx, -tx.get_size() * 0.5 + Vector2(3, 5), Color(0, 0.06, 0.12, 0.25 * fade))
				n.draw_texture(tx, -tx.get_size() * 0.5, Color(0.92, 0.95, 1.0, fade))
				n.draw_set_transform(Vector2.ZERO)
