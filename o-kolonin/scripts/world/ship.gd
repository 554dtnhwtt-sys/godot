extends Node2D
## Ett segelskepp (eller ett sjöodjur). Seglar efter order, påverkas av vinden
## och manövrerar själv för att skjuta bredsidor mot fiender.

const Y_SQUASH := 0.72

var type := "slup"
var def: Dictionary = {}
var owner_id := ""
var hp := 100.0
var max_hp := 100.0
var heading := 0.0
var speed := 0.0
var velocity := Vector2.ZERO
var troops := 0.0
var max_troops := 0.0
var order := "idle"   # idle, move, attack, attack_island, colonize, trade
var target_pos := Vector2.ZERO
var target_ship = null
var target_island = null
var trade_a = null
var trade_b = null
var trade_leg := 0
var reload_l := 0.0
var reload_r := 0.0
var selected := false
var sinking := 0.0
var shown := true
var size_f := 1.0
var ai_role := ""
var last_hit := -999.0
var world = null
var _wake: Array = []
var _wake_timer := 0.0
var _t := 0.0
var _auto_target = null
var _retarget := 0.0
var _flash_l := 0.0
var _flash_r := 0.0


func setup(p_type: String, p_owner: String, pos: Vector2, p_world) -> void:
	type = p_type
	def = Data.SHIPS[type]
	owner_id = p_owner
	position = pos
	world = p_world
	max_hp = def["hp"] * Game.mod(owner_id, "ship_hp")
	hp = max_hp
	max_troops = def["troops"] * Game.mod(owner_id, "troops")
	troops = max_troops
	size_f = def["size"]
	heading = randf() * TAU
	_t = randf() * 10.0
	add_to_group("ships")


func is_alive() -> bool:
	return sinking <= 0.0 and hp > 0.0


func is_monster() -> bool:
	return def.get("monster", false)


func display_name() -> String:
	return def["name"]


# ------------------------------------------------------------------ Order
func order_move(p: Vector2) -> void:
	order = "move"
	target_pos = p
	target_ship = null
	target_island = null


func order_attack(s) -> void:
	order = "attack"
	target_ship = s
	target_island = null


func order_attack_island(isl) -> void:
	order = "attack_island"
	target_island = isl
	target_ship = null


func order_colonize(isl) -> void:
	order = "colonize"
	target_island = isl
	target_ship = null


func order_trade(a, b) -> void:
	order = "trade"
	trade_a = a
	trade_b = b
	trade_leg = 1
	target_ship = null
	target_island = null


func stop() -> void:
	order = "idle"
	target_ship = null
	target_island = null


# ------------------------------------------------------------------ Fart & vind
func wind_factor(h: float) -> float:
	var d := cos(angle_difference(h, Game.wind_angle))  # 1 = medvind, -1 = motvind
	var f := 1.0 - 0.15 * d if d >= 0.0 else 1.0 + 0.62 * d
	return f * lerpf(0.85, 1.15, clampf(Game.wind_strength - 0.5, 0.0, 1.0))


func max_speed() -> float:
	var s: float = def["speed"] * Game.mod(owner_id, "ship_speed")
	if def.get("ghost", false) or is_monster():
		return s
	s *= wind_factor(heading)
	s *= 1.0 - Game.storm * 0.3
	if hp < max_hp * 0.3:
		s *= 0.75
	return s


# ------------------------------------------------------------------ Uppdatering
func _process(delta: float) -> void:
	_t += delta
	_flash_l = maxf(0.0, _flash_l - delta)
	_flash_r = maxf(0.0, _flash_r - delta)
	if sinking > 0.0:
		sinking += delta
		if sinking > 4.0:
			world.remove_ship(self)
		queue_redraw()
		return
	var days := delta / Data.DAY_SECONDS
	var goal := _think(delta)
	_combat(delta)
	_move(delta, goal)
	_upkeep(days)
	_wake_timer -= delta
	if _wake_timer <= 0.0:
		_wake_timer = 0.12
		if speed > 15.0:
			_wake.push_front(position + Vector2.from_angle(heading + PI) * 20.0 * size_f)
		elif _wake.size() > 0:
			_wake.pop_back()
		if _wake.size() > 14:
			_wake.pop_back()
	queue_redraw()


## Bestämmer vart skeppet vill. Returnerar {"pos": Vector2, "speed": float, "face": float eller null}.
func _think(delta: float) -> Dictionary:
	var stop_goal := {"pos": position, "speed": 0.0}
	match order:
		"move":
			if position.distance_to(target_pos) < 30.0 * size_f:
				order = "idle"
				return stop_goal
			return {"pos": target_pos, "speed": max_speed()}
		"attack":
			if target_ship == null or not is_instance_valid(target_ship) or not target_ship.is_alive() or not Game.at_war(owner_id, target_ship.owner_id):
				stop()
				return stop_goal
			return _fight_goal(target_ship.position)
		"attack_island":
			var isl = target_island
			if isl == null or not Game.at_war(owner_id, isl.owner_id) or isl.owner_id == "neutral":
				stop()
				return stop_goal
			var fort = world.island_fort_target(isl, position)
			if fort != null:
				return _fight_goal(fort.global_position)
			# Inga försvar kvar: gå in och landstig eller bombardera.
			var coast: Vector2 = isl.coast_point_towards(position, 20.0)
			if position.distance_to(coast) < 70.0 * size_f:
				if troops >= 1.0:
					world.land_troops(self, isl)
				return {"pos": coast, "speed": 0.0}
			return {"pos": coast, "speed": max_speed()}
		"colonize":
			var isl = target_island
			if isl == null or isl.owner_id != "neutral":
				stop()
				return stop_goal
			var coast: Vector2 = isl.coast_point_towards(position, 20.0)
			if position.distance_to(coast) < 70.0 * size_f:
				world.try_colonize(self, isl)
				stop()
				return stop_goal
			return {"pos": coast, "speed": max_speed()}
		"trade":
			if trade_a == null or trade_b == null or trade_a.owner_id != owner_id or trade_b.owner_id != owner_id:
				stop()
				return stop_goal
			var dest = trade_b if trade_leg == 1 else trade_a
			var coast: Vector2 = dest.coast_point_towards(position, 20.0)
			if position.distance_to(coast) < 70.0 * size_f:
				world.trade_arrival(self, dest)
				trade_leg = 1 - trade_leg
			return {"pos": coast, "speed": max_speed()}
	# idle: strid om fiender är nära, annars ligg still.
	if _auto_target != null and is_instance_valid(_auto_target) and _auto_target.is_alive():
		if position.distance_to(_auto_target.position) < _range() * 1.8:
			return _fight_goal(_auto_target.position)
	return stop_goal


func _range() -> float:
	return def["range"]


## Strid: närma dig, vänd sedan bredsidan mot målet.
func _fight_goal(tp: Vector2) -> Dictionary:
	var to := tp - position
	var dist := to.length()
	var r := _range()
	if is_monster():
		return {"pos": tp, "speed": max_speed() * (0.3 if dist < r * 0.6 else 1.0)}
	if def["cannons"] == 0:
		# Obeväpnat: fly bort.
		return {"pos": position - to.normalized() * 300.0, "speed": max_speed()}
	if dist > r * 0.9:
		return {"pos": tp, "speed": max_speed()}
	var a := to.angle()
	var opt1 := a + PI * 0.5
	var opt2 := a - PI * 0.5
	var face := opt1 if absf(angle_difference(heading, opt1)) < absf(angle_difference(heading, opt2)) else opt2
	# Håll avståndet: luta in eller ut lite.
	if dist > r * 0.7:
		face = lerp_angle(face, a, 0.3)
	elif dist < r * 0.4:
		face = lerp_angle(face, a + PI, 0.3)
	return {"pos": position + Vector2.from_angle(face) * 200.0, "speed": max_speed() * 0.65}


func _combat(delta: float) -> void:
	reload_l -= delta
	reload_r -= delta
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.5 + randf() * 0.3
		_auto_target = world.nearest_hostile_ship(owner_id, position, _range() * 1.6, self)
	if is_monster():
		_monster_attack()
		return
	if def["cannons"] == 0:
		return
	var tgt = null
	var tpos := Vector2.ZERO
	var bld = null
	if order == "attack" and target_ship != null and is_instance_valid(target_ship) and target_ship.is_alive():
		tgt = target_ship
	elif order == "attack_island" and target_island != null:
		bld = world.island_fort_target(target_island, position)
		if bld != null:
			tpos = bld.global_position + Vector2(0, -10)
		elif _auto_target != null and is_instance_valid(_auto_target):
			tgt = _auto_target
	if tgt == null and bld == null and _auto_target != null and is_instance_valid(_auto_target) and _auto_target.is_alive():
		tgt = _auto_target
	if tgt != null:
		tpos = tgt.position
	elif bld == null:
		return
	var to := tpos - position
	var dist := to.length()
	if dist > _range():
		return
	var a := to.angle()
	for side in [-1, 1]:
		var normal: float = heading + side * PI * 0.5
		if absf(angle_difference(normal, a)) < 0.45:
			if side == -1 and reload_l <= 0.0:
				_broadside(side, tgt, tpos, bld)
				reload_l = _reload_time()
			elif side == 1 and reload_r <= 0.0:
				_broadside(side, tgt, tpos, bld)
				reload_r = _reload_time()


func _reload_time() -> float:
	var r: float = def["reload"] * Game.mod(owner_id, "reload")
	if Game.is_playable(owner_id) and Game.res(owner_id, "rom") > 1.0:
		r *= 0.88  # rom på skeppen ger bättre moral
	return r * randf_range(0.9, 1.1)


func _broadside(side: int, tgt, tpos: Vector2, bld) -> void:
	var n: int = def["cannons"]
	var length := 46.0 * size_f
	var dmg: float = def["damage"] * Game.mod(owner_id, "cannon_dmg")
	if Game.is_playable(owner_id) and Game.res(owner_id, "rom") > 1.0:
		dmg *= 1.1
		Game.add_res(owner_id, "rom", -0.02 * n)
	var fwd := Vector2.from_angle(heading)
	var nrm := Vector2.from_angle(heading + side * PI * 0.5)
	for i in n:
		var t := (float(i) / maxf(1, n - 1)) - 0.5 if n > 1 else 0.0
		var from := position + fwd * t * length * 0.7 + nrm * 8.0 * size_f
		from.y = position.y + (from.y - position.y) * Y_SQUASH - 8.0
		var target = tgt if tgt != null else tpos
		world.fx.fire_cannonball(from, target, dmg, owner_id, bld, i * 0.07)
		world.fx.smoke(from + nrm * 10.0, 1)
	if side == -1:
		_flash_l = 0.15
	else:
		_flash_r = 0.15


func _monster_attack() -> void:
	var tgt = _auto_target
	if order == "attack" and target_ship != null and is_instance_valid(target_ship):
		tgt = target_ship
	if tgt == null or not is_instance_valid(tgt) or not tgt.is_alive():
		return
	if position.distance_to(tgt.position) < _range() and reload_l <= 0.0:
		reload_l = def["reload"]
		tgt.take_damage(def["damage"], owner_id)
		world.fx.splash(tgt.position, 2.0)


func _move(delta: float, goal: Dictionary) -> void:
	var gp: Vector2 = goal["pos"]
	var want: float = goal["speed"]
	var to := gp - position
	var desired := heading
	if to.length() > 4.0:
		desired = to.angle()
	# Undvik öar: titta framåt och sväng längs kusten.
	var look := 70.0 + speed * 0.9
	var ahead := position + Vector2.from_angle(heading) * look
	var ahead2 := position + Vector2.from_angle(desired) * look
	for isl in world.islands:
		if position.distance_to(isl.position) > isl.radius + 260.0:
			continue
		if isl.blocks(ahead) or isl.blocks(ahead2):
			var away: Vector2 = position - isl.position
			away.y /= Y_SQUASH
			var tangent := away.orthogonal().normalized()
			if tangent.dot(Vector2.from_angle(desired)) < 0.0:
				tangent = -tangent
			# Om målet ligger på ön (landstigning): stanna närmare.
			if isl.blocks(gp) and position.distance_to(gp) < 120.0:
				want = minf(want, 20.0)
			desired = (tangent + away.normalized() * 0.35).angle()
			break
	var turn := (1.3 if not is_monster() else 1.8) / size_f
	heading = rotate_toward(heading, desired, turn * delta)
	speed = move_toward(speed, want, 45.0 * delta)
	velocity = Vector2.from_angle(heading) * speed
	var np := position + velocity * delta
	var blocked := false
	for isl in world.islands:
		if position.distance_to(isl.position) > isl.radius + 120.0:
			continue
		if isl.contains_world_point(np):
			blocked = true
			var push: Vector2 = position - isl.position
			position += push.normalized() * 30.0 * delta
			speed *= 0.5
			break
	if not blocked:
		position = np
	# Håll avstånd till egna skepp
	for other in world.ships:
		if other == self or other.owner_id != owner_id or not other.is_alive():
			continue
		var d: Vector2 = position - other.position
		var min_d: float = 34.0 * (size_f + other.size_f) * 0.5
		if d.length() < min_d and d.length() > 0.01:
			position += d.normalized() * (min_d - d.length()) * 2.0 * delta
	position.x = clampf(position.x, 40.0, Data.WORLD_SIZE.x - 40.0)
	position.y = clampf(position.y, 40.0, Data.WORLD_SIZE.y - 40.0)


func _upkeep(days: float) -> void:
	if not Game.is_playable(owner_id):
		return
	var home = world.nearest_own_island(owner_id, position, 260.0)
	if home != null and Game.time - last_hit > 8.0:
		hp = minf(max_hp, hp + max_hp * 0.03 * days)
		troops = minf(max_troops, troops + max_troops * 0.05 * days)
	elif Game.storm > 0.4 and not def.get("ghost", false):
		hp -= max_hp * 0.006 * days * Game.storm
		if hp <= 0.0:
			hp = 1.0
			take_damage(5.0, "")


func take_damage(amount: float, attacker: String) -> void:
	if not is_alive():
		return
	hp -= amount
	last_hit = Game.time
	world.fx.splinters(position)
	if hp <= 0.0:
		hp = 0.0
		sinking = 0.001
		selected = false
		world.on_ship_sunk(self, attacker)


# ------------------------------------------------------------------ Rita
func _sq(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y * Y_SQUASH)


func _draw() -> void:
	if is_monster():
		_draw_kraken()
		return
	var sink_k: float = clampf(sinking / 4.0, 0.0, 1.0)
	var L := 46.0 * size_f
	var W := 15.0 * size_f
	var fwd := Vector2.from_angle(heading)
	var right := fwd.orthogonal()
	var ghost: bool = def.get("ghost", false)
	var crystal: bool = def.get("crystal", false)
	# Kölvatten
	if _wake.size() > 1:
		for i in range(_wake.size() - 1):
			var a: Vector2 = _wake[i] - position
			var b: Vector2 = _wake[i + 1] - position
			var k := 1.0 - float(i) / _wake.size()
			draw_line(a + right * 6.0 * (1.0 - k) * size_f, b + right * 7.0 * (1.0 - k) * size_f, Color(1, 1, 1, 0.35 * k), 2.0)
			draw_line(a - right * 6.0 * (1.0 - k) * size_f, b - right * 7.0 * (1.0 - k) * size_f, Color(1, 1, 1, 0.35 * k), 2.0)
	var sink_off := Vector2(0, sink_k * 18.0)
	var shape := [Vector2(0.5, 0), Vector2(0.28, 0.5), Vector2(-0.42, 0.46), Vector2(-0.5, 0.32), Vector2(-0.5, -0.32), Vector2(-0.42, -0.46), Vector2(0.28, -0.5)]
	var hull := PackedVector2Array()
	var hull_side := PackedVector2Array()
	for p in shape:
		var w: Vector2 = fwd * p.x * L + right * p.y * W
		hull.append(_sq(w) + sink_off)
		hull_side.append(_sq(w) + Vector2(0, 7.0 * size_f) + sink_off)
	var alpha := 1.0 - sink_k * 0.8
	if ghost:
		alpha *= 0.65 + 0.15 * sin(_t * 2.0)
	# Skugga på vattnet
	var shadow := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		shadow.append(_sq(fwd * cos(a) * L * 0.55 + right * sin(a) * W * 0.8) + Vector2(10, 10))
	draw_colored_polygon(shadow, Color(0, 0.1, 0.2, 0.2 * alpha))
	var hull_c := Color(0.42, 0.28, 0.16)
	var deck_c := Color(0.72, 0.55, 0.35)
	if owner_id == "svartarevet" or owner_id == "vildpirater":
		hull_c = Color(0.18, 0.15, 0.14)
		deck_c = Color(0.4, 0.32, 0.25)
	elif ghost:
		hull_c = Color(0.2, 0.45, 0.38)
		deck_c = Color(0.35, 0.65, 0.55)
	elif crystal:
		hull_c = Color(0.3, 0.5, 0.7)
		deck_c = Color(0.75, 0.9, 1.0)
	elif owner_id == "armadan":
		hull_c = Color(0.45, 0.32, 0.12)
		deck_c = Color(0.85, 0.68, 0.3)
	draw_colored_polygon(hull_side, Color(hull_c.darkened(0.25), alpha))
	draw_colored_polygon(hull, Color(deck_c, alpha))
	var rail := hull.duplicate()
	rail.append(hull[0])
	var nat := Data.nation_color(owner_id)
	draw_polyline(rail, Color(nat, alpha), 2.5 * size_f, true)
	# Kanonluckor (mynningsflammor)
	if _flash_l > 0.0 or _flash_r > 0.0:
		var side := -1.0 if _flash_l > 0.0 else 1.0
		for i in 3:
			var t := (i - 1) * 0.3
			var fp := _sq(fwd * t * L + right * side * W * 0.65) + sink_off
			draw_circle(fp, 5.0, Color(1, 0.85, 0.3, 0.9))
	# Master och segel
	var masts: int = def["masts"]
	var offsets := [0.05]
	if masts == 2:
		offsets = [0.22, -0.18]
	elif masts == 3:
		offsets = [0.3, 0.02, -0.26]
	var mast_h := 40.0 * size_f
	var sail_c := Color(0.97, 0.95, 0.88)
	if owner_id == "svartarevet" or owner_id == "vildpirater":
		sail_c = Color(0.22, 0.2, 0.2)
	elif ghost:
		sail_c = Color(0.6, 1.0, 0.85)
	elif crystal:
		sail_c = Color(0.7, 0.95, 1.0)
	elif owner_id == "armadan":
		sail_c = Color(0.95, 0.85, 0.5)
	var wind_push := _sq(Vector2.from_angle(Game.wind_angle)) * (3.0 + Game.wind_strength * 2.0) * size_f
	var perp := _sq(right)
	for mi in masts:
		var base := _sq(fwd * offsets[mi] * L) + sink_off
		var h := mast_h * (1.0 if mi != masts - 1 or masts == 1 else 0.85)
		draw_line(base, base + Vector2(0, -h), Color(0.3, 0.2, 0.12, alpha), 2.5)
		for si in 2:
			var hw := W * (1.05 if si == 0 else 0.8)
			var y_bot := h * (0.18 if si == 0 else 0.58)
			var y_top := h * (0.55 if si == 0 else 0.9)
			var sx := perp.x * hw
			if absf(sx) < hw * 0.45:
				sx = (1.0 if sx >= 0.0 else -1.0) * hw * 0.45
			var sy := perp.y * hw * 0.5
			var off := Vector2(sx, sy)
			var tl := base + Vector2(0, -y_top) + off
			var tr := base + Vector2(0, -y_top) - off
			var br := base + Vector2(0, -y_bot) - off
			var bl := base + Vector2(0, -y_bot) + off
			var mid_b := (br + bl) * 0.5 + wind_push
			var mid_t := (tl + tr) * 0.5 + wind_push * 0.5
			var sc := sail_c.darkened(0.08 * si)
			if hp < max_hp * 0.4 and si == 1:
				sc = sc.darkened(0.25)
			var sfill := Color(sc, alpha * (0.95 if not ghost else 0.6))
			var cols := PackedColorArray([sfill, sfill, sfill, sfill])
			# Två fyrhörningar istället för en polygon – klarar även segel som ses från sidan.
			draw_primitive(PackedVector2Array([tl, mid_t, mid_b, bl]), cols, PackedVector2Array())
			draw_primitive(PackedVector2Array([mid_t, tr, br, mid_b]), cols, PackedVector2Array())
			draw_polyline(PackedVector2Array([tl, mid_t, tr]), Color(0.3, 0.2, 0.12, alpha * 0.8), 1.5)
		if mi == 0:
			var top := base + Vector2(0, -h - 2)
			var wv := sin(_t * 6.0) * 2.0
			var fdir := _sq(Vector2.from_angle(Game.wind_angle)) * 16.0
			draw_colored_polygon(PackedVector2Array([top, top + fdir + Vector2(0, wv), top + fdir + Vector2(0, 7 + wv), top + Vector2(0, 7)]), Color(nat, alpha))
	if crystal or ghost:
		var gc := Color(0.5, 1.0, 0.8, 0.15) if ghost else Color(0.5, 0.9, 1.0, 0.15)
		draw_circle(Vector2(0, -mast_h * 0.4), L * 0.7, gc)
	# Markering och statusrad
	if selected:
		var ring := PackedVector2Array()
		for i in 25:
			var a := TAU * i / 24.0
			ring.append(Vector2(cos(a) * L * 0.65, sin(a) * L * 0.65 * Y_SQUASH * 0.7) + Vector2(0, 4))
		draw_polyline(ring, Color(0.6, 1.0, 0.6, 0.9), 2.0, true)
	if sinking <= 0.0 and (selected or hp < max_hp - 0.5):
		var bw := 40.0 * size_f
		var by := -mast_h - 14.0
		draw_rect(Rect2(-bw * 0.5, by, bw, 5), Color(0, 0, 0, 0.6))
		var hc := Color(0.4, 0.9, 0.4) if hp > max_hp * 0.5 else (Color(0.95, 0.8, 0.3) if hp > max_hp * 0.25 else Color(0.95, 0.3, 0.25))
		draw_rect(Rect2(-bw * 0.5, by, bw * hp / max_hp, 5), hc)
		if selected and max_troops > 0.0:
			draw_rect(Rect2(-bw * 0.5, by + 6, bw * troops / max_troops, 3), Color(0.85, 0.85, 1.0))
	if sinking > 0.0:
		for i in 4:
			var k := fmod(_t * 1.5 + i * 0.25, 1.0)
			draw_circle(Vector2(sin(i * 2.3) * 14.0, -k * 20.0 + 10.0), 3.0 + k * 2.0, Color(1, 1, 1, 0.5 * (1.0 - k)))


func _draw_kraken() -> void:
	var sink_k: float = clampf(sinking / 4.0, 0.0, 1.0)
	var a := 1.0 - sink_k
	var body := Color(0.45, 0.15, 0.35, a)
	var R := 34.0 * size_f
	draw_circle(Vector2(8, 10), R * 1.1, Color(0, 0.05, 0.1, 0.25 * a))
	for i in 8:
		var ang := TAU * i / 8.0 + sin(_t * 0.7 + i) * 0.3
		var prev := Vector2.ZERO
		for s in range(1, 8):
			var k := s / 7.0
			var p := Vector2.from_angle(ang + sin(_t * 2.0 + i + s * 0.6) * 0.35 * k) * R * (0.6 + k * 1.9)
			p.y *= Y_SQUASH
			p.y -= sin(k * PI) * 26.0
			draw_line(prev, p, body.lightened(0.1 * (s % 2)), (14.0 - s * 1.6) * size_f * 0.5, true)
			prev = p
	draw_circle(Vector2(0, -12), R * 0.7, body)
	draw_circle(Vector2(-10, -18), 5, Color(1, 0.9, 0.3, a))
	draw_circle(Vector2(10, -18), 5, Color(1, 0.9, 0.3, a))
	draw_circle(Vector2(-10, -18), 2, Color(0, 0, 0, a))
	draw_circle(Vector2(10, -18), 2, Color(0, 0, 0, a))
	if sinking <= 0.0 and hp < max_hp - 0.5:
		draw_rect(Rect2(-40, -70, 80, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-40, -70, 80 * hp / max_hp, 6), Color(0.85, 0.3, 0.6))
