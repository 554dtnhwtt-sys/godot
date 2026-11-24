extends Node2D
## Liv i världen: molnskuggor som driver med vinden och måsar som cirklar över öarna.

var world = null
var gulls: Array = []
var clouds: Array = []
var _t := 0.0


func _ready() -> void:
	z_index = 15
	var rng := RandomNumberGenerator.new()
	rng.seed = 1680
	for i in 16:
		clouds.append({
			"p": Vector2(rng.randf_range(0, Data.WORLD_SIZE.x), rng.randf_range(0, Data.WORLD_SIZE.y)),
			"r": rng.randf_range(240, 520),
			"blobs": _blobs(rng),
		})
	for isl in Data.ISLANDS:
		var n := rng.randi_range(2, 4)
		for k in n:
			gulls.append({
				"c": isl["pos"] + Vector2(rng.randf_range(-80, 80), rng.randf_range(-60, 40)),
				"r": rng.randf_range(120, isl["r"] + 120.0),
				"a": rng.randf() * TAU,
				"s": rng.randf_range(0.25, 0.45) * (1.0 if rng.randf() < 0.5 else -1.0),
				"h": rng.randf_range(60, 110),
			})


func _blobs(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for i in 6:
		out.append([Vector2(rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6)), rng.randf_range(0.45, 0.9)])
	return out


func _process(delta: float) -> void:
	_t += delta
	var wind := Vector2.from_angle(Game.wind_angle) * (14.0 + Game.wind_strength * 10.0 + Game.storm * 40.0)
	for c in clouds:
		c["p"] += wind * delta
		if c["p"].x > Data.WORLD_SIZE.x + 600:
			c["p"].x = -600
		elif c["p"].x < -600:
			c["p"].x = Data.WORLD_SIZE.x + 600
		if c["p"].y > Data.WORLD_SIZE.y + 600:
			c["p"].y = -600
		elif c["p"].y < -600:
			c["p"].y = Data.WORLD_SIZE.y + 600
	for g in gulls:
		g["a"] += g["s"] * delta
	queue_redraw()


func _draw() -> void:
	var shade := 0.07 + Game.storm * 0.12
	for c in clouds:
		for b in c["blobs"]:
			var off: Vector2 = b[0] * c["r"]
			draw_set_transform(c["p"] + off, 0.0, Vector2(1.0, 0.6))
			draw_circle(Vector2.ZERO, c["r"] * b[1], Color(0.02, 0.08, 0.15, shade * 0.5))
			draw_circle(Vector2.ZERO, c["r"] * b[1] * 0.7, Color(0.02, 0.08, 0.15, shade * 0.5))
	draw_set_transform(Vector2.ZERO)
	for g in gulls:
		var p: Vector2 = g["c"] + Vector2(cos(g["a"]), sin(g["a"]) * 0.6) * g["r"]
		var dir := Vector2(-sin(g["a"]), cos(g["a"]) * 0.6).normalized() * signf(g["s"])
		var flap := sin(_t * 9.0 + g["r"]) * 4.0
		var n := dir.orthogonal()
		# Skugga på vattnet
		var sp: Vector2 = p + Vector2(0, g["h"])
		draw_line(sp - n * 7.0, sp, Color(0, 0, 0, 0.15), 2.0)
		draw_line(sp + n * 7.0, sp, Color(0, 0, 0, 0.15), 2.0)
		# Fågeln
		draw_line(p - n * 8.0 + Vector2(0, -flap), p, Color(1, 1, 1, 0.95), 2.0, true)
		draw_line(p + n * 8.0 + Vector2(0, -flap), p, Color(1, 1, 1, 0.95), 2.0, true)
		draw_line(p - n * 8.0 + Vector2(0, -flap), p - n * 10.0 + Vector2(0, -flap + 2.0), Color(0.2, 0.2, 0.2, 0.8), 2.0)
		draw_line(p + n * 8.0 + Vector2(0, -flap), p + n * 10.0 + Vector2(0, -flap + 2.0), Color(0.2, 0.2, 0.2, 0.8), 2.0)
