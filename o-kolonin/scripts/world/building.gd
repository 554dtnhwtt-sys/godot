extends Node2D
## En byggnad på en ö, ritad snett uppifrån. Bygger sig själv, producerar
## (via World) och kanonbatterier skjuter på fiender.

var type := ""
var island = null
var owner_id := ""
var slot_index := -1
var progress := 0.0
var built := false
var hp := 150.0
var max_hp := 150.0
var reload := 0.0
var ruined := false
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	max_hp = 400.0 if type == "radhus" else (260.0 if type == "kanonbatteri" else 150.0)
	hp = max_hp
	_seed = randf() * 10.0


func def() -> Dictionary:
	return Data.BUILDINGS[type]


func is_active() -> bool:
	return built and not ruined


func _process(delta: float) -> void:
	_t += delta
	var days := delta / Data.DAY_SECONDS
	if not built:
		progress += days / max(0.5, def().get("time", 6.0))
		if progress >= 1.0:
			progress = 1.0
			built = true
			if owner_id == Game.player and Game.world:
				Game.say("%s är färdigbyggd på %s." % [def()["name"], island.display_name], Color(0.7, 0.95, 0.7))
	elif ruined:
		if Game.time - island.last_attacked > 20.0:
			hp += max_hp * 0.02 * days
			if hp >= max_hp * 0.5:
				ruined = false
	elif hp < max_hp and Game.time - island.last_attacked > 10.0:
		hp = min(max_hp, hp + max_hp * 0.01 * days)
	if is_active() and def().has("fort"):
		_fort_logic(delta)
	queue_redraw()


func _fort_logic(delta: float) -> void:
	reload -= delta
	if reload > 0.0 or Game.world == null:
		return
	var f: Dictionary = def()["fort"]
	var target = Game.world.nearest_hostile_ship(owner_id, global_position, f["range"])
	if target == null:
		reload = 0.5
		return
	var dmg: float = f["damage"] * Game.mod(owner_id, "fort")
	Game.world.fx.fire_cannonball(global_position + Vector2(0, -24), target, dmg, owner_id, null)
	Game.world.fx.smoke(global_position + Vector2(0, -24), 2)
	reload = f["reload"] * randf_range(0.85, 1.15)


func take_damage(amount: float) -> void:
	if not built:
		progress = max(0.0, progress - amount / 100.0)
		return
	hp -= amount
	island.last_attacked = Game.time
	if hp <= 0.0:
		hp = 0.0
		ruined = true


# ------------------------------------------------------------------ Rita
func _box(x: float, w: float, h: float, d: float, wall: Color, roof: Color, thatch := false) -> void:
	var l := x - w * 0.5
	var r := x + w * 0.5
	draw_rect(Rect2(l, -h, w, h), wall)
	draw_rect(Rect2(l, -h, w, h * 0.25), wall.darkened(0.15))
	var rh := d * 0.6
	var roof_pts := PackedVector2Array([Vector2(l - 4, -h + 2), Vector2(r + 4, -h + 2), Vector2(r - w * 0.12, -h - rh), Vector2(l + w * 0.12, -h - rh)])
	draw_colored_polygon(roof_pts, roof)
	draw_line(Vector2(l + w * 0.12, -h - rh), Vector2(r - w * 0.12, -h - rh), roof.lightened(0.25), 2.0)
	if thatch:
		for i in 4:
			var yy := -h + 2 - rh * (i + 1) / 5.0
			draw_line(Vector2(l, yy), Vector2(r, yy), roof.darkened(0.2), 1.0)
	# Dörr
	draw_rect(Rect2(x - 3, -10, 6, 10), Color(0.3, 0.2, 0.12))


func _shadow(w: float) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(Vector2(cos(a) * w * 0.65 + 6, sin(a) * w * 0.22 + 2))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.2))


func _flag(p: Vector2, h: float) -> void:
	draw_line(p, p + Vector2(0, -h), Color(0.35, 0.25, 0.15), 2.0)
	var wave := sin(_t * 4.0 + _seed) * 2.0
	var top := p + Vector2(0, -h)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(18, 2 + wave), top + Vector2(18, 12 + wave), top + Vector2(0, 10)]), Data.nation_color(owner_id))
	draw_line(top + Vector2(2, 5), top + Vector2(16, 6 + wave), Data.nation_accent(owner_id), 2.0)


func _smoke(p: Vector2, col := Color(0.6, 0.6, 0.6)) -> void:
	for i in 3:
		var k := fmod(_t * 0.4 + i / 3.0 + _seed, 1.0)
		draw_circle(p + Vector2(k * 14.0 + sin(_t + i) * 3.0, -k * 40.0), 4.0 + k * 7.0, Color(col, 0.5 * (1.0 - k)))


func _draw() -> void:
	var roof_c := Data.nation_color(owner_id).lerp(Color(0.6, 0.25, 0.18), 0.35)
	var wall := Color(0.93, 0.88, 0.76)
	var wood := Color(0.6, 0.42, 0.25)
	var straw := Color(0.86, 0.72, 0.4)
	if not built:
		_shadow(44)
		_draw_construction()
		return
	if ruined:
		modulate = Color(0.55, 0.5, 0.48)
	else:
		modulate = Color(1, 1, 1)
	match type:
		"radhus":
			_shadow(90)
			draw_rect(Rect2(-46, -20, 92, 20), Color(0.72, 0.68, 0.6))
			for tx in [-46, 34]:
				draw_rect(Rect2(tx, -34, 12, 34), Color(0.65, 0.6, 0.53))
				for k in 3:
					draw_rect(Rect2(tx + k * 4, -38, 3, 4), Color(0.65, 0.6, 0.53))
			for k in 10:
				draw_rect(Rect2(-34 + k * 7, -24, 4, 4), Color(0.72, 0.68, 0.6))
			_box(0, 44, 30, 26, wall, roof_c)
			draw_rect(Rect2(-14, -24, 6, 8), Color(0.35, 0.55, 0.75))
			draw_rect(Rect2(8, -24, 6, 8), Color(0.35, 0.55, 0.75))
			_flag(Vector2(0, -50), 30)
		"bosattning":
			_shadow(50)
			_box(-12, 24, 16, 18, Color(0.85, 0.75, 0.55), straw, true)
			_box(14, 20, 14, 16, Color(0.9, 0.8, 0.6), straw.darkened(0.1), true)
		"skogshuggare":
			_shadow(52)
			_box(-8, 26, 16, 18, wood.lightened(0.2), straw, true)
			for k in 3:
				var ly := -4.0 - k * 5.0
				draw_line(Vector2(10, ly), Vector2(28, ly), wood.darkened(0.1 * k), 5.0)
				draw_circle(Vector2(28, ly), 2.5, Color(0.85, 0.7, 0.45))
		"kokosodling":
			_shadow(56)
			for row in 2:
				for k in 3:
					var p := Vector2(-20 + k * 20, -2 + row * 10)
					draw_line(p, p + Vector2(0, -16), wood, 3.0)
					for a in 5:
						var ang := -PI * 0.5 + (a - 2) * 0.7
						draw_line(p + Vector2(0, -16), p + Vector2(0, -16) + Vector2(cos(ang), sin(ang) * 0.6 + 0.3) * 10.0, Color(0.25, 0.65, 0.3), 3.0)
			draw_circle(Vector2(26, 2), 5, Color(0.55, 0.4, 0.2))
		"fiskehydda":
			_shadow(44)
			for k in 3:
				draw_line(Vector2(-12 + k * 12, 0), Vector2(-12 + k * 12, -8), wood.darkened(0.3), 3.0)
			draw_set_transform(Vector2(0, -8))
			_box(0, 30, 14, 16, wood.lightened(0.25), straw, true)
			draw_set_transform(Vector2.ZERO)
			for k in 4:
				draw_line(Vector2(18 + k * 3, -18), Vector2(18 + k * 3, -2), Color(0.85, 0.85, 0.8, 0.8), 1.0)
				draw_line(Vector2(18, -18 + k * 4), Vector2(28, -18 + k * 4), Color(0.85, 0.85, 0.8, 0.8), 1.0)
		"stenbrott":
			_shadow(56)
			var pit := PackedVector2Array()
			for i in 14:
				var a := TAU * i / 14.0
				pit.append(Vector2(cos(a) * 26, sin(a) * 11))
			draw_colored_polygon(pit, Color(0.45, 0.44, 0.45))
			for k in 4:
				draw_rect(Rect2(-22 + k * 11, -8 - (k % 2) * 6, 9, 8), Color(0.7, 0.7, 0.72))
			draw_line(Vector2(20, -2), Vector2(26, -20), wood, 2.0)
		"sandtakt":
			_shadow(50)
			draw_colored_polygon(PackedVector2Array([Vector2(-28, 2), Vector2(-14, -16), Vector2(0, 2)]), Color(1.0, 0.92, 0.7))
			draw_colored_polygon(PackedVector2Array([Vector2(-4, 2), Vector2(10, -12), Vector2(24, 2)]), Color(0.96, 0.88, 0.66))
			draw_rect(Rect2(14, -8, 14, 6), wood)
			draw_circle(Vector2(16, -1), 3, Color(0.2, 0.2, 0.2))
		"sockerplantage":
			_shadow(56)
			for k in 9:
				var x := -26 + k * 6
				draw_line(Vector2(x, 2), Vector2(x + sin(_t + k) * 1.5, -20), Color(0.5, 0.75, 0.3), 2.5)
			_box(22, 14, 12, 12, wood.lightened(0.2), straw, true)
		"romdestilleri":
			_shadow(56)
			_box(-6, 34, 22, 20, Color(0.7, 0.55, 0.4), roof_c)
			draw_rect(Rect2(6, -42, 7, 20), Color(0.5, 0.35, 0.28))
			_smoke(Vector2(10, -44))
			for k in 2:
				draw_circle(Vector2(20 + k * 9, -5), 5, Color(0.5, 0.32, 0.18))
				draw_line(Vector2(15 + k * 9, -5), Vector2(25 + k * 9, -5), Color(0.3, 0.2, 0.1), 1.0)
		"kryddgard":
			_shadow(54)
			for k in 4:
				var p := Vector2(-22 + k * 13, -2 + (k % 2) * 5)
				draw_circle(p + Vector2(0, -6), 7, Color(0.28, 0.55, 0.25))
				draw_circle(p + Vector2(2, -8), 2, Color(0.95, 0.35, 0.2))
				draw_circle(p + Vector2(-3, -4), 2, Color(0.95, 0.6, 0.2))
			draw_line(Vector2(-26, -20), Vector2(24, -20), wood, 2.0)
		"parldykare":
			_shadow(46)
			_box(-8, 22, 14, 14, wood.lightened(0.3), straw, true)
			draw_colored_polygon(PackedVector2Array([Vector2(8, -2), Vector2(30, -2), Vector2(26, 4), Vector2(12, 4)]), wood.darkened(0.2))
			draw_circle(Vector2(-18, 2), 3, Color(1, 0.95, 0.95))
			draw_circle(Vector2(-12, 4), 2.5, Color(1, 0.9, 0.9))
		"kristallgruva", "guldgruva":
			_shadow(56)
			draw_colored_polygon(PackedVector2Array([Vector2(-30, 2), Vector2(-20, -24), Vector2(4, -32), Vector2(26, -18), Vector2(30, 2)]), Color(0.55, 0.52, 0.5))
			draw_colored_polygon(PackedVector2Array([Vector2(-8, 2), Vector2(-8, -14), Vector2(0, -20), Vector2(8, -14), Vector2(8, 2)]), Color(0.12, 0.1, 0.1))
			draw_line(Vector2(-9, 2), Vector2(-9, -15), wood, 3.0)
			draw_line(Vector2(9, 2), Vector2(9, -15), wood, 3.0)
			draw_line(Vector2(-10, -16), Vector2(10, -16), wood, 3.0)
			if type == "kristallgruva":
				var g := 0.6 + 0.4 * sin(_t * 2.5 + _seed)
				for k in 3:
					var p := Vector2(16 + k * 5, -2)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(0, -12 - k * 3), p + Vector2(3, 0)]), Color(0.5, 0.9, 1.0, 0.7 + 0.3 * g))
			else:
				draw_rect(Rect2(14, -8, 14, 8), wood.darkened(0.2))
				for k in 3:
					draw_circle(Vector2(17 + k * 4, -9), 2.5, Color(1, 0.84, 0.3))
		"marknad":
			_shadow(60)
			var cols := [Color(0.9, 0.3, 0.25), Color(0.25, 0.55, 0.85), Color(0.95, 0.75, 0.2)]
			for k in 3:
				var x := -24 + k * 24
				draw_line(Vector2(x - 9, 0), Vector2(x - 9, -16), wood, 2.0)
				draw_line(Vector2(x + 9, 0), Vector2(x + 9, -16), wood, 2.0)
				draw_rect(Rect2(x - 9, -8, 18, 6), wood.lightened(0.2))
				for s in 3:
					draw_colored_polygon(PackedVector2Array([Vector2(x - 11 + s * 7.3, -16), Vector2(x - 11 + (s + 1) * 7.3, -16), Vector2(x - 11 + (s + 1) * 7.3, -22), Vector2(x - 11 + s * 7.3, -22)]), cols[k] if s % 2 == 0 else Color(1, 1, 0.95))
		"akademi":
			_shadow(60)
			draw_rect(Rect2(-28, -24, 56, 24), Color(0.96, 0.95, 0.9))
			for k in 5:
				draw_rect(Rect2(-24 + k * 11, -22, 4, 20), Color(0.85, 0.84, 0.8))
			draw_rect(Rect2(-30, -28, 60, 5), Color(0.9, 0.88, 0.82))
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				dome.append(Vector2(cos(a) * 16, -28 + sin(a) * 16))
			draw_colored_polygon(dome, Color(0.45, 0.7, 0.75))
			draw_circle(Vector2(0, -46), 2.5, Data.nation_accent(owner_id))
		"skeppsvarv":
			_shadow(70)
			draw_colored_polygon(PackedVector2Array([Vector2(-36, 4), Vector2(36, 4), Vector2(30, -6), Vector2(-30, -6)]), wood)
			for k in 7:
				var x := -20 + k * 7
				var hh := 14.0 - abs(k - 3) * 2.5
				draw_arc(Vector2(x, -6), hh, PI, TAU, 8, wood.darkened(0.3), 2.0)
			draw_line(Vector2(-26, -6), Vector2(26, -6), wood.darkened(0.4), 3.0)
			draw_line(Vector2(30, -6), Vector2(30, -40), wood.darkened(0.2), 2.0)
			draw_line(Vector2(30, -40), Vector2(10, -30), wood.darkened(0.2), 1.5)
			_flag(Vector2(-32, -6), 26)
		"kanonbatteri":
			_shadow(60)
			var wall_pts := PackedVector2Array()
			for i in 11:
				var a := PI + PI * i / 10.0
				wall_pts.append(Vector2(cos(a) * 30, sin(a) * 12 - 4))
			wall_pts.append(Vector2(30, 4))
			wall_pts.append(Vector2(-30, 4))
			draw_colored_polygon(wall_pts, Color(0.62, 0.58, 0.52))
			draw_rect(Rect2(-30, -12, 60, 8), Color(0.7, 0.66, 0.6))
			for k in 2:
				var cx := -10 + k * 20
				draw_line(Vector2(cx, -14), Vector2(cx + 4, -26), Color(0.15, 0.15, 0.17), 6.0)
				draw_circle(Vector2(cx, -12), 5, Color(0.35, 0.25, 0.15))
			_flag(Vector2(26, -12), 22)
		"fyrtorn":
			_shadow(40)
			for k in 5:
				var y0 := -k * 14.0
				var c := Color(0.95, 0.95, 0.92) if k % 2 == 0 else Color(0.85, 0.25, 0.2)
				draw_colored_polygon(PackedVector2Array([Vector2(-10 + k, y0), Vector2(10 - k, y0), Vector2(9 - k, y0 - 14), Vector2(-9 + k, y0 - 14)]), c)
			draw_rect(Rect2(-7, -82, 14, 12), Color(1, 0.95, 0.6, 0.8 + 0.2 * sin(_t * 3.0)))
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -82), Vector2(9, -82), Vector2(0, -92)]), Color(0.3, 0.3, 0.32))
			var beam_a := _t * 1.2
			var beam := Vector2(cos(beam_a), sin(beam_a) * 0.4) * 90.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, -76), Vector2(0, -76) + beam + beam.orthogonal() * 0.15, Vector2(0, -76) + beam - beam.orthogonal() * 0.15]), Color(1, 0.95, 0.6, 0.18))
		"glasbruk":
			_shadow(56)
			var kiln := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				kiln.append(Vector2(cos(a) * 20 - 6, sin(a) * 22))
			draw_colored_polygon(kiln, Color(0.7, 0.45, 0.35))
			draw_circle(Vector2(-6, -6), 6, Color(1.0, 0.55 + 0.2 * sin(_t * 6.0), 0.15))
			draw_rect(Rect2(10, -40, 7, 38), Color(0.55, 0.38, 0.3))
			_smoke(Vector2(13, -42), Color(0.7, 0.7, 0.72))
			for k in 3:
				draw_circle(Vector2(22 + k * 5, -3), 3, Color(0.6, 0.9, 0.85, 0.8))
		_:
			_shadow(40)
			_box(0, 28, 18, 16, wall, roof_c)
	if ruined:
		_smoke(Vector2(0, -20), Color(0.25, 0.25, 0.25))
		draw_circle(Vector2(-4, -10), 5 + sin(_t * 9.0) * 1.5, Color(1, 0.5, 0.1, 0.8))
	if hp < max_hp - 1.0:
		draw_rect(Rect2(-20, 8, 40, 4), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-20, 8, 40 * hp / max_hp, 4), Color(0.9, 0.3, 0.25))


func _draw_construction() -> void:
	var wood := Color(0.6, 0.42, 0.25)
	var h := 30.0 * progress + 6.0
	draw_rect(Rect2(-18, -h * 0.6, 36, h * 0.6), Color(0.85, 0.78, 0.62, 0.8))
	for x in [-20, 0, 20]:
		draw_line(Vector2(x, 0), Vector2(x, -36), wood, 2.0)
	draw_line(Vector2(-20, -18), Vector2(20, -18), wood, 2.0)
	draw_line(Vector2(-20, -34), Vector2(20, -34), wood, 2.0)
	draw_line(Vector2(-20, 0), Vector2(0, -18), wood.darkened(0.2), 1.5)
	draw_rect(Rect2(-22, 8, 44, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-22, 8, 44 * progress, 5), Color(0.95, 0.8, 0.3))
