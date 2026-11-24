extends Node2D
## En palm som vajar lätt i vinden.

var seed_value := 0
var dark := false
var _variant := 1
var _phase := 0.0
var _scale := 0.4
var _flip := false
var force_variant := 0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_variant = 1 + rng.randi() % 4
	if force_variant > 0:
		_variant = force_variant
	_scale = rng.randf_range(0.34, 0.48) * (0.8 if _variant == 4 else 1.0)
	_phase = rng.randf() * TAU
	_flip = rng.randf() < 0.5


func _process(_delta: float) -> void:
	var w := Game.wind_strength * (1.0 + Game.storm * 2.5)
	skew = sin(Time.get_ticks_msec() * 0.0011 * w + _phase) * 0.045 * w + cos(Game.wind_angle) * 0.035 * w


func _draw() -> void:
	var tex: Texture2D = Art.deco("palm%d" % _variant)
	if tex == null:
		return
	var size := tex.get_size() * _scale
	# Skugga
	draw_set_transform(Vector2(size.x * 0.25, 2), 0.0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, size.x * 0.38, Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO)
	var col := Color(0.55, 0.6, 0.55) if dark else Color(1, 1, 1)
	var r := Rect2(Vector2(-size.x * 0.5, -size.y * 0.97), size)
	if _flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	draw_texture_rect(tex, r, false, col)
	draw_set_transform(Vector2.ZERO)
