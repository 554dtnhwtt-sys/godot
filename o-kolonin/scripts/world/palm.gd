extends Node2D
## En palm som vajar lätt i vinden.

var seed_value := 0
var dark := false
var _h := 50.0
var _lean := 0.0
var _phase := 0.0
var _scale := 1.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_scale = rng.randf_range(0.75, 1.2)
	_h = rng.randf_range(42, 62) * _scale
	_lean = rng.randf_range(-16, 16)
	_phase = rng.randf() * TAU


func _process(_delta: float) -> void:
	var w := Game.wind_strength * (1.0 + Game.storm * 2.5)
	skew = sin(Time.get_ticks_msec() * 0.0012 * w + _phase) * 0.05 * w + cos(Game.wind_angle) * 0.04 * w


func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	# Skugga
	var sh := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		sh.append(Vector2(cos(a) * 22 * _scale + 10, sin(a) * 8 * _scale + 2))
	draw_colored_polygon(sh, Color(0, 0, 0, 0.18))
	# Stam
	var trunk_c := Color(0.55, 0.4, 0.25) if not dark else Color(0.3, 0.25, 0.22)
	var prev := Vector2.ZERO
	var segs := 6
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := Vector2(_lean * t * t, -_h * t)
		draw_line(prev, p, trunk_c.darkened(0.1 * (i % 2)), 6.0 * _scale * (1.1 - t * 0.4), true)
		prev = p
	var top := prev
	# Blad
	var leaf_c := Color(0.2, 0.62, 0.25) if not dark else Color(0.18, 0.32, 0.2)
	for i in 7:
		var a := -PI * 0.5 + (i - 3) * 0.55 + (0.2 if i % 2 == 0 else -0.1)
		var dir := Vector2(cos(a), sin(a) * 0.6 + 0.35)
		var tip := top + dir * 30.0 * _scale
		var mid := top + dir * 16.0 * _scale + Vector2(0, -6 * _scale)
		var n := Vector2(-dir.y, dir.x) * 5.0 * _scale
		draw_colored_polygon(PackedVector2Array([top, mid + n, tip, mid - n]), leaf_c.lightened(0.08 * (i % 3)))
	# Kokosnötter
	draw_circle(top + Vector2(-3, 3), 3.0 * _scale, Color(0.45, 0.3, 0.15))
	draw_circle(top + Vector2(3, 4), 3.0 * _scale, Color(0.4, 0.27, 0.12))
